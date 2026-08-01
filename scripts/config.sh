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
        python3 "${RESOLVER_SCRIPT}" show "$@"
        ;;
    test)
        python3 "${RESOLVER_SCRIPT}" test "$@"
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
