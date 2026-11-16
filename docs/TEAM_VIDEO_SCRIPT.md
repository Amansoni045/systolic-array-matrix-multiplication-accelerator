# Team prototype video script

**Project:** 4×4 Systolic Array Matrix Multiplication Accelerator  
**Team:** Aman Soni, Mayank Sharma, Ankit Kumar Pandey  
**Target duration:** 4 minutes 40 seconds, including screen changes  
**Format:** English narration with Hindi-English recording directions  
**Story:** Follow one output, C[0][0] = 80, from its four products through the PE, the array, the controller, and the checked result.

Read only the quoted dialogue. Screen directions, commands, and preparation notes are not spoken. Rehearse once with a stopwatch; the timestamps are editing targets, not a guarantee of speaking duration. Keep the final 20 seconds before the five-minute limit as a buffer.

## Speaker and screen plan

| Time | Speaker | Screen | Purpose |
|---|---|---|---|
| 0:00–0:35 | Aman | Report title and team names, then the demo matrices below | Introduce idea and the result to follow |
| 0:35–1:25 | Aman | Architecture diagram, then processing_element.v | Explain how one output is accumulated |
| 1:25–2:35 | Mayank | Architecture diagram, then systolic_array.v | Explain the 16-PE grid, data reuse, and alignment |
| 2:35–3:20 | Ankit | FSM diagram, matrix_controller.v, top-level wiring | Explain autonomous control and result capture |
| 3:20–4:15 | Ankit | Actual system-test terminal output and VCD viewer | Demonstrate correctness and completion |
| 4:15–4:40 | Mayank | Expected result, report title, repository URL | Close the story and state Phase 1 scope |

## 0:00–0:35 Aman introduces the project

**Screen direction:** Report ka title aur teenon names 5 seconds dikhao. Phir neeche diye A aur B matrices dikhao. A ki first row aur B ki first column highlight karo. Corner par small label rakho: “Following C[0][0] = 80”.

> “How does a hardware accelerator turn two matrices into sixteen correct answers? Let us follow one answer: eighty.
>
> We are Aman Soni, Mayank Sharma, and Ankit Kumar Pandey. Our project is a four-by-four systolic array matrix multiplication accelerator in Verilog.
>
> Matrix multiplication is a core operation in AI. Our idea is to reuse operands as they move through sixteen processing elements, with several elements computing in parallel.”

## 0:35–1:25 Aman explains the processing element

**Screen direction:** `report/figures/fig1_accelerator_architecture.png` mein PE block point karo. Phir `rtl/processing_element.v` mein `product`, `acc_out`, valid condition, aur forwarding assignments dikhao. Screen par calculation aur running totals dikhao: 16 → 40 → 64 → 80. File names bolkar time waste mat karo.

> “I am Aman, and I designed the processing element, our basic multiply-accumulate unit.
>
> For our chosen output, the first row of A meets the first column of B. The calculation is one times sixteen, plus two times twelve, plus three times eight, plus four times four: eighty.
>
> Each element multiplies signed eight-bit inputs and adds the product to a thirty-two-bit accumulator. It updates only when both operands are valid.
>
> I also implemented reset, accumulator clear, and registered data forwarding. The unit testbench checks ten cases, including negative arithmetic and invalid inputs.
>
> Mayank will show how these elements work together.”

## 1:25–2:35 Mayank explains the array

**Screen direction:** Architecture diagram par A ke arrows left-to-right aur B ke arrows top-to-bottom trace karo. PE(0,0) highlight rakho. Phir `rtl/systolic_array.v` mein nested `rows`/`cols` generate loops, `input_skew`, aur `acc_out` connection point karo. Delay labels 0, 1, 2, 3 ko diagram ke paas dikhao.

> “I am Mayank, and I connected the sixteen processing elements into a four-by-four array.
>
> A values travel to the right, while B values travel down. Each element keeps its own partial sum, so each eventually produces one output matrix entry. This is output-stationary dataflow.
>
> Our top-left element builds eighty, while other elements calculate their outputs as the data wave reaches them. Forwarding lets neighbouring elements reuse operands.
>
> The important challenge is timing: matching operands must reach each element together. I added internal input delays of zero, one, two, and three cycles across the rows and columns. Valid signals follow the same delays.
>
> I also built a cycle-by-cycle scoreboard covering one hundred and five matrices, input gaps, and reset recovery.
>
> Ankit will show how the controller runs the complete operation.”

