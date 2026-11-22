# Phase 2 — Parameterizable Architecture & Sequential Hardware Baseline

## Overview & Objectives

Phase 2 builds upon the successful Phase 1 prototype of the **Systolic Array Matrix Multiplication Accelerator** by:
1. Extending the computational datapath to be fully **parameterizable** across operand bit widths and accumulator sizes.
2. Introducing a **sequential matrix multiplication hardware baseline** (`sequential_matmul_baseline.v`) using a single reusable Multiply-Accumulate (MAC) unit to serve as a hardware reference for speedup, throughput, area, and cycle count benchmarking.
3. Establishing an **architectural interface contract** to allow seamless parallel development between all three team members.
4. Integrating the parameterized controller, top level, PE, array and baseline into one verified end-to-end accelerator with measured latency and throughput.

---

## Architectural Direction

In Phase 2, the design moves from a hardcoded 4×4 INT8 implementation to a generic, parameterized architecture defined by:
- `ARRAY_SIZE`: Square matrix dimension ($N \times N$, rows and columns).
- `DATA_WIDTH`: Signed input operand bit width (default 8 bits).
- `ACC_WIDTH`: Signed accumulator bit width (default 32 bits, must satisfy $\text{ACC\_WIDTH} \ge 2 \times \text{DATA\_WIDTH}$).

Matrices maintain a **row-major packed bus representation**:
- Input bus ($A$, $B$): $\text{ARRAY\_SIZE} \times \text{ARRAY\_SIZE} \times \text{DATA\_WIDTH}$ bits.
- Output bus ($C$): $\text{ARRAY\_SIZE} \times \text{ARRAY\_SIZE} \times \text{ACC\_WIDTH}$ bits.
- Slicing formula: `matrix[(r * ARRAY_SIZE + c) * DATA_WIDTH +: DATA_WIDTH]`.

For complete interface definitions, consult the [Phase 2 Interface Contract](docs/phase2_interface_contract.md).

---

## Implemented Work (Member 1 — Aman)

Member 1 has completed the parameterized Processing Element and the Sequential Matrix Multiplication Baseline:

### 1. Parameterizable Processing Element (`rtl/processing_element.v`)
- Parameterized by `DATA_WIDTH` (default 8) and `ACC_WIDTH` (default 32). Fully independent of `ARRAY_SIZE`.
- Performs signed multiplication producing a $2 \times \text{DATA\_WIDTH}$ bit product.
- Sign-extends product to `ACC_WIDTH` bits before accumulation.
- Active-low asynchronous reset (`rst_n`) and active-high synchronous accumulator clear (`clear_acc`).
- `clear_acc` takes strict priority over incoming MAC operations.
- Continuous registered horizontal (`a_out`) and vertical (`b_out`) data forwarding accompanied by valid flags (`a_valid_out`, `b_valid_out`).

### 2. Sequential Matmul Baseline (`rtl/sequential_matmul_baseline.v`)
- Pure single-MAC sequential hardware implementation (no systolic array).
- Accepts packed inputs, latches matrices on `start` when idle, and ignores external bus noise during computation.
- Computes 1 MAC per clock cycle over $N^3$ compute cycles ($N = \text{ARRAY\_SIZE}$).
- Calculates and stores each output element $(r, c)$ before advancing to the next.
- Generates a single-cycle `done` pulse and holds the final `result` stable until another operation or reset.

---

## Implemented Work (Member 3 — Ankit)

Member 3 has completed the parameterized controller, the integrated top level, the Python golden model extension and the end-to-end system verification.

### 1. Parameterized Matrix Controller (`rtl/matrix_controller.v`)
- Parameterized by `ARRAY_SIZE`, `DATA_WIDTH` and `ACC_WIDTH`, and independent of the Phase 1 hardcoded geometry.
- Latches `a_flat` and `b_flat` on the cycle `start` is accepted, so bus changes while `busy` are ignored.
- Drives the unskewed row-major k-slices expected by the array: lane `r` receives `A[r][k]`, lane `c` receives `B[k][c]`.
- Schedule is derived from the dimensions: `LOAD = N` cycles, `DRAIN = 2N-1` cycles, so latency is exactly `3N-1` cycles and sustained initiation interval is `3N` cycles.
- Asserts `busy` on acceptance, ignores `start` while busy, pulses `done` for one cycle, and holds `result` stable until the next operation.
- Clears the array on the acceptance edge (reset is asynchronous); the final accumulator bus is captured after the last MAC wavefront.

