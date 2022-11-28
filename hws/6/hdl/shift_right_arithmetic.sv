`timescale 1ns/1ps
`default_nettype none
module shift_right_arithmetic(in,shamt,out);
parameter N = 32; // only used as a constant! Don't feel like you need to a shifter for arbitrary N.

//port definitions
input  wire [N-1:0] in;    // A 32 bit input
input  wire [$clog2(N)-1:0] shamt; // Shift ammount
output wire [N-1:0] out; // The same as SRL, but maintain the sign bit (MSB) after the shift! 

generate
	for (genvar i = 0; i < N; i++) begin
		muxn #(.INPUT_NUM(N)) MUX({{i{in[N-1]}}, in[N-1:i]}, shamt, out[i]);
	end
endgenerate


endmodule
