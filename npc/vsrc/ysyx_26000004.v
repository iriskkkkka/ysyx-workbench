module ysyx_26000004(
  input                               clock,
  input                               reset,
  input                               io_interrupt,

  input                               io_master_awready,
  output                              io_master_awvalid,
  output [31:0]                       io_master_awaddr,
  output [3:0]                        io_master_awid,
  output [7:0]                        io_master_awlen,
  output [2:0]                        io_master_awsize,
  output [1:0]                        io_master_awburst,

  input                               io_master_wready,
  output                              io_master_wvalid,
  output [31:0]                       io_master_wdata,
  output [3:0]                        io_master_wstrb,
  output                              io_master_wlast,

  output                              io_master_bready,
  input                               io_master_bvalid,
  input  [1:0]                        io_master_bresp,
  input  [3:0]                        io_master_bid,

  input                               io_master_arready,
  output                              io_master_arvalid,
  output [31:0]                       io_master_araddr,
  output [3:0]                        io_master_arid,
  output [7:0]                        io_master_arlen,
  output [2:0]                        io_master_arsize,
  output [1:0]                        io_master_arburst,

  output                              io_master_rready,
  input                               io_master_rvalid,
  input  [1:0]                        io_master_rresp,
  input  [31:0]                       io_master_rdata,
  input                               io_master_rlast,
  input  [3:0]                        io_master_rid,

  output                              io_slave_awready,
  input                               io_slave_awvalid,
  input  [31:0]                       io_slave_awaddr,
  input  [3:0]                        io_slave_awid,
  input  [7:0]                        io_slave_awlen,
  input  [2:0]                        io_slave_awsize,
  input  [1:0]                        io_slave_awburst,
  output                              io_slave_wready,
  input                               io_slave_wvalid,
  input  [31:0]                       io_slave_wdata,
  input  [3:0]                        io_slave_wstrb,
  input                               io_slave_wlast,
  input                               io_slave_bready,
  output                              io_slave_bvalid,
  output [1:0]                        io_slave_bresp,
  output [3:0]                        io_slave_bid,
  output                              io_slave_arready,
  input                               io_slave_arvalid,
  input  [31:0]                       io_slave_araddr,
  input  [3:0]                        io_slave_arid,
  input  [7:0]                        io_slave_arlen,
  input  [2:0]                        io_slave_arsize,
  input  [1:0]                        io_slave_arburst,
  input                               io_slave_rready,
  output                              io_slave_rvalid,
  output [1:0]                        io_slave_rresp,
  output [31:0]                       io_slave_rdata,
  output                              io_slave_rlast,
  output [3:0]                        io_slave_rid
);

/*===UNUSED PORTS===*/
assign io_slave_awready = 0;
assign io_slave_wready  = 0;
assign io_slave_bvalid  = 0;
assign io_slave_bresp   = 0;
assign io_slave_bid     = 0;
assign io_slave_arready = 0;
assign io_slave_rvalid  = 0;
assign io_slave_rresp   = 0;
assign io_slave_rdata   = 0;
assign io_slave_rlast   = 0;
assign io_slave_rid     = 0;

assign io_master_awid   = 0;
assign io_master_awlen  = 0;
assign io_master_awsize = 0;
assign io_master_awburst= 0;
assign io_master_wlast  = 0;
assign io_master_arlen  = 0;
assign io_master_arid   = 0;
assign io_master_arsize = 0;
assign io_master_arburst= 0;

/*===DPI-C functions===*/
import "DPI-C" function void ebreak(input int a0);
always @(*) begin
  if (instr == 32'h00100073 && instr_valid) begin
    ebreak(gpr_out[10]);
  end
end 

import "DPI-C" function void commit(input int pc, input int inst);
import "DPI-C" function void gpr_update(input int idx, input int val);

always @(posedge clock) begin
  if (!reset && pc_en) begin
    commit(pc_out, instr);
    for (int i = 0; i < 16; i = i + 1) gpr_update(i, gpr_out[i]);
  end
end

/*===General Purpose Registers===*/
genvar n;
generate
  for (n = 0; n < 16; n = n + 1) begin : gen_gpr
    ysyx_26000004_Reg #(.WIDTH(32)) u_gpr(
      .clk  (clock),
      .rst  (reset),
      .din  (gpr_in),
      .dout (gpr_out[n]),
      .wen  (wen[n])
    );
  end
endgenerate

wire [31:0] gpr_out [0:31];
wire [15:0] wen;
wire [31:0] gpr_in;

/*===Program Counter===*/
ysyx_26000004_Reg #(.WIDTH(32), .RESET_VAL(32'h20000000)) PC(
  .clk  	(clock     ),
  .rst  	(reset     ),
  .din  	(pc_in   ),
  .dout 	(pc_out  ),
  .wen  	(pc_en   )
);

