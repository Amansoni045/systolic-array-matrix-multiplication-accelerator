`timescale 1ns/1ps

module processing_element #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
) (
    input wire clk,
    input wire rst_n,
    input wire clear_acc,

    input wire signed [DATA_WIDTH-1:0] a_in,
    input wire signed [DATA_WIDTH-1:0] b_in,

    input wire a_valid_in,
    input wire b_valid_in,

    output reg signed [DATA_WIDTH-1:0] a_out,
    output reg signed [DATA_WIDTH-1:0] b_out,

    output reg a_valid_out,
    output reg b_valid_out,

    output reg signed [ACC_WIDTH-1:0] acc_out
);

    wire signed [2*DATA_WIDTH-1:0] product;
    wire signed [ACC_WIDTH-1:0] product_ext;

    assign product = a_in * b_in;

    generate
        if (ACC_WIDTH > 2 * DATA_WIDTH) begin : gen_ext
            assign product_ext = {{(ACC_WIDTH - 2*DATA_WIDTH){product[2*DATA_WIDTH-1]}}, product};
        end else begin : gen_no_ext
            assign product_ext = product;
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out <= {DATA_WIDTH{1'b0}};
            b_out <= {DATA_WIDTH{1'b0}};
            a_valid_out <= 1'b0;
            b_valid_out <= 1'b0;
            acc_out <= {ACC_WIDTH{1'b0}};
        end else begin
            a_out <= a_in;
            b_out <= b_in;
            a_valid_out <= a_valid_in;
            b_valid_out <= b_valid_in;

            if (clear_acc) begin
                acc_out <= {ACC_WIDTH{1'b0}};
            end else if (a_valid_in && b_valid_in) begin
                acc_out <= acc_out + product_ext;
            end
        end
    end

endmodule
