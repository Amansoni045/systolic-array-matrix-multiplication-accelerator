# Systolic Array Matrix Multiplication Accelerator (4×4 INT8 / INT32)

[![Verilog HDL](https://img.shields.io/badge/Language-Verilog%20HDL-blue.svg)](rtl/)
[![Simulator](https://img.shields.io/badge/Simulator-Icarus%20Verilog%2013.0-orange.svg)](simulation/)
[![Verification](https://img.shields.io/badge/Verification-100%25%20Passed-brightgreen.svg)](testbench/)
[![IEEE Report](https://img.shields.io/badge/Report-IEEE%20Format-red.svg)](report/IEEE_Project_Report_Phase_1.pdf)

---

## Phase 1 Project Submission Artefacts

| Artefact | Description | Link |
|:---|:---|:---:|
| **IEEE Project Report (PDF)** | Formal 4-page IEEE conference format report with architectural block diagrams, verification tables, waveforms, and references | [**IEEE_Project_Report_Phase_1.pdf**](report/IEEE_Project_Report_Phase_1.pdf) |
| **Project Report (Markdown)** | Full GitHub-rendered markdown edition of the IEEE Project Report | [**REPORT.md**](report/REPORT.md) |
| **LaTeX Report Source** | IEEEtran conference format LaTeX source file | [**IEEE_Project_Report_Phase_1.tex**](report/IEEE_Project_Report_Phase_1.tex) |
| **Prototype Demo Video** | 5-minute video demonstration covering project idea, 5 members, block diagrams, code walkthrough, and live simulation | [**Prototype Video Link (YouTube / Drive)**](https://youtu.be/placeholder-demo-video) |
| **Video Script & Guide** | Second-by-second presentation plan and word-for-word spoken script for the team | [**PROTOTYPE_VIDEO_GUIDE.md**](docs/PROTOTYPE_VIDEO_GUIDE.md) |
| **Submission Form** | Official submission portal (Deadline: Nov 16, 2026, 11:59 PM) | [Google Form Submission](https://docs.google.com/forms/d/e/1FAIpQLSc6Cx8OrOQLGj_X2ZMkyG5jc8mokq36mGRq2x8jGRNV1sbegA/viewform) |

---

## Project Overview

The **Systolic Array Matrix Multiplication Accelerator** is an academic hardware design project aimed at designing, simulating, and verifying a high-throughput, energy-efficient General Matrix Multiply (GEMM) engine in Verilog HDL. 

Systolic arrays stream data rhythmically through a tightly-coupled 2D grid of Processing Elements (PEs), maximizing operand reuse and minimizing memory bandwidth bottlenecks (overcoming the Von Neumann "memory wall").

### Key Architectural Specifications
- **Array Dimensions:** 4×4 2D Mesh (16 Processing Elements).
- **Operand Precision:** Signed 8-bit integers (`INT8`, range $-128$ to $+127$).
- **Accumulator Precision:** Signed 32-bit integers (`INT32`) guaranteeing zero arithmetic overflow across successive accumulations.
- **Dataflow Architecture:** Output-Stationary (OS) with local PE accumulation and registered horizontal ($A$) and vertical ($B$) data forwarding.
- **Internal Skewing:** Embedded row and column skewing registers eliminate external timing alignment buffers, allowing unskewed parallel row/column streaming.
- **Deterministic Latency:** Exactly **14 clock cycles** from `start` assertion to registered `result` commitment.
- **Handshake Interface:** Simple memory-controller handshake using `start`, `busy`, and single-cycle `done` pulse.

---

## Hardware Architecture

![Accelerator Architecture](report/figures/fig1_accelerator_architecture.png)

1. **Processing Element (PE) (`rtl/processing_element.v`)**:
   - Computes $C_{r,c}^{(k)} = C_{r,c}^{(k-1)} + (A_{r,k} \times B_{k,c})$.
   - Sign-extends 8-bit inputs to 16 bits, performs $16 \times 16$ multiplication, and sign-extends to 32 bits for accumulation.
   - Dual registered forwarding channels pass $A$ horizontally and $B$ vertically with registered valid flags.
   - Synchronous `clear_acc` resets accumulators; asynchronous `rst_n` clears all state.

2. **Systolic Array Core (`rtl/systolic_array.v`)**:
   - Instantiates 16 PEs in a 4×4 mesh using nested generate loops.
   - Integrates perimeter skewing registers (delaying row $r$ by $r$ cycles and column $c$ by $c$ cycles).
   - Arrival timing: operand pair $(A_{r,k}, B_{k,c})$ arrives at $\text{PE}(r, c)$ at exact clock cycle $k + r + c$.

3. **Matrix Controller (`rtl/matrix_controller.v`)**:
   - 4-state FSM: `IDLE` (00) $\rightarrow$ `CLEAR` (01) $\rightarrow$ `LOAD` (10, $k=0..3$) $\rightarrow$ `DRAIN` (11, $d=0..7$) $\rightarrow$ `IDLE`.
   - Coordinates unskewed matrix feeding, valid gating, and result capture.

4. **Top-Level Integration (`rtl/systolic_array_top.v`)**:
   - Integrates controller and 2D array, exposing packed 256-bit matrix inputs (`a_flat`, `b_flat`), control handshakes, and 512-bit packed `result`.

![FSM Schedule](report/figures/fig2_fsm_timing.png)

---

## Team Members & Responsibilities

| Member | Role & Module Ownership | Key Contributions |
|:---|:---|:---|
| **Aman Soni** | **Processing Element Architect & Designer**<br>`rtl/processing_element.v`<br>`testbench/tb_processing_element.v` | Architectural specification of PE; designed 8-bit sign-extension, $16 \times 16$ multiplier, 32-bit accumulator, and dual forwarding pipeline; verified all 10 unit test cases (100% pass). |
| **Mayank Sharma** | **Systolic Array Core Engineer**<br>`rtl/systolic_array.v`<br>`testbench/tb_systolic_array_core.v` | Designed 4×4 2D mesh grid; implemented perimeter row/column skewing pipeline; built cycle-accurate array scoreboard verifying 105 matrices across 1,533 clock edges. |
| **Ankit Pandey** | **Controller & Top-Level Integration**<br>`rtl/matrix_controller.v`<br>`rtl/systolic_array_top.v`<br>`testbench/tb_systolic_array.v` | Designed 4-state autonomous FSM; formulated 14-cycle compute schedule; integrated top-level module; authored 9 system test suites (extremes, back-to-back, reset recovery). |
| **Aditya Verma** | **Verification & Algorithmic Modeling**<br>`verification/golden_model.py`<br>`verification/test_vectors/` | Implemented Python golden reference model; generated automated 40-vector test suite; developed `$readmemh` hex export and 512-bit bus hex unpacking & verification. |
| **Priyanshu Kumar** | **Timing Analysis & System Validation**<br>`docs/PROTOTYPE_VIDEO_GUIDE.md`<br>`report/` | Conducted GTKWave/VaporView waveform analysis; verified single-cycle `done` pulse and mid-compute reset recovery; co-authored IEEE report and prototype video demonstration script. |

---

## Verification Results Summary

### 1. Top-Level System Testbench (`testbench/tb_systolic_array.v`)
```bash
vvp simulation/results/top.vvp
```
```text
VCD info: dumpfile simulation/waveforms/tb_systolic_array.vcd opened for output.
PASS test 0: identity x M (I*M = M)
PASS test 1: zero x zero (all outputs 0)
PASS test 2: known positive 4x4 multiply
PASS test 3: signed extreme values (-128/127)
PASS test 4: mixed positive/negative values
PASS test 5: back-to-back op 1
PASS test 6: back-to-back op 2
PASS test 7: reset-during-operation recovery
PASS test 8: result stability
ALL TESTS PASSED (9 tests)
```

### 2. Processing Element Unit Testbench (`testbench/tb_processing_element.v`)
```bash
vvp simulation/results/pe.vvp
```
```text
PASS: Test 1 - Positive multiplication (3 * 4 = 12)
PASS: Test 2 - Negative multiplication (-3 * 5 = -15)
PASS: Test 3 - Both negative (-3 * -4 = 12)
PASS: Test 4 - Multiplication by zero
PASS: Test 5 - Multiple MAC operations (accumulated result = 29)
PASS: Test 6 - A invalid and B valid (accumulator unchanged)
PASS: Test 7 - A valid and B invalid (accumulator unchanged)
PASS: Test 8 - Accumulator clearing and MAC priority
PASS: Test 9 - Reset clears accumulator and forwarding registers
PASS: Test 10 - Correct forwarding of A, B and their respective valid signals
ALL 10 PE TESTS PASSED SUCCESSFULLY
```

### 3. Core-Level Cycle Scoreboard (`testbench/tb_systolic_array_core.v`)
```bash
vvp simulation/results/array.vvp
```
```text
PASS: 105 matrices, valid masks, bubbles, clear/reset/restart; 1533 edges checked
```

### 4. Algorithmic Python Golden Model (`verification/golden_model.py`)
```bash
python3 verification/golden_model.py
```
```text
Results: 40 PASSED, 0 FAILED out of 40 vectors
Wrote $readmemh file: verification/test_vectors/test_002_readmemh.hex
verify_verilog_output returned: PASS
All golden model checks PASSED.
```

---

## Waveform Evidence

### Top-Level Integration Waveform (Test 2: Known 4×4 Matrix Multiplication)
![Top Waveform](report/figures/fig3_top_waveform.png)
*Waveform capture from `simulation/waveforms/tb_systolic_array.vcd` demonstrating `start` trigger at 380 ns, deterministic transition through CLEAR, LOAD ($k=0..3$), and DRAIN ($d=0..7$), and single-cycle `done` pulse at 515 ns committing the verified result.*

### Processing Element MAC & Clear Waveform
![PE Waveform](report/figures/fig4_pe_waveform.png)
*Waveform capture from `simulation/waveforms/pe.vcd` showing positive MAC ($3 \times 4 = 12$ at 45 ns), synchronous clear to zero at 55 ns, and negative MAC ($-3 \times 5 = -15$ at 65 ns).*

---

## How to Build and Run

### Prerequisites
- **Icarus Verilog** (`iverilog`, `vvp` v10.0+)
- **GTKWave** (for inspecting `.vcd` traces)
- **Python 3.8+**

### Step-by-Step Commands
```bash
# 1. Clone the repository
git clone https://github.com/Amansoni045/systolic-array-matrix-multiplication-accelerator.git
cd systolic-array-matrix-multiplication-accelerator

# 2. Compile and run Processing Element unit test
mkdir -p simulation/results simulation/waveforms
iverilog -g2005 -Wall -s tb_processing_element -o simulation/results/pe.vvp rtl/processing_element.v testbench/tb_processing_element.v
vvp simulation/results/pe.vvp

# 3. Compile and run 4x4 Array Core cycle scoreboard
iverilog -g2005 -Wall -s tb_systolic_array_core -o simulation/results/array.vvp rtl/processing_element.v rtl/systolic_array.v testbench/tb_systolic_array_core.v
vvp simulation/results/array.vvp

# 4. Compile and run Top-Level Integration testbench
iverilog -g2005 -Wall -s tb_systolic_array -o simulation/results/top.vvp \
    rtl/processing_element.v rtl/systolic_array.v rtl/matrix_controller.v rtl/systolic_array_top.v testbench/tb_systolic_array.v
vvp simulation/results/top.vvp

# 5. Run Python Golden Model & vector validation
python3 verification/golden_model.py

# 6. View simulation waveforms in GTKWave
gtkwave simulation/waveforms/tb_systolic_array.vcd
```

---

## Directory Structure
```text
systolic-array-matrix-multiplication-accelerator/
├── README.md                                # Project overview, submission links, and run instructions
├── rtl/                                     # Synthesizable RTL designs
│   ├── processing_element.v                 # INT8 MAC Processing Element
│   ├── systolic_array.v                     # 4×4 2D Mesh array with internal skewing
│   ├── matrix_controller.v                  # 4-state FSM execution controller
│   └── systolic_array_top.v                 # Unified accelerator top-level module
├── testbench/                               # Verification testbenches
│   ├── tb_processing_element.v              # PE unit testbench (10 tests)
│   ├── tb_systolic_array_core.v             # 2D Array cycle scoreboard (105 matrices)
│   └── tb_systolic_array.v                  # System integration testbench (9 tests)
├── verification/                            # Algorithmic modeling and test vectors
│   ├── golden_model.py                      # Python matrix multiplication reference model
│   └── test_vectors/                        # 40 directed and randomized test vectors
├── simulation/                              # Simulation binaries and waveform dumps
│   ├── results/                             # Compiled .vvp simulation files
│   └── waveforms/                           # Generated .vcd waveform dumps
├── report/                                  # IEEE Project Report and figures
│   ├── IEEE_Project_Report_Phase_1.pdf      # Compiled IEEE 4-page conference PDF
│   ├── IEEE_Project_Report_Phase_1.tex      # IEEEtran LaTeX source code
│   ├── IEEE_Project_Report_Phase_1.html     # HTML source for PDF compilation
│   ├── REPORT.md                            # Markdown edition of the report
│   └── figures/                             # High-resolution architectural & waveform diagrams
└── docs/                                    # Documentation and guides
    └── PROTOTYPE_VIDEO_GUIDE.md             # 5-minute video presentation script and recording guide
```

---

## Phase 2 Roadmap
- [ ] Integrate dual-port Block RAMs (BRAMs) for local matrix activation and weight storage.
- [ ] Implement an AXI4-Stream slave/master interface for DMA burst streaming.
- [ ] Develop dynamic matrix tiling hardware to support arbitrary $M \times K \times N$ dimensions.
- [ ] Synthesize, place, and route on AMD Xilinx Artix-7/Zynq FPGA with timing and power analysis.