### 2. Integrated Top Level (`rtl/systolic_array_top.v`)
- Connects the controller to Member 2's `systolic_array`, which instantiates Member 1's parameterized `processing_element`.
- Exposes a single `start`/`busy`/`done`/`result` interface with packed matrix buses.
- Enforces `ACC_WIDTH >= 2*DATA_WIDTH` at elaboration time.

### 3. Golden Model and System Verification
- `verification/golden_model.py` supports arbitrary `N`, `DATA_WIDTH` and `ACC_WIDTH`, with RTL-exact signed wrapping, packing, hex/`$readmemh` vector export and result verification.
- `testbench/tb_systolic_array.v` compares the systolic engine against both an independent expected model and Member 1's sequential baseline, and checks latching, handshake, back-to-back throughput and reset recovery.
- `verification/run_system_tests.py` runs 9 configurations (414 end-to-end cases) and produces the measured performance summary.

- **Design details:** [Phase II System Integration](docs/phase2_system_integration.md)
- **Measured results:** [System Integration Results](report/system_integration_results.md)

---

## Supported Standard Configurations

| Configuration | ARRAY_SIZE | DATA_WIDTH | ACC_WIDTH | Systolic Latency (cycles) | Systolic II (cycles) | Sequential Latency (cycles) | Latency Speedup |
|---|---:|---:|---:|---:|---:|---:|---:|
| **Minimal Edge** | 1 | 8 | 32 | **2** | 3 | **1** | 0.50x |
| **Small Baseline** | 2 | 8 | 32 | **5** | 6 | **8** | 1.60x |
| **Default Baseline** | 4 | 8 | 32 | **11** | 12 | **64** | 5.82x |
| **Extended Precision** | 4 | 16 | 48 | **11** | 12 | **64** | 5.82x |
| **Scaled Baseline** | 8 | 8 | 32 | **23** | 24 | **512** | 22.26x |
| **Scaled Extended** | 8 | 16 | 48 | **23** | 24 | **512** | 22.26x |

At 100 MHz the default 4×4 design completes a matrix in 110 ns and sustains one matrix every 120 ns; the 8×8 design completes in 230 ns and sustains one every 240 ns. The systolic engine is slower than the single-MAC baseline only at `N=1`, where fixed protocol overhead dominates.

---

## Verification Suite

- **PE Testbench (`testbench/tb_processing_element.v`):**
  - Fully parameterizable for 8-bit and 16-bit configurations.
  - Covers 13 test scenarios: positive multiplication, negative multiplication, double negative, multiplication by zero, multi-MAC accumulation, invalid valid flag masking, accumulator clear, clear priority over MAC, asynchronous reset, data forwarding, valid forwarding, and signed boundary extremes.
- **Sequential Baseline Testbench (`testbench/tb_sequential_baseline.v`):**
  - Parameterizable for $2\times2$, $4\times4$, and $8\times8$ matrices, as well as 16-bit extended precision ($4\times4$, `DATA_WIDTH=16`, `ACC_WIDTH=48`).
  - **Handshake Protocol & Busy/Done Verification:** Confirms `busy` asserts upon start acceptance, remains high throughout execution, and falls when done; confirms `done` asserts for exactly one clock cycle and returns to zero; confirms secondary `start` requests during `busy` are safely ignored and not queued; confirms external input bus corruption during computation does not affect results; confirms results remain stable across idle periods.
  - **Deterministic Latency & Timeout Protection:** Verifies exact $N^3$ clock cycle compute latency from start acceptance to done assertion; incorporates simulation timeout safeguards.
  - **Comprehensive Arithmetic Coverage:** Tests identity matrix ($A \times I = A$), zero matrix ($A \times 0 = 0$), mixed positive/negative values, signed boundary extremes (8-bit: $-128$ to $+127$; 16-bit: $-32768$ to $+32767$), large-magnitude product accumulation without overflow, back-to-back operations, and mid-computation asynchronous reset recovery.
  - Verifies all results against an independent algorithmic matrix multiplication model.
