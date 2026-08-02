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
  aiw benchmark [options] [model ...]

Examples:
  aiw benchmark
  aiw benchmark qwen3:8b
  aiw benchmark --cold qwen3:8b
  aiw benchmark --all
  aiw benchmark --include-cloud --all
  aiw benchmark --repeat 3 qwen3:8b

Options:
  -a, --all        Benchmark all installed Ollama models (local generative by default)
  --include-cloud  Include cloud and remote models when benchmarking --all
  --cold           Unload target model before benchmarking for reproducible cold start
  -r, --repeat N   Repeat benchmark queue N times
  -h, --help       Print usage information
EOF
}

if [[ $# -gt 0 ]]; then
    case "$1" in
        -h|--help|help)
            show_help
            exit 0
            ;;
        *)
            ;;
    esac
fi

if [[ -x "${BENCHMARK_DIR}/ollama.sh" ]]; then
    exec "${BENCHMARK_DIR}/ollama.sh" "$@"
elif [[ -f "${BENCHMARK_DIR}/ollama.sh" ]]; then
    exec bash "${BENCHMARK_DIR}/ollama.sh" "$@"
else
    echo "Error: Benchmark runner script '${BENCHMARK_DIR}/ollama.sh' not found." >&2
    exit 1
fi

