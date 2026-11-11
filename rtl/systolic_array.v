`timescale 1ns/1ps

// Fixed 4x4 output-stationary array. Input lane i occupies bits [8*i +: 8].
// Supply unskewed A[i][k] and B[k][i] together; this module delays lane i
// by i clocks. Result C[i][j] occupies bits [32*(4*i+j) +: 32].
module systolic_array (
    input wire clk,
    input wire rst_n,
    input wire clear_acc,
    input wire [31:0] a_in,
    input wire [31:0] b_in,
    input wire [3:0] a_valid_in,
    input wire [3:0] b_valid_in,
    output wire [511:0] acc_out
);
    wire signed [7:0] a_link [0:3][0:4];
    wire signed [7:0] b_link [0:4][0:3];
    wire a_valid_link [0:3][0:4];
    wire b_valid_link [0:4][0:3];

    genvar lane, stage, row, col;
    generate
        for (lane = 0; lane < 4; lane = lane + 1) begin : input_skew
            if (lane == 0) begin : direct
                assign a_link[lane][0] = a_in[8*lane +: 8];
                assign b_link[0][lane] = b_in[8*lane +: 8];
                assign a_valid_link[lane][0] = a_valid_in[lane];
                assign b_valid_link[0][lane] = b_valid_in[lane];
            end else begin : delayed
                reg signed [7:0] a_delay [0:lane-1];
                reg signed [7:0] b_delay [0:lane-1];
                reg [lane-1:0] a_valid_delay;
                reg [lane-1:0] b_valid_delay;
                for (stage = 0; stage < lane; stage = stage + 1) begin : delay_stage
                    always @(posedge clk or negedge rst_n) begin
                        if (!rst_n) begin
                            a_delay[stage] <= 8'sd0;
                            b_delay[stage] <= 8'sd0;
                            a_valid_delay[stage] <= 1'b0;
                            b_valid_delay[stage] <= 1'b0;
                        end else if (clear_acc) begin
                            a_delay[stage] <= 8'sd0;
                            b_delay[stage] <= 8'sd0;
                            a_valid_delay[stage] <= 1'b0;
                            b_valid_delay[stage] <= 1'b0;
                        end else begin
                            if (stage == 0) begin
                                a_delay[stage] <= a_in[8*lane +: 8];
                                b_delay[stage] <= b_in[8*lane +: 8];
                                a_valid_delay[stage] <= a_valid_in[lane];
                                b_valid_delay[stage] <= b_valid_in[lane];
                            end else begin
                                a_delay[stage] <= a_delay[stage-1];
                                b_delay[stage] <= b_delay[stage-1];
                                a_valid_delay[stage] <= a_valid_delay[stage-1];
                                b_valid_delay[stage] <= b_valid_delay[stage-1];
                            end
                        end
                    end
                end
                assign a_link[lane][0] = a_delay[lane-1];
                assign b_link[0][lane] = b_delay[lane-1];
                assign a_valid_link[lane][0] = a_valid_delay[lane-1];
                assign b_valid_link[0][lane] = b_valid_delay[lane-1];
            end
        end

        for (row = 0; row < 4; row = row + 1) begin : rows
            for (col = 0; col < 4; col = col + 1) begin : cols
                processing_element pe (
                    .clk(clk),
                    .rst_n(rst_n),
                    .clear_acc(clear_acc),
                    .a_in(a_link[row][col]),
                    .b_in(b_link[row][col]),
                    // Clear also invalidates every PE forwarding register,
                    // cancelling in-flight operands without modifying the PE.
                    .a_valid_in(a_valid_link[row][col] & ~clear_acc),
                    .b_valid_in(b_valid_link[row][col] & ~clear_acc),
                    .a_out(a_link[row][col+1]),
                    .b_out(b_link[row+1][col]),
                    .a_valid_out(a_valid_link[row][col+1]),
                    .b_valid_out(b_valid_link[row+1][col]),
                    .acc_out(acc_out[32*(4*row+col) +: 32])
                );
            end
        end
    endgenerate
endmodule