- **End-to-End System Testbench (`testbench/tb_systolic_array.v`):**
  - Instantiates the parameterized top level and Member 1's sequential baseline and drives both with identical matrices.
  - Checks every result three ways: `systolic RTL == sequential RTL == expected model`.
  - Runs 8 directed cases, golden-model vectors generated by Python, and seeded in-testbench random cases.
  - Verifies input latching when `start` is accepted, immunity to bus corruption while busy, ignored busy-time `start`, `busy`/`done` timing, one-cycle `done`, and result stability.
  - Checks exact latency (`3N-1` systolic, `N^3` sequential), back-to-back initiation intervals (`3N` versus `N^3+1`) and mid-operation reset recovery.
  - Optionally reads `$readmemh` golden vectors (`+VECTORS_DIR`) and writes a CSV report (`+REPORT`).
- **Python Golden Model and Runner:**
  - `verification/golden_model.py` supports arbitrary dimensions and signed wrapping.
  - `verification/test_golden_model.py` contains 12 unit tests for numerics, packing and vector I/O.
  - `verification/run_system_tests.py` runs 9 configurations × 46 cases, validates the measured schedule and writes `simulation/results/system_summary.csv`.

---

## How to Build and Simulate

> **Important Execution Path Rule:** Execute all Phase 2 simulation commands from the **repository root directory** so that VCD waveform paths (`phase2/simulation/waveforms/*.vcd`) resolve correctly.

### 1. Simulate Parameterizable Processing Element (PE)

```bash
# 8-bit Configuration (DATA_WIDTH=8, ACC_WIDTH=32)
iverilog -g2012 -P tb_processing_element.DATA_WIDTH=8 -P tb_processing_element.ACC_WIDTH=32 \
    -o phase2/simulation/results/pe_8bit.vvp \
    phase2/rtl/processing_element.v phase2/testbench/tb_processing_element.v
vvp phase2/simulation/results/pe_8bit.vvp

# 16-bit Extended Precision Configuration (DATA_WIDTH=16, ACC_WIDTH=48)
iverilog -g2012 -P tb_processing_element.DATA_WIDTH=16 -P tb_processing_element.ACC_WIDTH=48 \
    -o phase2/simulation/results/pe_16bit.vvp \
    phase2/rtl/processing_element.v phase2/testbench/tb_processing_element.v
vvp phase2/simulation/results/pe_16bit.vvp
```

### 2. Simulate Sequential Matmul Baseline

```bash
# 2x2 Matrix Configuration
iverilog -g2012 -P tb_sequential_baseline.ARRAY_SIZE=2 -P tb_sequential_baseline.DATA_WIDTH=8 -P tb_sequential_baseline.ACC_WIDTH=32 \
    -o phase2/simulation/results/seq_baseline_2x2.vvp \
    phase2/rtl/sequential_matmul_baseline.v phase2/testbench/tb_sequential_baseline.v
vvp phase2/simulation/results/seq_baseline_2x2.vvp

# 4x4 Matrix Configuration (Standard Precision: DATA_WIDTH=8, ACC_WIDTH=32)
iverilog -g2012 -P tb_sequential_baseline.ARRAY_SIZE=4 -P tb_sequential_baseline.DATA_WIDTH=8 -P tb_sequential_baseline.ACC_WIDTH=32 \
    -o phase2/simulation/results/seq_baseline_4x4.vvp \
    phase2/rtl/sequential_matmul_baseline.v phase2/testbench/tb_sequential_baseline.v
vvp phase2/simulation/results/seq_baseline_4x4.vvp

# 4x4 Matrix Configuration (Extended Precision: DATA_WIDTH=16, ACC_WIDTH=48)
iverilog -g2012 -P tb_sequential_baseline.ARRAY_SIZE=4 -P tb_sequential_baseline.DATA_WIDTH=16 -P tb_sequential_baseline.ACC_WIDTH=48 \
    -o phase2/simulation/results/seq_baseline_4x4_16bit.vvp \
    phase2/rtl/sequential_matmul_baseline.v phase2/testbench/tb_sequential_baseline.v
vvp phase2/simulation/results/seq_baseline_4x4_16bit.vvp

# 8x8 Scaled Matrix Configuration
iverilog -g2012 -P tb_sequential_baseline.ARRAY_SIZE=8 -P tb_sequential_baseline.DATA_WIDTH=8 -P tb_sequential_baseline.ACC_WIDTH=32 \
    -o phase2/simulation/results/seq_baseline_8x8.vvp \
    phase2/rtl/sequential_matmul_baseline.v phase2/testbench/tb_sequential_baseline.v
vvp phase2/simulation/results/seq_baseline_8x8.vvp
```

