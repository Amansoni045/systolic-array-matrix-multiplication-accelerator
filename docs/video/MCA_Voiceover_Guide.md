# Voiceover recording guide

The video is 4:40 with burned-in English captions and silent stereo audio. Record the paragraphs below to the matching captions. Only quoted narration is spoken.

| Speaker | Start | End | Duration |
|---|---|---|---|
| Aman Soni | 0:00 | 0:35 | 35s |
| Aman Soni | 0:35 | 1:25 | 50s |
| Mayank Sharma | 1:25 | 2:35 | 70s |
| Ankit Kumar Pandey | 2:35 | 3:20 | 45s |
| Ankit Kumar Pandey | 3:20 | 4:15 | 55s |
| Mayank Sharma | 4:15 | 4:40 | 25s |

## Aman Soni at 0:00

How does a hardware accelerator turn two matrices into sixteen correct answers? Let us follow one answer: eighty. We are Aman Soni, Mayank Sharma, and Ankit Kumar Pandey. Our project is a four-by-four systolic array matrix multiplication accelerator in Verilog. Matrix multiplication is a core operation in AI. Our idea is to reuse operands as they move through sixteen processing elements, with several elements computing in parallel.

## Aman Soni at 0:35

I am Aman, and I designed the processing element, our basic multiply-accumulate unit. For our chosen output, the first row of A meets the first column of B. The calculation is one times sixteen, plus two times twelve, plus three times eight, plus four times four: eighty. Each element multiplies signed eight-bit inputs and adds the product to a thirty-two-bit accumulator. It updates only when both operands are valid. I also implemented reset, accumulator clear, and registered data forwarding. The unit testbench checks ten cases, including negative arithmetic and invalid inputs. Mayank will show how these elements work together.

## Mayank Sharma at 1:25

I am Mayank, and I connected the sixteen processing elements into a four-by-four array. A values travel to the right, while B values travel down. Each element keeps its own partial sum, so each eventually produces one output matrix entry. This is output-stationary dataflow. Our top-left element builds eighty, while other elements calculate their outputs as the data wave reaches them. Forwarding lets neighbouring elements reuse operands. The important challenge is timing: matching operands must reach each element together. I added internal input delays of zero, one, two, and three cycles across the rows and columns. Valid signals follow the same delays. I also built a cycle-by-cycle scoreboard covering one hundred and five matrices, input gaps, and reset recovery. Ankit will show how the controller runs the complete operation.

## Ankit Kumar Pandey at 2:35

I am Ankit Kumar Pandey. I implemented the controller, top-level integration, and system verification. An external start pulse begins the operation. The controller clears previous sums, feeds four sets of matrix operands, and allows eight drain cycles for pipeline propagation and result capture. Busy indicates that computation is active. When the output is captured, done pulses for one cycle, and the result remains available. The documented controller sequence spans fourteen clock cycles. I also created a Python reference model with forty directed and random vectors. Those are software reference checks; the RTL is checked by the Verilog testbenches.

## Ankit Kumar Pandey at 3:20

Here is the complete system testbench. It compares all sixteen outputs against independently calculated expected values. Test two uses the matrices we started with. Its first expected output is eighty. The documented run shows this test passing, followed by all nine system tests passing. The tests include identity and zero matrices, signed extremes, consecutive operations, reset during computation, and output stability. In the report waveform, start begins the transaction, busy stays high during processing, and done marks the captured result. The first result word is eighty, completing our example. The recorded PE and array runs also show ten unit tests and one hundred and five matrix cases passing.

## Mayank Sharma at 4:15

We followed eighty from four products to a checked matrix output. The same structure computes all sixteen results. Our Phase One deliverable is a Verilog RTL prototype with simulation verification. Next, we plan memory integration, larger matrices through tiling, and FPGA deployment with resource and power measurements. Our code, tests, and report are on GitHub. Thank you.

## Evidence shown in the video

Architecture and dataflow scenes are explanatory animations. Verification summaries reproduce documented repository results. The waveform is the existing report figure, clearly labelled on screen; this video does not claim a fresh simulator run. The verification narration makes small wording adjustments to match these visuals.

Add your voice recordings at the section start times above. Keep the video speed unchanged. Use the included SRT for exact phrase timings.
