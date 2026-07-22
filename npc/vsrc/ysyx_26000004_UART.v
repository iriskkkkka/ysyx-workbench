module ysyx_26000004_UART(
  // Global
  input             aclk,
  input             aresetn,

  // Write Address Channel
  input             awvalid,
  output  reg       awready,
  input   [31:0]    awaddr,
  
  // Write Data Channel
  input             wvalid,
  output  reg       wready,
  input   [31:0]    wdata,
  input   [7 :0]    wstrb,

  // Write Response Channel
  output            bvalid,
  input             bready,
  output  [1:0]     bresp,

  // Read Address Channel
  input             arvalid,
  output reg        arready,
  input   [31:0]    arradr,
  
  // Read Data Channel
  output reg        rvalid,
  input             rready,
  output reg [31:0] rdata,
  output reg [1 :0] rresp
);

always @(posedge aclk) begin
  if (awvalid & awready & wvalid & wready) $write("%c", wdata[7:0]);
end

always @(*) begin
  if (!aresetn) begin
    awready = 1'b0;
    wready  = 1'b0;
  end else begin
    awready = 1'b1;
    wready  = 1'b1;
  end
end

assign bvalid = awvalid & awready & wvalid & wready;
assign bresp  = 2'b00;   


endmodule