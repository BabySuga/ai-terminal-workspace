# Metrics Contract & CLI Output Specification

## Overview

This specification defines the official metrics schema and CLI output contract for the **AI Terminal Workspace** (`aiw`). It serves as the binding contract for all current and future telemetry collectors, benchmarking engines, and reporting exporters.

By maintaining a strict abstraction layer between data collection backends and output serialization formats, this schema ensures long-term stability and backward compatibility. Transitioning internal implementation layers (e.g., from Bash/`amd-smi`/`ollama` CLI to Python, Go, Rust, or direct ROCm/C++ APIs) will **not** alter or break this JSON interface contract.

---

## Design Principles

The metric collection architecture adheres to the following foundational principles:

1. **Single Responsibility**: Each metric category (GPU, CPU, Memory, Disk, Ollama, Benchmark) represents a distinct domain. Telemetry collectors focus solely on gathering and normalizing metrics within their dedicated domain.
2. **Machine-Readable Output**: JSON is the primary serialization format for programmatic consumers, automated pipelines, logging agents, and dashboards.
3. **Human-Readable Output**: Terminal-optimized plain-text views are provided by default for interactive developer usage, formatted cleanly for immediate visual clarity.
4. **Backward Compatibility**: Existing fields in the JSON payload must remain stable over time. Fields will never be renamed or removed within the same major schema version (`v1`).
5. **Versionable Schema**: All JSON telemetry payloads include schema version metadata (`schema_version: "1.0"` within metadata) to allow clean future evolution and explicit contract migration.
6. **Stable Field Naming**: All fields use explicit, lowercase `snake_case` names appended with unit suffixes where applicable (e.g., `_percent`, `_mb`, `_w`, `_c`, `_mhz`, `_ms`, `_mb_s`).
7. **Future Extensibility**: Sub-objects and arrays permit optional, non-breaking additive fields (e.g., multi-GPU arrays or per-core CPU vectors) without invalidating existing consumers.

---

## Metrics Contract Specification

### 1. Metadata (`metadata`)

Identifies the operational environment, host context, service software versions, and collection timestamp.

| Metric Field | Description | Unit | Data Type | Example Value |
| :--- | :--- | :--- | :--- | :--- |
| `hostname` | Network hostname of the workstation | None | String | `"ai-workstation-01"` |
| `timestamp` | ISO-8601 UTC timestamp when metrics were collected | ISO-8601 | String | `"2026-08-01T18:45:00Z"` |
| `kernel_version` | Linux kernel release string | None | String | `"6.8.0-40-generic"` |
| `os_version` | Operating system distribution name and version | None | String | `"Ubuntu 24.04 LTS"` |
| `rocm_version` | Installed AMD ROCm driver runtime version | None | String | `"6.1.2"` |
| `ollama_version` | Installed Ollama inference service version | None | String | `"0.3.4"` |
| `cli_version` | Version of the `aiw` CLI dispatcher | None | String | `"0.1.0"` |

---

### 2. GPU (`gpu`)

Tracks graphics accelerator utilization, VRAM allocation, power draw, clock speeds, and thermal metrics.

| Metric Field | Description | Unit | Data Type | Example Value |
| :--- | :--- | :--- | :--- | :--- |
| `utilization_percent` | GPU compute core active utilization percentage | `%` | Number (Float) | `98.0` |
| `vram_used_mb` | Allocated video memory footprint in megabytes | `MB` | Number (Integer) | `6421` |
| `vram_total_mb` | Total physical video memory capacity in megabytes | `MB` | Number (Integer) | `16384` |
| `power_w` | Current real-time GPU board power draw in Watts | `W` | Number (Float) | `171.0` |
| `edge_temp_c` | Primary GPU die / edge temperature in Celsius | `°C` | Number (Float) | `61.0` |
| `hotspot_temp_c` | Peak GPU die junction / hotspot temperature in Celsius | `°C` | Number (Float) | `84.0` |
| `memory_temp_c` | VRAM memory module temperature in Celsius | `°C` | Number (Float) | `72.0` |
| `fan_rpm` | Cooling fan rotational speed in RPM | `RPM` | Number (Integer) | `2100` |
| `gpu_clock_mhz` | Core graphics engine clock frequency in MHz | `MHz` | Number (Integer) | `2150` |
| `memory_clock_mhz` | Video memory bus clock frequency in MHz | `MHz` | Number (Integer) | `1000` |

---

### 3. CPU (`cpu`)

Monitors central processor load, frequency, temperature, and system load averages.

| Metric Field | Description | Unit | Data Type | Example Value |
| :--- | :--- | :--- | :--- | :--- |
| `utilization_percent` | Overall CPU core aggregate utilization percentage | `%` | Number (Float) | `45.2` |
| `frequency_mhz` | Average active CPU clock frequency across cores | `MHz` | Number (Float) | `3800.0` |
| `temperature_c` | CPU package / die temperature in Celsius | `°C` | Number (Float) | `58.5` |
| `load_average` | System load average over 1, 5, and 15 minute intervals | Ratio | Array of Floats | `[2.15, 1.85, 1.42]` |

---

### 4. Memory (`memory`)

Measures main system RAM allocations and swap space utilization.

| Metric Field | Description | Unit | Data Type | Example Value |
| :--- | :--- | :--- | :--- | :--- |
| `used_mb` | Active system physical RAM memory footprint | `MB` | Number (Integer) | `28416` |
| `total_mb` | Total installed physical RAM memory capacity | `MB` | Number (Integer) | `65536` |
| `available_mb` | Free physical memory available for immediate allocation | `MB` | Number (Integer) | `37120` |
| `swap_used_mb` | Allocated swap space footprint in megabytes | `MB` | Number (Integer) | `512` |
| `swap_total_mb` | Total configured system swap space capacity | `MB` | Number (Integer) | `16384` |

