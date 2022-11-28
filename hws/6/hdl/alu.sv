`timescale 1ns/1ps
`default_nettype none

`include "alu_types.sv"

module alu(a, b, control, result, overflow, zero, equal);
parameter N = 32; // Don't need to support other numbers, just using this as a constant.

input wire [N-1:0] a, b; // Inputs to the ALU.
input alu_control_t control; // Sets the current operation.
output logic [N-1:0] result; // Result of the selected operation.

output logic overflow; // Is high if the result of an ADD or SUB wraps around the 32 bit boundary.
output logic zero;  // Is high if the result is ever all zeros.
output logic equal; // Is high if a == b.
logic carry; // Unused??

logic [N-1:0] invalid_control = 123;// {N{1'b0}};
logic subtract, shift_overflow;
logic [N-1:0] b_maybe_neg, sum, sll, srl, sra;

always_comb begin
	subtract = &control[3:2];
	b_maybe_neg = subtract ? ~b : b;
	shift_overflow = |b[N-1:5];
end

adder_n #(.N(N)) ADDER(a, b_maybe_neg, subtract, sum, carry);
shift_left_logical SLL(a, b[4:0], sll);
shift_right_logical SRL(a, b[4:0], srl);
shift_right_arithmetic SRA(a, b[4:0], sra);
mux16 #(.N(N)) RES_MUX(
	invalid_control,
	a & b, a | b, a ^ b,
	invalid_control,
	shift_overflow ? 0 : sll, shift_overflow ? 0 : srl, shift_overflow ? 0 : sra,
	sum,
	invalid_control, invalid_control, invalid_control,
	sum,
	{{(N-1){1'b0}}, sum[N-1] ^ overflow},
	invalid_control,
	{{(N-1){1'b0}}, ~carry},
	control, result
);
always_comb begin
	overflow = ~(control[2] ^ a[N-1] ^ b[N-1]) & (sum[N-1] ^ a[N-1]) & control[3];
	zero = ~|result;
	equal = &(a ~^ b);
end

endmodule