## 2:35–3:20 Ankit explains control

**Screen direction:** `report/figures/fig2_fsm_timing.png` ka state diagram dikhao. Exact cycle labels ko zoom karne ke bajay IDLE → CLEAR → LOAD → DRAIN trace karo. Phir `rtl/matrix_controller.v` ka `STATE_LOAD` aur `STATE_DRAIN`, aur `rtl/systolic_array_top.v` ki controller-array wiring briefly dikhao.

> “I am Ankit Kumar Pandey. I implemented the controller, top-level integration, and system verification.
>
> An external start pulse begins the operation. The controller clears previous sums, feeds four sets of matrix operands, and allows eight drain cycles for pipeline propagation and result capture.
>
> Busy indicates that computation is active. When the output is captured, done pulses for one cycle, and the result remains available.
>
> The documented controller sequence spans fourteen clock cycles. I also created a Python reference model with forty directed and random vectors. Those are software reference checks; the RTL is checked by the Verilog testbenches.”

## 3:20–4:15 Ankit demonstrates the working prototype

**Screen direction, 3:20–3:40:** Prepared terminal se `vvp simulation/results/top.vvp` run karo. `PASS test 2`, `known positive 4x4 multiply`, aur final `ALL TESTS PASSED (9 tests)` par pointer rakho. Actual fresh output hi dikhao. Current testbench full decimal C matrix print nahi karti, isliye next screen ka matrix clearly “Expected result for Test 2” label karo.

**Screen direction, 3:40–4:05:** Generated `simulation/waveforms/tb_systolic_array.vcd` ko GTKWave ya available VCD viewer mein kholo. Signals pehle se add rakho: `clk`, `start`, `busy`, `done`, `result`, `dut.ctrl.state`, `dut.ctrl.k_cnt`, `dut.ctrl.d_cnt`. Test 2 par zoom karo. `done` ke time result ka low 32-bit slice show kar pao toh decimal 80 dikhao; full bus hex mein eighty ko `00000050` ke roop mein least-significant word par identify karo. Hex `50` decimal 80 hai.

**Screen direction, 4:05–4:15:** Actual PE aur array run ke final PASS lines briefly dikhao. Agar live waveform viewer ready nahi hai, report ka existing waveform figure dikha sakte ho, lekin usse “report waveform figure” bolo; live viewer ya raw screenshot mat bolo.

> “Here is the complete system test. It compares all sixteen outputs against independently calculated expected values.
>
> Test two uses the matrices we started with. Its first expected output is eighty. The terminal shows this test passing, followed by all nine system tests passing.
>
> The tests include identity and zero matrices, signed extremes, consecutive operations, reset during computation, and output stability.
>
> In the waveform, start begins the transaction, busy stays high during processing, and done marks the captured result. The first result word is eighty, completing our example.
>
> The recorded PE and array runs also show ten unit tests and one hundred and five matrix cases passing.”

## 4:15–4:40 Mayank closes

**Screen direction:** Expected C matrix par C[0][0] = 80 highlight karo, phir report title aur teenon names. End card par user ka repository URL dikhao: `https://github.com/MAYANKSHARMA01010/systolic-array-matrix-multiplication-accelerator`. Last frame 2 seconds hold karo.

> “We followed eighty from four products to a checked matrix output. The same structure computes all sixteen results.
>
> Our Phase One deliverable is a Verilog RTL prototype with simulation verification. Next, we plan memory integration, larger matrices through tiling, and FPGA deployment with resource and power measurements.
>
> Our code, tests, and report are on GitHub. Thank you.”

## Exact example used throughout

This is the existing `test_known_positive` scenario, system Test 2. Matrix coordinates are zero-based.

| Row | A | B | Expected C |
|---|---|---|---|
| 0 | 1, 2, 3, 4 | 16, 15, 14, 13 | 80, 70, 60, 50 |
| 1 | 5, 6, 7, 8 | 12, 11, 10, 9 | 240, 214, 188, 162 |
| 2 | 9, 10, 11, 12 | 8, 7, 6, 5 | 400, 358, 316, 274 |
| 3 | 13, 14, 15, 16 | 4, 3, 2, 1 | 560, 502, 444, 386 |

