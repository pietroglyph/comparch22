// Generates "triangle" waves (counts from 0 to 2^N-1, then back down again)
// The triangle should increment/decrement only if the ena signal is high, and hold its value otherwise.
module triangle_generator(clk, rst, ena, out);

parameter N = 8;
input wire clk, rst, ena;
output logic [N-1:0] out;

typedef enum logic {COUNTING_UP, COUNTING_DOWN} state_t;
state_t state;

logic [N-1:0] counter_next;

always_ff @(posedge clk) begin
	if (rst) begin
		state <= COUNTING_UP;
		out <= 0;
	end
	else if (ena) out <= counter_next;
end

always_comb begin
	counter_next = out + (state === COUNTING_UP ? 1 : -1);

	if (counter_next === 0) state = COUNTING_UP;
	else if (counter_next === 2**N - 1) state = COUNTING_DOWN;
end

endmodule