---

### 5. Disk (`disk`)

Measures storage subsystem space capacity and real-time I/O throughput rates.

| Metric Field | Description | Unit | Data Type | Example Value |
| :--- | :--- | :--- | :--- | :--- |
| `usage_percent` | Primary workspace storage volume utilization percentage | `%` | Number (Float) | `62.4` |
| `read_mb_s` | Disk read throughput rate in megabytes per second | `MB/s` | Number (Float) | `124.5` |
| `write_mb_s` | Disk write throughput rate in megabytes per second | `MB/s` | Number (Float) | `48.2` |

---

### 6. Ollama (`ollama`)

Captures active state and concurrency metrics for the Ollama LLM inference service.

| Metric Field | Description | Unit | Data Type | Example Value |
| :--- | :--- | :--- | :--- | :--- |
| `running_models` | List of model tags currently loaded and active in memory | None | Array of Strings | `["llama3.1:8b"]` |
| `loaded_models` | Total count of model instances currently loaded in VRAM/RAM | Count | Number (Integer) | `1` |
| `active_requests` | Count of concurrent inference requests currently processing | Count | Number (Integer) | `1` |

---

### 7. Benchmark (`benchmark`)

Measures LLM performance timing and token generation metrics during workload execution.

| Metric Field | Description | Unit | Data Type | Example Value |
| :--- | :--- | :--- | :--- | :--- |
| `ttft_ms` | Time To First Token latency in milliseconds | `ms` | Number (Float) | `42.5` |
| `generation_tokens_per_second` | Response text generation throughput rate | `tokens/sec` | Number (Float) | `58.4` |
| `prompt_tokens_per_second` | Input prompt processing throughput rate | `tokens/sec` | Number (Float) | `312.8` |
| `total_latency_ms` | Total request latency from prompt dispatch to completion | `ms` | Number (Float) | `1250.0` |

---

## CLI Output Specification

Every monitoring module in `aiw` MUST support two distinct output modes.

### 1. Human-Readable Mode (Default)
- **Target Audience**: Terminal interactive users and developers.
- **Rules**:
  - Uses key-value alignment, clear headers, section dividers, and units.
  - Designed exclusively for human inspection.
  - **MUST NEVER be parsed by automated scripts or tools.**

#### Example Output (`aiw monitor gpu`):

```text
GPU
────────────────────────────────────────
Utilization : 98 %
VRAM        : 6421 / 16384 MB
Power       : 171 W
Edge Temp   : 61 °C
Hotspot     : 84 °C
Memory Temp : 72 °C
Fan Speed   : 2100 RPM
GPU Clock   : 2150 MHz
Mem Clock   : 1000 MHz
```

---

### 2. JSON Mode (`--json`)
- **Target Audience**: Automation scripts, CI/CD pipelines, metric aggregators, and dashboards.
- **Rules**:
  - Validated against this schema specification strictly.
  - Always outputs valid, minified or formatted JSON.
  - Emits errors to `stderr` and JSON payload to `stdout`.

#### Example Output (`aiw monitor gpu --json`):

```json
{
  "gpu": {
    "utilization_percent": 98.0,
    "vram_used_mb": 6421,
    "vram_total_mb": 16384,
    "power_w": 171.0,
    "edge_temp_c": 61.0,
    "hotspot_temp_c": 84.0,
    "memory_temp_c": 72.0,
    "fan_rpm": 2100,
    "gpu_clock_mhz": 2150,
    "memory_clock_mhz": 1000
  }
}
```

---

## Complete Example Telemetry JSON Document

Below is a complete, unified example JSON telemetry payload containing all metric categories and metadata fields:

```json
{
  "metadata": {
    "schema_version": "1.0",
    "hostname": "ai-workstation-01",
    "timestamp": "2026-08-01T18:45:00Z",
    "kernel_version": "6.8.0-40-generic",
    "os_version": "Ubuntu 24.04 LTS",
    "rocm_version": "6.1.2",
    "ollama_version": "0.3.4",
    "cli_version": "0.1.0"
  },
  "gpu": {
    "utilization_percent": 98.0,
    "vram_used_mb": 6421,
    "vram_total_mb": 16384,
    "power_w": 171.0,
    "edge_temp_c": 61.0,
    "hotspot_temp_c": 84.0,
    "memory_temp_c": 72.0,
    "fan_rpm": 2100,
    "gpu_clock_mhz": 2150,
    "memory_clock_mhz": 1000
  },
  "cpu": {
    "utilization_percent": 45.2,
    "frequency_mhz": 3800.0,
    "temperature_c": 58.5,
    "load_average": [
      2.15,
      1.85,
      1.42
    ]
  },
  "memory": {
    "used_mb": 28416,
    "total_mb": 65536,
    "available_mb": 37120,
    "swap_used_mb": 512,
    "swap_total_mb": 16384
  },
  "disk": {
    "usage_percent": 62.4,
    "read_mb_s": 124.5,
    "write_mb_s": 48.2
  },
  "ollama": {
    "running_models": [
      "llama3.1:8b"
    ],
    "loaded_models": 1,
    "active_requests": 1
  },
  "benchmark": {
    "ttft_ms": 42.5,
    "generation_tokens_per_second": 58.4,
    "prompt_tokens_per_second": 312.8,
    "total_latency_ms": 1250.0
  }
}
```
