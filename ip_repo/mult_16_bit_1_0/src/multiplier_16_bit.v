`timescale 1ns / 1ps

module multiplier_16_bit (
    input wire clk,
    input wire rst_n,
    input wire [15:0] a,
    input wire [15:0] b,
    output reg [31:0] prod
);

    always @(posedge clk) begin
        if (!rst_n)
            prod <= 32'd0;
        else
            prod <= a * b;
    end

endmodule
