`timescale 1ns/1ps

module processing_element (
    input wire clk,
    input wire rst_n,
    input wire clear_acc,

    input wire signed [7:0] a_in,
    input wire signed [7:0] b_in,

    input wire a_valid_in,
    input wire b_valid_in,

    output reg signed [7:0] a_out,
    output reg signed [7:0] b_out,

    output reg a_valid_out,
    output reg b_valid_out,

    output reg signed [31:0] acc_out
);

    wire signed [15:0] a_extended;
    wire signed [15:0] b_extended;
    wire signed [15:0] product;

    assign a_extended = {{8{a_in[7]}}, a_in};
    assign b_extended = {{8{b_in[7]}}, b_in};

    assign product = a_extended * b_extended;

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            a_out <= 0;
            b_out <= 0;

            a_valid_out <= 0;
            b_valid_out <= 0;

            acc_out <= 0;

        end

        else begin

            a_out <= a_in;
            b_out <= b_in;

            a_valid_out <= a_valid_in;
            b_valid_out <= b_valid_in;

            if (clear_acc) begin

                acc_out <= 32'sd0;

            end


            else if (a_valid_in && b_valid_in) begin

                acc_out <= acc_out +
                           {{16{product[15]}}, product};

            end

        end

    end

endmodule
