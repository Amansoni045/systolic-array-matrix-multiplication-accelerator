# Systolic Array Matrix Multiplication Accelerator

A high-throughput, energy-efficient General Matrix Multiply (GEMM) hardware accelerator implemented in Verilog HDL. The design leverages a 2D systolic array mesh architecture with local accumulation and data forwarding to maximize operand reuse, minimize memory bandwidth bottlenecks, and overcome the Von Neumann memory wall for deep learning and matrix-heavy workloads.

---

## Project Repository Structure

This repository contains two distinct project phases:

```text
systolic-array-matrix-multiplication-accelerator/
├── phase1/    # Phase 1: 4×4 INT8/INT32 Systolic Array Accelerator (Submitted & Complete)
└── phase2/    # Phase 2: Parameterizable System Integration & Baseline (Complete)
```

---

## Phase 1 — Completed

Phase 1 delivered a fully functional 4×4 Output-Stationary systolic array accelerator with integrated perimeter skewing buffers, an autonomous FSM matrix controller, and multi-tier verification.

- **Phase 1 Overview & Guide:** [phase1/README.md](phase1/README.md)
- **IEEE Project Report (PDF):** [IEEE_Project_Report_Phase_1.pdf](phase1/report/IEEE_Project_Report_Phase_1.pdf)
- **Project Report (Markdown):** [REPORT.md](phase1/report/REPORT.md)
- **LaTeX Report Source:** [IEEE_Project_Report_Phase_1.tex](phase1/report/IEEE_Project_Report_Phase_1.tex)
- **Presentation Video:** [MCA_Phase_1.mp4](phase1/video/MCA_Phase_1.mp4) (4:54.5 presentation in 1080p)
- **Architecture Specification:** [ACCELERATOR_SPECIFICATION.md](phase1/docs/architecture/ACCELERATOR_SPECIFICATION.md)
- **Theoretical References:** [BIBLIOGRAPHY.md](phase1/docs/references/BIBLIOGRAPHY.md)

### Phase 1 Specifications
- **Array Size:** 4×4 (16 homogeneous Processing Elements)
- **Input Precision:** Signed 8-bit integer (`INT8`, range $-128$ to $+127$)
- **Accumulator Precision:** Signed 32-bit integer (`INT32`) to guarantee overflow-free accumulation
- **Dataflow Paradigm:** Output-Stationary (OS) with registered horizontal ($A$) and vertical ($B$) data forwarding
- **Internal Skewing:** Embedded skew registers allow parallel, unskewed matrix row/column streaming
- **Deterministic Latency:** Exactly 14 clock cycles from `start` to valid `done` commitment

---

## Phase 2 — Complete

Phase 2 extends the accelerator into a parameterizable, scalable system and integrates the controller, top level, PE and array with a sequential hardware baseline for direct performance, throughput, and hardware-cost comparison.

- **Phase 2 Overview & Guide:** [phase2/README.md](phase2/README.md)
- **Configurable Processing Element RTL:** [processing_element.v](phase2/rtl/processing_element.v)
- **Sequential Matmul Baseline RTL:** [sequential_matmul_baseline.v](phase2/rtl/sequential_matmul_baseline.v)
- **Parameterized Controller RTL:** [matrix_controller.v](phase2/rtl/matrix_controller.v)
- **Integrated Top Level:** [systolic_array_top.v](phase2/rtl/systolic_array_top.v)
- **End-to-End Testbench:** [tb_systolic_array.v](phase2/testbench/tb_systolic_array.v)
- **Python Golden Model:** [golden_model.py](phase2/verification/golden_model.py)
- **System Integration Design:** [phase2_system_integration.md](phase2/docs/phase2_system_integration.md)
- **Measured Performance Results:** [system_integration_results.md](phase2/report/system_integration_results.md)
- **Phase 2 Interface Contract:** [phase2_interface_contract.md](phase2/docs/phase2_interface_contract.md)

### Phase 2 Focus Areas
- **Configurable PE Architecture:** Fully parameterizable operand width (`DATA_WIDTH`) and accumulator width (`ACC_WIDTH`).
- **Sequential Hardware Baseline:** Reusable single-MAC reference engine computing matrix products sequentially across $N^3$ clock cycles.
- **Scalable Array:** Parameterized $N \times N$ mesh verified with an array-only regression across 10 configurations.
- **Parameterized Controller:** Dimension-derived `LOAD = N` and `DRAIN = 2N-1` schedule, input latching, exact `3N-1` cycle latency and single-cycle `done`.
- **Full System Integration:** Controller + top level + PE + array + sequential baseline co-verified end-to-end.
- **Performance Comparison:** 9 configurations and 414 end-to-end cases, with measured latency and throughput at 100 MHz.
- **Golden Model:** Arbitrary `N`, `DATA_WIDTH` and `ACC_WIDTH`, RTL-exact signed wrapping, vector generation and result verification.

---

## Technologies Used

- **Hardware Description Language:** Verilog HDL (IEEE 1364-2001 / IEEE 1800 SystemVerilog standard features)
- **Simulation & Synthesis Toolchain:** Icarus Verilog (`iverilog`, `vvp` v12+; regression run on v13.0)
- **Waveform Inspection:** GTKWave (`.vcd` visual analysis)
- **Algorithmic Modeling & Verification:** Python 3 (automated test vector generation and validation)
- **Documentation & Typesetting:** LaTeX (IEEEtran conference template), Markdown, Git

---

## Team Members & Responsibilities

| Member | Project Role | Core Responsibilities |
|---|---|---|
| **Aman Soni** (Member 1) | Processing Element & Datapath RTL | Phase 1 PE implementation, signed multiplication and accumulation, forwarding registers, valid control, PE verification. Phase 2 parameterizable PE and sequential baseline reference. |
| **Mayank Sharma** (Member 2) | Systolic Array Architecture | Phase 1 4×4 2D mesh generation, horizontal/vertical data interconnects, perimeter skewing and timing alignment, core scoreboard verification. Phase 2 scalable array architecture. |
| **Ankit Kumar Pandey** (Member 3) | Matrix Controller & Top Integration | Phase 1 FSM controller (`matrix_controller.v`), top-level integration (`systolic_array_top.v`), input matrix registers, system verification, and Python golden model. Phase 2 parameterized controller, top-level integration, Python golden model extension, end-to-end system verification and performance benchmarking. |

---

## Quick Navigation

```text
├── phase1/
│   ├── rtl/              # Verilog source (PE, Array, Controller, Top)
│   ├── testbench/        # Unit, core scoreboard, and system testbenches
│   ├── verification/     # Python golden model & 40 test vectors
│   ├── simulation/       # Simulation results and waveform captures
│   ├── docs/             # Architecture specifications and literature
│   ├── report/           # IEEE formal report (PDF, LaTeX, Markdown, Figures)
│   └── video/            # Final prototype video presentation
└── phase2/
    ├── rtl/              # Parameterized PE, array, controller, top and baseline RTL
    ├── testbench/        # PE, baseline, array-core and end-to-end system testbenches
    ├── verification/     # Golden model, unit tests and array/system regression runners
    ├── simulation/       # Phase 2 simulation results and waveforms
    ├── docs/             # Interface contract and system integration design
    └── report/           # Measured performance results and future IEEE report
```
