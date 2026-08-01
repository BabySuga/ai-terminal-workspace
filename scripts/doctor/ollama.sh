#!/usr/bin/env bash
# Module: ollama.sh - Validate Ollama binary availability

check_ollama() {
    if command -v ollama >/dev/null 2>&1; then
        return 0
    fi
    return 1
}
