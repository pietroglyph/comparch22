`timescale 1ns/1ps
`default_nettype none

`include "alu_types.sv"
`include "rv32i_defines.sv"

module rv32i_multicycle_core(
  clk, rst, ena,
  mem_addr, mem_rd_data, mem_wr_data, mem_wr_ena,
  PC, instructions_completed
);

parameter PC_START_ADDRESS=0;

// Standard control signals.
input  wire clk, rst, ena; // <- worry about implementing the ena signal last.
output logic [31:0] instructions_completed;

// Memory interface.
output logic [31:0] mem_addr, mem_wr_data;
input   wire [31:0] mem_rd_data;
logic [31:0] mem_rd_data_old;
output logic mem_wr_ena;

// Program Counter
output wire [31:0] PC;
wire [31:0] PC_old;
logic PC_ena;
logic [31:0] PC_next; 

register #(.N(32), .RESET(PC_START_ADDRESS)) PC_REGISTER (
  .clk(clk), .rst(rst), .ena(PC_ena), .d(PC_next), .q(PC)
);
register #(.N(32)) PC_OLD_REGISTER(
  .clk(clk), .rst(rst), .ena(PC_ena), .d(PC), .q(PC_old)
);

// Instruction register
wire [31:0] IR;
logic IR_write;
logic [31:0] IR_next;

always_comb IR_next = mem_rd_data;
register #(.N(32)) INSTRUCTION_REGISTER(
  .clk(clk), .rst(rst), .ena(IR_write), .d(IR_next), .q(IR)
);

// Register file
logic reg_write;
logic [4:0] rd, rs1, rs2;
logic [31:0] rfile_wr_data;
wire [31:0] reg_data1, reg_data2;
logic [31:0] reg_data1_old, reg_data2_old;
register_file REGISTER_FILE(
  .clk(clk), 
  .wr_ena(reg_write), .wr_addr(rd), .wr_data(rfile_wr_data),
  .rd_addr0(rs1), .rd_addr1(rs2),
  .rd_data0(reg_data1), .rd_data1(reg_data2)
);

// ALU and related control signals
logic [31:0] src_a, src_b;
alu_control_t alu_control;
wire [31:0] alu_result;
logic [31:0] alu_result_old, writeback_result;
wire overflow, zero, equal;
alu_behavioural ALU (
  .a(src_a), .b(src_b), .result(alu_result),
  .control(alu_control),
  .overflow(overflow), .zero(zero), .equal(equal)
);

// Control unit
enum logic [3:0] {
	S_FETCH = 0,
	S_DECODE,

	// For L- and S-type
	S_MEM_ADDR,
	S_MEM_READ,
	S_MEM_WRITE,
	S_MEM_WRITE_BACK,

	// For R, I, and J-type
	S_EXECUTE_R_TYPE,
	S_EXECUTE_I_TYPE,
	S_EXECUTE_JAL,
	S_EXECUTE_JALR,
	S_ALU_WRITE_BACK,
	// XXX: Need jump writeback?

	// For B-type
	S_EXECUTE_B_TYPE,

	S_ERROR = 4'hF
} state;

always_ff @(posedge clk) begin : control_unit_fsm
	if (rst) state <= S_FETCH;
	else begin
		case (state)
			S_FETCH: state <= S_DECODE;
			S_DECODE: begin
				case (op)
					OP_LTYPE, OP_STYPE: state <= S_MEM_ADDR;
					OP_RTYPE: state <= S_EXECUTE_R_TYPE;
					OP_ITYPE: state <= S_EXECUTE_I_TYPE;
					OP_JAL: state <= S_EXECUTE_JAL;
					OP_JALR: state <= S_EXECUTE_JALR;
					OP_BTYPE: state <= S_EXECUTE_B_TYPE;
					default: state <= S_ERROR;
				endcase
			end

			S_MEM_ADDR: begin
				if (op == OP_LTYPE) state <= S_MEM_READ;
				else if (op == OP_STYPE) state <= S_MEM_WRITE;
				else state <= S_ERROR;
			end
			S_MEM_READ: state <= S_MEM_WRITE_BACK;
			S_MEM_WRITE: state <= S_FETCH;
			S_MEM_WRITE_BACK: state <= S_FETCH;

			S_EXECUTE_R_TYPE, S_EXECUTE_I_TYPE, S_EXECUTE_JAL, S_EXECUTE_JALR: state <= S_ALU_WRITE_BACK;
			S_ALU_WRITE_BACK: state <= S_FETCH;

			S_EXECUTE_B_TYPE: state <= S_FETCH;

			default: state <= S_ERROR; // XXX: We could just start over from fetch? Reset? Idk.
		endcase
	end
