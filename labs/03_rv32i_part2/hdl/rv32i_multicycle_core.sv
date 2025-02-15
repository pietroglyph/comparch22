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
logic alu_equal_old;
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
	S_JUMP_WRITE_BACK,

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
					// TODO: Support non-word L- and
					// S-types
					OP_LTYPE, OP_STYPE: state <= funct3 === 3'b010 ? S_MEM_ADDR : S_ERROR;
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

			S_EXECUTE_R_TYPE, S_EXECUTE_I_TYPE, S_EXECUTE_JAL: state <= S_ALU_WRITE_BACK;
			S_ALU_WRITE_BACK: state <= S_FETCH;

			S_EXECUTE_JALR: state <= S_JUMP_WRITE_BACK;
			S_JUMP_WRITE_BACK: state <= S_FETCH;

			S_EXECUTE_B_TYPE: state <= S_FETCH;

			default: state <= S_ERROR; // XXX: We could just start over from fetch? Reset? Idk.
		endcase
	end
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
		OP_LTYPE, OP_ITYPE, OP_JALR: imm_ext_src = IMM_EXT_SRC_I_TYPE;
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
		IMM_EXT_SRC_S_TYPE: imm_ext = {{20{IR[31]}}, IR[31:25], IR[11:7]};
		IMM_EXT_SRC_B_TYPE: imm_ext = {{20{IR[31]}}, IR[7], IR[30:25], IR[11:8], 1'b0};
		IMM_EXT_SRC_J_TYPE: imm_ext = {{12{IR[31]}}, IR[19:12], IR[20], IR[30:21], 1'b0};
		IMM_EXT_SRC_U_TYPE: imm_ext = {IR[31:12], 12'b0};
		default: imm_ext = 32'b0;
	endcase
end

// Datapath
// Writeback control
always_comb begin : writeback_control
	case (state)
		S_FETCH: writeback_result = alu_result;
		S_EXECUTE_R_TYPE, S_EXECUTE_B_TYPE, S_EXECUTE_JAL, S_ALU_WRITE_BACK, S_JUMP_WRITE_BACK, S_MEM_WRITE, S_MEM_READ: writeback_result = alu_result_old;
		S_MEM_WRITE_BACK: writeback_result = mem_rd_data_old;
		default: writeback_result = 32'b0;
	endcase

	PC_next = writeback_result;
end

// Register file control
always_comb begin : reg_file_control
	case (state)
		S_MEM_WRITE_BACK, S_ALU_WRITE_BACK: reg_write = 1'b1;
		default: reg_write = 1'b0;
	endcase

	rfile_wr_data = writeback_result;	
end

// Memory control
always_comb begin : memory_control
	case (state)
		S_FETCH: mem_addr = PC;
		S_MEM_WRITE, S_MEM_READ: mem_addr = writeback_result;
		default: mem_addr = 32'b0;
	endcase

	case (state)
		S_MEM_WRITE: mem_wr_ena = 1'b1;
		default: mem_wr_ena = 1'b0;
	endcase

	mem_wr_data = reg_data2_old;
end

// ALU control
logic magic_funct7, zero_funct7;
always_comb begin : alu_control_
	case (state)
		S_FETCH: src_a = PC;
		S_DECODE, S_EXECUTE_JAL: src_a = PC_old;
		S_EXECUTE_R_TYPE, S_EXECUTE_B_TYPE, S_EXECUTE_I_TYPE, S_EXECUTE_JALR, S_MEM_ADDR: src_a = reg_data1_old;
		default: src_a = 32'b0;
	endcase

	case (state)
		S_FETCH, S_EXECUTE_JAL: src_b = 32'd4;
		S_DECODE, S_EXECUTE_JALR: src_b = imm_ext;
		S_EXECUTE_R_TYPE, S_EXECUTE_B_TYPE: src_b = reg_data2_old;
		S_EXECUTE_I_TYPE: case (funct3)
			// sll and sra/srl have an effective funct7 in the
			// immediate which we don't want.
			FUNCT3_SLL, FUNCT3_SHIFT_RIGHT: src_b = {27'b0, imm_ext[4:0]};
			default: src_b = imm_ext;
		endcase
		S_MEM_ADDR: src_b = imm_ext;
		default: src_b = 32'b0;
	endcase

	magic_funct7 = funct7 === 7'b0100000;
	zero_funct7 = funct7 === 7'b0;

	// XXX: The instructions that use funct7 to
	// differentiate themselves will break if there's
	// a non sub/sra instruction with a nonzero funct7
	// code. I'll fix this later, right? :)
	case (state)
		S_FETCH, S_MEM_ADDR, S_DECODE, S_EXECUTE_JAL, S_EXECUTE_JALR: alu_control = ALU_ADD;
		S_EXECUTE_R_TYPE, S_EXECUTE_I_TYPE: case (funct3)
			FUNCT3_ADD: begin
				if (state === S_EXECUTE_I_TYPE | zero_funct7) alu_control = ALU_ADD;
				else if (state === S_EXECUTE_R_TYPE & magic_funct7) alu_control = ALU_SUB;
				else alu_control = ALU_INVALID;
			end
			FUNCT3_SLL: begin
				if (zero_funct7) alu_control = ALU_SLL;
				else alu_control = ALU_INVALID;
			end
			FUNCT3_SLT: alu_control = ALU_SLT;
			FUNCT3_SLTU: alu_control = ALU_SLTU;
			FUNCT3_XOR: alu_control = ALU_XOR;
			FUNCT3_SHIFT_RIGHT: begin
				if (zero_funct7) alu_control = ALU_SRL;
				else if (magic_funct7) alu_control = ALU_SRA;
				else alu_control = ALU_INVALID;
			end
			FUNCT3_OR: alu_control = ALU_OR;
			FUNCT3_AND: alu_control = ALU_AND;
			default: alu_control = ALU_INVALID;
		endcase
		S_EXECUTE_B_TYPE: case (funct3)
			FUNCT3_BLTU, FUNCT3_BGEU: alu_control = ALU_SLTU;
			default: alu_control = ALU_SLT;
		endcase
		default: alu_control = ALU_INVALID;
	endcase
end

// Program counter enable control
always_comb begin : pc_ena_control
	case (state)
		S_FETCH, S_EXECUTE_JAL, S_JUMP_WRITE_BACK: PC_ena = 1'b1;
		S_EXECUTE_B_TYPE: case (funct3)
			FUNCT3_BEQ: PC_ena = equal;
			FUNCT3_BNE: PC_ena = ~equal;
			FUNCT3_BLT, FUNCT3_BLTU: PC_ena = alu_result[0];
			FUNCT3_BGE, FUNCT3_BGEU: PC_ena = equal | ~alu_result[0];
			default: PC_ena = 1'b0;
		endcase
		default: PC_ena = 1'b0;
	endcase
end

// Instruction register enable control
always_comb begin : ir_ena_control
	case (state)
		S_FETCH: IR_write = 1'b1;
		default: IR_write = 1'b0;
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
		alu_equal_old <= 1'b0;
	end else begin
		mem_rd_data_old <= mem_rd_data;
		reg_data1_old <= reg_data1;
		reg_data2_old <= reg_data2;
		alu_result_old <= alu_result;
		alu_equal_old <= equal;
	end
end

endmodule
