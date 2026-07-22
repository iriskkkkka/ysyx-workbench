module ysyx_26000004_CLINT(
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

ysyx_26000004_Reg #(.WIDTH(64)) mtime(
    .clk  	(aclk   ),
    .rst  	(~aresetn   ),
    .din  	(din   ),
    .dout 	(dout  ),
    .wen  	(1'b1   )
);

wire [63:0] din;
wire [63:0] dout;

assign din = dout + 1;

// READ BLOCK
reg read_states;
reg [31:0] read_data;

always @(posedge aclk) begin
if (!aresetn) begin
    read_states <= 1'b0;
end 
else begin
    case (read_states)
    1'b0: begin
        if (arvalid & arready) begin
            if (arradr == 32'ha0000048) begin
                read_data <= dout[31:0];
            end else if (arradr == 32'ha000004c) begin
                read_data <= dout[63:32];
            end
            read_states <= 1'b1;
        end
    end
    1'b1: begin
        if (rvalid & rready) read_states <= 1'b0;
    end
    endcase
end
end

always @(*) begin
if (!aresetn) begin
    arready = 1'b0;
    rvalid  = 1'b0;
    rresp   = 2'b00;
    rdata = 0;
end else begin
    case (read_states)
    1'b0: begin
        arready = 1'b1;
        rvalid  = 1'b0;
        rresp   = 2'b11;
        rdata = 0;
    end
    1'b1: begin 
        rdata = read_data; 
        arready = 1'b0; 
        rvalid = 1'b1; 
        rresp = 2'b00; 
    end    
    endcase
end
end


endmodule