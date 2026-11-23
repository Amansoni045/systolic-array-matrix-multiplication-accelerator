`timescale 1ns/1ps

module systolic_array_top #(
    parameter ARRAY_SIZE = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
) (
    input  wire                                         clk,
    input  wire                                         rst_n,
    input  wire                                         start,

    input  wire signed [ARRAY_SIZE*ARRAY_SIZE*DATA_WIDTH-1:0] a_flat,
    input  wire signed [ARRAY_SIZE*ARRAY_SIZE*DATA_WIDTH-1:0] b_flat,

    output wire                                         busy,
    output wire                                         done,
    output wire signed [ARRAY_SIZE*ARRAY_SIZE*ACC_WIDTH-1:0] result
);

    initial begin
        if (ARRAY_SIZE < 1)
            $fatal(1, "systolic_array_top requires ARRAY_SIZE >= 1");
        if (DATA_WIDTH < 1)
            $fatal(1, "systolic_array_top requires DATA_WIDTH >= 1");
        if (ACC_WIDTH < 2 * DATA_WIDTH)
            $fatal(1, "systolic_array_top requires ACC_WIDTH >= 2*DATA_WIDTH");
    end

    wire                                                 clear_acc_w;
    wire signed [ARRAY_SIZE*DATA_WIDTH-1:0]              a_lane_w;
    wire signed [ARRAY_SIZE*DATA_WIDTH-1:0]              b_lane_w;
    wire [ARRAY_SIZE-1:0]                                a_valid_w;
    wire [ARRAY_SIZE-1:0]                                b_valid_w;
    wire signed [ARRAY_SIZE*ARRAY_SIZE*ACC_WIDTH-1:0]    acc_w;

    matrix_controller #(
        .ARRAY_SIZE(ARRAY_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH (ACC_WIDTH)
    ) ctrl (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start),
        .a_flat    (a_flat),
        .b_flat    (b_flat),
        .busy      (busy),
        .done      (done),
        .clear_acc (clear_acc_w),
        .a_out     (a_lane_w),
        .b_out     (b_lane_w),
        .a_valid   (a_valid_w),
        .b_valid   (b_valid_w),
        .acc_in    (acc_w),
        .result    (result)
    );

    systolic_array #(
        .ARRAY_SIZE(ARRAY_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH (ACC_WIDTH)
    ) array (
        .clk        (clk),
        .rst_n      (rst_n),
        .clear_acc  (clear_acc_w),
        .a_in       (a_lane_w),
        .b_in       (b_lane_w),
        .a_valid_in (a_valid_w),
        .b_valid_in (b_valid_w),
        .acc_out    (acc_w)
    );

endmodule
