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

endmodule
