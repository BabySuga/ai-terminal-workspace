#!/usr/bin/env bash
# Module: config.sh - Validate configuration manager system

check_config() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_root="$(cd "${script_dir}/../.." && pwd)"
    local resolver="${project_root}/config/resolver.py"
    if [[ -f "${resolver}" ]] && command -v python3 >/dev/null 2>&1; then
        if python3 "${resolver}" get-endpoint >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}
