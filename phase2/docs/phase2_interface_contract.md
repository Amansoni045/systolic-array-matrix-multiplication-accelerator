# Phase II Interface Contract: Systolic Array Matrix Multiplication Accelerator

**Status:** Draft for Team Review  
**Author:** Member 1 (Aman)  
**Applicability:** Universal agreement across Member 1 (PE & Sequential Baseline), Member 2 (Systolic Array & Skewing Logic), and Member 3 (Matrix Controller & Top-Level Integration)

---

## 1. Architectural Parameters

All Phase II modules and testbenches share the following parameterized architectural definitions:

```verilog
parameter ARRAY_SIZE = 4;
parameter DATA_WIDTH = 8;
parameter ACC_WIDTH  = 32;
```

### Parameter Semantics
- **`ARRAY_SIZE`**: Number of rows and columns in the square systolic array and input matrices ($N \times N$).
- **`DATA_WIDTH`**: Bit width of signed matrix input operands ($A_{r,c}$ and $B_{r,c}$).
- **`ACC_WIDTH`**: Bit width of the signed accumulator and output elements ($C_{r,c}$). Must satisfy $\text{ACC\_WIDTH} \ge 2 \times \text{DATA\_WIDTH}$.

### Supported Standard Configurations

| Configuration | ARRAY_SIZE | DATA_WIDTH | ACC_WIDTH | Input Bus Width (bits) | Output Bus Width (bits) |
|---|---:|---:|---:|---:|---:|
| **Default (4x4, 8-bit)** | 4 | 8 | 32 | 128 | 512 |
| **Extended Precision (4x4, 16-bit)** | 4 | 16 | 48 | 256 | 768 |
| **Small Baseline (2x2, 8-bit)** | 2 | 8 | 32 | 32 | 128 |
| **Scaled Baseline (8x8, 8-bit)** | 8 | 8 | 32 | 512 | 2048 |

---

## 2. Matrix Storage and Packing Convention

1. **Storage Ordering:** Matrices are stored in **row-major** order across flattened multi-bit vector buses.
2. **Total Bus Widths:**
   - Input matrix bus ($A$ or $B$): $\text{ARRAY\_SIZE} \times \text{ARRAY\_SIZE} \times \text{DATA\_WIDTH}$ bits.
   - Output matrix bus ($C$ / Result): $\text{ARRAY\_SIZE} \times \text{ARRAY\_SIZE} \times \text{ACC\_WIDTH}$ bits.
3. **Indexing Slices:**
   - For an input matrix element at row $r$ ($0 \le r < \text{ARRAY\_SIZE}$) and column $c$ ($0 \le c < \text{ARRAY\_SIZE}$):
     ```verilog
     matrix[(r * ARRAY_SIZE + c) * DATA_WIDTH +: DATA_WIDTH]
     ```
   - For an accumulated output matrix element at row $r$ and column $c$:
     ```verilog
     result[(r * ARRAY_SIZE + c) * ACC_WIDTH +: ACC_WIDTH]
     ```
4. **Number Representation:**
   - All input elements are signed two's complement integers in range $[-2^{\text{DATA\_WIDTH}-1}, 2^{\text{DATA\_WIDTH}-1}-1]$.
   - Intermediate products are signed $2 \times \text{DATA\_WIDTH}$ bits.
   - Accumulator outputs are signed two's complement integers in range $[-2^{\text{ACC\_WIDTH}-1}, 2^{\text{ACC\_WIDTH}-1}-1]$.

---

## 3. Processing Element (PE) Module Contract

The Processing Element is modular and **independent of `ARRAY_SIZE`**. It is parameterized strictly by `DATA_WIDTH` and `ACC_WIDTH`.

### Module Declaration
```verilog
module processing_element #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
) (
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         clear_acc,
    input  wire signed [DATA_WIDTH-1:0] a_in,
    input  wire signed [DATA_WIDTH-1:0] b_in,
    input  wire                         a_valid_in,
    input  wire                         b_valid_in,
    output reg  signed [DATA_WIDTH-1:0] a_out,
    output reg  signed [DATA_WIDTH-1:0] b_out,
    output reg                          a_valid_out,
    output reg                          b_valid_out,
    output reg  signed [ACC_WIDTH-1:0]  acc_out
);
```

### Signal Specifications

