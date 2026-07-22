module ysyx_26000004_IFU(
    input       [31:0] pc_out,
    output      [31:0] instr_out,
    input              clk,
    input              rst,
    //Write Not Used for fetching
    input              awready_i,
    output             awvalid_i,
    output      [31:0] awaddr_i,
    output             wvalid_i,
    output      [31:0] wdata_i,
    output      [3 :0] wstrb_i,
    input              wready_i,
    //Bresponse channel
    input              bvalid_i,
    input       [1 :0] bresp_i,   
    output             bready_i,
    // Address Read Channel
    input              arready_i,
    output reg         arvalid_i,
    output      [31:0] arradr_i,
    // Data Read Channel
    input              rvalid_i,
    input       [31:0] rdata_i,
    input       [1 :0] rresp_i,
    output             rready_i,
    // Handshake with IDU
    output             instr_valid,
    input              instr_ready
);

assign awvalid_i = 1'b0;
assign awaddr_i  = 32'b0;
assign wvalid_i  = 1'b0;
assign wdata_i   = 32'b0;
assign wstrb_i   = 4'b0;    
assign bready_i  = 1'b0;

assign arradr_i    = pc_out;
assign rready_i    = ~instr_valid_r;         
assign instr_out   = instr_r;
assign instr_valid = instr_valid_r;

always @(posedge clk) begin
    if (rst) begin
        arvalid_i     <= 1'b1; 
        instr_valid_r <= 1'b0;
    end else begin
        if (arvalid_i & arready_i) arvalid_i <= 1'b0;
        if (rvalid_i & rready_i) begin
            instr_r       <= rdata_i; 
            instr_valid_r <= 1'b1;
        end
        if (instr_valid_r & instr_ready) begin
            instr_valid_r <= 1'b0; 
            arvalid_i     <= 1'b1;    
        end
    end
end

reg        instr_valid_r;
reg [31:0] instr_r;

endmodule