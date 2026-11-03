
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

        $dumpfile("simulation/pe.vcd");
        $dumpvars(0, tb_processing_element);

        clk = 0;
        rst_n = 0;
        clear_acc = 0;

        a_in = 0;
        b_in = 0;

        a_valid_in = 0;
        b_valid_in = 0;

        repeat(2) @(negedge clk);
        rst_n = 1;

        @(negedge clk);
        clear_acc = 1;

        @(negedge clk);
        clear_acc = 0;

        a_in = -3;
        b_in = 5;

        a_valid_in = 1;
        b_valid_in = 1;

        @(negedge clk);

        if (a_out !== -8'sd3 ||
            b_out !== 8'sd5 ||
            a_valid_out !== 1 ||
            b_valid_out !== 1)
            $display("FAIL: Forwarding test 1");

        a_in = 2;
        b_in = -4;

        @(negedge clk);

        if (a_out !== 8'sd2 ||
            b_out !== -8'sd4)
            $display("FAIL: Forwarding test 2");

        a_valid_in = 0;
        b_valid_in = 0;

        @(negedge clk);

        if (acc_out === -32'sd23)
            $display("PASS: MAC test. Accumulator = %0d", acc_out);
        else
            $display("FAIL: Expected -23, Got %0d", acc_out);

        $finish;

    end

endmodule
