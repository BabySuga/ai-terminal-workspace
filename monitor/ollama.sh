#!/usr/bin/env bash
# Module: monitor/ollama.sh - Local Ollama runtime monitoring

set -euo pipefail

OLLAMA_VERSION=""
SERVER_STATUS="stopped"
LOADED_MODELS=0
RUNNING_MODELS_JSON="[]"

check_dependencies() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq is not installed or not available in PATH." >&2
        return 1
    fi

    if ! command -v ollama >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
        echo "Error: Ollama is not installed or not available in PATH." >&2
        return 1
    fi

    return 0
}

collect_metrics() {
    local host="${OLLAMA_HOST:-http://localhost:11434}"
    local api_version_raw=""

    if command -v curl >/dev/null 2>&1; then
        api_version_raw=$(curl -s -f --connect-timeout 2 "${host}/api/version" 2>/dev/null || true)
    fi

    if [[ -n "${api_version_raw}" ]]; then
        SERVER_STATUS="running"
        OLLAMA_VERSION=$(echo "${api_version_raw}" | jq -r '.version // empty' 2>/dev/null || true)
    else
        SERVER_STATUS="stopped"
        if command -v ollama >/dev/null 2>&1; then
            local cli_version_raw
            cli_version_raw=$(ollama --version 2>/dev/null || true)
            OLLAMA_VERSION=$(echo "${cli_version_raw}" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+[^ ]*' || echo "")
        fi
    fi

    if [[ "${SERVER_STATUS}" == "running" && -n "${api_version_raw}" ]]; then
        local api_ps_raw=""
        api_ps_raw=$(curl -s -f --connect-timeout 2 "${host}/api/ps" 2>/dev/null || true)

        if [[ -n "${api_ps_raw}" ]]; then
            RUNNING_MODELS_JSON=$(echo "${api_ps_raw}" | jq -c '
                def fmt_size(s):
                  if s == null or s == 0 then null
                  elif s >= 1073741824 then
                    (((s / 1073741824 * 10) | round) / 10 | tostring) + " GB"
                  elif s >= 1048576 then
                    (((s / 1048576 * 10) | round) / 10 | tostring) + " MB"
                  elif s >= 1024 then
                    (((s / 1024 * 10) | round) / 10 | tostring) + " KB"
                  else
                    (s | tostring) + " B"
                  end;

                def fmt_processor(s; vram):
                  if s == null or s == 0 then null
                  elif vram == null or vram == 0 then "100% CPU"
                  elif vram >= s then "100% GPU"
                  else
                    (((vram / s * 100) | round | tostring) + "% GPU / " + (((s - vram) / s * 100) | round | tostring) + "% CPU")
                  end;

                (.models // []) | map({
                  model_name: (.name // .model // null),
                  processor: fmt_processor(.size; .size_vram),
                  size: fmt_size(.size),
                  quantization: (.details.quantization_level // null),
                  context_length: (.context_length // null),
                  expires_at: (.expires_at // null)
                })
            ' 2>/dev/null || echo "[]")
        fi
    fi

    LOADED_MODELS=$(echo "${RUNNING_MODELS_JSON}" | jq 'length' 2>/dev/null || echo "0")
    return 0
}

print_pretty() {
    local status_display
    if [[ "${SERVER_STATUS}" == "running" ]]; then
        status_display="Running"
    else
        status_display="Stopped"
    fi

    local version_display="${OLLAMA_VERSION:-N/A}"
    if [[ -z "${version_display}" ]]; then
        version_display="N/A"
    fi

    echo "Ollama"
    echo "----------------------------"
    echo ""
    printf "%-14s : %s\n" "Version" "${version_display}"
    printf "%-14s : %s\n" "Status" "${status_display}"
    echo ""
    echo "Loaded Models"
    echo ""

    if [[ "${LOADED_MODELS}" -gt 0 ]]; then
        jq -r '
            .[] |
            "• \(.model_name // "Unknown")",
            "  Processor    : \(.processor // "N/A")",
            "  Size         : \(.size // "N/A")",
            "  Quantization : \(.quantization // "N/A")",
            "  Context      : \(.context_length // "N/A")\n"
        ' <<< "${RUNNING_MODELS_JSON}"
    else
        echo "No models loaded."
        echo ""
    fi

    printf "%-12s : %s\n" "Total Models" "${LOADED_MODELS}"
}

print_json() {
    jq -n \
        --arg ver "${OLLAMA_VERSION}" \
        --arg status "${SERVER_STATUS}" \
        --argjson models "${RUNNING_MODELS_JSON}" \
        --argjson count "${LOADED_MODELS}" \
        '{
            ollama: {
                version: (if $ver == "" then null else $ver end),
                status: $status,
                running_models: $models,
                loaded_models: $count
            }
        }'
}

main() {
    local json_output=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json)
                json_output=true
                shift
                ;;
            -h|--help)
                echo "Usage: monitor/ollama.sh [--json]"
                exit 0
                ;;
            *)
                echo "Error: Unknown argument '$1'" >&2
                exit 1
                ;;
        esac
    done

    if ! check_dependencies; then
        exit 1
    fi

    if ! collect_metrics; then
        exit 1
    fi

    if [[ "${json_output}" == true ]]; then
        print_json
    else
        print_pretty
    fi
}

main "$@"
