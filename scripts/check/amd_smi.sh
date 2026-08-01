#!/usr/bin/env bash
# Module: amd_smi.sh - Validate amd-smi availability

check_amd_smi() {
    if command -v amd-smi >/dev/null 2>&1; then
        return 0
    fi
    return 1
}