wire pc_en;
wire [31:0] pc_out;
wire [31:0] pc_in   = is_mret ? mepc_out : is_ecall ? mtvec_out : is_jump ? jump : (branch) ? btarget : (pc_out + 4);
wire [31:0] jump    = is_jalr ? ((gpr_out[rs1] + imm) & ~32'b1) : (pc_out + imm);
wire [31:0] btarget = pc_out + imm;

assign pc_en = instr_ready & instr_valid;

/*===CSR initialization===*/
ysyx_26000004_Reg #(.WIDTH(32), .RESET_VAL(32'h1800)) mstatus(
  .clk  	(clock   ),
  .rst  	(reset   ),
  .din  	(csr_in   ),
  .dout 	(mstatus_out  ),
  .wen  	(mstatus_en   )
);

ysyx_26000004_Reg #(.WIDTH(32)) mepc(
  .clk  	(clock   ),
  .rst  	(reset   ),
  .din  	(mepc_in   ),
  .dout 	(mepc_out  ),
  .wen  	(mepc_en   )
);

ysyx_26000004_Reg #(.WIDTH(32)) mcause(
  .clk  	(clock   ),
  .rst  	(reset   ),
  .din  	(mcause_in   ),
  .dout 	(mcause_out  ),
  .wen  	(mcause_en   )
);

ysyx_26000004_Reg #(.WIDTH(32)) mtval(
  .clk  	(clock),
  .rst  	(reset   ),
  .din  	(csr_in   ),
  .dout 	(mtval_out  ),
  .wen  	(mtval_en  )
);

ysyx_26000004_Reg #(.WIDTH(32)) mtvec(
  .clk  	(clock   ),
  .rst  	(reset   ),
  .din  	(csr_in   ),
  .dout 	(mtvec_out  ),
  .wen  	(mtvec_en )
);

wire [31:0] mepc_out, mcause_out, mtval_out, mtvec_out, mstatus_out;
wire [11:0] csr_address;
wire [31:0] csr_in;
reg  [31:0] csr_out;

wire [31:0] mepc_in   = (is_ecall) ? (pc_out) : (csr_in);
wire [31:0] mcause_in = (is_ecall) ? (11)     : (csr_in);

