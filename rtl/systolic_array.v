`timescale 1ns/1ps

module systolic_array #(
    parameter ARRAY_SIZE = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
) (
    input wire clk,
    input wire rst_n,
    input wire clear_acc,
    input wire [ARRAY_SIZE*DATA_WIDTH-1:0] a_in,
    input wire [ARRAY_SIZE*DATA_WIDTH-1:0] b_in,
    input wire [ARRAY_SIZE-1:0] a_valid_in,
    input wire [ARRAY_SIZE-1:0] b_valid_in,
    output wire [ARRAY_SIZE*ARRAY_SIZE*ACC_WIDTH-1:0] acc_out
);
    wire signed [DATA_WIDTH-1:0] a_link [0:ARRAY_SIZE-1][0:ARRAY_SIZE];
    wire signed [DATA_WIDTH-1:0] b_link [0:ARRAY_SIZE][0:ARRAY_SIZE-1];
    wire a_valid_link [0:ARRAY_SIZE-1][0:ARRAY_SIZE];
    wire b_valid_link [0:ARRAY_SIZE][0:ARRAY_SIZE-1];

    initial begin
        if (ARRAY_SIZE < 1 || DATA_WIDTH < 1 || ACC_WIDTH < 2*DATA_WIDTH)
            $fatal(1, "Require ARRAY_SIZE >= 1, DATA_WIDTH >= 1, ACC_WIDTH >= 2*DATA_WIDTH");
    end

    genvar lane, stage, row, col;
    generate
        for (lane = 0; lane < ARRAY_SIZE; lane = lane + 1) begin : input_skew
            if (lane == 0) begin : direct
                assign a_link[lane][0] = a_in[DATA_WIDTH*lane +: DATA_WIDTH];
                assign b_link[0][lane] = b_in[DATA_WIDTH*lane +: DATA_WIDTH];
                assign a_valid_link[lane][0] = a_valid_in[lane];
                assign b_valid_link[0][lane] = b_valid_in[lane];
            end else begin : delayed
                reg signed [DATA_WIDTH-1:0] a_delay [0:lane-1];
                reg signed [DATA_WIDTH-1:0] b_delay [0:lane-1];
                reg [lane-1:0] a_valid_delay;
                reg [lane-1:0] b_valid_delay;
                for (stage = 0; stage < lane; stage = stage + 1) begin : delay_stage
                    wire signed [DATA_WIDTH-1:0] a_source, b_source;
                    wire av_source, bv_source;
                    if (stage == 0) begin : first_stage
                        assign a_source = a_in[DATA_WIDTH*lane +: DATA_WIDTH];
                        assign b_source = b_in[DATA_WIDTH*lane +: DATA_WIDTH];
                        assign av_source = a_valid_in[lane];
                        assign bv_source = b_valid_in[lane];
                    end else begin : subsequent_stage
                        assign a_source = a_delay[stage-1];
                        assign b_source = b_delay[stage-1];
                        assign av_source = a_valid_delay[stage-1];
                        assign bv_source = b_valid_delay[stage-1];
                    end
                    always @(posedge clk or negedge rst_n) begin
                        if (!rst_n) begin
                            a_delay[stage] <= {DATA_WIDTH{1'b0}};
                            b_delay[stage] <= {DATA_WIDTH{1'b0}};
                            a_valid_delay[stage] <= 1'b0;
                            b_valid_delay[stage] <= 1'b0;
                        end else if (clear_acc) begin
                            a_delay[stage] <= {DATA_WIDTH{1'b0}};
                            b_delay[stage] <= {DATA_WIDTH{1'b0}};
                            a_valid_delay[stage] <= 1'b0;
                            b_valid_delay[stage] <= 1'b0;
                        end else begin
                            a_delay[stage] <= a_source;
                            b_delay[stage] <= b_source;
                            a_valid_delay[stage] <= av_source;
                            b_valid_delay[stage] <= bv_source;
                        end
                    end
                end
                assign a_link[lane][0] = a_delay[lane-1];
                assign b_link[0][lane] = b_delay[lane-1];
                assign a_valid_link[lane][0] = a_valid_delay[lane-1];
                assign b_valid_link[0][lane] = b_valid_delay[lane-1];
            end
        end

        for (row = 0; row < ARRAY_SIZE; row = row + 1) begin : rows
            for (col = 0; col < ARRAY_SIZE; col = col + 1) begin : cols
                processing_element #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH(ACC_WIDTH)
                ) pe (
                    .clk(clk),
                    .rst_n(rst_n),
                    .clear_acc(clear_acc),
                    .a_in(a_link[row][col]),
                    .b_in(b_link[row][col]),
                    .a_valid_in(a_valid_link[row][col] & ~clear_acc),
                    .b_valid_in(b_valid_link[row][col] & ~clear_acc),
                    .a_out(a_link[row][col+1]),
                    .b_out(b_link[row+1][col]),
                    .a_valid_out(a_valid_link[row][col+1]),
                    .b_valid_out(b_valid_link[row+1][col]),
                    .acc_out(acc_out[ACC_WIDTH*(ARRAY_SIZE*row+col) +: ACC_WIDTH])
                );
            end
        end
    endgenerate
endmodule
