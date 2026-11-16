`timescale 1ns/1ps

module systolic_array_top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [255:0] a_flat,
    input  wire [255:0] b_flat,
    output wire        busy,
    output wire        done,
    output wire [511:0] result
);

    wire        clear_acc_w;
    wire [31:0] a_out_w;
    wire [31:0] b_out_w;
    wire [3:0]  a_valid_w;
    wire [3:0]  b_valid_w;
    wire [511:0] acc_out_w;

    matrix_controller ctrl (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start),
        .a_flat    (a_flat),
        .b_flat    (b_flat),
        .busy      (busy),
        .done      (done),
        .clear_acc (clear_acc_w),
        .a_out     (a_out_w),
        .b_out     (b_out_w),
        .a_valid   (a_valid_w),
        .b_valid   (b_valid_w),
        .acc_in    (acc_out_w),
        .result    (result)
    );

    systolic_array array (
        .clk        (clk),
        .rst_n      (rst_n),
        .clear_acc  (clear_acc_w),
        .a_in       (a_out_w),
        .b_in       (b_out_w),
        .a_valid_in (a_valid_w),
        .b_valid_in (b_valid_w),
        .acc_out    (acc_out_w)
    );

endmodule
