module ysyx_26000004_SRAM(
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

  import "DPI-C" function int pmem_read(input int raddr);
  import "DPI-C" function void pmem_write(input int waddr, input int wdata, input byte wmask);

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
             read_data   <= pmem_read(arradr); 
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


// WRITE BLOCK
always @(posedge aclk) begin
  if (awvalid & awready & wvalid & wready)
    pmem_write(awaddr, wdata, wstrb);
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