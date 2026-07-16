module top(
  input clk,
  input rst,
  input [31:0] instr,
  output [31:0] addr,
  output [31:0] pc_out,
  output [31:0] gpr_out [0:31] 
);

/*===ebreak===*/
import "DPI-C" function void ebreak(input int a0);
always @(*) begin
  if (instr == 32'h00100073) begin
    ebreak(gpr_out[10]);
  end
end 

/*===General Purpose Registers===*/
genvar n;
generate
for (n = 0; n < 16; n = n + 1) begin : gen_gpr
  Reg #(.WIDTH(32)) u_gpr(
    .clk  (clk),
    .rst  (rst),
    .din  (gpr_in),
    .dout (gpr_out[n]),
    .wen  (wen[n])
  );
end
endgenerate

wire [15:0] wen;
wire [31:0] gpr_in;

/*===Program Counter===*/
Reg #(.WIDTH(32), .RESET_VAL(32'h80000000)) PC(
  .clk  	(clk   ),
  .rst  	(rst   ),
  .din  	(pc_in   ),
  .dout 	(pc_out  ),
  .wen  	(pc_en   )
);

wire [31:0] pc_in;
wire pc_en;
wire [31:0] jump;

assign jump = is_jalr ? ((gpr_out[rs1] + imm) & ~32'b1):(pc_out + imm);
wire [31:0] btarget = pc_out + imm;
assign pc_in = is_mret ? mepc_out : is_ecall ? mtvec_out : is_jump ? jump:(branch) ? btarget:(pc_out + 4);
assign pc_en = 1;

/*===CSR initialization===*/
Reg #(.WIDTH(32), .RESET_VAL(32'h1800)) mstatus(
  .clk  	(clk   ),
  .rst  	(rst   ),
  .din  	(csr_in   ),
  .dout 	(mstatus_out  ),
  .wen  	(mstatus_en   )
);

Reg #(.WIDTH(32)) mepc(
  .clk  	(clk   ),
  .rst  	(rst   ),
  .din  	(mepc_in   ),
  .dout 	(mepc_out  ),
  .wen  	(mepc_en   )
);

Reg #(.WIDTH(32)) mcause(
  .clk  	(clk   ),
  .rst  	(rst   ),
  .din  	(mcause_in   ),
  .dout 	(mcause_out  ),
  .wen  	(mcause_en   )
);

Reg #(.WIDTH(32)) mtval(
  .clk  	(clk   ),
  .rst  	(rst   ),
  .din  	(csr_in   ),
  .dout 	(mtval_out  ),
  .wen  	(mtval_en  )
);

Reg #(.WIDTH(32)) mtvec(
  .clk  	(clk   ),
  .rst  	(rst   ),
  .din  	(csr_in   ),
  .dout 	(mtvec_out  ),
  .wen  	(mtvec_en )
);
wire [31:0] mepc_out, mcause_out, mtval_out, mtvec_out;
wire [11:0] csr_address;
wire [31:0] csr_in;
reg [31:0] csr_out;

wire [31:0] mepc_in = (is_ecall) ? (pc_out) : (csr_in);
wire [31:0] mcause_in = (is_ecall) ? (11) : (csr_in);

wire mepc_en   = (is_csr && csr_address == 12'h341) || is_ecall;
wire mcause_en = (is_csr && csr_address == 12'h342) || is_ecall;
wire mtval_en = is_csr && (csr_address == 12'h343);
wire mtvec_en = is_csr && (csr_address == 12'h305);

wire [31:0] mstatus_out;
wire mstatus_en = is_csr && (csr_address == 12'h300);

always @(*) begin
  case (csr_address) 
    12'h300: csr_out = mstatus_out; 
    12'h341: csr_out = mepc_out;
    12'h342: csr_out = mcause_out;
    12'h343: csr_out = mtval_out;
    12'h305: csr_out = mtvec_out;
    default: csr_out = 0;
  endcase
end

/*===Instruction Fetch Unit===*/
IFU u_IFU(
  .pc    	(pc_out     ),
  .instr 	(instr  ),
  .addr  	(addr   )
);

/*===Instruction Decode Unit===*/
IDU u_IDU(
  .instr     	(instr      ),
  .rs1       	(rs1        ),
  .rs2       	(rs2        ),
  .rd         (rd         ),
  .imm       	(imm        ),
  .use_imm   	(use_imm    ),
  .use_pc    	(use_pc     ),
  .is_csr     (is_csr     ),
  .mem_write 	(mem_write  ),
  .mem_read  	(mem_read   ),
  .is_branch 	(is_branch  ),
  .write_reg  (write_reg  ),
  .is_jump   	(is_jump    ),
  .func3      (func3      ),
  .is_ecall   (is_ecall   ),
  .is_mret    (is_mret    ),  
  .is_jalr    (is_jalr    ),
  .alu_op     (alu_op     )
);

wire [2:0] func3;
wire [4:0] rs1;
wire [4:0] rs2;
wire [4:0] rd;
wire [31:0] imm;
wire [3:0] alu_op;
wire is_ecall;
wire is_mret;
wire use_imm;
wire is_jalr;
wire use_pc;
wire mem_write;
wire mem_read;
wire is_branch;
wire is_jump;
wire is_csr;
wire write_reg;
assign csr_address = imm[11:0];

/*===CSR Control Unit===*/
CSRCU u_CSRCU(
  .exu_in   (exu_in1),
  .csr_out  (csr_out),
  .rs       (rs1),
  .func3    (func3),
  .csr_in   (csr_in)
);

/*===Execution Control Unit===*/
EXU u_EXU(
  .exu_in1 	(exu_in1  ),
  .exu_in2 	(exu_in2  ),
  .alu_op   (alu_op   ),
  .is_branch(is_branch),
  .func3    (func3    ),
  .branch   (branch   ),
  .exu_out 	(exu_out  )
);

wire [31:0] exu_in1;
wire [31:0] exu_in2;
wire [31:0] exu_out;
wire [31:0] wb_data;
wire branch;

assign exu_in1 = use_pc ? pc_out : gpr_out[rs1]; 
assign exu_in2 = (use_imm) ? imm:gpr_out[rs2]; 
assign wb_data = (is_csr) ? csr_out : (is_jump) ? (pc_out + 4) : ((mem_read) ? rdata : exu_out);
assign gpr_in = wb_data;
assign wen = (write_reg) ? (rd == 5'd0) ? 16'b0 : (16'b1 << rd) : 0;

/*===Load Store Unit===*/
LSU u_LSU(
  .raddr  (raddr),
  .waddr  (waddr),
  .wdata  (wdata),
  .rdata  (rdata),
  .mem_read(mem_read),
  .mem_write(mem_write),
  .func3    (func3),
  .clk      (clk)
);

wire [31:0] raddr;
wire [31:0] waddr;
wire [31:0] wdata;
reg [31:0] rdata;

assign wdata = gpr_out[rs2];
assign waddr = exu_out;
assign raddr = exu_out;


endmodule