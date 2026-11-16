# Phase 1 Prototype Video Demonstration Guide & Script

**Project Title:** 4×4 Systolic Array Matrix Multiplication Accelerator  
**Team Members:** Aman Soni, Mayank Sharma, and Ankit Kumar Pandey  
**GitHub Repository:** [https://github.com/Amansoni045/systolic-array-matrix-multiplication-accelerator](https://github.com/Amansoni045/systolic-array-matrix-multiplication-accelerator)  

**Evaluation Criteria (15 Marks):**
- Maximum duration: **Strictly under 5 minutes** (Target: 4:30 – 4:45)
- Clearly mention the project idea
- Clearly introduce the names of all 3 group members
- Demonstrate the working/progress of the prototype (RTL walkthrough, testbenches, waveforms)

---

## 5-Minute Video Breakdown (Second-by-Second Plan)

| Time Window | Section | Speaker / Presenter | Visual on Screen |
|:---|:---|:---|:---|
| **0:00 – 0:45** (45s) | Team Introduction & Project Idea | Aman Soni | Slide 1 (Title, Problem Statement, 3 Member Names, GitHub Link) |
| **0:45 – 1:50** (65s) | Member 1: Processing Element Design | Aman Soni | Fig. 1 Architecture Diagram & `rtl/processing_element.v`, `vvp pe.vvp` |
| **1:50 – 2:55** (65s) | Member 2: Systolic Array Architecture | Mayank Sharma | 4×4 Grid Diagram & `rtl/systolic_array.v`, `vvp array.vvp` |
| **2:55 – 4:15** (80s) | Member 3: Controller, Top-Level & Verification | Ankit Kumar Pandey | Fig. 2 FSM Diagram & `rtl/matrix_controller.v`, `vvp top.vvp`, `golden_model.py` |
| **4:15 – 4:45** (30s) | GTKWave Waveform Timing Analysis | All / Team Lead | GTKWave waveform (`tb_systolic_array.vcd`) showing 14-cycle GEMM |
| **4:45 – 5:00** (15s) | Conclusion & Phase 2 Outlook | All | Slide with GitHub Repo URL & Summary |

---

## Word-for-Word Spoken Script

### [0:00 – 0:45] Introduction of Project Idea & 3 Members
**Speaker (Aman Soni):**
> "Hello everyone, and welcome to our Phase 1 prototype demonstration for the Hardware Accelerator Project.  
> Our project is the **Design, Implementation, and Verification of a 4×4 Systolic Array Matrix Multiplication Accelerator** in Verilog HDL.  
> 
> Matrix multiplication is the primary computational bottleneck in deep learning and modern edge-AI workloads. Standard CPU architectures suffer from the Von Neumann memory wall, repeatedly fetching operands from memory. Our systolic array accelerator solves this by streaming INT8 operands through a 2D mesh of processing elements, achieving $O(N^3)$ operations with only $O(N)$ perimeter bandwidth.
> 
> Our team consists of three members:
> 1. **Aman Soni** — Member 1: Processing Element Design (Datapath RTL)
> 2. **Mayank Sharma** — Member 2: Systolic Array Architecture (Hardware Integration)
> 3. **Ankit Kumar Pandey** — Member 3: Controller and Verification (Control RTL + Testing)"

---

### [0:45 – 1:50] Member 1 — Processing Element Design
**Speaker (Aman Soni):**
> *(Screen shows `report/figures/fig1_accelerator_architecture.png` on the left, then splits to `rtl/processing_element.v`)*  
> "As Member 1, I owned the basic computational unit:
> - I implemented `rtl/processing_element.v` in Verilog HDL.
> - Each PE computes $C = C + (A \times B)$ with signed 8-bit operands `a_in` and `b_in`.
> - Inputs are sign-extended to 16 bits, multiplied using a signed multiplier, and accumulated into a signed 32-bit accumulator `acc_out`. This 32-bit width guarantees zero overflow across accumulations.
> - Clock, synchronous `clear_acc`, and active-low asynchronous reset `rst_n` are fully implemented.
> - Data forwarding registers pass operand $A$ horizontally and operand $B$ vertically on every rising clock edge, with valid handshake flags `a_valid_out` and `b_valid_out` ensuring data synchronization.
> 
> Let's run the unit testbench `testbench/tb_processing_element.v`:
> ```bash
> vvp simulation/results/pe.vvp
> ```
> *(Point to terminal)*: As you can see, **ALL 10 PE TESTS PASSED SUCCESSFULLY**, verifying positive, negative, zero, accumulator clear priority, and forwarding integrity."

---

### [1:50 – 2:55] Member 2 — Systolic Array Architecture
**Speaker (Mayank Sharma):**
> *(Screen shows `rtl/systolic_array.v` and the 4×4 2D mesh diagram)*  
> "As Member 2, I owned the 16-PE network and hardware data movement:
> - In `rtl/systolic_array.v`, I instantiated 16 Processing Elements using nested Verilog `generate` loops arranged in a 4×4 2D grid.
> - I routed the horizontal $A$ data paths across each row and vertical $B$ data paths down each column, connecting valid handshake signals between neighbouring PEs.
> - An essential architectural feature I implemented is the **internal input skewing pipeline**: row $r$ is delayed by $r$ cycles and column $c$ is delayed by $c$ cycles using cascaded registers right at the array perimeter. This allows unskewed, row-major matrices to be streamed directly into the core without external buffers!
> - Finally, all 16 PE accumulators are wired to the 512-bit output matrix bus `acc_out`.
> 
> In `testbench/tb_systolic_array_core.v`, I built a cycle-accurate software scoreboard:
> ```bash
> vvp simulation/results/array.vvp
> ```
> *(Point to terminal)*: 'PASS: 105 matrices, valid masks, bubbles, clear/reset/restart; 1533 edges checked' with zero mismatches!"

---

### [2:55 – 4:15] Member 3 — Controller and Verification
**Speaker (Ankit Kumar Pandey):**
> *(Screen shows `report/figures/fig2_fsm_timing.png`, `rtl/matrix_controller.v`, and terminal)*  
> "As Member 3, I owned the complete operation from input matrices to verified results:
> - I implemented input matrix packed bus registers (256-bit `a_flat` and `b_flat`).
> - In `rtl/matrix_controller.v`, I designed the 4-state Finite State Machine: `IDLE`, `CLEAR`, `LOAD`, and `DRAIN`.
> - The controller streams four consecutive matrix terms ($k = 0, 1, 2, 3$) across 4 cycles with all valid flags high, then drains for 8 cycles while results propagate.
> - The controller generates the `start`, `busy`, and single-cycle `done` handshake signals, latching `result <= acc_in` on cycle 13.
> - I integrated the array and controller into `rtl/systolic_array_top.v` and built the system testbench `testbench/tb_systolic_array.v`.
> 
> Let's run the system integration testbench:
> ```bash
> vvp simulation/results/top.vvp
> ```
> *(Point to terminal)*: 'ALL TESTS PASSED (9 tests)' — verifying Identity matrix, zero matrix, known positive matrix, signed extremes (-128 to 127), back-to-back operations, and reset recovery!
> 
> Next, I developed the algorithmic reference model in Python (`verification/golden_model.py`):
> ```bash
> python3 verification/golden_model.py
> ```
> *(Point to terminal)*: 'Results: 40 PASSED, 0 FAILED' across 40 directed and randomized test vectors!"

---

### [4:15 – 4:45] Waveform Timing Analysis
**Speaker (Aman Soni / Ankit Kumar Pandey):**
> *(Screen switches to GTKWave showing `simulation/waveforms/tb_systolic_array.vcd`)*  
> "Here is the GTKWave trace from our top-level execution of Test 2:
> - At 380 ns, `start` is pulsed. `busy` asserts high, and state enters `CLEAR`.
> - Over cycles 1 to 4, state is in `LOAD`, driving terms $k=0, 1, 2, 3$ with valid lines high.
> - The controller then drains for 8 cycles. Notice how each diagonal PE completes its accumulation sequentially without a single stall cycle.
> - At 515 ns (exactly 14 clock cycles from start), `done` pulses high for exactly 1 cycle, and the 512-bit `result` register commits the verified matrix product: $C[0][0]=80$ down to $C[3][3]=386$."

---

### [4:45 – 5:00] Conclusion & Submission
**Speaker (All):**
> "In conclusion, Phase 1 has achieved 100% functional verification of our 4×4 systolic array accelerator.  
> In Phase 2, we will integrate dual-port BRAM memory, AXI4-Stream bus interfaces, and matrix tiling for arbitrary dimensions on an FPGA.  
> All project source code, testbenches, waveform captures, and our IEEE report are fully documented on GitHub.  
> Thank you!"

---

## Recording Tips for the Team
1. **Screen Recording:** Use QuickTime Player, OBS Studio, or Loom at 1080p.
2. **Timing:** Keep speaking briskly to finish between 4:30 and 4:50.
3. **Upload:** Upload to YouTube as **Unlisted** (or Google Drive with link sharing set to 'Anyone with link can view'). Add the link into `README.md` and the Google Form.
