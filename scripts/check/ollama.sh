#!/usr/bin/env bash
# Module: ollama.sh - Validate Ollama binary existence and server reachability

check_ollama() {
    if ! command -v ollama >/dev/null 2>&1; then
        return 1
    fi

    local host="${OLLAMA_HOST:-http://localhost:11434}"
    if command -v curl >/dev/null 2>&1; then
        if curl -s -f --connect-timeout 2 "${host}/api/version" >/dev/null 2>&1; then
            return 0
        fi
    elif ollama list >/dev/null 2>&1; then
        return 0
    fi

    return 1
}
