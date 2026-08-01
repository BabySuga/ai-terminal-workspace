#!/usr/bin/env bash
# Module: jq.sh - Validate jq availability

check_jq() {
    if command -v jq >/dev/null 2>&1; then
        return 0
    fi
    return 1
}
