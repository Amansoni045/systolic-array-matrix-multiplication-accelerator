# Phase II System Integration — Controller, Top Level and End-to-End Verification

**Status:** Complete  
**Owner:** Member 3 (Ankit Kumar Pandey)  
**Related files:**

| File | Purpose |
|---|---|
| [`phase2/rtl/matrix_controller.v`](../rtl/matrix_controller.v) | Parameterized FSM controller, input latching, LOAD/DRAIN schedule |
| [`phase2/rtl/systolic_array_top.v`](../rtl/systolic_array_top.v) | Controller + scalable array integration |
| [`phase2/testbench/tb_systolic_array.v`](../testbench/tb_systolic_array.v) | End-to-end protocol, arithmetic and performance testbench |
| [`phase2/verification/golden_model.py`](../verification/golden_model.py) | Parameterized Python golden model and vector generator |
| [`phase2/verification/run_system_tests.py`](../verification/run_system_tests.py) | Multi-configuration regression and benchmark runner |

---

## 1. System Architecture

```text
                     +--------------------------------------------------+
 a_flat  ----------->|                                                  |
 b_flat  ----------->|              matrix_controller                   |
 start   ----------->|  IDLE -> LOAD (N) -> DRAIN (2N-1) -> IDLE        |
                     |  input latches, clear_acc, valid, result,        |
 busy    <-----------|  busy, done                                      |
 done    <-----------|                                                  |
 result  <-----------|                                                  |
                     +----+----------------------+----------------------+
                          | a_out/b_out/valids   | acc_in
                          v                      |
                     +--------------------------------------------------+
                     |            systolic_array (N x N)                |
                     |  input skew buffers + Member 1 processing        |
                     |  elements, output-stationary accumulation        |
                     +--------------------------------------------------+
```

`matrix_controller` owns the complete transaction. `systolic_array_top` is a
thin structural wrapper that connects the controller to Member 2's array, which
in turn instantiates Member 1's parameterized `processing_element`.

Member 1's `sequential_matmul_baseline` is integrated at the system-verification
level: `tb_systolic_array` instantiates both engines, applies the same packed
matrices, and compares their results, latency and sustained throughput.

---

## 2. Parameters and Interface

```verilog
parameter ARRAY_SIZE = 4;   // N x N matrix and array dimension
parameter DATA_WIDTH = 8;   // signed operand width
parameter ACC_WIDTH  = 32;  // signed accumulator width, >= 2*DATA_WIDTH
```

All ports use the row-major packing convention from the
[Phase II interface contract](phase2_interface_contract.md):

```verilog
a_flat[(r*ARRAY_SIZE + c)*DATA_WIDTH +: DATA_WIDTH]
result[(r*ARRAY_SIZE + c)*ACC_WIDTH  +: ACC_WIDTH]
```

The top-level interface is:

| Signal | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 | Clock and asynchronous active-low reset |
| `start` | input | 1 | Start request; accepted only when idle |
| `a_flat`, `b_flat` | input | `N*N*DATA_WIDTH` | Row-major input matrices |
| `busy` | output | 1 | High from start acceptance until completion |
| `done` | output | 1 | Single-cycle completion pulse |
| `result` | output | `N*N*ACC_WIDTH` | Row-major result, stable until the next operation |

The controller exposes the array-facing bus (`a_out`, `b_out`, `a_valid`,
`b_valid`, `clear_acc`, `acc_in`) so that timing can be inspected directly in
simulation.

---

## 3. Controller FSM and Schedule

| State | Duration | Behaviour |
|---|---:|---|
| `IDLE` | until `start` | `busy = 0`, valids deasserted. On `start`, latch `a_flat`/`b_flat`, assert `busy`, clear the array, and enter `LOAD`. |
| `LOAD` | `N` cycles | Drive slice `k = 0 .. N-1`; lane `r` receives `A[r][k]`, lane `c` receives `B[k][c]`; all valids high. |
| `DRAIN` | `2N-1` cycles | Valids low. Wait for the final MAC wavefront and capture `acc_in` into `result`; pulse `done` and drop `busy`. |

### Timing derivation

The array skews lane `r`/`c` by `r+c` cycles inside `systolic_array`, therefore
external slice `k` reaches PE`(r,c)` on edge `k+r+c`.

* The first slice is presented on the edge immediately after acceptance.
* The last MAC for PE`(N-1,N-1)` occurs at edge `1 + 3(N-1) = 3N-2`.
* The completed accumulator bus is captured one edge later, at `3N-1`.
* `DRAIN_CYCLES = 2N-1` covers the `2(N-1)` skew drain edges plus the capture edge.

Hence, for every `ARRAY_SIZE >= 1`:

```text
LOAD_CYCLES        = N
DRAIN_CYCLES       = 2N - 1
start-to-done      = 3N - 1 clock cycles
sustained interval = 3N clock cycles
```

