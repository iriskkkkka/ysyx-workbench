module IFU(
    input [31:0] pc,
    input [31:0] instr,
    output [31:0] addr
);

assign addr = pc;

endmodule