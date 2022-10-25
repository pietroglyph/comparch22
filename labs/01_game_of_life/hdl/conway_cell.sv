`timescale 1ns/1ps
`default_nettype none

module conway_cell(clk, rst, ena, state_0, state_d, state_q, neighbors);
// In practice this won't ever change; it's nice to have because it makes the
// HDL clearer.
localparam NUM_NEIGHBORS = 8;
// We need one less bit than the number of bits needed to count all the
// neighbors; this is because we don't care about sums greater than 3--we can
// just look at the or of the carry-outs.
localparam ADDER_BITS = $clog2(NUM_NEIGHBORS) - 1;

input wire clk;
input wire rst;
input wire ena;

input wire state_0;
output logic state_d; // NOTE - this is only an output of the module for debugging purposes. 
output logic state_q;

input wire [NUM_NEIGHBORS - 1:0] neighbors;

wire [ADDER_BITS * NUM_NEIGHBORS - 1:0] sums;
wire [NUM_NEIGHBORS - 1:0] carries;
wire [ADDER_BITS - 1:0] sum_final;
wire carry_final;

// This gets a specific sum out of the sum bus
`define get_sum(bus, i, offset=0) bus[ADDER_BITS * (i + offset + 1) - 1:ADDER_BITS * (i + offset)]

// The design here is very simple: we only care about when this sums to 2 and
// 3, so we can get away with using 2-bit adders that successively add together each
// neighbor. We can detect if the sum is greater than 3 by checking to see if
// any of the carries are 1 (i.e. we've ever overflowed). If we haven't
// overflowed then we can check the sum directly.
assign `get_sum(sums, 0) = {{(ADDER_BITS-1){1'b0}}, neighbors[0]};
assign carries[0] = 1'b0;
generate
for (genvar i = 0; i < NUM_NEIGHBORS - 1; i++) begin
	adder_n #(.N(ADDER_BITS)) ADDER(`get_sum(sums, i), {{(ADDER_BITS-1){1'b0}}, neighbors[i+1]}, carries[i], `get_sum(sums, i, 1), carries[i+1]);
end
endgenerate
assign sum_final = `get_sum(sums, NUM_NEIGHBORS-1);

always_comb begin : conway_cell_logic
	// The cell is alive and we haven't overflowed and the MSB of the
	// sum is 1 (which will be true if and only if the sum is 2 or 3)
	// OR we're not alive and we haven't overflowed and the sum is 2'b11
	// (3).
	state_d = (state_q & sum_final[1] & ~(|carries)) | (~state_q & &sum_final & ~(|carries));
end
always_ff @(posedge clk) begin
	// Could do this with a mux to truly avoid behavioral Verilog; Avi
	// says this is ok though.
	if (rst) state_q <= state_0;
	else if (ena) state_q <= state_d;
end

endmodule
