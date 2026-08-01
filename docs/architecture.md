# System Architecture

## Project Goals
- Provide a modular architecture for monitoring hardware metrics and benchmarking LLM inference workloads.
- Standardize metrics collection across system resources and inference backends.
- Produce clean, machine-readable output format to support automation, logging, and reporting.

## High-Level Architecture Diagram

```
+-----------------------------------------------------------------------+
|                            User / Orchestrator                        |
+-----------------------------------------------------------------------+
                                   |
                                   v
+-----------------------------------------------------------------------+
|                           Core Controller                             |
|    - Configuration & Inputs Parser                                    |
|    - Execution Pipeline & Workflow State                              |
+-----------------------------------------------------------------------+
           |                                       |
           v                                       v
+-----------------------+               +-----------------------+
|   Monitoring Module   |               |  Benchmarking Module  |
|  - Telemetry Engine   |               |  - Workload Runner    |
|  - Resource Samplers  |               |  - Metric Collectors  |
+-----------------------+               +-----------------------+
           |                                       |
           +-------------------+-------------------+
                               |
                               v
+-----------------------------------------------------------------------+
|                        Data Collector & Reporter                      |
|  - Data Normalization & Formatting                                    |
|  - Export & Persistence                                               |
+-----------------------------------------------------------------------+
```

## Module Responsibilities

### Core Controller
- Serves as the primary entry point for managing execution pipelines.
- Parses configuration parameters and operational flags.
- Coordinates synchronization between telemetry monitoring and benchmark workloads.

### Monitoring Module
- Samples hardware resource metrics periodically during execution.
- Collects status and telemetry from backend services.
- Delivers normalized resource usage data to the aggregator.

### Benchmarking Module
- Executes predefined inference workloads against backend endpoints.
- Measures key timing, throughput, and efficiency metrics.
- Records request and response lifecycle events.

### Data Collector & Reporter
- Receives raw telemetry and execution timings from monitoring and benchmark components.
- Aggregates and formats measurements into structured datasets.
- Generates machine-readable output files and visual summary reports.

## Data Flow

1. **Initialization**: The Core Controller validates inputs and loads configuration profiles.
2. **Telemetry Sampling**: The Monitoring Module initiates resource sampling across system hardware and active backend processes.
3. **Workload Execution**: The Benchmarking Module executes designated performance runs against the target backend.
4. **Metric Aggregation**: Telemetry and benchmark latency data are aligned chronologically and aggregated.
5. **Output Export**: The Data Collector & Reporter formats aggregated metrics into machine-readable datasets and persistent documentation outputs.

## Design Principles

- **Single Responsibility**: Each component is focused strictly on a single operational concern (e.g., telemetry gathering, benchmark runner, or data formatting).
- **Modular Structure**: Components communicate via standardized interfaces, enabling seamless replacement or addition of telemetry sources and benchmark engines.
- **Machine-Readable Output**: Data payloads and result reports adhere to consistent, structured formats (e.g., JSON/CSV) to simplify automated parsing and visualization.
