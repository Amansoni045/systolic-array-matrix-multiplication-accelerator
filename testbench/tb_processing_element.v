`timescale 1ns/1ps

module tb_processing_element;

    reg clk;
    reg rst_n;
    reg clear_acc;

    reg signed [7:0] a_in;
    reg signed [7:0] b_in;

    reg a_valid_in;
    reg b_valid_in;

    wire signed [7:0] a_out;
    wire signed [7:0] b_out;

    wire a_valid_out;
    wire b_valid_out;

    wire signed [31:0] acc_out;

    processing_element uut (
        .clk(clk),
        .rst_n(rst_n),
        .clear_acc(clear_acc),

        .a_in(a_in),
        .b_in(b_in),

        .a_valid_in(a_valid_in),
        .b_valid_in(b_valid_in),

        .a_out(a_out),
        .b_out(b_out),

        .a_valid_out(a_valid_out),
        .b_valid_out(b_valid_out),

        .acc_out(acc_out)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("simulation/waveforms/pe.vcd");
        $dumpvars(0, tb_processing_element);

        clk = 0;
        rst_n = 0;
        clear_acc = 0;
        a_in = 8'sd0;
        b_in = 8'sd0;
        a_valid_in = 1'b0;
        b_valid_in = 1'b0;

        repeat (2) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        clear_acc = 1;
        @(negedge clk);
        clear_acc = 0;

        a_in = 8'sd3;
        b_in = 8'sd4;
        a_valid_in = 1'b1;
        b_valid_in = 1'b1;

        @(negedge clk);
        a_valid_in = 1'b0;
        b_valid_in = 1'b0;

        if (acc_out !== 32'sd12)
            $fatal(1, "Test 1 Failed: Positive mult. Expected 12, got %0d", acc_out);
        $display("PASS: Test 1 - Positive multiplication (3 * 4 = 12)");

        clear_acc = 1;
        @(negedge clk);
        clear_acc = 0;

        a_in = -8'sd3;
        b_in = 8'sd5;
        a_valid_in = 1'b1;
        b_valid_in = 1'b1;

        @(negedge clk);
        a_valid_in = 1'b0;
        b_valid_in = 1'b0;

        if (acc_out !== -32'sd15)
            $fatal(1, "Test 2 Failed: Negative mult. Expected -15, got %0d", acc_out);
        $display("PASS: Test 2 - Negative multiplication (-3 * 5 = -15)");

        clear_acc = 1;
        @(negedge clk);
        clear_acc = 0;

        a_in = -8'sd3;
        b_in = -8'sd4;
        a_valid_in = 1'b1;
        b_valid_in = 1'b1;

        @(negedge clk);
        a_valid_in = 1'b0;
        b_valid_in = 1'b0;

        if (acc_out !== 32'sd12)
            $fatal(1, "Test 3 Failed: Both negative. Expected 12, got %0d", acc_out);
        $display("PASS: Test 3 - Both negative (-3 * -4 = 12)");

        clear_acc = 1;
        @(negedge clk);
        clear_acc = 0;

        a_in = 8'sd0;
        b_in = 8'sd7;
        a_valid_in = 1'b1;
        b_valid_in = 1'b1;
        @(negedge clk);

        if (acc_out !== 32'sd0)
            $fatal(1, "Test 4 Failed: Expected 0 for (0 * 7), got %0d", acc_out);

        a_in = -8'sd5;
        b_in = 8'sd0;
        a_valid_in = 1'b1;
        b_valid_in = 1'b1;
        @(negedge clk);
        a_valid_in = 1'b0;
        b_valid_in = 1'b0;

        if (acc_out !== 32'sd0)
            $fatal(1, "Test 4 Failed: Expected 0 for (-5 * 0), got %0d", acc_out);
        $display("PASS: Test 4 - Multiplication by zero");

        clear_acc = 1;
        @(negedge clk);
        clear_acc = 0;

        a_in = 8'sd2;
        b_in = 8'sd3;
        a_valid_in = 1'b1;
        b_valid_in = 1'b1;
        @(negedge clk);

        a_in = 8'sd4;
        b_in = 8'sd5;
        @(negedge clk);

        a_in = -8'sd2;
        b_in = 8'sd6;
        @(negedge clk);

        a_in = -8'sd3;
        b_in = -8'sd5;
        @(negedge clk);
        a_valid_in = 1'b0;
        b_valid_in = 1'b0;

        if (acc_out !== 32'sd29)
            $fatal(1, "Test 5 Failed: Multiple MAC. Expected 29, got %0d", acc_out);
        $display("PASS: Test 5 - Multiple MAC operations (accumulated result = 29)");

        a_in = 8'sd10;
        b_in = 8'sd10;
        a_valid_in = 1'b0;
        b_valid_in = 1'b1;
        @(negedge clk);

        if (acc_out !== 32'sd29)
            $fatal(1, "Test 6 Failed: Accumulator changed when A was invalid! Expected 29, got %0d", acc_out);
        $display("PASS: Test 6 - A invalid and B valid (accumulator unchanged)");

        a_in = 8'sd10;
        b_in = 8'sd10;
        a_valid_in = 1'b1;
        b_valid_in = 1'b0;
        @(negedge clk);
        a_valid_in = 1'b0;
        b_valid_in = 1'b0;

        if (acc_out !== 32'sd29)
            $fatal(1, "Test 7 Failed: Accumulator changed when B was invalid! Expected 29, got %0d", acc_out);
        $display("PASS: Test 7 - A valid and B invalid (accumulator unchanged)");

        clear_acc = 1'b1;

        a_in = 8'sd7;
        b_in = 8'sd7;

        a_valid_in = 1'b1;
        b_valid_in = 1'b1;

        @(negedge clk);

        if (acc_out !== 32'sd0)
            $fatal(1, "Test 8 Failed: Accumulator clear priority");

        clear_acc = 1'b0;

        a_in = 8'sd3;
        b_in = 8'sd7;

        @(negedge clk);

        a_valid_in = 1'b0;
        b_valid_in = 1'b0;

        if (acc_out !== 32'sd21)
            $fatal(1, "Test 8 Failed: Expected 21, got %0d", acc_out);

        $display("PASS: Test 8 - Accumulator clearing and MAC priority");

        if (acc_out !== 32'sd0)
            $fatal(1, "Test 8 Failed: clear_acc did not reset accumulator to 0! Got %0d", acc_out);

        clear_acc = 1'b0;
        a_in = 8'sd3;
        b_in = 8'sd7;
        a_valid_in = 1'b1;
        b_valid_in = 1'b1;
        @(negedge clk);
        a_valid_in = 1'b0;
        b_valid_in = 1'b0;

        if (acc_out !== 32'sd21)
            $fatal(1, "Test 8 Failed: Operation after clear failed. Expected 21, got %0d", acc_out);
        $display("PASS: Test 8 - Accumulator clearing after nonzero value and priority over MAC");

        a_in = 8'sd42;
        b_in = -8'sd84;
        a_valid_in = 1'b1;
        b_valid_in = 1'b1;
        @(negedge clk);

        rst_n = 1'b0;
        #1;
        if (acc_out !== 32'sd0 || a_out !== 8'sd0 || b_out !== 8'sd0 ||
            a_valid_out !== 1'b0 || b_valid_out !== 1'b0)
            $fatal(1, "Test 9 Failed: Reset did not immediately clear all registers!");

        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        a_in = 8'sd0;
        b_in = 8'sd0;
        a_valid_in = 1'b0;
        b_valid_in = 1'b0;
        @(negedge clk);

        if (acc_out !== 32'sd0 || a_out !== 8'sd0 || b_out !== 8'sd0 ||
            a_valid_out !== 1'b0 || b_valid_out !== 1'b0)
            $fatal(1, "Test 9 Failed: Registers nonzero after reset release!");
        $display("PASS: Test 9 - Reset clears accumulator and forwarding registers");

        a_in = 8'sd55;
        b_in = -8'sd77;
        a_valid_in = 1'b1;
        b_valid_in = 1'b0;
        @(negedge clk);

        if (a_out !== 8'sd55 || a_valid_out !== 1'b1)
            $fatal(1, "Test 10 Failed: a_out/a_valid_out incorrect! Expected 55/1, got %0d/%0b", a_out, a_valid_out);
        if (b_out !== -8'sd77 || b_valid_out !== 1'b0)
            $fatal(1, "Test 10 Failed: b_out/b_valid_out incorrect! Expected -77/0, got %0d/%0b", b_out, b_valid_out);

        a_in = -8'sd110;
        b_in = 8'sd99;
        a_valid_in = 1'b0;
        b_valid_in = 1'b1;
        @(negedge clk);

        if (a_out !== -8'sd110 || a_valid_out !== 1'b0)
            $fatal(1, "Test 10 Failed: a_out/a_valid_out incorrect! Expected -110/0, got %0d/%0b", a_out, a_valid_out);
        if (b_out !== 8'sd99 || b_valid_out !== 1'b1)
            $fatal(1, "Test 10 Failed: b_out/b_valid_out incorrect! Expected 99/1, got %0d/%0b", b_out, b_valid_out);

        a_in = 8'sd0;
        b_in = 8'sd0;
        a_valid_in = 1'b0;
        b_valid_in = 1'b0;
        @(negedge clk);

        if (a_out !== 8'sd0 || a_valid_out !== 1'b0 || b_out !== 8'sd0 || b_valid_out !== 1'b0)
            $fatal(1, "Test 10 Failed: Idle values not forwarded correctly!");
        $display("PASS: Test 10 - Correct forwarding of A, B and their respective valid signals");

        @(negedge clk);
        $display("========================================");
        $display("ALL 10 PE TESTS PASSED SUCCESSFULLY");
        $display("========================================");
        $finish;
    end

endmodule
