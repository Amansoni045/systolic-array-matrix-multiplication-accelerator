`timescale 1ns/1ps

module matrix_controller #(
    parameter ARRAY_SIZE = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
) (
    input  wire                                         clk,
    input  wire                                         rst_n,
    input  wire                                         start,

    input  wire signed [ARRAY_SIZE*ARRAY_SIZE*DATA_WIDTH-1:0] a_flat,
    input  wire signed [ARRAY_SIZE*ARRAY_SIZE*DATA_WIDTH-1:0] b_flat,

    output reg                                          busy,
    output reg                                          done,

    output wire                                         clear_acc,
    output wire signed [ARRAY_SIZE*DATA_WIDTH-1:0]       a_out,
    output wire signed [ARRAY_SIZE*DATA_WIDTH-1:0]       b_out,
    output wire [ARRAY_SIZE-1:0]                        a_valid,
    output wire [ARRAY_SIZE-1:0]                        b_valid,

    input  wire signed [ARRAY_SIZE*ARRAY_SIZE*ACC_WIDTH-1:0] acc_in,
    output reg  signed [ARRAY_SIZE*ARRAY_SIZE*ACC_WIDTH-1:0] result
);

    localparam integer ELEMENTS     = ARRAY_SIZE * ARRAY_SIZE;
    localparam integer IN_WIDTH     = ELEMENTS * DATA_WIDTH;
    localparam integer OUT_WIDTH    = ELEMENTS * ACC_WIDTH;
    localparam integer LOAD_CYCLES  = ARRAY_SIZE;
    localparam integer DRAIN_CYCLES = 2 * ARRAY_SIZE - 1;
    localparam integer COUNT_WIDTH  = (DRAIN_CYCLES <= 1) ? 1 : $clog2(DRAIN_CYCLES);

    localparam [1:0] STATE_IDLE  = 2'd0;
    localparam [1:0] STATE_LOAD  = 2'd1;
    localparam [1:0] STATE_DRAIN = 2'd2;

    initial begin
        if (ARRAY_SIZE < 1)
            $fatal(1, "matrix_controller requires ARRAY_SIZE >= 1");
        if (DATA_WIDTH < 1)
            $fatal(1, "matrix_controller requires DATA_WIDTH >= 1");
        if (ACC_WIDTH < 2 * DATA_WIDTH)
            $fatal(1, "matrix_controller requires ACC_WIDTH >= 2*DATA_WIDTH");
    end

    reg [1:0]         state;
    reg [COUNT_WIDTH-1:0] cycle_cnt;

    reg signed [IN_WIDTH-1:0] a_latched;
    reg signed [IN_WIDTH-1:0] b_latched;

    assign clear_acc = (state == STATE_IDLE) && start;

    genvar lane;
    generate
        for (lane = 0; lane < ARRAY_SIZE; lane = lane + 1) begin : gen_operand_lanes
            assign a_out[DATA_WIDTH*lane +: DATA_WIDTH] =
                a_latched[(lane*ARRAY_SIZE + cycle_cnt)*DATA_WIDTH +: DATA_WIDTH];
            assign b_out[DATA_WIDTH*lane +: DATA_WIDTH] =
                b_latched[(cycle_cnt*ARRAY_SIZE + lane)*DATA_WIDTH +: DATA_WIDTH];
            assign a_valid[lane] = (state == STATE_LOAD);
            assign b_valid[lane] = (state == STATE_LOAD);
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= STATE_IDLE;
            cycle_cnt <= {COUNT_WIDTH{1'b0}};
            busy      <= 1'b0;
            done      <= 1'b0;
            a_latched <= {IN_WIDTH{1'b0}};
            b_latched <= {IN_WIDTH{1'b0}};
            result    <= {OUT_WIDTH{1'b0}};
        end else begin
            done <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        a_latched <= a_flat;
                        b_latched <= b_flat;
                        cycle_cnt <= {COUNT_WIDTH{1'b0}};
                        busy      <= 1'b1;
                        state     <= STATE_LOAD;
                    end
                end

                STATE_LOAD: begin
                    if (cycle_cnt == LOAD_CYCLES - 1) begin
                        cycle_cnt <= {COUNT_WIDTH{1'b0}};
                        state     <= STATE_DRAIN;
                    end else begin
                        cycle_cnt <= cycle_cnt + 1'b1;
                    end
                end

                STATE_DRAIN: begin
                    if (cycle_cnt == DRAIN_CYCLES - 1) begin

                        result    <= acc_in;
                        busy      <= 1'b0;
                        done      <= 1'b1;
                        state     <= STATE_IDLE;
                        cycle_cnt <= {COUNT_WIDTH{1'b0}};
                    end else begin
                        cycle_cnt <= cycle_cnt + 1'b1;
                    end
                end

                default: begin
                    state     <= STATE_IDLE;
                    cycle_cnt <= {COUNT_WIDTH{1'b0}};
                    busy      <= 1'b0;
                end
            endcase
        end
    end

endmodule
