`default_nettype none
`timescale 1ns/1ps

module register_file(
  clk, //Note - intentionally does not have a reset! 
  wr_ena, wr_addr, wr_data,
  rd_addr0, rd_data0,
  rd_addr1, rd_data1
);
parameter REG_SIZE = 32;
parameter REG_NUM = 32;

input wire clk;

// Write channel
input wire wr_ena;
input wire [$clog2(REG_NUM)-1:0] wr_addr;
input wire [REG_SIZE-1:0] wr_data;

// Two read channels
input wire [$clog2(REG_NUM)-1:0] rd_addr0, rd_addr1;
output logic [REG_SIZE-1:0] rd_data0, rd_data1;

wire [REG_NUM*REG_SIZE-1:0] register_ds, register_qs;
wire [REG_NUM-1:0] should_write;

generate
	for (genvar i = 0; i < REG_NUM; i++) begin
		if (i == 0) begin
			assign register_qs[REG_SIZE-1:0] = {REG_SIZE{1'b0}};
		end
		else begin
			register #(.N(REG_SIZE)) REG(clk, wr_ena, 1'b0, register_ds[REG_SIZE*(i+1)-1:REG_SIZE*i], register_qs[REG_SIZE*(i+1)-1:REG_SIZE*i]);
		end

		// This is *totally* not the most efficient way to do this,
		// but it also means I don't have to glue together a bunch of
		// decoders to get a 32-bit decoder :)
		comparator_eq #(.N($clog2(REG_NUM))) WR_CMP(wr_addr, $clog2(REG_NUM)'(i), should_write[i]);
		assign register_ds = should_write[i] ? wr_data : register_qs;
	end
endgenerate

muxn #(.INPUT_SIZE(REG_SIZE), .INPUT_NUM(REG_NUM)) MUX_Q0(register_qs, rd_addr0, rd_data0);
muxn #(.INPUT_SIZE(REG_SIZE), .INPUT_NUM(REG_NUM)) MUX_Q1(register_qs, rd_addr1, rd_data1);


endmodule
