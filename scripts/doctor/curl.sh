#!/usr/bin/env bash
# Module: curl.sh - Validate curl availability

check_curl() {
    if command -v curl >/dev/null 2>&1; then
        return 0
    fi
    return 1
}
