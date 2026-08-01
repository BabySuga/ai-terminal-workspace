#!/usr/bin/env bash
# Entrypoint for Preflight Environment Validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_DIR="${SCRIPT_DIR}/check"

# Source all validation modules
# shellcheck source=scripts/check/bash.sh
source "${CHECK_DIR}/bash.sh"
# shellcheck source=scripts/check/tmux.sh
source "${CHECK_DIR}/tmux.sh"
# shellcheck source=scripts/check/jq.sh
source "${CHECK_DIR}/jq.sh"
# shellcheck source=scripts/check/amd_smi.sh
source "${CHECK_DIR}/amd_smi.sh"
# shellcheck source=scripts/check/ollama.sh
source "${CHECK_DIR}/ollama.sh"
# shellcheck source=scripts/check/sensors.sh
source "${CHECK_DIR}/sensors.sh"
# shellcheck source=scripts/check/summary.sh
source "${CHECK_DIR}/summary.sh"

run_validation() {
    local names=("Bash" "tmux" "jq" "amd-smi" "Ollama" "lm-sensors")
    local check_funcs=("check_bash" "check_tmux" "check_jq" "check_amd_smi" "check_ollama" "check_sensors")
    local statuses=()
    local missing=()

    local i
    for i in "${!names[@]}"; do
        local name="${names[$i]}"
        local func="${check_funcs[$i]}"

        if "$func"; then
            statuses+=(0)
        else
            statuses+=(1)
            missing+=("${name}")
        fi
    done

    print_summary names statuses missing

    if [[ ${#missing[@]} -gt 0 ]]; then
        return 1
    fi
    return 0
}

run_validation "$@"
