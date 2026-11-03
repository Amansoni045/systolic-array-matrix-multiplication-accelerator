# Systolic Array Matrix Multiplication Accelerator

## Project Overview

The **Systolic Array Matrix Multiplication Accelerator** is an academic hardware design project aimed at designing, simulating, and verifying a high-throughput, energy-efficient matrix multiplication engine. Systolic arrays are specialized parallel computing architectures where data streams rhythmically through a 2D grid of tightly-coupled Processing Elements (PEs), maximizing data reuse and minimizing memory bandwidth bottlenecks.

This project implements a parameterized 2D systolic array architecture in Verilog HDL, verified against a software-based golden reference model written in Python, with simulation and waveform analysis carried out via Icarus Verilog and GTKWave.

---

## Technologies Used

- **Verilog HDL**: Hardware Description Language used for designing the RTL components (Processing Element, Systolic Array grid, Matrix Controller, and Top-level module) and Verilog testbenches.
- **Icarus Verilog (`iverilog`)**: Open-source Verilog simulation and synthesis compiler used to compile RTL designs and execute verification testbenches.
- **GTKWave**: Fully featured GTK+ based wave viewer for inspecting Value Change Dump (`.vcd`) simulation waveforms and debugging timing behavior.
- **Python**: Scripting language utilized for developing the algorithmic golden reference model, generating randomized matrix test vectors, and performing automated output verification.

---

## Project Architecture Overview

The accelerator design is structured into modular hardware tiers and verification layers:

1. **Processing Element (PE) (`rtl/processing_element.v`)**:
   - The fundamental building block of the systolic array.
   - Computes multiply-accumulate operations: $C = C + (A \times B)$.
   - Buffers and forwards operand $A$ horizontally to the neighbor PE.
   - Buffers and forwards operand $B$ vertically to the neighbor PE.
   - Registers intermediate/final accumulated sums.

2. **Systolic Array Core (`rtl/systolic_array.v`)**:
   - A 2D interconnected grid of PEs arranged in rows and columns.
   - Supports parallel spatial computation and rhythmic pipeline data movement across cycles.

3. **Matrix Controller (`rtl/matrix_controller.v`)**:
   - Manages state machine control flow (IDLE, LOAD, COMPUTE, READOUT).
   - Skews and aligns input matrix data streams (systolic delay staggering).
   - Generates control signals, valid flags, and memory read/write handshakes.

4. **Top-Level Module (`rtl/systolic_array_top.v`)**:
   - Integrates the Matrix Controller, Systolic Array core, and external memory/bus interfaces into a unified accelerator interface.

5. **Verification & Golden Model (`verification/golden_model.py`)**:
   - High-level Python implementation computing matrix multiplication reference outputs.
   - Generates stimulus vectors (`verification/test_vectors/`) and compares simulation outputs against expected values for functional correctness.

---

## Folder Structure

```text
systolic-array-matrix-multiplication-accelerator/
│
├── README.md
├── .gitignore
│
├── rtl/
│   ├── .gitkeep
│   ├── processing_element.v
│   ├── systolic_array.v
│   ├── matrix_controller.v
│   └── systolic_array_top.v
│
├── testbench/
│   ├── .gitkeep
│   ├── tb_processing_element.v
│   └── tb_systolic_array.v
│
├── verification/
│   ├── .gitkeep
│   ├── golden_model.py
│   └── test_vectors/
│       └── .gitkeep
│
├── simulation/
│   ├── .gitkeep
│   ├── waveforms/
│   │   └── .gitkeep
│   └── results/
│       └── .gitkeep
│
├── docs/
│   ├── .gitkeep
│   ├── architecture/
│   │   └── .gitkeep
│   └── references/
│       └── .gitkeep
│
└── report/
    ├── .gitkeep
    └── figures/
        └── .gitkeep
```

---

## Team Responsibilities

The development and verification tasks are partitioned among the team members as follows:

### **Member 1 — Processing Element**
- `rtl/processing_element.v`: Design and implementation of the multiply-accumulate (MAC) processing element.
- `testbench/tb_processing_element.v`: Unit-level testbench for verifying individual PE functionality and timing.

### **Member 2 — Systolic Array**
- `rtl/systolic_array.v`: Implementation of the 2D mesh grid array, interconnecting processing elements and routing horizontal/vertical data channels.

### **Member 3 — Controller and Verification**
- `rtl/matrix_controller.v`: Control logic, state machine, data skewing, and sequencing.
- `rtl/systolic_array_top.v`: Top-level integration of controller and array grid.
- `testbench/tb_systolic_array.v`: System-level integration testbench.
- `verification/golden_model.py`: Algorithmic golden model, test vector generation, and automated result validation.

