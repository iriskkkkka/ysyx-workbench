module ysyx_26000004_WBU(
    // Handshake with EXU
    input  exu_out_valid,
    output wbu_in_ready,

    // Handshake with LSU
    input  lsu_out_valid,
    output lsu_out_ready,

    output reg [31:0] wb_data,
    output reg [15:0] gpr_en,

    input [31:0] csr_out,
    input [31:0] pc_out,
    input [31:0] rdata,
    input [31:0] exu_out,
    input [4: 0] rd,

    input write_reg,
    input is_csr,
    input is_jump,
    input mem_read
);

assign wbu_in_ready = 1'b1;
assign lsu_out_ready = 1'b1;

always @(*) begin
    if (exu_out_valid) begin
        if (is_csr) wb_data = csr_out;
        else if (is_jump) wb_data = pc_out + 4;
        else if (mem_read) begin
            if (lsu_out_valid) begin
                wb_data = rdata;
            end else begin
                wb_data = 0;
            end
        end
        else wb_data = exu_out;
    end else wb_data = 0;
end

always @(*) begin
    if (exu_out_valid) begin
        if (write_reg) begin
            gpr_en = ((rd != 5'd0) & (~mem_read | lsu_out_valid)) ? (16'b1 << rd) : 16'b0;
        end else begin
            gpr_en = 16'b0;
        end
    end else begin
        gpr_en = 16'b0;
    end
end

endmodule