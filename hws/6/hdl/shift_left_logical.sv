`timescale 1ns/1ps
`default_nettype none
module shift_left_logical(in, shamt, out);

parameter N = 32; // only used as a constant! Don't feel like you need to a shifter for arbitrary N.

input wire [N-1:0] in;            // the input number that will be shifted left. Fill in the remainder with zeros.
input wire [$clog2(N)-1:0] shamt; // the amount to shift by (think of it as a decimal number from 0 to 31). 
output logic [N-1:0] out;

wire [N-1:0] in_reversed;

generate
	for (genvar i = 0; i < N; i++) begin
		assign in_reversed[i] = in[N-1-i];
		muxn #(.INPUT_NUM(N)) MUX({{(N-1-i){1'b0}}, in_reversed[N-1:N-1-i]}, shamt, out[i]);
	end
endgenerate

endmodule
