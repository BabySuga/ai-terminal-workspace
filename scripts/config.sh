#!/usr/bin/env bash
# AI Terminal Workspace - Configuration Component Dispatcher

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RESOLVER_SCRIPT="${PROJECT_ROOT}/config/resolver.py"

show_help() {
    cat << 'EOF'
aiw config - Configuration System

Usage:
  aiw config <subcommand> [arguments]

Available Subcommands:
  init                  Create default configuration (~/.config/aiw/config.toml)
  show                  Display resolved configuration
  test                  Test configured Ollama endpoint reachability and latency
  set endpoint <url>    Update endpoint in config file
  reset                 Restore default configuration

Options:
  --endpoint <url>      Override endpoint for command execution
  -h, --help            Print usage information
EOF
}

if [[ $# -eq 0 ]]; then
    show_help
    exit 0
fi

subcmd="$1"
shift

case "${subcmd}" in
    init)
        python3 "${RESOLVER_SCRIPT}" init "$@"
        ;;
    show)
        # shellcheck source=lib/table.sh
        source "${PROJECT_ROOT}/lib/table.sh"
        show_json=$(python3 "${RESOLVER_SCRIPT}" show-data "$@")
        cfg_file=$(echo "${show_json}" | jq -r '.config_file')
        exists=$(echo "${show_json}" | jq -r '.exists')
        endpoint=$(echo "${show_json}" | jq -r '.endpoint')
        exists_str="Not Found"
        if [[ "${exists}" == "true" ]]; then exists_str="Exists"; fi
        cfg_file_val="${cfg_file} (${exists_str})"

        keys=("Config File" "Ollama Endpoint")
        vals=("${cfg_file_val}" "${endpoint}")
        print_kv_table --title "Configuration Summary" --headers "Property" "Value" --align2 L --min-width1 17 --min-width2 40 keys vals

        mapfile -t lines < <(echo "${show_json}" | jq -r '.content_lines[]')
        max_w=40
        for l in "${lines[@]}"; do
            if (( ${#l} > max_w )); then max_w=${#l}; fi
        done

        headers=()
        aligns=("L")
        data=()
        for l in "${lines[@]}"; do
            data+=( "${l}" )
        done

        print_table --title "Config File Contents" --no-header --min-widths "${max_w}" headers aligns data
        ;;
    test)
        # shellcheck source=lib/table.sh
        source "${PROJECT_ROOT}/lib/table.sh"
        test_json=$(python3 "${RESOLVER_SCRIPT}" test-data "$@")
        ep=$(echo "${test_json}" | jq -r '.endpoint')
        reach=$(echo "${test_json}" | jq -r '.reachability')
        ver=$(echo "${test_json}" | jq -r '.version')
        count=$(echo "${test_json}" | jq -r '.model_count')
        lat=$(echo "${test_json}" | jq -r '.latency')

        keys=("Endpoint" "Reachability" "Ollama Version" "Installed Model Count" "Request Latency")
        vals=("${ep}" "${reach}" "${ver}" "${count}" "${lat}")
        print_kv_table --title "Configuration Test" --headers "Parameter" "Value" --align2 L --min-width1 23 --min-width2 30 keys vals
        ;;
    set)
        if [[ $# -lt 2 ]]; then
            echo "Error: 'aiw config set' requires key and value (e.g., aiw config set endpoint http://192.168.1.20:11434)" >&2
            exit 1
        fi
        python3 "${RESOLVER_SCRIPT}" set "$@"
        ;;
    reset)
        python3 "${RESOLVER_SCRIPT}" reset "$@"
        ;;
    -h|--help|help)
        show_help
        ;;
    *)
        echo "Error: Unknown config subcommand '${subcmd}'" >&2
        echo "" >&2
        show_help
        exit 1
        ;;
esac
