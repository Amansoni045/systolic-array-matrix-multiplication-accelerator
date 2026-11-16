# Phase 1 Prototype Video Demonstration Guide & Script

**Project Title:** 4×4 Systolic Array Matrix Multiplication Accelerator  
**Evaluation Criteria (15 Marks):**
- Maximum duration: **Strictly under 5 minutes** (Target: 4:30 – 4:45)
- Clearly mention the project idea
- Clearly introduce the names of **all 5 group members**
- Demonstrate the working/progress of the prototype (RTL walkthrough, testbenches, waveforms)

---

## 5-Minute Video Breakdown (Second-by-Second Plan)

| Time Window | Section | Speaker / Presenter | Visual on Screen |
|:---|:---|:---|:---|
| **0:00 – 0:40** (40s) | Team Introduction & Project Idea | Member 1 (Aman Soni) | Slide 1 (Title, Problem Statement, 5 Member Names) |
| **0:40 – 1:30** (50s) | Architecture & Processing Element (PE) | Member 1 & Member 2 | Fig. 1 Architecture Diagram & `rtl/processing_element.v` |
| **1:30 – 2:20** (50s) | 4×4 2D Mesh Core & Internal Skewing | Member 2 (Mayank Sharma) | 4×4 Grid Diagram & `rtl/systolic_array.v` |
| **2:20 – 3:10** (50s) | Controller FSM & Top-Level Integration | Member 3 (Ankit Pandey) | Fig. 2 FSM Diagram & `rtl/matrix_controller.v` |
| **3:10 – 4:10** (60s) | Live Prototype Simulation & Verification | Member 4 (Aditya Verma) | Terminal running `vvp top.vvp`, `pe.vvp`, `golden_model.py` |
| **4:10 – 4:45** (35s) | Waveform Timing Analysis & Phase 2 Outlook | Member 5 (Priyanshu Kumar) | GTKWave/VaporView waveform (`tb_systolic_array.vcd`) |
| **4:45 – 5:00** (15s) | Conclusion & Thank You | All / Team Lead | Slide with GitHub Repo URL & Summary |

---

## Word-for-Word Spoken Script

### [0:00 – 0:40] Introduction of Project Idea & 5 Members
**Speaker (Aman Soni):**
> "Hello everyone, and welcome to our Phase 1 prototype demonstration for the Hardware Accelerator Project.  
> Our project is the **Design, Implementation, and Verification of a 4×4 Systolic Array Matrix Multiplication Accelerator** in Verilog HDL.  
> 
> Matrix multiplication is the foundational computational bottleneck in deep learning and modern edge-AI workloads. Standard CPU architectures suffer from the Von Neumann memory wall, repeatedly fetching operands from DRAM. Our systolic array accelerator solves this by streaming INT8 operands through a 2D mesh of processing elements, achieving $O(N^3)$ operations with only $O(N)$ perimeter bandwidth.
> 
> Our team consists of five members:
> 1. **Aman Soni** — Responsible for the Processing Element datapath and PE unit verification.
> 2. **Mayank Sharma** — Responsible for the 4×4 Systolic Array 2D mesh and internal skewing pipeline.
> 3. **Ankit Pandey** — Responsible for the Matrix Controller FSM and top-level accelerator integration.
> 4. **Aditya Verma** — Responsible for the Python algorithmic golden model and test vector generation suite.
> 5. **Priyanshu Kumar** — Responsible for system-level verification, timing analysis, and waveform evidence."

---

### [0:40 – 1:30] Architecture & Processing Element (PE)
**Speaker (Aman Soni):**
> *(Screen shows `report/figures/fig1_accelerator_architecture.png` on the left, then splits to `rtl/processing_element.v`)*  
> "At the heart of our accelerator is the **Processing Element (PE)**. Each PE implements an Output-Stationary multiply-accumulate unit.  
> Here in `rtl/processing_element.v`:
> - We take signed 8-bit inputs `a_in` and `b_in`. They are sign-extended to 16 bits and multiplied using a signed multiplier.
> - The 16-bit product is sign-extended to 32 bits and accumulated into the `acc_out` register. Using a 32-bit accumulator guarantees zero arithmetic overflow across successive accumulations.
> - Accumulation is gated by valid flags `a_valid_in` and `b_valid_in`. When either is low, accumulation pauses, allowing bubbles without corrupting the state.
> - Simultaneously, operands and valid flags are registered and forwarded: `a_out` horizontally to the right neighbor, and `b_out` vertically to the bottom neighbor on the rising clock edge."

---

### [1:30 – 2:20] 4×4 Systolic Array Core & Internal Skewing
**Speaker (Mayank Sharma):**
> *(Screen shows `rtl/systolic_array.v` and the 4×4 mesh diagram)*  
> "I designed the **4×4 Systolic Array Core** in `rtl/systolic_array.v`.  
> - We instantiate a 2D grid of 16 identical PEs using nested Verilog `generate` loops.
> - A major architectural innovation in our design is the **integrated input skewing pipeline**. Standard systolic arrays require external software or complex memory buffering to stagger inputs into diagonal waves.
> - In our design, row $r$ is delayed internally by $r$ clock cycles, and column $c$ is delayed by $c$ cycles using cascaded flip-flops right at the array perimeter.
> - This means our accelerator accepts clean, unskewed, row-major matrices directly from memory, dramatically simplifying the memory controller!"