end

always_comb begin : control_unit_combinational
	case (state)
		S_FETCH: begin
			PC_ena = 1'b1;
			writeback_src = RESULT_SRC_ALU;

			alu_control = ALU_ADD;
			alu_src_a = ALU_SRC_A_PC;
			alu_src_b = ALU_SRC_B_WORD_SIZE;

			mem_wr_ena = 1'b0;
			mem_addr_src = MEM_ADDR_SRC_PC;

			reg_write = 1'b0;

			IR_write = 1'b1;
		end
		S_EXECUTE_R_TYPE: begin
			PC_ena = 1'b0;
			writeback_src = RESULT_SRC_ALU_OLD;

			alu_control = ALU_INVALID;//alu_control_t'(funct3);
			alu_src_a = ALU_SRC_A_RS1;
			alu_src_b = ALU_SRC_B_RS2;

			mem_wr_ena = 1'b0;
			mem_addr_src = MEM_ADDR_SRC_INVALID;

			reg_write = 1'b0;

			IR_write = 1'b0;
		end
		S_ALU_WRITE_BACK: begin
			PC_ena = 1'b0;
			writeback_src = RESULT_SRC_ALU_OLD;

			alu_control = ALU_INVALID;
			alu_src_a = ALU_SRC_A_INVALID;
			alu_src_b = ALU_SRC_B_INVALID;

			mem_wr_ena = 1'b0;
			mem_addr_src = MEM_ADDR_SRC_INVALID;

			reg_write = 1'b1;

			IR_write = 1'b0;
		end
		default: begin
			PC_ena = 1'b0;
			writeback_src = RESULT_SRC_INVALID;

			alu_control = ALU_INVALID;
			alu_src_a = ALU_SRC_A_INVALID;
			alu_src_b = ALU_SRC_B_INVALID;

			mem_wr_ena = 1'b0;
			mem_addr_src = MEM_ADDR_SRC_INVALID;

			reg_write = 1'b0;

			IR_write = 1'b0;
		end
	endcase
end

// Decode unit (we're throwing immediate extension in too)
logic [6:0] op;
logic [2:0] funct3;
logic [31:25] funct7;
logic [31:0] imm_ext;

