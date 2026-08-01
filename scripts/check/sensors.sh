#!/usr/bin/env bash
# Module: sensors.sh - Validate lm-sensors availability

check_sensors() {
    if command -v sensors >/dev/null 2>&1; then
        return 0
    fi
    return 1
}
