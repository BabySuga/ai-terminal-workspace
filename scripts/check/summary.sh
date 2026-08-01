#!/usr/bin/env bash
# Module: summary.sh - Format and display preflight check summary output

print_summary() {
    local -n _names=$1
    local -n _statuses=$2
    local -n _missing=$3

    echo "================================="
    echo "AI Terminal Workspace"
    echo "Environment Validation"
    echo "================================="
    echo ""

    local i
    for i in "${!_names[@]}"; do
        local name="${_names[$i]}"
        local status="${_statuses[$i]}"
        if [[ "$status" -eq 0 ]]; then
            echo "✔ ${name}"
        else
            echo "✖ ${name}"
        fi
        echo ""
    done

    echo "---------------------------------"
    echo ""

    if [[ ${#_missing[@]} -eq 0 ]]; then
        echo "Environment Ready"
    else
        echo "Missing dependencies:"
        echo ""
        local item
        for item in "${_missing[@]}"; do
            echo "- ${item}"
        done
    fi
}
