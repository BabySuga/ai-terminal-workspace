#!/usr/bin/env bash
# Module: benchmark/ollama.sh - Benchmark local Ollama models with streaming API

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MONITOR_GPU="${PROJECT_ROOT}/monitor/gpu.sh"
PROMPT_FILE="${PROJECT_ROOT}/config/prompts/default.txt"
TUI_SCRIPT="${SCRIPT_DIR}/tui.py"
RESOLVER="${PROJECT_ROOT}/config/resolver.py"
RESOLVED_ENDPOINT=""

show_help() {
    cat << 'EOF'
aiw benchmark - LLM Performance Benchmarking

Usage:
  aiw benchmark [options] [model ...]

Examples:
  aiw benchmark
  aiw benchmark qwen3:8b
  aiw benchmark --cold qwen3:8b
  aiw benchmark --all
  aiw benchmark --include-cloud --all
  aiw benchmark --repeat 3 qwen3:8b

Options:
  -a, --all        Benchmark all installed Ollama models (local generative by default)
  --include-cloud  Include cloud and remote models when benchmarking --all
  --cold           Unload target model before benchmarking for reproducible cold start
  -r, --repeat N   Repeat benchmark queue N times
  --endpoint URL   Override Ollama endpoint URL
  -h, --help       Print usage information
EOF
}

check_dependencies() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq is not installed or not available in PATH." >&2
        return 1
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        echo "Error: python3 is not installed or not available in PATH." >&2
        return 1
    fi

    if ! command -v ollama >/dev/null 2>&1; then
        echo "Error: ollama is not installed or not available in PATH." >&2
        return 1
    fi

    return 0
}

get_gpu_metrics() {
    local json_output=""
    if [[ -x "${MONITOR_GPU}" ]]; then
        json_output=$("${MONITOR_GPU}" --json 2>/dev/null || true)
    elif [[ -f "${MONITOR_GPU}" ]]; then
        json_output=$(bash "${MONITOR_GPU}" --json 2>/dev/null || true)
    fi
    echo "${json_output}"
}

parse_vram() {
    local json_data="$1"
    if [[ -n "${json_data}" ]] && echo "${json_data}" | jq empty 2>/dev/null; then
        echo "${json_data}" | jq -r '
            if .gpu.vram_used_mb != null and .gpu.vram_total_mb != null then
                "\(.gpu.vram_used_mb) / \(.gpu.vram_total_mb) MB"
            elif .gpu.vram_used_mb != null then
                "\(.gpu.vram_used_mb) MB"
            else
                "N/A"
            end
        ' 2>/dev/null || echo "N/A"
    else
        echo "N/A"
    fi
}

parse_power() {
    local json_data="$1"
    if [[ -n "${json_data}" ]] && echo "${json_data}" | jq empty 2>/dev/null; then
        echo "${json_data}" | jq -r '
            if .gpu.power_w != null then
                "\(.gpu.power_w) W"
            else
                "N/A"
            end
        ' 2>/dev/null || echo "N/A"
    else
        echo "N/A"
    fi
}