---

### [2:20 – 3:10] Controller FSM & Top-Level Integration
**Speaker (Ankit Pandey):**
> *(Screen shows `report/figures/fig2_fsm_timing.png` and `rtl/matrix_controller.v`)*  
> "I implemented the **Matrix Controller** and top-level integration in `rtl/matrix_controller.v` and `rtl/systolic_array_top.v`.  
> - The controller implements an autonomous 4-state Finite State Machine: `IDLE`, `CLEAR`, `LOAD`, and `DRAIN`.
> - When `start` is pulsed, the controller enters `STATE_CLEAR`, pulsing `clear_acc` to flush all 16 PE accumulators and skew registers.
> - Next, in `STATE_LOAD`, it streams four consecutive matrix terms ($k = 0, 1, 2, 3$) across 4 cycles with all lane valid bits asserted.
> - It then enters `STATE_DRAIN` for 8 cycles while the operand wave propagates diagonally through the array.
> - On exact cycle 13, PE(3,3) finishes its final MAC, all 16 results are valid, and the controller latches `result <= acc_in`, dropping `busy` and pulsing `done` for exactly one clock cycle.
> Total computation latency from `start` to `done` is deterministic and exactly **14 clock cycles**!"

---

### [3:10 – 4:10] Live Prototype Simulation & Verification Demo
**Speaker (Aditya Verma):**
> *(Screen switches to a live Terminal)*  
> "Now let us demonstrate the working prototype live in the terminal using Icarus Verilog and Python!
> 
> First, let's run the Processing Element unit test:
> ```bash
> vvp simulation/results/pe.vvp
> ```
> *(Point to terminal output)*: 'ALL 10 PE TESTS PASSED SUCCESSFULLY' — verifying signed positive, negative, zero, accumulator clear priority, and forwarding.
> 
> Next, let's run the 4×4 core unit testbench:
> ```bash
> vvp simulation/results/array.vvp
> ```
> *(Point to output)*: 'PASS: 105 matrices, valid masks, bubbles, clear/reset/restart; 1533 edges checked'.
> 
> Next, let's run our integrated top-level system testbench:
> ```bash
> vvp simulation/results/top.vvp
> ```
> *(Point to output)*: 'ALL TESTS PASSED (9 tests)' — verifying Identity matrix, zero matrix, known positive matrix, signed extremes (-128 to 127), back-to-back operations, and reset recovery!
> 
> Finally, our Python golden model:
> ```bash
> python3 verification/golden_model.py
> ```
> *(Point to output)*: '40 PASSED, 0 FAILED' — self-checking all vectors and validating our 512-bit hex dump output."

---

### [4:10 – 4:45] Waveform Timing Analysis
**Speaker (Priyanshu Kumar):**
> *(Screen switches to GTKWave showing `simulation/waveforms/tb_systolic_array.vcd`)*  
> "Here is the GTKWave simulation trace from our top-level execution of Test 2:
> - Notice the yellow marker at $T_1 = 380$\,ns where `start` is pulsed.
> - `busy` immediately asserts high, `clear_acc` resets the core, and state advances to `LOAD` where $k$ increments from 0 to 3 with all valid bits high.
> - The FSM then drains for 8 cycles. Notice how each diagonal PE completes its accumulation sequentially without a single cycle of stall.
> - At $T_2 = 515$\,ns (exactly 14 cycles later), `done` pulses high for exactly 1 cycle, and the 512-bit `result` register commits the verified matrix product: $C[0][0]=80$ down to $C[3][3]=386$.
> - When reset is asserted mid-computation in Test 7, the DUT recovers cleanly without latching garbage data."

---

### [4:45 – 5:00] Conclusion & Submission
**Speaker (Aman Soni / All):**
> "In conclusion, Phase 1 has achieved 100% functional verification of our 4×4 systolic array accelerator. In Phase 2, we will integrate dual-port BRAM memory, AXI4-Stream bus interfaces, and matrix tiling for arbitrary dimensions on an FPGA.  
> All project source code, testbenches, waveform captures, and our IEEE report are fully documented in our GitHub repository.  
> Thank you for watching!"

---

## Recording Tips for the Team
1. **Screen Recording Tool:** Use OBS Studio, QuickTime Player (macOS), or Loom. Record at 1080p (1920×1080) at 30 or 60 fps.
2. **Audio:** Ensure each member's microphone is clear without background noise.
3. **Pacing:** Practice speaking with a timer running to ensure you finish comfortably between 4:30 and 4:50. Do not exceed 5:00:00!
4. **Video Upload:** Upload to YouTube as **Unlisted** (or Google Drive with link access set to "Anyone with the link can view"). Place the URL in your GitHub `README.md` and in the submission form.
