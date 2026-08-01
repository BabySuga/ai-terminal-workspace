#!/usr/bin/env bash
# Module: ollama.sh - Validate Ollama binary existence and server reachability

check_ollama() {
    if ! command -v ollama >/dev/null 2>&1; then
        return 1
    fi
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_root="$(cd "${script_dir}/../.." && pwd)"
    local resolver="${project_root}/config/resolver.py"
    local host=""
    if [[ -f "${resolver}" ]] && command -v python3 >/dev/null 2>&1; then
        host=$(python3 "${resolver}" get-endpoint 2>/dev/null || echo "")
    fi
    if [[ -z "${host}" ]]; then
        host="${AIW_OLLAMA_ENDPOINT:-${OLLAMA_HOST:-http://127.0.0.1:11434}}"
    fi
    if command -v curl >/dev/null 2>&1; then
        if curl -s -f --connect-timeout 2 "${host}/api/version" >/dev/null 2>&1; then
            return 0
        fi
    elif ollama list >/dev/null 2>&1; then
        return 0
    fi

    return 1
}
