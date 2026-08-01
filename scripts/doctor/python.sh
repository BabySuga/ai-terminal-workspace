#!/usr/bin/env bash
# Module: python.sh - Validate Python 3 installation

check_python() {
    if command -v python3 >/dev/null 2>&1; then
        return 0
    fi
    return 1
}