**Followed output:** C[0][0] = 1×16 + 2×12 + 3×8 + 4×4 = 80.

## Before recording

Ek person screen share aur screen switches handle kare. Baaki speakers apne handoff par bolen. Report, architecture, relevant code, terminal, aur VCD viewer pehle se ready rakho. Compilation ko video ke bahar complete karo; video mein short simulation runs aur meaningful results dikhana sufficient hai.

Run these commands from the repository root on a machine with Icarus Verilog installed. Do not show or read the entire preparation block in the video.

```bash
mkdir -p simulation/results simulation/waveforms

iverilog -g2005 -Wall -s tb_processing_element -o simulation/results/pe.vvp rtl/processing_element.v testbench/tb_processing_element.v
vvp simulation/results/pe.vvp

iverilog -g2005 -Wall -s tb_systolic_array_core -o simulation/results/array.vvp rtl/processing_element.v rtl/systolic_array.v testbench/tb_systolic_array_core.v
vvp simulation/results/array.vvp

iverilog -g2005 -Wall -s tb_systolic_array -o simulation/results/top.vvp rtl/processing_element.v rtl/systolic_array.v rtl/matrix_controller.v rtl/systolic_array_top.v testbench/tb_systolic_array.v
vvp simulation/results/top.vvp
```

Use the passing dialogue only after those runs actually pass on the recording machine. Existing README/report PASS summaries are recorded project results; the present script review did not rerun RTL simulations because Icarus Verilog was unavailable in this environment. The forty stored expected matrices and the demonstration matrix were independently checked with Python during script preparation.

## Questions to prepare for

| Question | Answer |
|---|---|
| Why is it called systolic? | Operands move through neighbouring elements in a regular clocked rhythm, with computation along the path. |
| Why thirty-two-bit sums? | A sum needs more range than one signed eight-bit operand. Thirty-two bits comfortably accommodate the four INT8 products in each supported output. |
| Why input skewing? | Row and column operands travel different distances. Delays align matching terms at each PE. |
| Do all sixteen PEs work from the first clock? | The array fills and drains as a wavefront. Activity depends on which valid operands have arrived. |
| Are forty Python passes forty RTL tests? | No. The Python runner generates and checks reference vectors. The supplied Verilog benches separately check the PE, array, and integrated RTL. |
| Are input matrices stored inside the top level? | The current controller reads packed input ports during LOAD; the source must keep the matrices stable through that phase. There are no internal BRAM matrix buffers yet. |
| Is start generated by the controller? | No. Start is an external input. Busy and done are controller outputs. |
| Is fourteen cycles fourteen times faster than a CPU? | No. The documented controller sequence is a cycle count for this implementation. A CPU speedup requires comparable measured workloads and clock frequencies. |
| How is the fourteen-cycle count defined? | Count the acceptance edge and the thirteen subsequent edges through result capture as fourteen sequenced edges. Do not equate an arbitrary start-signal transition timestamp with fourteen full clock periods. |
| Has it run on an FPGA or demonstrated lower power? | The repository presents RTL simulation evidence. FPGA deployment, achieved frequency, resource use, and power measurements are future work. |

## Source review notes

Prepared against local commit `c68c8fb`, also observed as the latest commit on the supplied GitHub repository. Reviewed the four RTL modules, three Verilog testbenches, Python model and all forty stored vector files, README, architecture specification, bibliography, report text and LaTeX, complete commit chronology, and the earlier video guide recovered from Git history.

The shared ChatGPT conversation “Plan Samiksha’s Phase 1 RISC-V work” was read for its result-based storytelling, timed speaker handoffs, and screen cues. This script applies that approach to the systolic-array implementation. Relevant context from the earlier MCA conversations was retrieved; the complete transcripts of those two project chats could not be opened through the available chat-history tools.

Existing documentation contains details that should not be repeated uncritically: it describes external input buses as internal matrix storage, sometimes groups Python reference checks with RTL verification, and states an elapsed latency without consistently distinguishing inclusive edge counting from clock periods. The script uses the implementation-backed wording above. No RTL, report, or README changes were made as part of script preparation.
