`timescale 1ns/1ps
`default_nettype none

module test_adder;

parameter N = 8;

logic [N-1:0] a, b, sum_desired;
logic c_in, c_out_desired;

wire [N-1:0] sum;
wire c_out;

adder_n #(.N(N)) UUT(
  .a(a), 
  .b(b),
  .c_in(c_in),
  .sum(sum),
  .c_out(c_out)
);

//adder_n #(.N(N)) adder(.a(a), .b(b), .c_in(c_in), .sum(sum), .c_out(c_out));

initial begin
  $dumpfile("adder.fst");
  $dumpvars(0, UUT);

  a = 0;
  b = 0;
  c_in = 0;

  #1

  $display("Running simulation...");
  for (a = 0; a < 2**N - 1; a++) begin
	  for (b = 0; b < 2**N - 1; b++) begin
		  {c_out_desired, sum_desired} = a + b + c_in;
		  #1
		  if (c_out_desired !== c_out) begin
			  $display("Bad carry: %d + %d gives carry %d, but we had %d", a, b, c_out_desired, c_out);
			  $stop;
		  end
		  if (sum_desired !== sum) begin
			  $display("Bad sum: %d + %d gives %d, but we had %d", a, b, sum_desired, sum);
			  $stop;
		  end
	  end
  end
  $finish;
end

endmodule
