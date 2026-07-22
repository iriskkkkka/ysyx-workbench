module ysyx_26000004_Arbiter(
  // Global
  input              aclk,
  input              aresetn,

  // AXI FROM IFU
  input              awvalid_i,
  output reg         awready_i,
  input       [31:0] awaddr_i,
  
  input              wvalid_i,
  output reg         wready_i,
  input       [31:0] wdata_i,
  input       [3 :0] wstrb_i,

  output reg         bvalid_i,
  input              bready_i,
  output reg  [1:0]  bresp_i,
  
  input              arvalid_i,
  output reg         arready_i,
  input       [31:0] arradr_i,
  
  output reg         rvalid_i,
  input              rready_i,
  output reg  [31:0] rdata_i,
  output reg  [1 :0] rresp_i,

  // AXI FROM LSU
  input              awvalid_l,
  output reg         awready_l,
  input       [31:0] awaddr_l,
  
  input              wvalid_l,
  output reg         wready_l,
  input       [31:0] wdata_l,
  input       [3 :0] wstrb_l,

  output reg         bvalid_l,
  input              bready_l,
  output reg  [1:0]  bresp_l,
  
  input              arvalid_l,
  output reg         arready_l,
  input       [31:0] arradr_l,
  
  output reg         rvalid_l,
  input              rready_l,
  output reg  [31:0] rdata_l,
  output reg  [1 :0] rresp_l,

  // AXI to OUTPUT
  output  reg        awvalid,
  input              awready,
  output  reg [31:0] awaddr,
  
  output  reg        wvalid,
  input              wready,
  output  reg [31:0] wdata,
  output  reg [3 :0] wstrb,

  input              bvalid,
  output  reg        bready,
  input    [1:0]     bresp,
  
  output  reg        arvalid,
  input              arready,
  output  reg [31:0] arradr,
  
  input              rvalid,
  output  reg        rready,
  input    [31:0]    rdata,
  input    [1 :0]    rresp,

  // AXI to CLINT
  output  reg        arvalid_c,
  input              arready_c,
  output  reg [31:0] arradr_c,
  
  input              rvalid_c,
  output  reg        rready_c,
  input    [31:0]    rdata_c,
  input    [1 :0]    rresp_c
);

reg [1:0] state; // 00 idle, 01 ifu, 10 lsu

always @(posedge aclk) begin
  if (!aresetn) state <= 2'b00;
  else begin
    case (state)
      default: begin
        if      (arvalid_l | awvalid_l) state <= 2'b10;
        else if (arvalid_i) state <= 2'b01;
        else    state <= 2'b00;
      end
      2'b01: begin
        if (rvalid & rready) begin
          state <= 2'b00;
        end else state <= 2'b01;
      end
      2'b10: begin
        if (((rvalid & rready) | (bvalid & bready)) | (rvalid_c & rready_c)) begin
          state <= 2'b00;
        end else state <= 2'b10;
      end
    endcase
  end
end



always @(*) begin
  case (state) 
    2'b01: begin
      // IFU recieve
      awready_i = 1'b0;
      wready_i  = 1'b0;
      bvalid_i  = 1'b0;
      bresp_i   = 2'b0;
      arready_i = arready;
      rvalid_i  = rvalid;
      rdata_i   = rdata;
      rresp_i   = rresp;
 
      // LSU receive
      awready_l = 1'b0;
      wready_l  = 1'b0;
      bvalid_l  = 1'b0;
      bresp_l   = 2'b0;
      arready_l = 1'b0;
      rvalid_l  = 1'b0;
      rdata_l   = 32'b0;
      rresp_l   = 2'b0;
      
      // Outside recieve
      awvalid = 1'b0;
      awaddr  = 32'b0;
      wvalid  = 1'b0;
      wdata   = 32'b0;
      wstrb   = 4'b0;
      bready  = 1'b0;
      arvalid = arvalid_i;
      arradr  = arradr_i;
      rready  = rready_i;

      // CLINT receive
      arradr_c  = 32'b0;
      rready_c = 1'b0;
      arvalid_c = 1'b0;
    end
    2'b10: begin
      // IFU receive
      awready_i = 1'b0;
      wready_i  = 1'b0;
      bvalid_i  = 1'b0;
      bresp_i   = 2'b0;
      arready_i = 1'b0;
      rvalid_i  = 1'b0;
      rdata_i   = 32'b0;
      rresp_i   = 2'b0;

      if (arradr_l == 32'ha0000048 | arradr_l == 32'ha000004c) begin
        // Output receive
        awvalid = 1'b0;
        awaddr  = 32'b0;
        wvalid  = 1'b0;
        wdata   = 32'b0;
        wstrb   = 4'b0;
        bready  = 1'b0;
        arvalid = 1'b0;
        arradr  = 32'b0;
        rready  = 1'b0;

        // LSU receive
        awready_l = 1'b0;
        wready_l  = 1'b0;
        bvalid_l  = 1'b0;
        bresp_l   = 2'b0;
        arready_l = arready_c;
        rvalid_l  = rvalid_c;
        rdata_l   = rdata_c;
        rresp_l   = rresp_c;

        // CLINT receive
        arradr_c  = arradr_l;
        rready_c = rready_l;   
        arvalid_c = arvalid_l;   
      end else begin
        // Output Recieve
        awvalid = awvalid_l;
        awaddr  = awaddr_l;
        wvalid  = wvalid_l;
        wdata   = wdata_l;
        wstrb   = wstrb_l;
        bready  = bready_l;
        arvalid = arvalid_l;
        arradr  = arradr_l;
        rready  = rready_l;

        // LSU receive
        awready_l = awready;
        wready_l  = wready;
        bvalid_l  = bvalid;
        bresp_l   = bresp;
        arready_l = arready;
        rvalid_l  = rvalid;
        rdata_l   = rdata;
        rresp_l   = rresp;
        
        // CLINT receive
        arradr_c  = 32'b0;
        rready_c = 1'b0; 
        arvalid_c = 1'b0;
      end
      
    end
    default: begin
      awready_i = 1'b0;
      wready_i  = 1'b0;
      bvalid_i  = 1'b0;
      bresp_i   = 2'b0;
      arready_i = 1'b0;
      rvalid_i  = 1'b0;
      rdata_i   = 32'b0;
      rresp_i   = 2'b0;
      
      awready_l = 1'b0;
      wready_l  = 1'b0;
      bvalid_l  = 1'b0;
      bresp_l   = 2'b0;
      arready_l = 1'b0;
      rvalid_l  = 1'b0;
      rdata_l   = 32'b0;
      rresp_l   = 2'b0;
 
      awvalid = 1'b0;
      awaddr  = 32'b0;
      wvalid  = 1'b0;
      wdata   = 32'b0;
      wstrb   = 4'b0;
      bready  = 1'b0;
      arvalid = 1'b0;
      arradr  = 32'b0;
      rready  = 1'b0;

      arradr_c  = 32'b0;
      rready_c = 1'b0;
      arvalid_c = 1'b0;
    end
  endcase
end

endmodule