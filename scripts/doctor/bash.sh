#!/usr/bin/env bash
# Module: bash.sh - Validate Bash environment and version

check_bash() {
    if command -v bash >/dev/null 2>&1 && [[ -n "${BASH_VERSION:-}" ]]; then
        # Require Bash 4.0 or higher
        local major_version="${BASH_VERSINFO[0]:-0}"
        if [[ "$major_version" -ge 4 ]]; then
            return 0
        fi
    fi
    return 1
}
