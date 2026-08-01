#!/usr/bin/env bash
# Module: tmux.sh - Validate tmux availability

check_tmux() {
    if command -v tmux >/dev/null 2>&1; then
        return 0
    fi
    return 1
}
