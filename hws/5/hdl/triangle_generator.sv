// Generates "triangle" waves (counts from 0 to 2^N-1, then back down again)
// The triangle should increment/decrement only if the ena signal is high, and hold its value otherwise.
module triangle_generator(clk, rst, ena, out);

parameter N = 8;
input wire clk, rst, ena;
output logic [N-1:0] out;

typedef enum logic {COUNTING_UP = 0, COUNTING_DOWN} state_t;
state_t state;

always_ff @(posedge clk) begin
	if (rst) begin
		state <= COUNTING_DOWN;
		out <= 0;
	end
	else if (ena) begin
		if (out === 0 | out === 2**N - 1) begin
			// Ideally this would be:
			// state = (pulse_zero | pulse_max) ? state_t'(~logic'(state)) : state;
			// But Icarus Verilog doesn't support casting to an enum.
			state <= state === COUNTING_UP ? COUNTING_DOWN : COUNTING_UP;
			// We could also maintain separate counters, like in
			// my schematic... This requires more adders, while
			// the current implementation just requires two muxes
			// and a single adder.
			out <= out + (state === COUNTING_DOWN ? {{(N-1){1'b0}}, 1'b1} : {N{1'b1}});
		end
		else begin
			out <= out + (state === COUNTING_UP ? {{(N-1){1'b0}}, 1'b1} : {N{1'b1}});
		end
	end
end

endmodule
