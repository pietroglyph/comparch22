`timescale 1ns/1ps
`default_nettype none

module mux_n(in, sel, out);
	parameter N = 2;
	parameter S = $clog2(N);

	input wire [N-1:0] in;
	input wire [S-1:0] sel;

	wire [N - 2:0] intermediates;

	output wire out;

	assign out = intermediates[N - 2];

	generate
		for (genvar i = 0; i < S; i++) begin
			for (genvar j = 0; j < 2**(S - i - 1); j++) begin
				if (i === 0) begin
					mux_1 MUX(
						.in(in[2*j + 1:2*j]),
						.sel(sel[i]),
						.out(intermediates[j])
					);
				end
				else begin
					localparam num_intermediates = 2**S - 2**(S - i + 1);
					mux_1 MUX(
						.in(intermediates[num_intermediates + 2*j + 1:num_intermediates + 2*j]),
						.sel(sel[i]),
						.out(intermediates[2**S - 2**(S - i) + j])
					);
				end
			end
		end
	endgenerate
endmodule
