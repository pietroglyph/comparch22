`timescale 1ns/1ps
`default_nettype none

module muxn(in, sel, out);
	parameter INPUT_NUM = 2;
	localparam S = $clog2(INPUT_NUM);
	parameter INPUT_SIZE = 1;

	input wire [INPUT_NUM*INPUT_SIZE-1:0] in;
	input wire [S-1:0] sel;

	wire [(INPUT_NUM-1)*INPUT_SIZE-1:0] intermediates;

	output wire [INPUT_SIZE-1:0] out;

	assign out = intermediates[(INPUT_NUM-1)*INPUT_SIZE-1:(INPUT_NUM-1)*INPUT_SIZE-INPUT_SIZE-1];

	generate
		for (genvar i = 0; i < S; i++) begin
			for (genvar j = 0; j < 2**(S - i - 1); j++) begin
				if (i === 0) begin
					assign intermediates[INPUT_SIZE*(j+1)-1:INPUT_SIZE*j] = sel[i] ? in[2*INPUT_SIZE*(j+1)-1:2*INPUT_SIZE*j+INPUT_SIZE] : in[2*INPUT_SIZE*j+INPUT_SIZE-1:2*INPUT_SIZE*j];
				end
				else begin
					localparam num_intermediates = 2**S - 2**(S - i + 1);
					assign intermediates[INPUT_SIZE*(2**S - 2**(S - i) + j + 1)-1:INPUT_SIZE*(2**S - 2**(S - i) + j)] = sel[i] ? intermediates[num_intermediates*INPUT_SIZE + 2*INPUT_SIZE*(j+1)-1:num_intermediates*INPUT_SIZE + 2*INPUT_SIZE*j + INPUT_SIZE] : intermediates[INPUT_SIZE*num_intermediates + 2*INPUT_SIZE*j+INPUT_SIZE-1:INPUT_SIZE*num_intermediates + 2*INPUT_SIZE*j];
				end
			end
		end
	endgenerate
endmodule
