module top(
  input clk,
  input rst,
  input [31:0] instr,
  output [31:0] addr
);

/*===General Purpose Registers===*/
genvar n;
generate
for (n = 0; n < 32; n = n + 1) begin : gen_gpr
  Reg #(.WIDTH(32)) u_gpr(
    .clk  (clk),
    .rst  (rst),
    .din  (gpr_in),
    .dout (gpr_out[n]),
    .wen  (wen[n])
  );
end
endgenerate

wire [31:0] wen;
wire [31:0] gpr_in;
wire [31:0] gpr_out [0:31];

/*===Program Counter===*/
Reg #(.WIDTH(32)) PC(
  .clk  	(clk   ),
  .rst  	(rst   ),
  .din  	(pc_in   ),
  .dout 	(pc_out  ),
  .wen  	(pc_en   )
);

wire [31:0] pc_in;
wire [31:0] pc_out;
wire pc_en;
wire [31:0] jump;

assign jump = (gpr_out[rs1] + imm) & ~32'b1;
assign pc_in = (is_jump) ? jump : (pc_out + 4);
assign pc_en = 1;

/*===Instruction Fetch Unit===*/
IFU u_IFU(
  .pc    	(pc_out     ),
  .instr 	(instr  ),
  .addr  	(addr   )
);

/*===Instruction Decode Unit===*/
IDU u_IDU(
  .instr     	(instr      ),
  .func3     	(func3      ),
  .func7     	(func7      ),
  .rs1       	(rs1        ),
  .rs2       	(rs2        ),
  .rd         (rd         ),
  .imm       	(imm        ),
  .use_imm   	(use_imm    ),
  .use_pc    	(use_pc     ),
  .mem_write 	(mem_write  ),
  .mem_read  	(mem_read   ),
  .is_branch 	(is_branch  ),
  .write_reg  (write_reg  ),
  .is_jump   	(is_jump    ),
  .opcode     (opcode     )
);

wire [2:0] func3;
wire [6:0] func7;
wire [4:0] rs1;
wire [4:0] rs2;
wire [4:0] rd;
wire [31:0] imm;
wire [6:0] opcode;
wire use_imm;
wire use_pc;
wire mem_write;
wire mem_read;
wire is_branch;
wire is_jump;
wire write_reg;

/*===Execution Control Unit===*/
EXU u_EXU(
  .exu_in1 	(exu_in1  ),
  .exu_in2 	(exu_in2  ),
  .func3   	(func3    ),
  .func7   	(func7    ),
  .opcode   (opcode   ),
  .exu_out 	(exu_out  )
);

wire [31:0] exu_in1;
wire [31:0] exu_in2;
wire [31:0] exu_out;
wire [31:0] wb_data;

assign exu_in1 = gpr_out[rs1];
assign exu_in2 = (use_imm) ? imm:gpr_out[rs2]; 
assign wb_data = (is_jump) ? (pc_out + 4) : ((mem_read) ? rdata : exu_out);
assign gpr_in = wb_data;
assign wen = (write_reg) ? (rd == 5'd0) ? 32'b0 : (32'b1 << rd) : 0;


/*===Load Store Unit===*/
LSU u_LSU(
  .raddr  (raddr),
  .waddr  (waddr),
  .wdata  (wdata),
  .rdata  (rdata),
  .mem_read(mem_read),
  .mem_write(mem_write),
  .func3    (func3)
);

wire [31:0] raddr;
wire [31:0] waddr;
wire [31:0] wdata;
reg [31:0] rdata;

assign wdata = gpr_out[rs2];
assign waddr = exu_out;
assign raddr = exu_out;


endmodule