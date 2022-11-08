`timescale 1ns/1ps
`default_nettype none

module test_mux;

parameter N = 32;
parameter RUNS = 10000;

logic [N-1:0] in;
logic [$clog2(N)-1:0] sel;
logic out_desired;

wire out;

mux_n #(.N(N)) UUT(
	.in(in),
	.sel(sel),
	.out(out)
);

initial begin
  $dumpfile("mux.fst");
  $dumpvars(0, UUT);

  $display("Running simulation...");
  for (int unsigned i = 0; i < RUNS; i++) begin
	  in = $random;
	  sel = $random;

	  #10

	  out_desired = in[sel];
	  if (out_desired !== out) begin
		  $display("Selected bit %d with value %b but output was %b", sel, out_desired, out);
		  foreach (in[i]) $display("%b", in[i]);
		  $stop;
	  end
  end
  $finish;
end

endmodule
