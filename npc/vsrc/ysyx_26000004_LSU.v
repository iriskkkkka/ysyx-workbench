module ysyx_26000004_LSU(
    input         clk,
    input         reset,

    input         awready_l,
    output reg    awvalid_l,
    output [31:0] awaddr_l,
    
    input         wready_l,
    output reg    wvalid_l,
    output [31:0] wdata_l,
    output [3 :0] wstrb_l,
   
   
    input         bvalid_l,
    output        bready_l,
    input [1:0]   bresp_l,   
    
    input         arready_l,
    output reg    arvalid_l,
    output [31:0] arradr_l,

    input         rvalid_l,
    input [31:0]  rdata_l,
    input [1 :0]  rresp_l,
    output        rready_l,

    input         exu_out_valid,
    input         lsu_out_ready,

    output        lsu_in_ready,
    output reg    lsu_out_valid,
    
    input         mem_read,
    input         mem_write,
    input [31:0]  raddr,
    input [31:0]  waddr,
    input [31:0]  wdata,
    input [2:0]   func3,

    output reg [31:0] rdata
);

wire   [31:0] lw     = rdata_r;
assign arradr_l      = raddr;
assign rready_l      = ~lsu_out_valid_r;         
assign lsu_out_valid = lsu_out_valid_r;
assign lsu_in_ready  = mem_write ? (bvalid_l & bready_l) :
                       mem_read  ? (lsu_out_valid & lsu_out_ready) : 1'b1;

always @(posedge clk) begin
  if (reset) begin
        arvalid_l       <= 1'b0; 
        busy            <= 1'b0; 
        lsu_out_valid_r <= 1'b0;
  end else begin
    if (exu_out_valid & mem_read & ~busy) begin
        arvalid_l <= 1'b1;                     
        busy      <= 1'b1;
    end
    if (arvalid_l & arready_l) arvalid_l <= 1'b0;
    if (rvalid_l & rready_l) begin
        rdata_r         <= rdata_l; 
        lsu_out_valid_r <= 1'b1;
    end
    if (lsu_out_valid_r & lsu_out_ready) begin
        lsu_out_valid_r <= 1'b0;
        busy            <= 1'b0;  
    end
  end
end

reg        lsu_out_valid_r;
reg [31:0] rdata_r;    
reg        busy;


assign awaddr_l = waddr;
assign wdata_l  = wdata_s;
assign wstrb_l  = wmask_s;
assign bready_l = 1'b1;

always @(posedge clk) begin
    if (reset) begin
        awvalid_l <= 1'b0;
        wvalid_l  <= 1'b0;
    end else begin
        if (exu_out_valid & mem_write & ~busyw) begin
            awvalid_l  <= 1'b1;
            wvalid_l   <= 1'b1;   
            busyw      <= 1'b1;
        end
        if (awvalid_l & awready_l) awvalid_l  <= 1'b0;  
        if (wvalid_l  & wready_l)  wvalid_l   <= 1'b0;
        if (bvalid_l  & bready_l)  busyw      <= 1'b0;  
    end
end

reg busyw;
wire [1:0]  off = waddr[1:0];
reg  [31:0] wdata_s;
reg  [3:0]  wmask_s;

always @(*) begin
    rdata = 0;
    if (lsu_out_valid) begin
        case (func3)
            3'b000: case (raddr[1:0])                       // LB
                2'b00: rdata = {{24{lw[7]}},  lw[7:0]};
                2'b01: rdata = {{24{lw[15]}}, lw[15:8]};
                2'b10: rdata = {{24{lw[23]}}, lw[23:16]};
                2'b11: rdata = {{24{lw[31]}}, lw[31:24]};
            endcase
            3'b100: case (raddr[1:0])                       // LBU
                2'b00: rdata = {24'b0, lw[7:0]};
                2'b01: rdata = {24'b0, lw[15:8]};
                2'b10: rdata = {24'b0, lw[23:16]};
                2'b11: rdata = {24'b0, lw[31:24]};
            endcase
            3'b001: case (raddr[1])                    // LH
                1'b0: rdata = {{16{lw[15]}}, lw[15:0]};
                1'b1: rdata = {{16{lw[31]}}, lw[31:16]};
            endcase
            3'b101: case (raddr[1])                    // LHU
                1'b0: rdata = {16'b0, lw[15:0]};
                1'b1: rdata = {16'b0, lw[31:16]};
            endcase
            3'b010:  rdata = lw;                        // LW
            default: rdata = 32'b0;
        endcase
    end
end

always @(*) begin
    wdata_s = 32'b0;
    wmask_s = 4'h00;
    if (mem_write) begin
        case (func3)
            3'b000: begin wdata_s = wdata << (8*off); wmask_s = 4'h01 << off; end // SB
            3'b001: begin wdata_s = wdata << (8*off); wmask_s = 4'h03 << off; end // SH
            3'b010: begin wdata_s = wdata;            wmask_s = 4'h0F;        end // SW
            default:begin wdata_s = 32'b0;            wmask_s = 4'h00;        end
        endcase
    end
end

endmodule