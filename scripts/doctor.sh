#!/usr/bin/env bash
# Entrypoint for AIW Doctor Environment & Configuration Validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCTOR_DIR="${SCRIPT_DIR}/doctor"

# Source all validation modules
# shellcheck source=scripts/doctor/bash.sh
source "${DOCTOR_DIR}/bash.sh"
# shellcheck source=scripts/doctor/python.sh
source "${DOCTOR_DIR}/python.sh"
# shellcheck source=scripts/doctor/jq.sh
source "${DOCTOR_DIR}/jq.sh"
# shellcheck source=scripts/doctor/curl.sh
source "${DOCTOR_DIR}/curl.sh"
# shellcheck source=scripts/doctor/ollama.sh
source "${DOCTOR_DIR}/ollama.sh"
# shellcheck source=scripts/doctor/gpu.sh
source "${DOCTOR_DIR}/gpu.sh"
# shellcheck source=scripts/doctor/rocm.sh
source "${DOCTOR_DIR}/rocm.sh"
# shellcheck source=scripts/doctor/endpoint.sh
source "${DOCTOR_DIR}/endpoint.sh"
# shellcheck source=scripts/doctor/config.sh
source "${DOCTOR_DIR}/config.sh"
# shellcheck source=scripts/doctor/summary.sh
source "${DOCTOR_DIR}/summary.sh"

run_validation() {
    local names=("Bash" "Python" "jq" "curl" "Ollama" "AMD GPU" "ROCm" "Endpoint" "Configuration")
    local check_funcs=("check_bash" "check_python" "check_jq" "check_curl" "check_ollama" "check_gpu" "check_rocm" "check_endpoint" "check_config")
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
