#!/usr/bin/env bash
# Module: gpu.sh - Validate AMD GPU availability

check_gpu() {
    if command -v amd-smi >/dev/null 2>&1 || [ -c /dev/kfd ] || [ -d /sys/class/drm ]; then
        return 0
    fi
    return 1
}
