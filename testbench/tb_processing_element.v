`timescale 1ns/1ps

module tb_processing_element;

    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 32;

    reg clk;
    reg rst_n;
    reg clear_acc;

    reg signed [DATA_WIDTH-1:0] a_in;
    reg signed [DATA_WIDTH-1:0] b_in;

    reg a_valid_in;
    reg b_valid_in;

    wire signed [DATA_WIDTH-1:0] a_out;
    wire signed [DATA_WIDTH-1:0] b_out;

    wire a_valid_out;
    wire b_valid_out;

    wire signed [ACC_WIDTH-1:0] acc_out;

    processing_element #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) uut (
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

    reg signed [DATA_WIDTH-1:0] min_val;
    reg signed [DATA_WIDTH-1:0] max_val;
    reg signed [ACC_WIDTH-1:0] exp_boundary;

    initial begin
        if (DATA_WIDTH == 8)
            $dumpfile("phase2/simulation/waveforms/pe_8bit.vcd");
        else
            $dumpfile("phase2/simulation/waveforms/pe_16bit.vcd");
        $dumpvars(0, tb_processing_element);

        clk = 0;
        rst_n = 0;
        clear_acc = 0;
        a_in = {DATA_WIDTH{1'b0}};
        b_in = {DATA_WIDTH{1'b0}};
        a_valid_in = 1'b0;
        b_valid_in = 1'b0;

        repeat (2) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        clear_acc = 1;
        @(negedge clk);
        clear_acc = 0;

        a_in = 3;
        b_in = 4;
        a_valid_in = 1'b1;
        b_valid_in = 1'b1;
        @(negedge clk);
        a_valid_in = 1'b0;
        b_valid_in = 1'b0;

        if (acc_out !== 12)
            $fatal(1, "Test 1 Failed: Positive mult. Expected 12, got %0d", acc_out);
        $display("PASS: Test 1 - Positive multiplication");

        clear_acc = 1;
        @(negedge clk);
        clear_acc = 0;

        a_in = -3;
        b_in = 5;
        a_valid_in = 1'b1;
        b_valid_in = 1'b1;
        @(negedge clk);
        a_valid_in = 1'b0;
        b_valid_in = 1'b0;

        if (acc_out !== -15)
            $fatal(1, "Test 2 Failed: Negative mult. Expected -15, got %0d", acc_out);
        $display("PASS: Test 2 - Negative multiplication");

        clear_acc = 1;
        @(negedge clk);
        clear_acc = 0;

        a_in = -3;
        b_in = -4;
        a_valid_in = 1'b1;
        b_valid_in = 1'b1;
        @(negedge clk);
        a_valid_in = 1'b0;
        b_valid_in = 1'b0;

        if (acc_out !== 12)
            $fatal(1, "Test 3 Failed: Both negative. Expected 12, got %0d", acc_out);
        $display("PASS: Test 3 - Both negative operands");

        clear_acc = 1;
        @(negedge clk);
        clear_acc = 0;

        a_in = 0;
        b_in = 7;
        a_valid_in = 1'b1;
        b_valid_in = 1'b1;
        @(negedge clk);

        if (acc_out !== 0)
            $fatal(1, "Test 4 Failed: Expected 0 for 0 * 7, got %0d", acc_out);

        a_in = -5;
        b_in = 0;
        a_valid_in = 1'b1;
        b_valid_in = 1'b1;
        @(negedge clk);
        a_valid_in = 1'b0;
        b_valid_in = 1'b0;

        if (acc_out !== 0)
            $fatal(1, "Test 4 Failed: Expected 0 for -5 * 0, got %0d", acc_out);
        $display("PASS: Test 4 - Multiplication by zero");

        clear_acc = 1;
        @(negedge clk);
        clear_acc = 0;

        a_in = 2;
        b_in = 3;
        a_valid_in = 1'b1;
        b_valid_in = 1'b1;
        @(negedge clk);

        a_in = 4;
        b_in = 5;
        @(negedge clk);

        a_in = -2;
        b_in = 6;
        @(negedge clk);

        a_in = -3;
        b_in = -5;
        @(negedge clk);
        a_valid_in = 1'b0;
        b_valid_in = 1'b0;

        if (acc_out !== 29)
            $fatal(1, "Test 5 Failed: Multiple MAC. Expected 29, got %0d", acc_out);
        $display("PASS: Test 5 - Multiple consecutive MAC operations");

        a_in = 10;
        b_in = 10;
        a_valid_in = 1'b0;
        b_valid_in = 1'b1;
        @(negedge clk);

        if (acc_out !== 29)
            $fatal(1, "Test 6 Failed: Accumulator changed when A was invalid! Expected 29, got %0d", acc_out);
        $display("PASS: Test 6 - Invalid A and valid B");

        a_in = 10;
        b_in = 10;
        a_valid_in = 1'b1;
        b_valid_in = 1'b0;
        @(negedge clk);
        a_valid_in = 1'b0;
        b_valid_in = 1'b0;

        if (acc_out !== 29)
            $fatal(1, "Test 7 Failed: Accumulator changed when B was invalid! Expected 29, got %0d", acc_out);
        $display("PASS: Test 7 - Valid A and invalid B");

        clear_acc = 1'b1;
        @(negedge clk);
        clear_acc = 1'b0;

        if (acc_out !== 0)
            $fatal(1, "Test 8 Failed: clear_acc did not reset accumulator to 0! Got %0d", acc_out);
        $display("PASS: Test 8 - Accumulator clear after nonzero result");

        a_in = 7;
        b_in = 7;
        a_valid_in = 1'b1;
        b_valid_in = 1'b1;
        clear_acc = 1'b1;
        @(negedge clk);
        clear_acc = 1'b0;

        if (acc_out !== 0)
            $fatal(1, "Test 9 Failed: clear_acc did not take priority over MAC! Expected 0, got %0d", acc_out);

        a_in = 3;
        b_in = 7;
        a_valid_in = 1'b1;
        b_valid_in = 1'b1;
        @(negedge clk);
        a_valid_in = 1'b0;
        b_valid_in = 1'b0;

        if (acc_out !== 21)
            $fatal(1, "Test 9 Failed: MAC operation after clear failed! Expected 21, got %0d", acc_out);
        $display("PASS: Test 9 - Clear priority over simultaneous MAC");

        a_in = 42;
        b_in = -84;
        a_valid_in = 1'b1;
        b_valid_in = 1'b1;
        @(negedge clk);

        rst_n = 1'b0;
        #1;
        if (acc_out !== 0 || a_out !== 0 || b_out !== 0 || a_valid_out !== 1'b0 || b_valid_out !== 1'b0)
            $fatal(1, "Test 10 Failed: Reset did not immediately clear all registers!");

        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        a_in = 0;
        b_in = 0;
        a_valid_in = 1'b0;
        b_valid_in = 1'b0;
        @(negedge clk);

        if (acc_out !== 0 || a_out !== 0 || b_out !== 0 || a_valid_out !== 1'b0 || b_valid_out !== 1'b0)
            $fatal(1, "Test 10 Failed: Registers nonzero after reset release!");
        $display("PASS: Test 10 - Reset functionality");

        a_in = 55;
        b_in = -77;
        a_valid_in = 1'b0;
        b_valid_in = 1'b0;
        @(negedge clk);

        if (a_out !== 55 || b_out !== -77)
            $fatal(1, "Test 11 Failed: Data forwarding incorrect! a_out=%0d, b_out=%0d", a_out, b_out);

        a_in = -110;
        b_in = 99;
        @(negedge clk);

        if (a_out !== -110 || b_out !== 99)
            $fatal(1, "Test 11 Failed: Data forwarding incorrect! a_out=%0d, b_out=%0d", a_out, b_out);
        $display("PASS: Test 11 - Data forwarding");

        a_valid_in = 1'b1;
        b_valid_in = 1'b0;
        @(negedge clk);

        if (a_valid_out !== 1'b1 || b_valid_out !== 1'b0)
            $fatal(1, "Test 12 Failed: Valid forwarding failed for 1/0! a_valid_out=%0b, b_valid_out=%0b", a_valid_out, b_valid_out);

        a_valid_in = 1'b0;
        b_valid_in = 1'b1;
        @(negedge clk);

        if (a_valid_out !== 1'b0 || b_valid_out !== 1'b1)
            $fatal(1, "Test 12 Failed: Valid forwarding failed for 0/1! a_valid_out=%0b, b_valid_out=%0b", a_valid_out, b_valid_out);

        a_valid_in = 1'b0;
        b_valid_in = 1'b0;
        @(negedge clk);

        if (a_valid_out !== 1'b0 || b_valid_out !== 1'b0)
            $fatal(1, "Test 12 Failed: Valid forwarding failed for 0/0! a_valid_out=%0b, b_valid_out=%0b", a_valid_out, b_valid_out);
        $display("PASS: Test 12 - Valid-signal forwarding");

        min_val = - (1 <<< (DATA_WIDTH - 1));
        max_val = (1 <<< (DATA_WIDTH - 1)) - 1;

        clear_acc = 1'b1;
        @(negedge clk);
        clear_acc = 1'b0;

        a_in = max_val;
        b_in = max_val;
        a_valid_in = 1'b1;
        b_valid_in = 1'b1;
        exp_boundary = $signed(max_val) * $signed(max_val);
        @(negedge clk);

        if (acc_out !== exp_boundary)
            $fatal(1, "Test 13 Failed: max * max. Expected %0d, got %0d", exp_boundary, acc_out);

        clear_acc = 1'b1;
        @(negedge clk);
        clear_acc = 1'b0;

        a_in = min_val;
        b_in = max_val;
        a_valid_in = 1'b1;
        b_valid_in = 1'b1;
        exp_boundary = $signed(min_val) * $signed(max_val);
        @(negedge clk);

        if (acc_out !== exp_boundary)
            $fatal(1, "Test 13 Failed: min * max. Expected %0d, got %0d", exp_boundary, acc_out);

        clear_acc = 1'b1;
        @(negedge clk);
        clear_acc = 1'b0;

        a_in = min_val;
        b_in = min_val;
        a_valid_in = 1'b1;
        b_valid_in = 1'b1;
        exp_boundary = $signed(min_val) * $signed(min_val);
        @(negedge clk);

        if (acc_out !== exp_boundary)
            $fatal(1, "Test 13 Failed: min * min. Expected %0d, got %0d", exp_boundary, acc_out);

        clear_acc = 1'b1;
        @(negedge clk);
        clear_acc = 1'b0;

        a_in = min_val;
        b_in = -1;
        a_valid_in = 1'b1;
        b_valid_in = 1'b1;
        exp_boundary = $signed(min_val) * -1;
        @(negedge clk);
        a_valid_in = 1'b0;
        b_valid_in = 1'b0;

        if (acc_out !== exp_boundary)
            $fatal(1, "Test 13 Failed: min * -1. Expected %0d, got %0d", exp_boundary, acc_out);

        $display("PASS: Test 13 - Signed boundary values");

        @(negedge clk);
        $display("========================================");
        $display("ALL 13 PE TESTS PASSED SUCCESSFULLY (DATA_WIDTH=%0d, ACC_WIDTH=%0d)", DATA_WIDTH, ACC_WIDTH);
        $display("========================================");
        $finish;
    end

endmodule
