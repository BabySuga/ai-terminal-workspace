#!/usr/bin/env bash
# Module: monitor/ollama.sh - Local Ollama runtime monitoring

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RESOLVER="${PROJECT_ROOT}/config/resolver.py"
RESOLVED_ENDPOINT=""

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
    local host="${RESOLVED_ENDPOINT}"
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

    # shellcheck source=lib/table.sh
    source "${PROJECT_ROOT}/lib/table.sh"

    local keys=("Version" "Status" "Loaded Models")
    local vals=("${version_display}" "${status_display}" "${LOADED_MODELS}")

    print_kv_table --title "Ollama Runtime" --headers "Metric" "Value" --align2 R --min-width1 17 --min-width2 20 keys vals

    local headers=("Model" "Processor" "Size" "Quantization" "Context")
    local aligns=("L" "L" "L" "L" "R")
    local data=()

    local count
    count=$(echo "${RUNNING_MODELS_JSON}" | jq 'length' 2>/dev/null || echo "0")

    if (( count > 0 )); then
        mapfile -t model_rows < <(echo "${RUNNING_MODELS_JSON}" | jq -r '.[] | [.model_name, .processor, .size, .quantization, (.context_length | tostring)] | map(. // "N/A") | join("\t")' 2>/dev/null)
        local row
        for row in "${model_rows[@]}"; do
            IFS=$'\t' read -r m_name m_proc m_size m_quant m_ctx <<< "${row}"
            data+=( "${m_name}" "${m_proc}" "${m_size}" "${m_quant}" "${m_ctx}" )
        done
    else
        data+=( "(No models loaded)" "-" "-" "-" "-" )
    fi

    print_table --title "Loaded Models" --min-widths "22 12 10 14 10" headers aligns data
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
    local cli_endpoint=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json)
                json_output=true
                shift
                ;;
            --endpoint)
                cli_endpoint="$2"
                shift 2
                ;;
            --endpoint=*)
                cli_endpoint="${1#*=}"
                shift
                ;;
            -h|--help)
                echo "Usage: monitor/ollama.sh [--json] [--endpoint URL]"
                exit 0
                ;;
            *)
                echo "Error: Unknown argument '$1'" >&2
                exit 1
                ;;
        esac
    done

    if [[ -f "${RESOLVER}" ]] && command -v python3 >/dev/null 2>&1; then
        RESOLVED_ENDPOINT=$(python3 "${RESOLVER}" get-endpoint ${cli_endpoint:+--endpoint "${cli_endpoint}"})
    else
        RESOLVED_ENDPOINT="${cli_endpoint:-${AIW_OLLAMA_ENDPOINT:-${OLLAMA_HOST:-http://127.0.0.1:11434}}}"
    fi

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