get_installed_models() {
    local inc_cloud="$1"
    python3 - "${RESOLVED_ENDPOINT}" "${inc_cloud}" << 'PYEOF'
import json, urllib.request, subprocess, sys

endpoint = sys.argv[1]
include_cloud = sys.argv[2].lower() == "true" if len(sys.argv) > 2 else False

def is_embedding(model_name, show_data):
    name_lower = model_name.lower()
    if any(k in name_lower for k in ["embed", "bge", "minilm", "e5-"]):
        return True
    if show_data:
        minfo = show_data.get("model_info", {})
        gtype = minfo.get("general.type", "").lower()
        arch = minfo.get("general.architecture", "").lower()
        family = show_data.get("details", {}).get("family", "").lower()
        families = [f.lower() for f in show_data.get("details", {}).get("families", []) or []]
        if gtype == "embedding" or "bert" in arch or "bert" in family or any("bert" in f for f in families):
            return True
        if "embedding" in arch or "embedding" in family or any("embedding" in f for f in families):
            return True
    return False

def is_cloud(model_name, show_data):
    name_lower = model_name.lower()
    if "-cloud" in name_lower or ":cloud" in name_lower or "cloud" in name_lower or "-remote" in name_lower or ":remote" in name_lower:
        return True
    if show_data:
        fmt = show_data.get("details", {}).get("format", "")
        if fmt == "":
            return True
    return False

raw_models = []
try:
    req = urllib.request.Request(f"{endpoint}/api/tags")
    with urllib.request.urlopen(req, timeout=5) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        raw_models = [m["name"] for m in data.get("models", [])]
except Exception:
    pass

if not raw_models:
    try:
        out = subprocess.check_output(["ollama", "list"], text=True, stderr=subprocess.DEVNULL)
        lines = out.strip().split("\n")
        for line in lines[1:]:
            parts = line.split()
            if parts:
                raw_models.append(parts[0])
    except Exception:
        pass

filtered_models = []
for model in raw_models:
    show_data = None
    try:
        sreq = urllib.request.Request(f"{endpoint}/api/show", data=json.dumps({"name": model}).encode("utf-8"), headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(sreq, timeout=3) as sresp:
            show_data = json.loads(sresp.read().decode("utf-8"))
    except Exception:
        pass

    if is_embedding(model, show_data):
        continue

    if not include_cloud and is_cloud(model, show_data):
        continue

    filtered_models.append(model)

if filtered_models:
    print("\n".join(filtered_models))
PYEOF
}

run_single_benchmark() {
    local model="$1"
    local cold_mode="${2:-false}"

    if [[ ! -f "${PROMPT_FILE}" ]]; then
        echo "Error: Benchmark prompt file '${PROMPT_FILE}' not found." >&2
        return 1
    fi

    local prompt
    prompt=$(cat "${PROMPT_FILE}")

    if [[ -z "${prompt}" ]]; then
        echo "Error: Benchmark prompt file '${PROMPT_FILE}' is empty." >&2
        return 1
    fi

    if [[ "${cold_mode}" == "true" ]]; then
        local unload_ok
        unload_ok=$(python3 - "${model}" "${RESOLVED_ENDPOINT}" << 'PYEOF'
import sys, json, urllib.request, subprocess
model = sys.argv[1]
endpoint = sys.argv[2]

try:
    payload = json.dumps({"model": model, "keep_alive": 0}).encode("utf-8")
    req = urllib.request.Request(f"{endpoint}/api/generate", data=payload, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=10) as resp:
        resp.read()
    print("true")
except Exception:
    try:
        res = subprocess.run(["ollama", "stop", model], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
        if res.returncode == 0:
            print("true")
        else:
            print("false")
    except Exception:
        print("false")
PYEOF
)
        if [[ "${unload_ok}" != "true" ]]; then
            echo "Warning: Could not unload model '${model}' before benchmark." >&2
        fi
    fi

    # 1. GPU metrics BEFORE benchmark
    local gpu_before_json
    gpu_before_json=$(get_gpu_metrics)
    local vram_before
    vram_before=$(parse_vram "${gpu_before_json}")
    local power_before
    power_before=$(parse_power "${gpu_before_json}")

    # 2. Run benchmark check & streaming generate call via python client
    local bench_result
    bench_result=$(python3 - "${model}" "${prompt}" "${RESOLVED_ENDPOINT}" << 'PYEOF'
import sys, json, time, urllib.request, urllib.error, socket

model = sys.argv[1]
prompt = sys.argv[2]
endpoint = sys.argv[3]

# 1. Check if model is loaded (Warm vs Cold)
is_warm = False
try:
    req = urllib.request.Request(f"{endpoint}/api/ps")
    with urllib.request.urlopen(req, timeout=5) as resp:
        ps_data = json.loads(resp.read().decode("utf-8"))
        loaded_models = [m.get("name", "") for m in ps_data.get("models", [])] + \
                        [m.get("model", "") for m in ps_data.get("models", [])]
        if model in loaded_models:
            is_warm = True
except Exception:
    pass

start_mode = "Warm" if is_warm else "Cold"

# 2. Check if embedding model
show_data = None
try:
    sreq = urllib.request.Request(f"{endpoint}/api/show", data=json.dumps({"name": model}).encode("utf-8"), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(sreq, timeout=5) as sresp:
        show_data = json.loads(sresp.read().decode("utf-8"))
except Exception:
    pass

is_embedding = False
model_lower = model.lower()
if any(k in model_lower for k in ["embed", "bge", "minilm", "e5-"]):
    is_embedding = True
elif show_data:
    minfo = show_data.get("model_info", {})
    gtype = minfo.get("general.type", "").lower()
    arch = minfo.get("general.architecture", "").lower()
    family = show_data.get("details", {}).get("family", "").lower()
    families = [f.lower() for f in show_data.get("details", {}).get("families", []) or []]
    if gtype == "embedding" or "bert" in arch or "bert" in family or any("bert" in f for f in families):
        is_embedding = True
    elif "embedding" in arch or "embedding" in family or any("embedding" in f for f in families):
        is_embedding = True

if is_embedding:
    print(json.dumps({
        "skipped": True,
        "reason": "Embedding model (generate API unsupported)"
    }))
    sys.exit(0)

# 3. Text generation benchmark
url = f"{endpoint}/api/generate"
payload = json.dumps({
    "model": model,
    "prompt": prompt,
    "stream": True
}).encode("utf-8")

req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"})

start_time = time.perf_counter()
first_token_time = None
chunks = []
eval_count = None

try:
    with urllib.request.urlopen(req, timeout=120) as resp:
        for line in resp:
            line_str = line.decode("utf-8").strip()
            if not line_str:
                continue
            now = time.perf_counter()
            data = json.loads(line_str)
            
            if "error" in data:
                print(json.dumps({"error": data["error"]}))
                sys.exit(0)
                
            chunk = data.get("response", "") or data.get("thinking", "")
            if chunk and first_token_time is None:
                first_token_time = now
            if chunk:
                chunks.append(chunk)
            if data.get("done"):
                eval_count = data.get("eval_count")

    end_time = time.perf_counter()
    
    if first_token_time is None:
        ttft_ms = 0
        gen_time = end_time - start_time
    else:
        ttft_ms = (first_token_time - start_time) * 1000.0
        gen_time = end_time - first_token_time

    total_latency_s = end_time - start_time
    text = "".join(chunks)
    chars = len(text)
    words = len(text.split())
    
    if eval_count is not None and eval_count > 0:
        approx_tokens = eval_count
    else:
        approx_tokens = int(words * 1.35)

    if gen_time > 0 and approx_tokens > 0:
        gen_speed = approx_tokens / gen_time
    else:
        gen_speed = 0.0

    result = {
        "success": True,
        "start_mode": start_mode,
        "ttft_ms": round(ttft_ms),
        "gen_speed_tok_s": round(gen_speed),
        "latency_s": round(total_latency_s, 2),
        "chars": chars,
        "words": words,
        "approx_tokens": approx_tokens
    }
    print(json.dumps(result))

except urllib.error.HTTPError as e:
    err_msg = f"HTTP error {e.code}"
    try:
        err_body = e.read().decode("utf-8", errors="replace")
        err_data = json.loads(err_body)
        if "error" in err_data:
            err_msg = err_data["error"]
    except Exception:
        pass
    print(json.dumps({"error": err_msg}))
    sys.exit(0)

except urllib.error.URLError as e:
    if isinstance(e.reason, socket.timeout):
        print(json.dumps({"error": "Benchmark request timed out."}))
    else:
        print(json.dumps({"error": f"Ollama service is stopped or unreachable at {endpoint}."}))
    sys.exit(0)

except (socket.timeout, TimeoutError):
    print(json.dumps({"error": "Benchmark request timed out."}))
    sys.exit(0)

except Exception as e:
    print(json.dumps({"error": f"Stream interrupted: {str(e)}"}))
    sys.exit(0)
PYEOF
) || true

    if [[ -z "${bench_result}" ]]; then
        echo "Error: Failed to execute benchmark for ${model}." >&2
        RESULT_STATUS="error"
        return 1
    fi

    if echo "${bench_result}" | jq -e '.skipped' >/dev/null 2>&1; then
        local reason
        reason=$(echo "${bench_result}" | jq -r '.reason // "Generate API unsupported"')
        echo "Skipped"
        echo ""
        echo "Reason"
        echo "${reason}"
        RESULT_STATUS="skipped"
        return 0
    fi

    if echo "${bench_result}" | jq -e '.error' >/dev/null 2>&1; then
        local err_msg
        err_msg=$(echo "${bench_result}" | jq -r '.error')
        echo "Error: ${err_msg}" >&2
        RESULT_STATUS="error"
        return 1
    fi

    # 3. GPU metrics AFTER benchmark
    local gpu_after_json
    gpu_after_json=$(get_gpu_metrics)
    local vram_after
    vram_after=$(parse_vram "${gpu_after_json}")
    local power_after
    power_after=$(parse_power "${gpu_after_json}")

    # Parse metrics
    local start_mode ttft_ms gen_speed latency_s chars words approx_tokens
    start_mode=$(echo "${bench_result}" | jq -r '.start_mode')
    ttft_ms=$(echo "${bench_result}" | jq -r '.ttft_ms')
    gen_speed=$(echo "${bench_result}" | jq -r '.gen_speed_tok_s')
    latency_s=$(echo "${bench_result}" | jq -r '.latency_s')
    chars=$(echo "${bench_result}" | jq -r '.chars')
    words=$(echo "${bench_result}" | jq -r '.words')
    approx_tokens=$(echo "${bench_result}" | jq -r '.approx_tokens')

    # 4. Display benchmark summary for this single run
    # shellcheck source=lib/table.sh
    source "${PROJECT_ROOT}/lib/table.sh"

    local metrics=(
        "Model"
        "Start Mode"
        "TTFT"
        "Generation Speed"
        "Latency"
        "Characters"
        "Words"
        "Approx Tokens"
    )
    local vals=(
        "${model}"
        "${start_mode}"
        "$(printf "%.0f ms" "${ttft_ms}")"
        "$(printf "%.0f tok/s" "${gen_speed}")"
        "$(printf "%.2f s" "${latency_s}")"
        "$(printf "%.0f" "${chars}")"
        "$(printf "%.0f" "${words}")"
        "$(printf "%.0f" "${approx_tokens}")"
    )

    print_kv_table --title "Benchmark Results" --headers "Metric" "Value" --align2 R --min-width1 17 --min-width2 20 metrics vals

    local gpu_headers=("Metric" "Before" "After")
    local gpu_aligns=("L" "R" "R")
    local gpu_data=(
        "VRAM" "${vram_before}" "${vram_after}"
        "Power" "${power_before}" "${power_after}"
    )

    print_table --title "GPU Telemetry" --min-widths "17 18 18" gpu_headers gpu_aligns gpu_data

    RESULT_STATUS="success"
    RESULT_START_MODE="${start_mode}"
    RESULT_TTFT_MS="${ttft_ms}"
    RESULT_GEN_SPEED="${gen_speed}"
    RESULT_LATENCY_S="${latency_s}"
    return 0
}

main() {
    if ! check_dependencies; then
        exit 1
    fi

    local run_all=false
    local include_cloud=false
    local cold_mode=false
    local repeat_count=1
    local cli_endpoint=""
    local models=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -a|--all)
                run_all=true
                shift
                ;;
            --include-cloud)
                include_cloud=true
                shift
                ;;
            --cold)
                cold_mode=true
                shift
                ;;
            -r|--repeat)
                if [[ $# -lt 2 ]]; then
                    echo "Error: Option '$1' requires an argument." >&2
                    exit 1
                fi
                repeat_count="$2"
                shift 2
                ;;
            --repeat=*)
                repeat_count="${1#*=}"
                shift
                ;;
            --endpoint)
                if [[ $# -lt 2 ]]; then
                    echo "Error: Option '$1' requires an argument." >&2
                    exit 1
                fi
                cli_endpoint="$2"
                shift 2
                ;;
            --endpoint=*)
                cli_endpoint="${1#*=}"
                shift
                ;;
            -*)
                echo "Error: Unknown option '$1'" >&2
                show_help
                exit 1
                ;;
            *)
                models+=("$1")
                shift
                ;;
        esac
    done

    if [[ -f "${RESOLVER}" ]] && command -v python3 >/dev/null 2>&1; then
        RESOLVED_ENDPOINT=$(python3 "${RESOLVER}" get-endpoint ${cli_endpoint:+--endpoint "${cli_endpoint}"})
    else
        RESOLVED_ENDPOINT="${cli_endpoint:-${AIW_OLLAMA_ENDPOINT:-${OLLAMA_HOST:-http://127.0.0.1:11434}}}"
    fi

    # Build initial list of models
    if [[ "${run_all}" == "true" ]]; then
        mapfile -t models < <(get_installed_models "${include_cloud}")
        if [[ ${#models[@]} -eq 0 ]]; then
            echo "Error: No installed Ollama models found matching benchmark criteria." >&2
            exit 1
        fi
    elif [[ ${#models[@]} -eq 0 ]]; then
        # Launch Interactive TUI
        local tui_res
        local tui_status=0
        tui_res=$(python3 "${TUI_SCRIPT}" --endpoint "${RESOLVED_ENDPOINT}") || tui_status=$?

        if [[ ${tui_status} -ne 0 ]]; then
            exit 1
        fi

        if [[ -z "${tui_res}" ]] || [[ "${tui_res}" == "[]" ]]; then
            exit 0
        fi

        mapfile -t models < <(python3 -c "import sys, json; print('\n'.join(json.loads(sys.argv[1])))" "${tui_res}")
        if [[ ${#models[@]} -eq 0 ]]; then
            exit 0
        fi
    fi

    # Build queue considering repeat_count
    local queue=()
    for (( r=0; r<repeat_count; r++ )); do
        for m in "${models[@]}"; do
            queue+=("$m")
        done
    done

    local total_models=${#queue[@]}
    if [[ ${total_models} -eq 0 ]]; then
        exit 0
    fi

    local summary_json="[]"

    for (( i=0; i<total_models; i++ )); do
        local model="${queue[$i]}"
        local current=$((i + 1))

        echo "Queue"
        echo "${current}/${total_models}"
        echo ""
        echo "Benchmarking"
        echo "${model}"
        echo "↓"

        RESULT_STATUS=""
        RESULT_START_MODE=""
        RESULT_TTFT_MS=""
        RESULT_GEN_SPEED=""
        RESULT_LATENCY_S=""

        run_single_benchmark "${model}" "${cold_mode}" || true

        if [[ "${RESULT_STATUS}" == "success" ]]; then
            summary_json=$(python3 - "${summary_json}" "${model}" "${RESULT_TTFT_MS}" "${RESULT_GEN_SPEED}" "${RESULT_LATENCY_S}" << 'PYEOF'
import sys, json
results = json.loads(sys.argv[1])
model = sys.argv[2]
ttft_ms = float(sys.argv[3])
gen_speed = float(sys.argv[4])
latency_s = float(sys.argv[5])
results.append({
    "model": model,
    "status": "success",
    "ttft_ms": ttft_ms,
    "gen_speed": gen_speed,
    "latency_s": latency_s
})
print(json.dumps(results))
PYEOF
)
        elif [[ "${RESULT_STATUS}" == "skipped" ]]; then
            summary_json=$(python3 - "${summary_json}" "${model}" << 'PYEOF'
import sys, json
results = json.loads(sys.argv[1])
model = sys.argv[2]
results.append({
    "model": model,
    "status": "skipped",
    "skipped": True
})
print(json.dumps(results))
PYEOF
)
        else
            summary_json=$(python3 - "${summary_json}" "${model}" << 'PYEOF'
import sys, json
results = json.loads(sys.argv[1])
model = sys.argv[2]
results.append({
    "model": model,
    "status": "error",
    "error": True
})
print(json.dumps(results))
PYEOF
)
        fi

        echo ""
        echo "Completed"
        if [[ ${current} -lt ${total_models} ]]; then
            echo "↓"
            echo ""
        fi
    done

    # Print concise summary table and summary footer
    # shellcheck source=lib/table.sh
    source "${PROJECT_ROOT}/lib/table.sh"

    local summary_count
    summary_count=$(echo "${summary_json}" | jq 'length' 2>/dev/null || echo "0")

    if (( summary_count > 0 )); then
        local headers=("Model" "TTFT" "TPS" "Latency")
        local aligns=("L" "R" "R" "R")
        local data=()

        local successful_count
        successful_count=$(echo "${summary_json}" | jq '[.[] | select(.status == "success")] | length')
        local skipped_count
        skipped_count=$(echo "${summary_json}" | jq '[.[] | select(.status == "skipped")] | length')
        local failed_count
        failed_count=$(echo "${summary_json}" | jq '[.[] | select(.status == "error")] | length')
        local total_latency_sum
        total_latency_sum=$(echo "${summary_json}" | jq '[.[] | select(.status == "success") | .latency_s] | add // 0')

        mapfile -t model_rows < <(echo "${summary_json}" | jq -r '.[] | [.model, (if .status == "skipped" then "Skipped" elif .status == "error" then "Error" else (((.ttft_ms / 1000 * 100 | round / 100) | tostring) + "s") end), (if .status == "skipped" then "Skipped" elif .status == "error" then "Error" else (.gen_speed | round | tostring) end), (if .status == "skipped" then "Skipped" elif .status == "error" then "Error" else (((.latency_s * 10 | round / 10) | tostring) + "s") end)] | join("\t")' 2>/dev/null)

        local row
        for row in "${model_rows[@]}"; do
            IFS=$'\t' read -r m_name ttft_str tps_str lat_str <<< "${row}"
            data+=( "${m_name}" "${ttft_str}" "${tps_str}" "${lat_str}" )
        done

        print_table --title "Benchmark Summary" --row-separators --min-widths "20 10 10 10" headers aligns data

        local total_time_fmt
        total_time_fmt=$(jq -n --argjson total "${total_latency_sum}" '
            if $total >= 60 then
              (($total / 60 | floor | tostring) + "m " + ((($total % 60 | floor) | tostring) + "s"))
            else
              ((($total * 10 | round / 10) | tostring) + "s")
            end
        ' -r)

        local sum_keys=("Models Tested" "Successful" "Skipped" "Failed" "Total Time")
        local sum_vals=("${summary_count}" "${successful_count}" "${skipped_count}" "${failed_count}" "${total_time_fmt}")
        print_kv_table --title "Summary" --no-header --align2 R --min-width1 28 --min-width2 11 sum_keys sum_vals
    fi
}

main "$@"
