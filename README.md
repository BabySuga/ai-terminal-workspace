# AI Terminal Workspace

[![Version](https://img.shields.io/badge/version-v0.1.0-blue.svg)](https://github.com/BabySuga/ai-terminal-workspace)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20ROCm-orange.svg)]()

A lightweight, developer-focused CLI toolkit and terminal workspace for local LLM inference, hardware telemetry monitoring, and performance benchmarking.

---

## Why This Project Exists

Local LLM engineering requires fast, reliable CLI tooling to validate system readiness, sample hardware telemetry, benchmark inference token speed, and manage configuration across local, containerized, or remote endpoint setups without heavy daemons or external database dependencies.

---

## Features

- **Environment Doctor**: Preflight validation of CLI dependencies, GPU drivers, ROCm, Ollama service, and endpoint configuration.
- **Unified Configuration**: Centralized endpoint resolver supporting CLI flags, environment variables, TOML configuration files, and fallbacks.
- **Hardware Telemetry**: Real-time monitoring of AMD GPU metrics and Ollama runtime status.
- **Streaming LLM Benchmark**: Granular measurements for Time To First Token (TTFT), tokens per second (t/s), response duration, and memory utilization.
- **Interactive TUI**: Terminal UI to select single or multiple models into sequential execution queues.
- **Modular CLI**: Zero-dependency Bash dispatcher (`aiw`).

---

## Requirements

- **OS**: Linux
- **Shell**: Bash 4.0+
- **Python**: Python 3.11+ (uses built-in `tomllib`)
- **Dependencies**: `jq`, `curl`
- **Optional**: `ollama`, AMD GPU driver / ROCm (`amd-smi`, `rocminfo`)

---

## Installation

```bash
git clone https://github.com/BabySuga/ai-terminal-workspace.git
cd ai-terminal-workspace
./scripts/install.sh
aiw doctor
aiw config test
```

---

## Configuration

The endpoint configuration resolver resolves the Ollama API server address according to the following priority:

1. `--endpoint <url>` (CLI argument override)
2. `AIW_OLLAMA_ENDPOINT` (AIW environment variable)
3. `OLLAMA_HOST` (Standard Ollama environment variable)
4. `~/.config/aiw/config.toml` (User configuration file)
5. `http://127.0.0.1:11434` (Default fallback endpoint)

### Design Rationale

This priority resolution avoids hardcoded endpoints and seamlessly supports local instances, remote GPU servers, Docker containers, reverse proxies, and SSH or cloud tunnel deployments.

---

## Doctor

The `doctor` command runs preflight validation checks across system dependencies, backend runtime state, hardware, and configuration.

```bash
aiw doctor
```

### Example Output

```
AIW Doctor

✓ Bash
✓ Python
✓ jq
✓ curl
✓ Ollama
✓ AMD GPU
✓ ROCm
✓ Endpoint
✓ Configuration

Status
READY
```

---

## Monitoring

Monitor GPU telemetry and local Ollama server state.

```bash
# Monitor AMD GPU telemetry
aiw monitor gpu

# Monitor Ollama runtime state and loaded models
aiw monitor ollama
```

---

## Benchmarking

Benchmark LLM models with real-time streaming token breakdown and GPU telemetry capture.

```bash
# Benchmark a single model
aiw benchmark qwen3:8b

# Repeat benchmark runs
aiw benchmark --repeat 3 qwen3:8b
```

---

## Interactive Benchmark

Launch interactive TUI model selection mode.

```bash
aiw benchmark
```

### Workflow

```
User
 │
 ▼
Interactive Menu
 │
 ▼
Single / Multiple
 │
 ▼
Benchmark Queue
 │
 ▼
Summary
```

- **Single Model Mode**: Quick selection for individual model runs.
- **Multiple Model Selection**: Multi-select models to build sequential queues.
- **Sequential Execution**: Benchmarks run sequentially reuse the standard streaming engine.

---

## CLI Examples

Copy-paste ready examples for all supported CLI commands:

### Doctor
```bash
aiw doctor
```

### Configuration
```bash
aiw config init
aiw config show
aiw config test
aiw config set endpoint http://192.168.1.20:11434
```

### Monitoring
```bash
aiw monitor gpu
aiw monitor ollama
```

### Benchmark
```bash
aiw benchmark qwen3:8b
aiw benchmark hermes3:8b
aiw benchmark qwen3:8b hermes3:8b
aiw benchmark --all
aiw benchmark --repeat 3 qwen3:8b
```

### Interactive
```bash
aiw benchmark
```

---

## Example AI Workstation

| Component | Specification |
| :--- | :--- |
| **OS** | Lubuntu 26.04 |
| **GPU** | AMD Radeon RX 9060 XT 16GB |
| **CPU** | Ryzen 5 5600G |
| **Backend** | ROCm |
| **Inference Engine** | Ollama |
| **Terminal** | Kitty |
| **Shell** | Bash |

---

## Installed Models

| Model | Category | Primary Use Case |
| :--- | :--- | :--- |
| `qwen3:8b` | General LLM | General reasoning, conversation, and multilingual tasks |
| `hermes3:8b` | Instruct / Agent | Instruction following, tool usage, and agentic workflows |
| `deepseek-coder:6.7b` | Code Generation | Dedicated code completion and algorithm synthesis |
| `qwen2.5-coder:7b` | Code Generation | Polyglot coding, refactoring, and technical Q&A |
| `qwen2.5vl:7b` | Vision-Language | Multimodal visual reasoning and image understanding |
| `nomic-embed-text` | Embedding | Semantic text embedding for RAG and vector retrieval |

### Workstation Benchmarking Suite

This collection covers diverse local AI workload profiles—from code synthesis and multimodal vision to instructor agents and text embeddings. Evaluating performance across these distinct architectures measures VRAM footprint, TTFT, model swap latency, and token throughput under real-world usage.

---

## Roadmap

### Current (v0.1.0)

- Doctor environment validator
- Centralized configuration system
- AMD GPU telemetry monitor
- Ollama runtime monitor
- Streaming LLM benchmark engine
- Interactive TUI benchmark mode

### Future

- Benchmark History
- Model Comparison
- Markdown Report
- CSV Export
- HTML Report
- tmux Workspace
- Dashboard (optional)
- Prometheus Integration (optional)
- Grafana Integration (optional)

---

## Contributing

Contributions are welcome! Please open an issue or submit a pull request for improvements and bug fixes.

---

## License

This project is licensed under the [MIT License](LICENSE).
