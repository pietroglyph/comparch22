module decoder_1_to_2(ena, in, out);

  input wire ena;
  input wire in;
  output logic [1:0] out;

  always_comb out = {ena & in, ena & ~in};

endmodule