wire mepc_en    = ((is_csr && csr_address == 12'h341) || is_ecall) & decode_valid;
wire mcause_en  = ((is_csr && csr_address == 12'h342) || is_ecall) & decode_valid;
wire mtval_en   = (is_csr && (csr_address == 12'h343)) & decode_valid;
wire mtvec_en   = (is_csr && (csr_address == 12'h305)) & decode_valid;
wire mstatus_en = (is_csr && (csr_address == 12'h300)) & decode_valid;

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

/*===clint====*/
ysyx_26000004_CLINT u_CLINT(
  .aclk    	(clock      ),
  .aresetn 	(~reset     ),
  .awvalid 	(1'b0       ),
  .awready 	(           ),
  .awaddr  	(32'b0      ),
  .wvalid  	(1'b0       ),
  .wready  	(           ),
  .wdata   	(32'b0      ),
  .wstrb   	(8'b0       ),
  .bvalid  	(           ),
  .bready  	(1'b0       ),
  .bresp   	(           ),
  .arvalid 	(arvalid_c  ),
  .arready 	(arready_c  ),
  .arradr  	(arradr_c   ),
  .rvalid  	(rvalid_c   ),
  .rready  	(rready_c   ),
  .rdata   	(rdata_c    ),
  .rresp   	(rresp_c    )
);

wire arready_c;
wire rvalid_c;
wire [31:0] rdata_c;
wire [1 :0] rresp_c; 


ysyx_26000004_Arbiter u_Arbiter(
  .aclk      	(clock      ),
  .aresetn   	(~reset     ),
  // IFU
  .awready_i  (awready_i  ),
  .wready_i   (wready_i   ),
  .bvalid_i   (bvalid_i   ),
  .bresp_i    (bresp_i    ),   
  .arready_i  (arready_i  ),
  .rvalid_i   (rvalid_i   ),
  .rdata_i    (rdata_i    ),
  .rresp_i    (rresp_i    ),

  .awvalid_i 	(awvalid_i  ),
  .awaddr_i  	(awaddr_i   ),
  .wvalid_i  	(wvalid_i   ),
  .wdata_i   	(wdata_i    ),
  .wstrb_i   	(wstrb_i    ),
  .bready_i  	(bready_i   ),
  .arvalid_i 	(arvalid_i  ),
  .arradr_i  	(arradr_i   ),
  .rready_i  	(rready_i   ),
  //LSU
  .awready_l  (awready_l  ),
  .wready_l   (wready_l   ),
  .bvalid_l   (bvalid_l   ),
  .bresp_l    (bresp_l    ),   
  .arready_l  (arready_l  ),
  .rvalid_l   (rvalid_l   ),
  .rdata_l    (rdata_l    ),
  .rresp_l    (rresp_l    ),

  .awvalid_l 	(awvalid_l  ),
  .awaddr_l  	(awaddr_l   ),
  .wvalid_l  	(wvalid_l   ),
  .wdata_l   	(wdata_l    ),
  .wstrb_l   	(wstrb_l    ),
  .bready_l  	(bready_l   ),
  .arvalid_l 	(arvalid_l  ),
  .arradr_l  	(arradr_l   ),
  .rready_l  	(rready_l   ),
  //AXI_OUT
  .awvalid   	(io_master_awvalid),
  .awready   	(io_master_awready),
  .awaddr    	(io_master_awaddr ),
  .wvalid    	(io_master_wvalid ),
  .wready    	(io_master_wready ),
  .wdata     	(io_master_wdata  ),
  .wstrb     	(io_master_wstrb  ),
  .bvalid    	(io_master_bvalid ),
  .bready    	(io_master_bready ),
  .bresp     	(io_master_bresp  ),
  .arvalid   	(io_master_arvalid),
  .arready   	(io_master_arready),
  .arradr    	(io_master_araddr ),
  .rvalid    	(io_master_rvalid ),
  .rready    	(io_master_rready ),
  .rdata     	(io_master_rdata  ),
  .rresp     	(io_master_rresp  ),
  //CLINT
  .arvalid_c  (arvalid_c  ),
  .arready_c  (arready_c  ),
  .arradr_c   (arradr_c   ),
  .rvalid_c   (rvalid_c   ),
  .rready_c   (rready_c   ),
  .rdata_c    (rdata_c    ),
  .rresp_c    (rresp_c    )
);

wire arvalid_c;
wire [31:0] arradr_c;
wire rready_c;

wire awvalid;
wire [31:0] awaddr;
wire wvalid;
wire [31:0] wdata_SRAM;
wire [7:0 ] wstrb;
wire bready;
wire arvalid;
wire [31:0] arradr;
wire rready;

wire awready_i;
wire wready_i;
wire bvalid_i;
wire [1 :0] bresp_i;   
wire arready_i;
wire rvalid_i;
wire [31:0] rdata_i;
wire [1 :0] rresp_i;

wire awready_l;
wire wready_l;
wire bvalid_l;
wire [1 :0] bresp_l;   
wire arready_l;
wire rvalid_l;
wire [31:0] rdata_l;
wire [1 :0] rresp_l;

/*===Instruction Fetch Unit===*/
ysyx_26000004_IFU u_IFU(
    .pc_out     (pc_out   ),
    .instr_out  (instr    ),

    .clk        (clock    ),
    .rst        (reset    ),

    .awready_i  (awready_i),
    .wready_i   (wready_i ),
    .bvalid_i   (bvalid_i ),
    .bresp_i    (bresp_i  ),   
    .arready_i  (arready_i), 
    .rvalid_i   (rvalid_i ),
    .rdata_i    (rdata_i  ),
    .rresp_i    (rresp_i  ),

    .awvalid_i  (awvalid_i),
    .awaddr_i   (awaddr_i ),
    .wvalid_i   (wvalid_i ),
    .wdata_i    (wdata_i  ),
    .wstrb_i    (wstrb_i  ),
    .bready_i   (bready_i ),
    .arvalid_i  (arvalid_i),
    .arradr_i   (arradr_i ),
    .rready_i   (rready_i ),
    
    // Handshake with IDU
    .instr_valid(instr_valid),
    .instr_ready(instr_ready)
);

wire awvalid_i;
wire [31:0] awaddr_i;
wire wvalid_i;
wire [31:0] wdata_i;
wire [3 :0] wstrb_i;
wire bready_i;
wire arvalid_i;
wire [31:0] arradr_i;
wire rready_i;

wire instr_valid;
wire [31:0] instr;
wire instr_ready;

/*===Instruction Decode Unit===*/
ysyx_26000004_IDU u_IDU(
  .instr_valid  	(instr_valid   ),
  .instr_ready  	(instr_ready   ),

  .decode_valid 	(decode_valid  ),
  .decode_ready 	(decode_ready  ),
  
  .instr        	(instr         ),
  .alu_op       	(alu_op        ),
  .rs1          	(rs1           ),
  .rs2          	(rs2           ),
  .rd           	(rd            ),
  .imm          	(imm           ),
  .func3        	(func3         ),
  
  .use_imm      	(use_imm       ),
  .is_csr       	(is_csr        ),
  .use_pc       	(use_pc        ),
  .is_mret      	(is_mret       ),
  .is_ecall     	(is_ecall      ),
  .mem_write    	(mem_write     ),
  .mem_read     	(mem_read      ),
  .is_branch    	(is_branch     ),
  .write_reg    	(write_reg     ),
  .is_jalr      	(is_jalr       ),
  .is_jump      	(is_jump       )
);

wire decode_valid;
wire decode_ready;
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

assign csr_address  = imm[11:0];
assign decode_ready = is_csr ? csr_ready : exu_ready;

/*===CSR Control Unit===*/
ysyx_26000004_CSRCU u_CSRCU(
  .decode_valid (decode_valid),
  .csr_ready    (csr_ready),

  .exu_in   (exu_in1),
  .csr_out  (csr_out),
  .rs       (rs1    ),
  .func3    (func3  ),
  .csr_in   (csr_in )
);

wire csr_ready;

/*===Execution Control Unit===*/
ysyx_26000004_EXU u_EXU(
  .decode_valid  	(decode_valid   ),
  .exu_ready     	(exu_ready      ),

  .exu_out_valid 	(exu_out_valid  ),
  .exu_out_ready 	(exu_out_ready  ),
  
  .exu_in1       	(exu_in1        ),
  .exu_in2       	(exu_in2        ),
  
  .alu_op        	(alu_op         ),
  .func3         	(func3          ),
  .is_branch     	(is_branch      ),
  .branch        	(branch         ),
  
  .exu_out       	(exu_out        )
);

wire exu_ready;
wire exu_out_ready;
wire exu_out_valid;

wire [31:0] exu_in1;
wire [31:0] exu_in2;
wire [31:0] exu_out;
wire [31:0] wb_data;
wire branch;

assign exu_out_ready = (mem_read | mem_write) ? lsu_in_ready : wbu_in_ready;
assign exu_in1 = use_pc  ? pc_out  : gpr_out[rs1]; 
assign exu_in2 = use_imm ? imm     : gpr_out[rs2]; 

/*===Writeback Unit===*/
ysyx_26000004_WBU u_WBU(
  .exu_out_valid 	(exu_out_valid  ),
  .wbu_in_ready 	(wbu_in_ready  ),

  .wb_data       	(gpr_in         ),
  .gpr_en        	(wen            ),

  .lsu_out_valid  (lsu_out_valid  ),
  .lsu_out_ready  (lsu_out_ready  ),
  
  .csr_out       	(csr_out        ),
  .pc_out        	(pc_out         ),
  .rdata         	(rdata          ),
  .exu_out       	(exu_out        ),
  .rd            	(rd             ),
  
  .write_reg     	(write_reg      ),
  .is_csr        	(is_csr         ),
  .is_jump       	(is_jump        ),
  .mem_read      	(mem_read       )
);

wire wbu_in_ready;

/*===Load Store Unit===*/
ysyx_26000004_LSU u_LSU(
  .clk           	(clock          ),
  .reset         	(reset          ),
  .awready_l     	(awready_l      ),
  .wready_l      	(wready_l       ),
  .bvalid_l      	(bvalid_l       ),
  .bresp_l       	(bresp_l        ),
  .arready_l     	(arready_l      ),
  .rvalid_l      	(rvalid_l       ),
  .rdata_l       	(rdata_l        ),
  .rresp_l       	(rresp_l        ),
  .awvalid_l     	(awvalid_l      ),
  .awaddr_l      	(awaddr_l       ),
  .wvalid_l      	(wvalid_l       ),
  .wdata_l       	(wdata_l        ),
  .wstrb_l       	(wstrb_l        ),
  .bready_l      	(bready_l       ),
  .arvalid_l     	(arvalid_l      ),
  .arradr_l      	(arradr_l       ),
  .rready_l      	(rready_l       ),
  .exu_out_valid 	(exu_out_valid  ),
  .lsu_in_ready  	(lsu_in_ready   ),
  .lsu_out_valid 	(lsu_out_valid  ),
  .lsu_out_ready 	(lsu_out_ready  ),
  .mem_read      	(mem_read       ),
  .mem_write     	(mem_write      ),
  .raddr         	(raddr          ),
  .waddr         	(waddr          ),
  .wdata         	(wdata          ),
  .func3         	(func3          ),
  .rdata         	(rdata          )
);

wire awvalid_l;
wire [31:0] awaddr_l;
wire wvalid_l;
wire [31:0] wdata_l;
wire [3 :0] wstrb_l;
wire bready_l;
wire arvalid_l;
wire [31:0] arradr_l;
wire rready_l;

wire lsu_in_ready;
wire lsu_out_valid;
wire lsu_out_ready;
wire [31:0] raddr;
wire [31:0] waddr;
wire [31:0] wdata;
reg  [31:0] rdata;

assign wdata = gpr_out[rs2];
assign waddr = exu_out;
assign raddr = exu_out;

endmodule