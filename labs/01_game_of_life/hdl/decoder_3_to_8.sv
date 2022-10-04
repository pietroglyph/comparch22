`timescale 1ns/1ps
module decoder_3_to_8(ena, in, out);

  input wire ena;
  input wire [2:0] in;
  output logic [7:0] out;

  decoder_2_to_4 DECODER_0(.ena(~in[2] & ena), .in(in[1:0]), .out(out[3:0]));
  decoder_2_to_4 DECODER_1(.ena(in[2] & ena), .in(in[1:0]), .out(out[7:4]));

endmodule
