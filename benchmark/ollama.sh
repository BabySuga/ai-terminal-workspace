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
  aiw benchmark qwen3:8b hermes3:8b
  aiw benchmark --all
  aiw benchmark --repeat 3 qwen3:8b

Options:
  -a, --all        Benchmark all installed Ollama models
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
    python3 - "${RESOLVED_ENDPOINT}" << 'PYEOF'
import json, urllib.request, subprocess, sys
endpoint = sys.argv[1]
try:
    req = urllib.request.Request(f"{endpoint}/api/tags")
    with urllib.request.urlopen(req, timeout=5) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        models = [m["name"] for m in data.get("models", [])]
        if models:
            print("\n".join(models))
            sys.exit(0)
except Exception:
    pass

try:
    out = subprocess.check_output(["ollama", "list"], text=True, stderr=subprocess.DEVNULL)
    lines = out.strip().split("\n")
    models = []
    for line in lines[1:]:
        parts = line.split()
        if parts:
            models.append(parts[0])
    if models:
        print("\n".join(models))
        sys.exit(0)
except Exception:
    pass
PYEOF
}

run_single_benchmark() {
    local model="$1"

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

    # 1. GPU metrics BEFORE benchmark
    local gpu_before_json
    gpu_before_json=$(get_gpu_metrics)
    local vram_before
    vram_before=$(parse_vram "${gpu_before_json}")
    local power_before
    power_before=$(parse_power "${gpu_before_json}")

    # 2. Run streaming benchmark via python HTTP streaming client
    local bench_result
    bench_result=$(python3 - "${model}" "${prompt}" "${RESOLVED_ENDPOINT}" << 'PYEOF'
import sys, json, time, urllib.request, urllib.error, socket

model = sys.argv[1]
prompt = sys.argv[2]
endpoint = sys.argv[3]
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
        return 1
    fi

    if echo "${bench_result}" | jq -e '.error' >/dev/null 2>&1; then
        local err_msg
        err_msg=$(echo "${bench_result}" | jq -r '.error')
        echo "Error: ${err_msg}" >&2
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
    local ttft_ms gen_speed latency_s chars words approx_tokens
    ttft_ms=$(echo "${bench_result}" | jq -r '.ttft_ms')
    gen_speed=$(echo "${bench_result}" | jq -r '.gen_speed_tok_s')
    latency_s=$(echo "${bench_result}" | jq -r '.latency_s')
    chars=$(echo "${bench_result}" | jq -r '.chars')
    words=$(echo "${bench_result}" | jq -r '.words')
    approx_tokens=$(echo "${bench_result}" | jq -r '.approx_tokens')

    # 4. Display benchmark summary for this single run
    echo "Benchmark"
    echo "--------------------------"
    printf "%-18s : %s\n" "Model" "${model}"
    printf "%-18s : %d ms\n" "TTFT" "${ttft_ms}"
    printf "%-18s : %d tok/s\n" "Generation Speed" "${gen_speed}"
    printf "%-18s : %.2f s\n" "Latency" "${latency_s}"
    printf "%-18s : %d\n" "Characters" "${chars}"
    printf "%-18s : %d\n" "Words" "${words}"
    printf "%-18s : %d\n" "Approx Tokens" "${approx_tokens}"
    echo ""
    echo "GPU Before"
    echo "VRAM : ${vram_before}"
    echo "Power : ${power_before}"
    echo ""
    echo "GPU After"
    echo "VRAM : ${vram_after}"
    echo "Power : ${power_after}"

    # Return metric values for caller
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
        mapfile -t models < <(get_installed_models)
        if [[ ${#models[@]} -eq 0 ]]; then
            echo "Error: No installed Ollama models found." >&2
            exit 1
        fi
    elif [[ ${#models[@]} -eq 0 ]]; then
        # Launch Interactive TUI
        local tui_res
        tui_res=$(python3 "${TUI_SCRIPT}" --endpoint "${RESOLVED_ENDPOINT}")
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

        RESULT_TTFT_MS=""
        RESULT_GEN_SPEED=""
        RESULT_LATENCY_S=""

        if run_single_benchmark "${model}"; then
            summary_json=$(python3 - "${summary_json}" "${model}" "${RESULT_TTFT_MS}" "${RESULT_GEN_SPEED}" "${RESULT_LATENCY_S}" << 'PYEOF'
import sys, json
results = json.loads(sys.argv[1])
model = sys.argv[2]
ttft_ms = float(sys.argv[3])
gen_speed = float(sys.argv[4])
latency_s = float(sys.argv[5])
results.append({
    "model": model,
    "ttft_ms": ttft_ms,
    "gen_speed": gen_speed,
    "latency_s": latency_s
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

    # Print concise summary table
    python3 - "${summary_json}" << 'PYEOF'
import sys, json

results = json.loads(sys.argv[1])
if not results:
    sys.exit(0)

print("")
print("Summary")
print("")
print(f"%-21s %-9s %-9s %s" % ("Model", "TTFT", "TPS", "Latency"))
print("-" * 48)
for r in results:
    model = r["model"]
    if r.get("error"):
        ttft_str = "Error"
        tps_str = "Error"
        lat_str = "Error"
    else:
        ttft_str = f"%.2fs" % (r["ttft_ms"] / 1000.0)
        tps_str = "%d" % int(r["gen_speed"])
        lat_str = f"%.1fs" % r["latency_s"]
    print(f"%-21s %-9s %-9s %s" % (model, ttft_str, tps_str, lat_str))
PYEOF
}

main "$@"
