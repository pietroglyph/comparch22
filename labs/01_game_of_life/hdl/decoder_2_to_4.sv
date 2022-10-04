`timescale 1ns/1ps
module decoder_2_to_4(ena, in, out);

  input wire ena;
  input wire [1:0] in;
  output logic [3:0] out;

  decoder_1_to_2 DECODER_0(.ena(~in[1] & ena), .in(in[0]), .out(out[1:0]));
  decoder_1_to_2 DECODER_1(.ena(in[1] & ena), .in(in[0]), .out(out[3:2]));

endmodule
