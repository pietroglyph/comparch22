/*
  A pulse width modulation module 
*/

module pwm(clk, rst, ena, step, duty, out);

parameter N = 8;

input wire clk, rst;
input wire ena; // Enables the output.
input wire step; // Enables the internal counter. You should only increment when this signal is high (this is how we slow down the PWM to reasonable speeds).
input wire [N-1:0] duty; // The "duty cycle" input.
output logic out;

logic [N-1:0] counter;

always_ff @(posedge clk) begin
	if (rst) counter <= 0;
	else if (ena & step) begin
		counter <= counter + 1;
	end
end

always_comb out = (counter <= duty) & ena;

endmodule
