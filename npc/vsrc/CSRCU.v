module CSRCU(
    input [31:0] exu_in,
    input [31:0] csr_out,
    input [4:0] rs,
    input [2:0] func3,
    output reg [31:0] csr_in
);

always @(*) begin
    case (func3)
        3'b001: csr_in = exu_in;
        3'b010: csr_in = csr_out | exu_in;
        3'b011: csr_in = csr_out & ~exu_in;
        3'b101: csr_in = {27'b0, rs};
        3'b110: csr_in = csr_out | {27'b0, rs};
        3'b111: csr_in = csr_out & ~{27'b0, rs};
        default: csr_in = 0;
    endcase
end

endmodule