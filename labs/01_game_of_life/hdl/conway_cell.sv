`timescale 1ns/1ps
`default_nettype none

module conway_cell(clk, rst, ena, state_0, state_d, state_q, neighbors);
parameter NUM_NEIGHBORS = 8;
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

`define get_seg(bus, i, offset=0) bus[ADDER_BITS * (i + offset + 1) - 1:ADDER_BITS * (i + offset)]

assign `get_seg(sums, 0) = {{(ADDER_BITS-1){1'b0}}, neighbors[0]};
assign carries[0] = 1'b0;
generate
for (genvar i = 0; i < NUM_NEIGHBORS - 1; i++) begin
	adder_n #(.N(ADDER_BITS)) ADDER(`get_seg(sums, i), {{(ADDER_BITS-1){1'b0}}, neighbors[i+1]}, carries[i], `get_seg(sums, i, 1), carries[i+1]);
end
endgenerate
assign sum_final = `get_seg(sums, NUM_NEIGHBORS-1);

always_comb begin : conway_cell_logic
	state_d = (state_q & sum_final[1] & ~(|carries)) | (~state_q & &sum_final & ~(|carries));
end
always_ff @(posedge clk) begin
	if (rst) state_q <= state_0;
	else if (ena) state_q <= state_d;
end

endmodule
