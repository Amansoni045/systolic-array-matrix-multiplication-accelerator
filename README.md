# Systolic Array Matrix Multiplication Accelerator

## Project Overview

The **Systolic Array Matrix Multiplication Accelerator** is an academic hardware design project aimed at designing, simulating, and verifying a high-throughput, energy-efficient matrix multiplication engine. Systolic arrays are specialized parallel computing architectures where data streams rhythmically through a 2D grid of tightly-coupled Processing Elements (PEs), maximizing data reuse and minimizing memory bandwidth bottlenecks.

This project targets a fixed 4×4 systolic array in Verilog HDL, with signed 8-bit operands and signed 32-bit accumulators. The PE and array RTL are implemented. Controller, top-level integration, and Python golden-model files are currently placeholders; complete accelerator verification is pending.

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
   - Supplies unskewed input matrix streams; the array handles lane staggering internally.
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
- `rtl/matrix_controller.v`: Control logic, state machine, unskewed input streaming, and sequencing.
- `rtl/systolic_array_top.v`: Top-level integration of controller and array grid.
- `testbench/tb_systolic_array.v`: System-level integration testbench.
- `verification/golden_model.py`: Algorithmic golden model, test vector generation, and automated result validation.

## Member 2: Array Integration Contract

`rtl/systolic_array.v` instantiates Aman's unchanged `processing_element` module
16 times using nested generate loops. A travels right, B travels down, and each
operand has its own registered valid path. No start/busy/done signals are generated
by the array; these belong to Member 3's controller/top-level.

| Port | Width | Meaning |
| --- | --- | --- |
| `clk` | 1 | Rising-edge clock |
| `rst_n` | 1 | Active-low asynchronous reset of all array state |
| `clear_acc` | 1 | Synchronous clear of all sums and pending valid operands; input on this edge is discarded |
| `a_in` | 32 | Four signed 8-bit A row lanes; row `r` at `[8*r +: 8]` |
| `b_in` | 32 | Four signed 8-bit B column lanes; column `c` at `[8*c +: 8]` |
| `a_valid_in` | 4 | One valid bit per A row lane |
| `b_valid_in` | 4 | One valid bit per B column lane |
| `acc_out` | 512 | Sixteen signed 32-bit sums; `C[r][c]` at `[32*(4*r+c) +: 32]` |

Packed buses are unsigned containers. Interpret individual operand/result slices
as signed values (for example, `$signed(acc_out[32*(4*r+c) +: 32])`). Index zero
occupies the least significant bits. Results remain available until clear/reset
or another valid operand pair contributes to a sum.

### Controller schedule (no external skewing)

1. Pulse `clear_acc` for one rising edge before each matrix operation.
2. On the next four rising edges, provide `a_in[r] = A[r][k]` and
   `b_in[c] = B[k][c]`, for `k = 0, 1, 2, 3`. Assert all lane valid bits.
3. Deassert all input valid bits and let the array drain for six more edges.
4. Collect all 16 results after the final edge's register updates. A synchronous
   top-level result register can capture them on the following edge.

Here `a_in[r]`/`b_in[c]` denote 8-bit lanes, not single Verilog bits. For example,
`a_in = {A[3][k], A[2][k], A[1][k], A[0][k]}` with each element 8 bits.

The array delays A row `r` by `r` clocks and B column `c` by `c` clocks. Both
operands for term `k` therefore reach PE `(r,c)` on edge `k+r+c`, counting the
first input edge as edge 0. Each PE completes its result on edge `3+r+c`.

| Edge | Input term | Event |
| --- | --- | --- |
| Clear | Discarded | Clear accumulators and invalidate pipeline |
| 0 | `k=0` | First MAC at PE `(0,0)` |
| 1 | `k=1` | Operands advance to neighbours |
| 2 | `k=2` | Array fills |
| 3 | `k=3` | `C[0][0]` complete |
| 4–8 | All valids low | Remaining MACs propagate |
| 9 | All valids low | `C[3][3]` complete; all results ready after edge |
| 10 | All valids low | Controller may register the complete result matrix |

Common all-lane bubbles are supported: hold all valid bits low for a bubble and
resume with the next `k` on all lanes. Every bubble adds one clock to the schedule.
Independent valid masks are propagated correctly, but there is no buffering,
backpressure, or operand matching: the controller must supply corresponding A/B
terms in the same external slot. A missing lane is a missing contribution, not a
stall. Do not skew the streams again in the controller.

`clear_acc` takes priority over MAC and also cancels in-flight work. A new stream
can start on the next edge. Internal data registers inside Aman's PEs still forward
data on clear, as designed; their valid bits are forced low, so discarded data
cannot contribute to later sums.

