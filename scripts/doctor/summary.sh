#!/usr/bin/env bash
# Module: summary.sh - Format and display doctor status output

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck source=lib/table.sh
source "${PROJECT_ROOT}/lib/table.sh"

print_summary() {
    local -n _names=$1
    local -n _statuses=$2
    local -n _missing=$3

    local keys=()
    local vals=()
    local i
    for i in "${!_names[@]}"; do
        keys+=("${_names[$i]}")
        if [[ ${_statuses[$i]} -eq 0 ]]; then
            vals+=("✓ OK")
        else
            vals+=("✗ FAIL")
        fi
    done

    keys+=("System Status")
    if [[ ${#_missing[@]} -eq 0 ]]; then
        vals+=("READY")
    else
        vals+=("NOT READY")
    fi

    print_kv_table --title "AIW Doctor" --headers "Component" "Status" --align2 L --sep-before-last --min-width1 25 --min-width2 12 keys vals
}
