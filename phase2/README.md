# Phase 2 — Parameterizable Architecture & Sequential Hardware Baseline

## Overview & Objectives

Phase 2 builds upon the successful Phase 1 prototype of the **Systolic Array Matrix Multiplication Accelerator** by:
1. Extending the computational datapath to be fully **parameterizable** across operand bit widths and accumulator sizes.
2. Introducing a **sequential matrix multiplication hardware baseline** (`sequential_matmul_baseline.v`) using a single reusable Multiply-Accumulate (MAC) unit to serve as a hardware reference for speedup, throughput, area, and cycle count benchmarking.
3. Establishing an **architectural interface contract** to allow seamless parallel development between all three team members.

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

## Supported Standard Configurations

| Configuration | ARRAY_SIZE | DATA_WIDTH | ACC_WIDTH | Clock Cycles (Sequential) | Latency ($T_{\text{clk}}=10\text{ ns}$) |
|---|---:|---:|---:|---:|---:|
| **Small Baseline** | 2 | 8 | 32 | **8 cycles** | 80 ns |
| **Default Baseline** | 4 | 8 | 32 | **64 cycles** | 640 ns |
| **Extended Precision** | 4 | 16 | 48 | **64 cycles** | 640 ns |
| **Scaled Baseline** | 8 | 8 | 32 | **512 cycles** | 5,120 ns |

---

## Verification Suite

- **PE Testbench (`testbench/tb_processing_element.v`):**
  - Fully parameterizable for 8-bit and 16-bit configurations.
  - Covers 13 test scenarios: positive multiplication, negative multiplication, double negative, multiplication by zero, multi-MAC accumulation, invalid valid flag masking, accumulator clear, clear priority over MAC, asynchronous reset, data forwarding, valid forwarding, and signed boundary extremes.
- **Sequential Baseline Testbench (`testbench/tb_sequential_baseline.v`):**
  - Parameterizable for $2\times2$, $4\times4$, and $8\times8$ matrices.
  - Tests identity matrix, zero matrix, mixed positive/negative values, signed boundaries, input bus latching, output stability during idle, back-to-back operations, and reset recovery.
  - Verifies all results against an independent algorithmic matrix multiplication model.

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

# 4x4 Matrix Configuration
iverilog -g2012 -P tb_sequential_baseline.ARRAY_SIZE=4 -P tb_sequential_baseline.DATA_WIDTH=8 -P tb_sequential_baseline.ACC_WIDTH=32 \
    -o phase2/simulation/results/seq_baseline_4x4.vvp \
    phase2/rtl/sequential_matmul_baseline.v phase2/testbench/tb_sequential_baseline.v
vvp phase2/simulation/results/seq_baseline_4x4.vvp

# 8x8 Scaled Matrix Configuration
iverilog -g2012 -P tb_sequential_baseline.ARRAY_SIZE=8 -P tb_sequential_baseline.DATA_WIDTH=8 -P tb_sequential_baseline.ACC_WIDTH=32 \
    -o phase2/simulation/results/seq_baseline_8x8.vvp \
    phase2/rtl/sequential_matmul_baseline.v phase2/testbench/tb_sequential_baseline.v
vvp phase2/simulation/results/seq_baseline_8x8.vvp
```

---

## Development Status & Upcoming Work

```text
Phase 2 Component Status:
├── Processing Element (PE) RTL       [COMPLETED - Member 1]
├── Sequential Matmul Baseline RTL    [COMPLETED - Member 1]
├── PE & Baseline Verification        [COMPLETED - Member 1]
├── Interface Contract Document       [COMPLETED - Member 1]
├── Scalable Systolic Array Core      [PENDING   - Member 2]
├── Parameterized Controller & Top    [PENDING   - Member 3]
├── System Integration Verification   [PENDING   - Members 2 & 3]
└── Final Phase 2 IEEE Report         [PENDING   - All Members]
```

### Upcoming Responsibilities:
- **Member 2 (Mayank Sharma):** Design and implement the scalable $N \times N$ systolic array core with parameterized skewing stages based on `phase2_interface_contract.md`.
- **Member 3 (Ankit Kumar Pandey):** Implement the parameterized matrix controller and top-level module, and develop comprehensive integration testbenches.
- **Final Report Deliverable:** The completed Phase 2 IEEE conference report will be placed at `phase2/report/Phase_2_Final_IEEE_Project_Report.pdf`.
