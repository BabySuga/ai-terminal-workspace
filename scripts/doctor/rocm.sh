#!/usr/bin/env bash
# Module: rocm.sh - Validate ROCm environment

check_rocm() {
    if command -v rocminfo >/dev/null 2>&1 || command -v amd-smi >/dev/null 2>&1 || [ -c /dev/kfd ] || [ -d /opt/rocm ]; then
        return 0
    fi
    return 1
}