| Signal | Direction | Width | Description |
|---|---|---|---|
| `clk` | Input | 1 | Global system clock (posedge active). |
| `rst_n` | Input | 1 | Asynchronous active-low reset. Resets all registers and outputs to 0. |
| `clear_acc` | Input | 1 | Synchronous active-high accumulator clear. Takes priority over MAC operations. |
| `a_in` | Input | `DATA_WIDTH` | Signed input data operand from left neighbor or input feeder. |
| `b_in` | Input | `DATA_WIDTH` | Signed input data operand from top neighbor or input feeder. |
| `a_valid_in` | Input | 1 | Valid control indicator accompanying `a_in`. |
| `b_valid_in` | Input | 1 | Valid control indicator accompanying `b_in`. |
| `a_out` | Output | `DATA_WIDTH` | Registered forwarding of `a_in` to the right neighboring PE. |
| `b_out` | Output | `DATA_WIDTH` | Registered forwarding of `b_in` to the bottom neighboring PE. |
| `a_valid_out`| Output | 1 | Registered forwarding of `a_valid_in`. |
| `b_valid_out`| Output | 1 | Registered forwarding of `b_valid_in`. |
| `acc_out` | Output | `ACC_WIDTH` | Accumulated signed sum ($C_{r,c} = \sum A \times B$). |

### Operational Rules
1. **Reset (`rst_n == 0`):** Asynchronously forces `a_out <= 0`, `b_out <= 0`, `a_valid_out <= 0`, `b_valid_out <= 0`, `acc_out <= 0`.
2. **Data & Valid Forwarding:** On each rising clock edge, incoming data and valid flags are registered to outgoing ports:
   `a_out <= a_in`, `b_out <= b_in`, `a_valid_out <= a_valid_in`, `b_valid_out <= b_valid_in`.
3. **Accumulator Priority:**
   - If `clear_acc == 1'b1`: `acc_out <= 0` (takes immediate priority regardless of valid signals).
   - Else if `a_valid_in && b_valid_in`: `acc_out <= acc_out + sign_ext(a_in * b_in)`.
   - Otherwise: `acc_out` remains unchanged.

---

## 4. Sequential Matrix Multiplication Baseline Contract

The sequential baseline serves as the golden hardware reference, utilizing a single reusable MAC unit without systolic array pipelines.

### Module Declaration
```verilog
module sequential_matmul_baseline #(
    parameter ARRAY_SIZE = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
) (
    input  wire                                                      clk,
    input  wire                                                      rst_n,
    input  wire                                                      start,
    input  wire signed [ARRAY_SIZE * ARRAY_SIZE * DATA_WIDTH - 1 : 0] a_flat,
    input  wire signed [ARRAY_SIZE * ARRAY_SIZE * DATA_WIDTH - 1 : 0] b_flat,
    output reg                                                       busy,
    output reg                                                       done,
    output reg  signed [ARRAY_SIZE * ARRAY_SIZE * ACC_WIDTH - 1 : 0]  result
);
```

### Signal Specifications

| Signal | Direction | Width | Description |
|---|---|---|---|
| `clk` | Input | 1 | Global system clock. |
| `rst_n` | Input | 1 | Asynchronous active-low reset. |
| `start` | Input | 1 | Pulse to initiate matrix multiplication when idle. |
| `a_flat` | Input | `ARRAY_SIZE^2 * DATA_WIDTH` | Row-major packed input matrix $A$. |
| `b_flat` | Input | `ARRAY_SIZE^2 * DATA_WIDTH` | Row-major packed input matrix $B$. |
| `busy` | Output | 1 | High while computation is ongoing. |
| `done` | Output | 1 | Single-cycle pulse asserted when `result` is fully valid. |
| `result` | Output | `ARRAY_SIZE^2 * ACC_WIDTH` | Row-major packed output matrix $C$. Holds stable until next operation or reset. |

### Operational Rules
1. **Input Latching:** On `start` assertion while idle, `a_flat` and `b_flat` are latched into internal registers. Subsequent changes on external input buses do not affect the active computation.
2. **Busy Protection:** If `start` is asserted while `busy == 1`, the request is ignored and does not corrupt the running computation.
3. **Execution Timeline:** Calculates 1 MAC per clock cycle over $N^3$ compute cycles ($N = \text{ARRAY\_SIZE}$). Each matrix element $C_{r,c}$ is accumulated over $N$ consecutive cycles before updating `result`.
4. **Completion:** Upon completing the final MAC, `done` pulses high for 1 clock cycle, `busy` drops to 0, and `result` remains valid and stable until a subsequent operation completes.

---

## 5. Integration Notes for Member 2 and Member 3

- **Member 2 (Systolic Array & Skewing):**
  - Parameterize PE instances inside `systolic_array` with `.DATA_WIDTH(DATA_WIDTH)` and `.ACC_WIDTH(ACC_WIDTH)`.
  - Maintain the row/column skewing delay chains parameterized by `DATA_WIDTH`.
  - Slicing of `acc_out` to output buses must use `(r * ARRAY_SIZE + c) * ACC_WIDTH +: ACC_WIDTH`.
- **Member 3 (Matrix Controller & Top-Level Integration):**
  - Update `a_flat` and `b_flat` bus sizes to `ARRAY_SIZE * ARRAY_SIZE * DATA_WIDTH`.
  - Retain control signals `start`, `busy`, `done`, `clear_acc`.
  - Verify top-level outputs against both golden model and sequential baseline results.