### 3. Run the Full System Integration Regression

The runner generates golden vectors, compiles every configuration, runs the end-to-end testbench, validates the measured latency/throughput and writes the performance summary:

```bash
python3 phase2/verification/run_system_tests.py
```

Outputs:

- `phase2/simulation/results/system_summary.csv` — machine-readable measured results
- `phase2/simulation/results/system_*.csv` — per-configuration reports
- `phase2/simulation/results/system_*.log` and `*_compile.log` — simulation and compile logs

Options: `--golden-random N`, `--random-cases N`, `--seed N`, `--clock-mhz F`,
`--waveforms`, `--skip-unit-tests`.

Single-configuration manual run:

```bash
iverilog -g2012 -Wall -s tb_systolic_array \
    -P tb_systolic_array.ARRAY_SIZE=4 \
    -P tb_systolic_array.DATA_WIDTH=8 \
    -P tb_systolic_array.ACC_WIDTH=32 \
    -P tb_systolic_array.RANDOM_CASES=4 \
    -o phase2/simulation/results/system_4x4.vvp \
    phase2/rtl/processing_element.v phase2/rtl/systolic_array.v \
    phase2/rtl/matrix_controller.v phase2/rtl/systolic_array_top.v \
    phase2/rtl/sequential_matmul_baseline.v \
    phase2/testbench/tb_systolic_array.v
vvp phase2/simulation/results/system_4x4.vvp
```

Golden model only:

```bash
python3 phase2/verification/golden_model.py --size 4 --data-width 8 --acc-width 32
cd phase2/verification && python3 -m unittest test_golden_model -v
```

---

## Development Status & Upcoming Work

```text
Phase 2 Component Status:
├── Processing Element (PE) RTL       [COMPLETED - Member 1]
├── Sequential Matmul Baseline RTL    [COMPLETED - Member 1]
├── PE & Baseline Verification        [COMPLETED - Member 1]
├── Interface Contract Document       [COMPLETED - Member 1]
├── Scalable Systolic Array Core      [COMPLETED - Member 2; standalone regression passed]
├── Parameterized Controller & Top    [COMPLETED - Member 3]
├── Golden Model Extension            [COMPLETED - Member 3]
├── System Integration Verification   [COMPLETED - Members 2 & 3]
├── Latency/Throughput Benchmark      [COMPLETED - Member 3; 9 configurations, 414 cases]
└── Final Phase 2 IEEE Report         [PENDING   - All Members]
```

### Remaining Work:
- **Final Report Deliverable:** The completed Phase 2 IEEE conference report will be placed at `phase2/report/Phase_2_Final_IEEE_Project_Report.pdf`.
- **Member 2 (Mayank Sharma):** Review the integrated array timing and contribute the array section to the final report.
- **Member 1 (Aman Soni):** Review the PE/baseline integration and contribute the datapath section to the final report.
- **Member 3 (Ankit Kumar Pandey):** Integrate the controller, golden model and measured benchmark results into the final report.


## Member 2 — Scalable Array

- RTL: `rtl/systolic_array.v`
- Testbench: `testbench/tb_systolic_array_core.v`
- Parameters: `ARRAY_SIZE`, `DATA_WIDTH`, `ACC_WIDTH`.
- Supply unskewed inputs for N edges, then drain for `2*(N-1)` edges.

Run from the repository root:

```bash
python3 phase2/verification/run_array_tests.py
```

The standalone regression passed all 10 configurations with Icarus Verilog, checking 110 matrices per configuration. It covers array sizes 1, 2, 3, 4 and 8, 8-bit and 16-bit operands, and minimum-width accumulators. The runner writes measured results to `simulation/results/array_summary.csv`.
