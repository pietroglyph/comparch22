`timescale 1ns/1ps
`default_nettype none

module mux_1(in, sel, out);
	input wire [1:0] in;
	input wire sel;

	output wire out;

	assign out = (in[0] & ~sel) ^ (in[1] & sel);
endmodule