The sustained interval is one cycle longer than the latency because `start` is
accepted only in `IDLE`; the `done` cycle itself is used to observe completion.
This is a deliberate, documented single-outstanding-transaction policy.

### Input latching

`a_flat` and `b_flat` are captured on the acceptance edge into
`a_latched`/`b_latched`. All subsequent slices are read from those registers.
Changing either external bus while `busy` is high has no effect on the active
operation. A `start` pulse while busy is ignored and is not queued.

### Protocol guarantees

* `busy` rises on the cycle after `start` is accepted and stays high until the
  final capture.
* `done` is asserted for exactly one clock cycle together with valid `result`.
* `busy` and `done` are both low during `IDLE`; `result` is unchanged until the
  next completed operation.
* Reset asynchronously clears the FSM, latches, `busy`, `done` and `result`.
* Every operand is masked by its lane valid, so cleared or idle lanes cannot
  corrupt an accumulator.

---

## 4. Golden Model

`phase2/verification/golden_model.py` is parameterized by `size`,
`data_width` and `acc_width` and matches the RTL numerics:

* operands are wrapped to signed `DATA_WIDTH` bits;
* products are exact signed values;
* accumulation is wrapped modulo `2**ACC_WIDTH`.

It provides matrix multiplication, packing/unpacking, row-major hex export,
human-readable test-vector generation, `$readmemh` files for the integration
testbench, and verification of an RTL result hex dump. `test_golden_model.py`
adds 12 unit tests covering random sizes, signed extremes, minimum accumulator
widths, wraparound, packing layout and vector round-trips.

---

## 5. Verification Strategy

The end-to-end testbench (`tb_systolic_array.v`) runs, for each configuration:

1. **Eight directed cases** — zero, identity on both sides, all-ones, maximum
   positive, minimum negative, alternating extremes and mixed signs.
2. **Golden-model vectors** — directed plus deterministic random cases
   generated in Python (default 31), each checked against the RTL result and
   against the sequential baseline.
3. **Additional random cases** — generated inside the Verilog testbench.
4. **Input latching and busy-time start** — buses are corrupted immediately
   after acceptance and a `start` pulse is injected while busy; the original
   result and exact latency must be preserved.
5. **Back-to-back operation** — a second transaction is launched in the cycle
   after `done`; measured initiation interval must be exactly `3N` for the
   systolic engine and `N^3+1` for the sequential baseline.
6. **Reset recovery** — reset in the middle of an operation must clear
   `busy`/`done`/`result`, after which a complete new operation must pass.

Every arithmetic case is checked three ways:

```text
systolic RTL  ==  sequential RTL  ==  expected model
```

The runner compiles nine configurations (`N = 1, 2, 3, 4, 8`, 8/16-bit
operands, 32/48-bit accumulators, and the minimum legal 16-bit accumulator).
All configurations pass 46 cases each, i.e. **414 end-to-end cases**, plus the
golden-model unit tests.

---

## 6. Reproduction

From the repository root:

```bash
# Full multi-configuration regression and performance summary
python3 phase2/verification/run_system_tests.py

# Golden model only
python3 phase2/verification/golden_model.py --size 4 --data-width 8 --acc-width 32

# Golden model unit tests
cd phase2/verification && python3 -m unittest test_golden_model -v
```

Manual single-configuration simulation:

```bash
iverilog -g2012 -Wall -s tb_systolic_array \
    -P tb_systolic_array.ARRAY_SIZE=4 \
    -P tb_systolic_array.DATA_WIDTH=8 \
    -P tb_systolic_array.ACC_WIDTH=32 \
    -P tb_systolic_array.RANDOM_CASES=4 \
    -P tb_systolic_array.GOLDEN_CASES=0 \
    -o phase2/simulation/results/system_4x4.vvp \
    phase2/rtl/processing_element.v phase2/rtl/systolic_array.v \
    phase2/rtl/matrix_controller.v phase2/rtl/systolic_array_top.v \
    phase2/rtl/sequential_matmul_baseline.v \
    phase2/testbench/tb_systolic_array.v
vvp phase2/simulation/results/system_4x4.vvp
```

Measured results are in
[`phase2/report/system_integration_results.md`](../report/system_integration_results.md)
and the machine-readable
[`system_summary.csv`](../simulation/results/system_summary.csv).

---

## 7. Design Notes and Limitations

* The controller is a single-outstanding-transaction engine. Supporting
  overlapped loads would require a separate input buffer or a ping-pong latch,
  and is outside the current Phase II scope.
* `ACC_WIDTH >= 2 * DATA_WIDTH` is enforced by the PE/array/top elaboration
  checks; the testbench also exercises the minimum-width wraparound case.
* The array is output-stationary. Results are captured from the array's
  accumulator bus after the final wavefront, rather than being shifted out.
* `ARRAY_SIZE = 1` is legal but the fixed protocol overhead dominates; the
  systolic engine is slower than the sequential baseline at that size. The
  crossover is at `N >= 2` for latency and throughput in the measured table.