enum logic [2:0] {IMM_EXT_SRC_I_TYPE, IMM_EXT_SRC_S_TYPE, IMM_EXT_SRC_B_TYPE, IMM_EXT_SRC_J_TYPE, IMM_EXT_SRC_U_TYPE, IMM_EXT_INVALID} imm_ext_src;
always_comb begin : decode_unit
	op = IR[6:0];
	rd = IR[11:7];
	funct3 = IR[14:12];
	rs1 = IR[19:15];
	rs2 = IR[24:20];
	funct7 = IR[31:25];

	case (op)
		OP_LTYPE, OP_ITYPE: imm_ext_src = IMM_EXT_SRC_I_TYPE;
		OP_AUIPC, OP_LUI: imm_ext_src = IMM_EXT_SRC_U_TYPE;
		OP_STYPE: imm_ext_src = IMM_EXT_SRC_S_TYPE;
		OP_BTYPE: imm_ext_src = IMM_EXT_SRC_B_TYPE;	
		OP_JAL: imm_ext_src = IMM_EXT_SRC_J_TYPE;
		default: imm_ext_src = IMM_EXT_INVALID;
	endcase

	case (imm_ext_src)
		// We sign-extend (i.e. take MSB for top bytes) for everything
		// but U-type.
		IMM_EXT_SRC_I_TYPE: imm_ext = {{20{IR[31]}}, IR[31:20]};
		IMM_EXT_SRC_S_TYPE: imm_ext = {{20{IR[31]}}, IR[11:5], IR[4:0]};
		IMM_EXT_SRC_B_TYPE: imm_ext = {{20{IR[31]}}, IR[7], IR[30:25], IR[11:8], 1'b0};
		IMM_EXT_SRC_J_TYPE: imm_ext = {{12{IR[31]}}, IR[19:12], IR[20], IR[30:21], 1'b0};
		IMM_EXT_SRC_U_TYPE: imm_ext = {IR[31:12], 12'b0};
		default: imm_ext = 32'b0;
	endcase
end

// Datapath
// Writeback result mux
enum logic [1:0] {RESULT_SRC_ALU, RESULT_SRC_ALU_OLD, RESULT_SRC_MEM_READ, RESULT_SRC_INVALID} writeback_src;
always_comb begin : writeback_datapath_and_mux
	case (writeback_src)
		RESULT_SRC_ALU: writeback_result = alu_result;
		RESULT_SRC_ALU_OLD: writeback_result = alu_result_old;
		RESULT_SRC_MEM_READ: writeback_result = mem_rd_data_old;
		default: writeback_result = 32'b0;
	endcase

	PC_next = writeback_result;
	rfile_wr_data = writeback_result;	
end

// Memory input address mux
enum logic [1:0] {MEM_ADDR_SRC_ALU, MEM_ADDR_SRC_PC, MEM_ADDR_SRC_INVALID} mem_addr_src;
always_comb begin : mem_addr_mux
	case (mem_addr_src)
		MEM_ADDR_SRC_ALU: mem_addr = writeback_result;
		MEM_ADDR_SRC_PC: mem_addr = PC;
		default: mem_addr = 32'b0;
	endcase
end

// ALU input muxes
enum logic [1:0] {ALU_SRC_A_PC, ALU_SRC_A_PC_OLD, ALU_SRC_A_RS1, ALU_SRC_A_INVALID} alu_src_a;
enum logic [1:0] {ALU_SRC_B_WORD_SIZE, ALU_SRC_B_IMM_EXT, ALU_SRC_B_RS2, ALU_SRC_B_INVALID} alu_src_b;
always_comb begin : alu_input_muxes
	case (alu_src_a)
		ALU_SRC_A_PC: src_a = PC;
		ALU_SRC_A_PC_OLD: src_a = PC_old;
		ALU_SRC_A_RS1: src_a = {27'b0, rs1}; // XXX: Same as below.
		default: src_a = 32'b0;
	endcase

	case (alu_src_b)
		ALU_SRC_B_WORD_SIZE: src_b = 32'd4;
		ALU_SRC_B_IMM_EXT: src_b = imm_ext;
		ALU_SRC_B_RS2: src_b = {27'b0, rs2}; // XXX: Should we sign extend?
		default: src_b = 32'b0;
	endcase
end

// Registers that hold state across cycles; could use the register module, but
// this is a litte more concise.
// TODO: Add a lot more state if we pipeline this.
always_ff @(posedge clk) begin : interstage_registers
	if (rst) begin
		mem_rd_data_old <= 32'b0;
		reg_data1_old <= 32'b0;
		reg_data2_old <= 32'b0;
		alu_result_old <= 32'b0;
	end else begin
		mem_rd_data_old <= mem_rd_data;
		reg_data1_old <= reg_data1;
		reg_data2_old <= reg_data2;
		alu_result_old <= alu_result;
	end
end

/*always_comb begin : control_combinational
	// TODO: this maybe can just be a switch
	case (state)
		S_FETCH: begin
			// Mux on program counter reg
			PC_next = alu_result;
			PC_ena = 1'b1;

			// Mux on ALU control and inputs
			alu_control = ALU_ADD;
			src_a = PC;
			src_b = 32'd4;

			// Mux on MMU inputs
			mem_addr = PC;
			mem_wr_ena = 1'b0;

			// Mux on instruction reg
			IR_write = 1'b1;
			IR_next = mem_rd_data;	
		end
		default: begin
			// Honestly not sure what the most useful thing is
			// here. Start over I guess?

			// Mux on program counter reg
			PC_next = 32'b0;
			PC_ena = 1'b0;

			// Mux on ALU control and inputs
			alu_control = ALU_INVALID;
			src_a = 32'b0;
			src_b = 32'b0;

			// Mux on MMU inputs
			mem_addr = 32'b0;
			mem_wr_ena = 1'b0;
			mem_wr_data = 32'b0;

			// Mux on instruction reg
			IR_write = 1'b0;
			IR_next = 32'b0;
		end
	endcase
end*/

endmodule
