module comparator_eq(a, b, out);
parameter N = 32;
input wire signed [N-1:0] a, b;
output logic out;

always_comb out = &(a ~^ b);

endmodule


