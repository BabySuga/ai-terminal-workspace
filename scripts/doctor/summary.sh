#!/usr/bin/env bash
# Module: summary.sh - Format and display doctor status output

print_summary() {
    local -n _names=$1
    local -n _statuses=$2
    local -n _missing=$3

    echo "AIW Doctor"
    echo ""

    local i
    for i in "${!_names[@]}"; do
        local name="${_names[$i]}"
        local status="${_statuses[$i]}"
        if [[ "$status" -eq 0 ]]; then
            echo "✓ ${name}"
        else
            echo "✗ ${name}"
        fi
    done

    echo ""
    echo "Status"

    if [[ ${#_missing[@]} -eq 0 ]]; then
        echo "READY"
    else
        echo "NOT READY"
    fi
}
