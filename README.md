# Systolic Array Matrix Multiplication Accelerator

A high-throughput, energy-efficient General Matrix Multiply (GEMM) hardware accelerator implemented in Verilog HDL. The design leverages a 2D systolic array mesh architecture with local accumulation and data forwarding to maximize operand reuse, minimize memory bandwidth bottlenecks, and overcome the Von Neumann memory wall for deep learning and matrix-heavy workloads.

---

## Project Repository Structure

This repository contains two distinct project phases:

```text
systolic-array-matrix-multiplication-accelerator/
├── phase1/    # Phase 1: 4×4 INT8/INT32 Systolic Array Accelerator (Submitted & Complete)
└── phase2/    # Phase 2: Scalable Architecture & Sequential Baseline (In Progress)
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

## Phase 2 — In Progress

Phase 2 extends the original accelerator into a parameterizable, scalable architecture and introduces a golden sequential matrix multiplication hardware baseline to enable direct performance, throughput, and hardware cost comparisons.

- **Phase 2 Overview & Guide:** [phase2/README.md](phase2/README.md)
- **Configurable Processing Element RTL:** [processing_element.v](phase2/rtl/processing_element.v)
- **Sequential Matmul Baseline RTL:** [sequential_matmul_baseline.v](phase2/rtl/sequential_matmul_baseline.v)
- **Phase 2 Interface Contract:** [phase2_interface_contract.md](phase2/docs/phase2_interface_contract.md)

### Phase 2 Focus Areas
- **Configurable PE Architecture:** Fully parameterizable operand width (`DATA_WIDTH`) and accumulator width (`ACC_WIDTH`).
- **Sequential Hardware Baseline:** Reusable single-MAC reference engine computing matrix products sequentially across $N^3$ clock cycles.
- **Scalable Array & Integration (Upcoming):** Scalable $N \times N$ array mesh and parameterized FSM matrix controller.

---

## Technologies Used

- **Hardware Description Language:** Verilog HDL (IEEE 1364-2001 / IEEE 1800 SystemVerilog standard features)
- **Simulation & Synthesis Toolchain:** Icarus Verilog (`iverilog`, `vvp` v12+)
- **Waveform Inspection:** GTKWave (`.vcd` visual analysis)
- **Algorithmic Modeling & Verification:** Python 3 (automated test vector generation and validation)
- **Documentation & Typesetting:** LaTeX (IEEEtran conference template), Markdown, Git

---

## Team Members & Responsibilities

| Member | Project Role | Core Responsibilities |
|---|---|---|
| **Aman Soni** (Member 1) | Processing Element & Datapath RTL | Phase 1 PE implementation, signed multiplication and accumulation, forwarding registers, valid control, PE verification. Phase 2 parameterizable PE and sequential baseline reference. |
| **Mayank Sharma** (Member 2) | Systolic Array Architecture | Phase 1 4×4 2D mesh generation, horizontal/vertical data interconnects, perimeter skewing and timing alignment, core scoreboard verification. Phase 2 scalable array architecture. |
| **Ankit Kumar Pandey** (Member 3) | Matrix Controller & Top Integration | Phase 1 FSM controller (`matrix_controller.v`), top-level integration (`systolic_array_top.v`), input matrix registers, system verification, and Python golden model. Phase 2 parameterized controller and system integration. |

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
    ├── rtl/              # Parameterized PE and sequential baseline RTL
    ├── testbench/        # Parameterized PE and baseline testbenches
    ├── verification/     # Future Phase 2 verification artefacts
    ├── simulation/       # Phase 2 simulation results and waveforms
    ├── docs/             # Phase 2 interface contract
    └── report/           # Future Phase 2 report deliverables
```
