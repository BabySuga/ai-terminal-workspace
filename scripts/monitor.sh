#!/usr/bin/env bash
# Telemetry Monitoring Dispatcher

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MONITOR_DIR="${PROJECT_ROOT}/monitor"

show_help() {
    cat << 'EOF'
aiw monitor - Workstation Telemetry Monitoring

Usage:
  aiw monitor <component> [options]

Available Components:
  gpu         Monitor GPU telemetry (amd-smi)
  ollama      Monitor local Ollama runtime

Options:
  --json      Output metrics in JSON format matching docs/schema.md
  -h, --help  Print usage information
EOF
}

if [[ $# -eq 0 ]]; then
    show_help
    exit 0
fi

subcommand="$1"
shift

case "${subcommand}" in
    gpu)
        if [[ -x "${MONITOR_DIR}/gpu.sh" ]]; then
            exec "${MONITOR_DIR}/gpu.sh" "$@"
        else
            exec bash "${MONITOR_DIR}/gpu.sh" "$@"
        fi
        ;;
    ollama)
        if [[ -x "${MONITOR_DIR}/ollama.sh" ]]; then
            exec "${MONITOR_DIR}/ollama.sh" "$@"
        else
            exec bash "${MONITOR_DIR}/ollama.sh" "$@"
        fi
        ;;
    -h|--help|help)
        show_help
        ;;
    *)
        echo "Error: Unknown monitor component '${subcommand}'" >&2
        echo "" >&2
        show_help
        exit 1
        ;;
esac

