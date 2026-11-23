# Systolic Array Matrix Multiplication Accelerator

A high-throughput, parameterizable hardware accelerator for general matrix multiplication (GEMM) implemented in Verilog HDL. The accelerator utilizes a two-dimensional output-stationary systolic array with integrated diagonal skewing registers and an autonomous finite state machine controller. It scales across matrix dimensions ($N \times N$) and arithmetic precisions (INT8, INT16), achieving an optimal $3N-1$ clock-cycle compute latency. A single-MAC sequential baseline is provided for bit-accurate verification and performance benchmarking.

## Key Features

- **Scalable Architecture:** Parameterized array dimension (`ARRAY_SIZE`), operand width (`DATA_WIDTH`), and accumulator width (`ACC_WIDTH`).
- **Output-Stationary Dataflow:** Dot products accumulate locally within processing elements, minimizing data movement and register switching.
- **Autonomous FSM Control:** Deterministic input latching, single-cycle clear, and streamlined LOAD/DRAIN scheduling with start/busy/done handshaking.
- **Benchmarked Performance:** Validated against a single-MAC sequential baseline across 9 configurations, delivering up to $22.26\times$ latency speedup at $N=8$.

## Repository Layout

| Directory / File | Description |
|---|---|
| `rtl/` | Synthesizable Verilog modules (PE, array mesh, controller, top level, sequential baseline) |
| `testbench/` | Self-checking Verilog testbenches for unit, core, system, and baseline verification |
| `verification/` | Python golden model, vector generators, and automated regression runners |
| `sim/` | Simulation artifacts (`results/system_summary.csv` and waveform output directory) |
| `phase&#49;_report/` | Phase I IEEE project report (`.tex` and `.pdf`) and architecture figures |
| `final_report/` | Final IEEE project report (`.tex` and `.pdf`) with comprehensive benchmark data |
| `video/` | Prototype demonstration video (`MCA_Phase_1.mp4`) |

## Team Members and Roles

| Member | Assigned Responsibility |
|---|---|
| **Aman Soni** (Member 1) | Processing Element (`rtl/processing_element.v`), Sequential Baseline (`rtl/sequential_matmul_baseline.v`), PE and baseline testbenches, interface contract |
| **Mayank Sharma** (Member 2) | Systolic Array mesh & skewing logic (`rtl/systolic_array.v`), core scoreboard testbench (`testbench/tb_systolic_array_core.v`) |
| **Ankit Kumar Pandey** (Member 3) | Matrix Controller FSM (`rtl/matrix_controller.v`), top-level wrapper (`rtl/systolic_array_top.v`), golden model, system tests & benchmarking |

## Simulation and Verification

Run each test suite from the repository root using Icarus Verilog and Python 3:

```bash
# 1. Processing Element Unit Test (8-bit operands, 32-bit accumulator)
iverilog -g2012 -DDATA_WIDTH=8 -DACC_WIDTH=32 -o sim/pe_8bit.vvp rtl/processing_element.v testbench/tb_processing_element.v && vvp sim/pe_8bit.vvp

# 2. Processing Element Unit Test (16-bit operands, 48-bit accumulator)
iverilog -g2012 -P tb_processing_element.DATA_WIDTH=16 -P tb_processing_element.ACC_WIDTH=48 -o sim/pe_16bit.vvp rtl/processing_element.v testbench/tb_processing_element.v && vvp sim/pe_16bit.vvp

# 3. Sequential Baseline Test (4x4 matrix, 8-bit operands, 32-bit accumulator)
iverilog -g2012 -DARRAY_SIZE=4 -DDATA_WIDTH=8 -DACC_WIDTH=32 -o sim/seq_4x4.vvp rtl/sequential_matmul_baseline.v testbench/tb_sequential_baseline.v && vvp sim/seq_4x4.vvp

# 4. Golden Model Unit Tests
python3 -m unittest discover -s verification -p "*test*.py" -v

# 5. Array Core Regressions (10 configurations)
python3 verification/run_array_tests.py

# 6. Full System Integration & Benchmark Suite (9 configurations, 414 test cases)
python3 verification/run_system_tests.py
```

## Documentation and Deliverables

- **Phase I IEEE Report:** [IEEE_Project_Report_Phase_1.pdf](phase%31_report/IEEE_Project_Report_Phase_%31.pdf)
- **Final IEEE Report:** [Final_IEEE_Project_Report.pdf](final_report/Final_IEEE_Project_Report.pdf)
- **Prototype Demonstration Video:** [MCA_Phase_1.mp4](video/MCA_Phase_1.mp4)
- **Measured Benchmark Summary:** [system_summary.csv](sim/results/system_summary.csv)
