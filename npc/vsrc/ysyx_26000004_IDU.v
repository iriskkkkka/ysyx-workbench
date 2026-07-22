module ysyx_26000004_IDU(
    // Handshake with IFU
    input       instr_valid,
    output      instr_ready,

    // Handshake with EXU
    output      decode_valid,
    input       decode_ready,

    // Decode
    input [31:0] instr,

    output reg [3:0] alu_op,
    output [4:0] rs1,
    output [4:0] rs2,
    output [4:0] rd,
    output reg [31:0] imm,
    output [2:0] func3,
    
    // Flags
    output reg use_imm,
    output reg is_csr,
    output reg use_pc,
    output reg is_mret,
    output reg is_ecall,
    output reg mem_write,
    output reg mem_read,
    output reg is_branch,
    output reg write_reg,
    output reg is_jalr,
    output reg is_jump
);

wire [6:0] opcode;
wire [6:0] func7;

assign rd = instr[11:7];
assign rs1 = instr[19:15];
assign rs2 = instr[24:20];
assign opcode = instr[6:0];
assign func3 = instr[14:12];
assign func7 = instr[31:25];

assign instr_ready = decode_ready;
assign decode_valid = instr_valid;

// Immediate multiplexer
always @(*) begin
    if (instr_valid) begin
        case (opcode)
            7'b1100111: imm = {{20{instr[31]}}, instr[31:20]};// I Type
            7'b0000011: imm = {{20{instr[31]}}, instr[31:20]};// I Type
            7'b0010011: imm = {{20{instr[31]}}, instr[31:20]};// I Type
            7'b1110011: imm = {20'b0,           instr[31:20]};// CSR 

            7'b0100011: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]}; // S Type

            7'b1100011: imm = {{19{instr[31]}}, instr[31] ,instr[7], instr[30:25], instr[11:8], 1'b0}; // B Type
            
            7'b0110111: imm = {instr[31:12], {12{1'b0}}}; // U Type
            7'b0010111: imm = {instr[31:12], {12{1'b0}}}; // U Type

            7'b1101111: imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0}; // J Type 

            default: imm = 0; 
        endcase
    end else imm = 0;
end

// Flags multiplexer
always @(*) begin
    use_imm = 1'b0;
    write_reg = 1'b0;
    use_pc = 1'b0;
    mem_write = 1'b0;
    mem_read = 1'b0;
    is_branch = 1'b0;
    is_jump = 1'b0;
    is_jalr = 1'b0;
    is_csr = 1'b0;
    is_ecall = 1'b0;
    is_mret = 1'b0;

    if (instr_valid) begin 
        case (opcode)
            7'b1110011: begin
                if (func3 != 3'b000) begin 
                    is_csr = 1'b1;
                    use_imm = 1'b1;
                    write_reg = 1'b1; 
                end else if (func3 == 3'b000) begin
                if (instr[31:20] == 12'b000000000000) begin
                        is_ecall = 1'b1;
                        is_csr = 1'b1;
                end else if (instr[31:20] == 12'b001100000010) begin
                        is_mret = 1'b1;
                        is_csr = 1'b1;
                end
                end else ;
            end
            7'b0010111: begin
                use_imm = 1'b1;
                write_reg = 1'b1;
                use_pc = 1'b1;
            end
            7'b1101111: begin
                use_imm = 1'b1;
                write_reg = 1'b1;
                is_jump = 1'b1;
            end
            7'b0010011: begin
                use_imm = 1'b1;
                write_reg = 1'b1;
            end
            7'b1100011: begin
                is_branch = 1'b1;
            end
            7'b0110011: begin
                write_reg = 1'b1;
            end
            7'b1100111: begin
                use_imm = 1'b1;
                write_reg = 1'b1;
                is_jump = 1'b1;
                is_jalr = 1'b1;
            end
            7'b0110111: begin 
                use_imm = 1'b1;
                write_reg = 1'b1;
            end 
            7'b0100011: begin
                use_imm = 1'b1;
                mem_write = 1'b1;
            end
            7'b0000011: begin
                use_imm = 1'b1;
                mem_read = 1'b1;
                write_reg = 1'b1;
            end
            default: use_imm = 1'b0;
        endcase
    end
end

// ALU opcode generation
always @(*) begin
  alu_op = 4'b0000; 
  if (instr_valid) begin 
    case (opcode)
        7'b0110011:                                       // R-type
        case (func3)
            3'b000: alu_op = func7[5] ? 4'b0001 : 4'b0000;
            3'b001: alu_op = 4'b0111;
            3'b010: alu_op = 4'b0010;
            3'b011: alu_op = 4'b0011;
            3'b100: alu_op = 4'b0100;
            3'b101: alu_op = func7[5] ? 4'b1001 : 4'b1000;
            3'b110: alu_op = 4'b0101;
            3'b111: alu_op = 4'b0110;
        endcase
        7'b0010011:                                       // I-type
        case (func3)
            3'b000: alu_op = 4'b0000;
            3'b001: alu_op = 4'b0111;
            3'b010: alu_op = 4'b0010;
            3'b011: alu_op = 4'b0011;
            3'b100: alu_op = 4'b0100;
            3'b101: alu_op = func7[5] ? 4'b1001 : 4'b1000;  
            3'b110: alu_op = 4'b0101;
            3'b111: alu_op = 4'b0110;
        endcase
        7'b0110111: alu_op = 4'b1010; 
        default:    alu_op = 4'b0000;   
    endcase
    end
end

endmodule