# AI Terminal Workspace

[![Version](https://img.shields.io/badge/version-v0.1.0-blue.svg)](https://github.com/BabySuga/ai-terminal-workspace)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20ROCm-orange.svg)]()

A lightweight, developer-focused CLI toolkit for local LLM environment validation, hardware telemetry monitoring, and streaming performance benchmarking.

---

## Quick Start

Run your first benchmark in under one minute:

```bash
git clone https://github.com/BabySuga/ai-terminal-workspace.git
cd ai-terminal-workspace
./scripts/install.sh
aiw doctor
aiw benchmark
```

---

## Preview

The image placeholders below reserved in `docs/images/` demonstrate the CLI features and terminal interface:

- `doctor.png` – Environment and dependency preflight check
- `gpu-monitor.png` – AMD GPU hardware telemetry monitoring
- `ollama-monitor.png` – Ollama server runtime status and loaded models
- `interactive-benchmark.gif` – TUI model selection and queue execution
- `benchmark-summary.png` – Final benchmark performance output

![Doctor](docs/images/doctor.png)
![GPU Monitor](docs/images/gpu-monitor.png)
![Ollama Monitor](docs/images/ollama-monitor.png)
![Interactive Benchmark](docs/images/interactive-benchmark.gif)
![Benchmark Summary](docs/images/benchmark-summary.png)

---

## Features

- **Doctor**: Environment preflight check for dependencies, drivers, and Ollama connectivity.
- **Configuration**: Priority resolver supporting CLI flags, environment variables, TOML config, and defaults.
- **GPU Monitor**: Real-time AMD GPU hardware telemetry (`amd-smi`).
- **Ollama Monitor**: Server status and loaded model inspection.
- **Streaming Benchmark**: Real-time TTFT, generation speed, latency, and peak VRAM measurement.
- **Interactive Benchmark**: Terminal UI for sequential multi-model benchmarking.

---

## Installation

Clone the repository and run the installation script:

```bash
git clone https://github.com/BabySuga/ai-terminal-workspace.git
cd ai-terminal-workspace
./scripts/install.sh
```

This creates an executable symlink at `~/.local/bin/aiw`.

---

## Requirements

| Requirement | Specification |
| :--- | :--- |
| **OS** | Linux |
| **Shell** | Bash 4.0+ |
| **Python** | Python 3.11+ |
| **Dependencies** | `jq`, `curl` |
| **Optional** | `ollama`, AMD GPU driver / ROCm (`amd-smi`, `rocminfo`) |

---

## Configuration

`aiw` uses a hierarchical configuration resolver with the following priority order:

1. CLI argument (`--endpoint <url>`)
2. Environment variable (`AIW_OLLAMA_ENDPOINT`)
3. Ollama default environment variable (`OLLAMA_HOST`)
4. Config file (`~/.config/aiw/config.toml`)
5. Default fallback (`http://127.0.0.1:11434`)

### Configuration Commands

```bash
aiw config init
aiw config show
aiw config test
aiw config set endpoint http://127.0.0.1:11434
aiw config reset
```

---

## Doctor

Validate system environment dependencies and service status:

```bash
aiw doctor
```

---

## Monitoring

Monitor system hardware telemetry and inference runtime state:

```bash
# AMD GPU telemetry
aiw monitor gpu

# Ollama server status and loaded models
aiw monitor ollama
```

---

## Benchmark

Execute streaming benchmarks on installed Ollama models:

```bash
# Benchmark a single model
aiw benchmark qwen3:8b

# Benchmark all installed models
aiw benchmark --all

# Execute multiple runs per model
aiw benchmark --repeat 3 qwen3:8b
```

---

## Interactive Benchmark

Launch the interactive Terminal UI to select models and queue benchmark tasks:

```bash
aiw benchmark
```

---

## Example AI Workstation

Reference workstation specifications used for testing and baseline benchmarks:

| Environment | Specification |
| :--- | :--- |
| **OS** | Lubuntu 26.04 |
| **GPU** | AMD Radeon RX 9060 XT 16GB |
| **CPU** | Ryzen 5 5600G |
| **RAM** | 16 GB |
| **Backend** | ROCm |
| **Inference Engine** | Ollama |
| **Terminal** | Kitty |
| **Shell** | Bash |

---

## Installed Models

| Model | Category | Primary Use Case |
| :--- | :--- | :--- |
| `qwen3:8b` | General LLM | General reasoning and task completion |
| `hermes3:8b` | Instruction | Multi-turn chat and instruction following |
| `deepseek-coder:6.7b` | Code Generation | Code completion and technical problem solving |
| `qwen2.5-coder:7b` | Code Generation | Software engineering and code synthesis |
| `qwen2.5vl:7b` | Vision-Language | Multimodal vision and document analysis |
| `nomic-embed-text` | Embedding | Text embeddings and semantic retrieval |

---

## Benchmark Metrics

| Metric | Explanation |
| :--- | :--- |
| **TTFT** | Time To First Token measures elapsed time from prompt submission to receiving the first token. |
| **Generation Speed** | Generation speed measures average token completion throughput in tokens per second. |
| **Latency** | Latency measures total round-trip execution duration from initiation to final completion. |
| **Peak VRAM** | Peak VRAM measures maximum video memory consumed by the GPU during benchmark execution. |
| **GPU Utilization** | GPU utilization measures peak GPU compute core usage percentage recorded during inference. |
| **Power Draw** | Power draw measures maximum GPU electrical power consumption in Watts during active benchmarking. |
| **Prompt Tokens** | Prompt tokens count input tokens in the benchmark prompt payload processed by the model. |
| **Output Tokens** | Output tokens count total completion tokens generated by the model. |
| **Approx Tokens** | Approx tokens represent the combined total of prompt input tokens and output tokens. |
| **Characters** | Characters count total character length of the generated completion text response. |
| **Words** | Words count total word count contained in the generated completion text response. |

---

## Example Benchmark

Realistic benchmark output captured on the reference workstation:

```text
Benchmark
────────────────────────

Model
qwen3:8b

Backend
ROCm

TTFT
2.12 s

Generation Speed
50 tok/s

Latency
11.8 s

GPU
Peak VRAM
6.2 GB

Peak Power
131 W

Output
Characters
2326

Words
395

Approx Tokens
487
```

> [!IMPORTANT]
> This is an example benchmark captured on the reference workstation.
> Actual results vary depending on:
> - model
> - quantization
> - prompt
> - GPU clocks
> - power limits
> - cold/warm model state.

---

## Architecture

```
CLI
 ↓
Doctor
 ↓
Configuration Resolver
 ↓
Ollama API
 ↓
GPU Monitor
 ↓
Benchmark Engine
 ↓
Summary
```

---

## Repository Structure

| Directory | Description |
| :--- | :--- |
| `assets/` | Static graphic assets and project badges |
| `benchmark/` | Streaming benchmark engine and interactive TUI script |
| `bin/` | Executable CLI binary launcher (`aiw`) |
| `config/` | Endpoint configuration resolver and default prompt files |
| `docs/` | Architecture specs, schemas, and release guidelines |
| `examples/` | Configuration snippets and output examples |
| `monitor/` | AMD GPU telemetry and Ollama monitoring scripts |
| `scripts/` | Modular command handlers and doctor preflight checks |
| `workspace/` | Terminal workspace layout files and session templates |

---

## Roadmap

### Current (v0.1.0)
- [x] **Doctor**: Environment and dependency preflight checks
- [x] **Configuration**: Centralized priority endpoint resolver
- [x] **GPU Monitor**: AMD GPU hardware telemetry via `amd-smi`
- [x] **Ollama Monitor**: Server status and loaded model inspection
- [x] **Streaming Benchmark**: Granular TTFT, speed, latency, and VRAM measurement
- [x] **Interactive Benchmark**: Terminal UI for sequential model selection

---

## Contributing

We welcome contributions! To contribute:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Run `shellcheck` on changed shell scripts
4. Run `shfmt` to format code
5. Open a Pull Request

---

## License

Distributed under the [MIT License](LICENSE).
