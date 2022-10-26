/*
  Outputs a pulse generator with a period of "ticks".
  out should go high for one cycle ever "ticks" clocks.
*/
module pulse_generator(clk, rst, ena, ticks, out);

parameter N = 8;
input wire clk, rst, ena;
input wire [N-1:0] ticks;
output logic out;

always_ff @(posedge clk) begin
	if (rst) counter <= 0;
	else counter <= counter + 1;
end
always_comb begin
	counter_comparator = counter == ticks;
	out = counter_comparator;
end

endmodule