### Array unit verification

`testbench/tb_systolic_array_core.v` is Member 2's independent unit test. It leaves
Member 3's `tb_systolic_array.v` untouched. It checks every output on every clock
against an independent timing model and compares complete matrix products for
105 cases: zero, identity, positive, mixed signs, signed extremes, and 100 random
pairs. It also exercises bubbles, independent valid masks, idle result retention,
clear during active traffic, asynchronous reset, and restart.

From the repository root, with Icarus Verilog installed:

```bash
mkdir -p simulation/results simulation/waveforms
iverilog -g2005 -Wall -s tb_processing_element -o simulation/results/pe.vvp rtl/processing_element.v testbench/tb_processing_element.v
vvp simulation/results/pe.vvp
iverilog -g2005 -Wall -s tb_systolic_array_core -o simulation/results/array.vvp rtl/processing_element.v rtl/systolic_array.v testbench/tb_systolic_array_core.v
vvp simulation/results/array.vvp
```

The array test ends with a `PASS: 105 matrices, ...` message if successful and
terminates with `$fatal` on mismatches. These commands have not yet been executed
in the implementation environment because Icarus Verilog is unavailable.

---

## Member 3: Controller, Top-level, and Verification

### Controller Schedule Summary

The `matrix_controller` drives the `systolic_array` with the following precise cycle
schedule (all transitions on rising edges of `clk`):

| Cycle from `start` | State  | Action                                      |
|--------------------|--------|---------------------------------------------|
| 0 (start detected) | CLEAR  | Assert `clear_acc=1`, `busy=1`              |
| 1                  | LOAD k=0 | Drive A[r][0] / B[0][c], `valids=1111`  |
| 2                  | LOAD k=1 | Drive A[r][1] / B[1][c]                 |
| 3                  | LOAD k=2 | Drive A[r][2] / B[2][c]                 |
| 4                  | LOAD k=3 | Drive A[r][3] / B[3][c]                 |
| 5–10               | DRAIN d=0..5 | `valids=0000`, operands propagate    |
| 11                 | IDLE   | Latch `result <= acc_in`, pulse `done=1`, `busy=0` |

Total latency from `start` to `done`: **12 clock cycles**.

The controller supplies **unskewed** inputs — it does NOT pre-skew the matrix
streams. The `systolic_array` module handles all internal lane staggering (row `r`
delayed by `r` clocks, column `c` delayed by `c` clocks).

Indexing convention:
- `a_flat[8*(4*r+c) +: 8]` = `A[r][c]`  (row-major)
- `b_flat[8*(4*r+c) +: 8]` = `B[r][c]`  (row-major)
- `result[32*(4*r+c) +: 32]` = `C[r][c]` (row-major, signed 32-bit)

### Running the System Integration Testbench

```bash
mkdir -p simulation/results simulation/waveforms
iverilog -g2005 -Wall -s tb_systolic_array \
    -o simulation/results/top.vvp \
    rtl/processing_element.v \
    rtl/systolic_array.v \
    rtl/matrix_controller.v \
    rtl/systolic_array_top.v \
    testbench/tb_systolic_array.v
vvp simulation/results/top.vvp
```

The testbench covers 9 test cases:
0. Identity × M = M
1. Zero × Zero = Zero
2. Known positive 4×4 multiply
3. Signed extreme values (−128 / 127)
4. Mixed positive and negative values
5–6. Back-to-back operations (no idle between multiplications)
7. Reset during active operation — DUT must recover cleanly
8. Result stability — output holds unchanged until next `start`

Each test case verifies the `done` pulse is exactly one cycle wide. On mismatch
the testbench prints the failing element and increments an error counter; the
final line reports `ALL TESTS PASSED` or the number of failures.

### Python Golden Model

```bash
python3 verification/golden_model.py
```

This script:
1. Generates 40 test vectors (20 corner cases + 20 random) in `verification/test_vectors/`.
2. Runs every vector through `matmul_4x4()` and self-checks against the stored expected output.
3. Exports a `$readmemh`-compatible hex file (`test_002_readmemh.hex`) for use in directed tests.
4. Demonstrates `verify_verilog_output()` by packing a known result and verifying it.

The `verify_verilog_output(result_hex_512bit, A, B)` function accepts the hex dump
of the 512-bit `acc_out` bus (LSB-first, C[0][0] in the least-significant 32-bit
word), unpacks 16 signed 32-bit words, and checks each against `matmul_4x4(A, B)`.

