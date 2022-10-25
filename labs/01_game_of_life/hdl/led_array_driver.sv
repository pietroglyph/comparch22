`default_nettype none
`timescale 1ns/1ps

module led_array_driver(ena, x, cells, rows, cols);
// Module I/O and parameters
parameter N=8; // Size of Conway Cell Grid.
parameter ROWS=N;
parameter COLS=N;
localparam XBITS = $clog2(N);

// I/O declarations
input wire ena;
input wire [XBITS:0] x;
input wire [N*N-1:0] cells;
output logic [N-1:0] rows;
output logic [N-1:0] cols;


// You can check parameters with the $error macro within initial blocks.
initial begin
  if ((N <= 0) || (N > 8)) begin
    $error("N must be within 0 and 8.");
  end
  if (ROWS != COLS) begin
    $error("Non square led arrays are not supported. (%dx%d)", ROWS, COLS);
  end
  if (ROWS < N) begin
    $error("ROWS/COLS must be >= than the size of the Conway Grid.");
  end
end

// We only need to wire ena to the decoder, because if the decoder is disabled
// we'll never put any columns high, which means we'll never display anything.
wire [7:0] x_decoded;
decoder_3_to_8 COL_DECODER(ena, x, x_decoded);

always_comb cols = x_decoded;
generate
for (genvar i = 0; i < N; i++) begin
	wire sum;
	adder_n #(.N(XBITS)) ADDER(.a(N*i), .b(x), .c_in({{XBITS}{1'b0}}), .sum(sum), .c_out());
	always_comb rows[i] = ~cells[sum];
end
endgenerate

endmodule
