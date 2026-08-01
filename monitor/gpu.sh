#!/usr/bin/env bash
# Module: monitor/gpu.sh - AMD GPU monitoring using amd-smi

set -euo pipefail

UTILIZATION_PERCENT=0
VRAM_USED_MB=0
VRAM_TOTAL_MB=0
POWER_W=0
EDGE_TEMP_C=0
HOTSPOT_TEMP_C=0
MEMORY_TEMP_C=0
FAN_RPM=0
GPU_CLOCK_MHZ=0
MEMORY_CLOCK_MHZ=0

check_dependencies() {
    if ! command -v amd-smi >/dev/null 2>&1; then
        echo "Error: amd-smi is not installed or not available in PATH." >&2
        return 1
    fi
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq is not installed or not available in PATH." >&2
        return 1
    fi
    return 0
}

collect_metrics() {
    local raw_json
    if ! raw_json=$(amd-smi metric --json 2>/dev/null); then
        echo "Error: Failed to query GPU metrics using amd-smi." >&2
        return 1
    fi

    if [[ -z "${raw_json}" ]]; then
        echo "Error: Empty output received from amd-smi." >&2
        return 1
    fi

    local parsed
    if ! parsed=$(echo "${raw_json}" | jq -r '
        .gpu_data[0] as $g |
        if $g == null then empty else
        def parse_num(v): if v != null and (v | type == "number") then v else 0 end;
        def parse_float(v): if v != null and (v | type == "number") then v else 0.0 end;
        [
          (parse_float($g.usage.gfx_activity.value)),
          (parse_num($g.mem_usage.used_vram.value) | floor),
          (parse_num($g.mem_usage.total_vram.value) | floor),
          (parse_float($g.power.socket_power.value // $g.power.average_socket_power.value)),
          (parse_float($g.temperature.edge.value)),
          (parse_float($g.temperature.hotspot.value)),
          (parse_float($g.temperature.mem.value)),
          (parse_num($g.fan.rpm) | floor),
          (parse_num($g.clock.gfx_0.clk.value) | floor),
          (parse_num($g.clock.mem_0.clk.value) | floor)
        ] | map(tostring) | join(" ")
        end
    ' 2>/dev/null) || [[ -z "${parsed}" ]]; then
        echo "Error: Unsupported GPU or invalid metric data from amd-smi." >&2
        return 1
    fi

    read -r UTILIZATION_PERCENT VRAM_USED_MB VRAM_TOTAL_MB POWER_W EDGE_TEMP_C HOTSPOT_TEMP_C MEMORY_TEMP_C FAN_RPM GPU_CLOCK_MHZ MEMORY_CLOCK_MHZ <<< "${parsed}"
    return 0
}

print_pretty() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_root
    project_root="$(cd "${script_dir}/.." && pwd)"

    # shellcheck source=lib/table.sh
    source "${project_root}/lib/table.sh"

    local metrics=(
        "Utilization"
        "VRAM"
        "Power"
        "Edge Temp"
        "Hotspot"
        "Memory Temp"
        "Fan Speed"
        "GPU Clock"
        "Mem Clock"
    )
    local vals=(
        "${UTILIZATION_PERCENT} %"
        "${VRAM_USED_MB} / ${VRAM_TOTAL_MB} MB"
        "${POWER_W} W"
        "${EDGE_TEMP_C} °C"
        "${HOTSPOT_TEMP_C} °C"
        "${MEMORY_TEMP_C} °C"
        "${FAN_RPM} RPM"
        "${GPU_CLOCK_MHZ} MHz"
        "${MEMORY_CLOCK_MHZ} MHz"
    )

    print_kv_table --title "GPU Telemetry" --headers "Metric" "Value" --align2 R --min-width1 17 --min-width2 20 metrics vals
}

print_json() {
    jq -n \
        --argjson util "${UTILIZATION_PERCENT}" \
        --argjson vused "${VRAM_USED_MB}" \
        --argjson vtotal "${VRAM_TOTAL_MB}" \
        --argjson power "${POWER_W}" \
        --argjson etemp "${EDGE_TEMP_C}" \
        --argjson htemp "${HOTSPOT_TEMP_C}" \
        --argjson mtemp "${MEMORY_TEMP_C}" \
        --argjson fan "${FAN_RPM}" \
        --argjson gclk "${GPU_CLOCK_MHZ}" \
        --argjson mclk "${MEMORY_CLOCK_MHZ}" \
        '{
            gpu: {
                utilization_percent: $util,
                vram_used_mb: $vused,
                vram_total_mb: $vtotal,
                power_w: $power,
                edge_temp_c: $etemp,
                hotspot_temp_c: $htemp,
                memory_temp_c: $mtemp,
                fan_rpm: $fan,
                gpu_clock_mhz: $gclk,
                memory_clock_mhz: $mclk
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
                echo "Usage: monitor/gpu.sh [--json]"
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
