#!/usr/bin/env bash
# LLM Benchmarking Component Dispatcher

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BENCHMARK_DIR="${PROJECT_ROOT}/benchmark"

show_help() {
    cat << 'EOF'
aiw benchmark - LLM Performance Benchmarking

Usage:
  aiw benchmark <model>

Example:
  aiw benchmark qwen3:8b

Options:
  -h, --help  Print usage information
EOF
}

if [[ $# -eq 0 ]]; then
    show_help
    exit 0
fi

case "$1" in
    -h|--help|help)
        show_help
        exit 0
        ;;
    *)
        if [[ -x "${BENCHMARK_DIR}/ollama.sh" ]]; then
            exec "${BENCHMARK_DIR}/ollama.sh" "$@"
        elif [[ -f "${BENCHMARK_DIR}/ollama.sh" ]]; then
            exec bash "${BENCHMARK_DIR}/ollama.sh" "$@"
        else
            echo "Error: Benchmark runner script '${BENCHMARK_DIR}/ollama.sh' not found." >&2
            exit 1
        fi
        ;;
esac

