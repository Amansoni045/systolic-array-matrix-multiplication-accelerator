`timescale 1ns/1ps

// Matrix Controller FSM for 4x4 systolic array.
// Supplies unskewed A[r][k] / B[k][c] to the array; the array handles lane skewing.
// Schedule: IDLE -> CLEAR (1 cycle) -> LOAD (4 cycles, k=0..3) -> DRAIN (6 cycles) -> IDLE
// On the cycle after DRAIN completes, result is latched and done is pulsed.

module matrix_controller (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,          // pulse to begin operation
    input  wire [255:0] a_flat,        // A[r][c] at [8*(4*r+c) +: 8]; 16 signed 8-bit values
    input  wire [255:0] b_flat,        // B[r][c] at [8*(4*r+c) +: 8]
    output reg         busy,
    output reg         done,           // one-cycle pulse when results are captured
    output reg         clear_acc,
    output reg [31:0]  a_out,          // unskewed: a_out[8*r +: 8] = A[r][k]
    output reg [31:0]  b_out,          // unskewed: b_out[8*c +: 8] = B[k][c]
    output reg [3:0]   a_valid,
    output reg [3:0]   b_valid,
    input  wire [511:0] acc_in,        // from systolic array
    output reg [511:0]  result         // latched result
);

    // FSM state encoding
    localparam STATE_IDLE  = 2'd0;
    localparam STATE_CLEAR = 2'd1;
    localparam STATE_LOAD  = 2'd2;
    localparam STATE_DRAIN = 2'd3;

    reg [1:0] state;
    reg [1:0] k_cnt;   // LOAD sub-counter: k = 0..3
    reg [2:0] d_cnt;   // DRAIN sub-counter: d = 0..5

    // busy: asserted in CLEAR/LOAD/DRAIN states; cleared on done pulse in DRAIN->IDLE.
    // done: one-cycle pulse asserted exactly on the transition from DRAIN when d_cnt==5.
    // Both busy and done are registered outputs updated in the single always block below.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= STATE_IDLE;
            k_cnt     <= 2'd0;
            d_cnt     <= 3'd0;
            busy      <= 1'b0;
            done      <= 1'b0;
            clear_acc <= 1'b0;
            a_out     <= 32'd0;
            b_out     <= 32'd0;
            a_valid   <= 4'd0;
            b_valid   <= 4'd0;
            result    <= 512'd0;
        end else begin
            // Default: deassert single-cycle signals
            done      <= 1'b0;
            clear_acc <= 1'b0;

            case (state)
                // ----------------------------------------------------------------
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

                // ----------------------------------------------------------------
                // CLEAR state: clear_acc was asserted entering this state.
                // Transition to LOAD on the next cycle; deassert clear_acc.
                STATE_CLEAR: begin
                    clear_acc <= 1'b0;
                    k_cnt     <= 2'd0;
                    state     <= STATE_LOAD;
                end

                // ----------------------------------------------------------------
                // LOAD state: drive unskewed A[r][k] and B[k][c] for k=0..3.
                // a_flat[8*(4*r+c) +: 8] = A[r][c]  =>  A[r][k] = a_flat[8*(4*r+k) +: 8]
                // b_flat[8*(4*r+c) +: 8] = B[r][c]  =>  B[k][c] = b_flat[8*(4*k+c) +: 8]
                STATE_LOAD: begin
                    a_valid <= 4'b1111;
                    b_valid <= 4'b1111;

                    // Row lanes: a_out[8*r +: 8] = A[r][k]
                    a_out[8*0 +: 8] <= a_flat[8*(4*0 + k_cnt) +: 8];
                    a_out[8*1 +: 8] <= a_flat[8*(4*1 + k_cnt) +: 8];
                    a_out[8*2 +: 8] <= a_flat[8*(4*2 + k_cnt) +: 8];
                    a_out[8*3 +: 8] <= a_flat[8*(4*3 + k_cnt) +: 8];

                    // Col lanes: b_out[8*c +: 8] = B[k][c]
                    b_out[8*0 +: 8] <= b_flat[8*(4*k_cnt + 0) +: 8];
                    b_out[8*1 +: 8] <= b_flat[8*(4*k_cnt + 1) +: 8];
                    b_out[8*2 +: 8] <= b_flat[8*(4*k_cnt + 2) +: 8];
                    b_out[8*3 +: 8] <= b_flat[8*(4*k_cnt + 3) +: 8];

                    if (k_cnt == 2'd3) begin
                        k_cnt <= 2'd0;
                        d_cnt <= 3'd0;
                        state <= STATE_DRAIN;
                    end else begin
                        k_cnt <= k_cnt + 2'd1;
                    end
                end

                // ----------------------------------------------------------------
                // DRAIN state: valids deasserted, let operands propagate through array.
                // 6 drain cycles (d=0..5). After d==5, latch result and return to IDLE.
                STATE_DRAIN: begin
                    a_valid <= 4'd0;
                    b_valid <= 4'd0;

                    if (d_cnt == 3'd5) begin
                        // All results ready — latch and signal done
                        result <= acc_in;
                        done   <= 1'b1;
                        busy   <= 1'b0;
                        state  <= STATE_IDLE;
                    end else begin
                        d_cnt <= d_cnt + 3'd1;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
