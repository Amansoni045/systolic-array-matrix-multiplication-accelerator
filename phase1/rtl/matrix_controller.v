`timescale 1ns/1ps

module matrix_controller (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [255:0] a_flat,
    input  wire [255:0] b_flat,
    output reg         busy,
    output reg         done,
    output reg         clear_acc,
    output reg [31:0]  a_out,
    output reg [31:0]  b_out,
    output reg [3:0]   a_valid,
    output reg [3:0]   b_valid,
    input  wire [511:0] acc_in,
    output reg [511:0]  result
);

    localparam STATE_IDLE  = 2'd0;
    localparam STATE_CLEAR = 2'd1;
    localparam STATE_LOAD  = 2'd2;
    localparam STATE_DRAIN = 2'd3;

    reg [1:0] state;
    reg [1:0] k_cnt;
    reg [3:0] d_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= STATE_IDLE;
            k_cnt     <= 2'd0;
            d_cnt     <= 4'd0;
            busy      <= 1'b0;
            done      <= 1'b0;
            clear_acc <= 1'b0;
            a_out     <= 32'd0;
            b_out     <= 32'd0;
            a_valid   <= 4'd0;
            b_valid   <= 4'd0;
            result    <= 512'd0;
        end else begin
            done      <= 1'b0;
            clear_acc <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    busy    <= 1'b0;
                    a_valid <= 4'd0;
                    b_valid <= 4'd0;
                    if (start) begin
                        busy      <= 1'b1;
                        clear_acc <= 1'b1;
                        state     <= STATE_CLEAR;
                    end
                end

                STATE_CLEAR: begin
                    clear_acc <= 1'b0;
                    k_cnt     <= 2'd0;
                    state     <= STATE_LOAD;
                end

                STATE_LOAD: begin
                    a_valid <= 4'b1111;
                    b_valid <= 4'b1111;

                    a_out[8*0 +: 8] <= a_flat[8*(4*0 + k_cnt) +: 8];
                    a_out[8*1 +: 8] <= a_flat[8*(4*1 + k_cnt) +: 8];
                    a_out[8*2 +: 8] <= a_flat[8*(4*2 + k_cnt) +: 8];
                    a_out[8*3 +: 8] <= a_flat[8*(4*3 + k_cnt) +: 8];

                    b_out[8*0 +: 8] <= b_flat[8*(4*k_cnt + 0) +: 8];
                    b_out[8*1 +: 8] <= b_flat[8*(4*k_cnt + 1) +: 8];
                    b_out[8*2 +: 8] <= b_flat[8*(4*k_cnt + 2) +: 8];
                    b_out[8*3 +: 8] <= b_flat[8*(4*k_cnt + 3) +: 8];

                    if (k_cnt == 2'd3) begin
                        k_cnt <= 2'd0;
                        d_cnt <= 4'd0;
                        state <= STATE_DRAIN;
                    end else begin
                        k_cnt <= k_cnt + 2'd1;
                    end
                end

                STATE_DRAIN: begin
                    a_valid <= 4'd0;
                    b_valid <= 4'd0;

                    if (d_cnt == 4'd7) begin
                        result <= acc_in;
                        done   <= 1'b1;
                        busy   <= 1'b0;
                        state  <= STATE_IDLE;
                    end else begin
                        d_cnt <= d_cnt + 4'd1;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
