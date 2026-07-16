module LSU(
    input [31:0] raddr,
    input [31:0] waddr,
    input [31:0] wdata,
    input mem_read,
    input mem_write,
    input [2:0] func3,
    output reg [31:0] rdata,
    input clk
);

import "DPI-C" function int pmem_read(input int raddr);
import "DPI-C" function void pmem_write(input int waddr, input int wdata, input byte wmask);

reg [31:0] lw;
wire [1:0] off = waddr[1:0];
wire [1:0] off_r = raddr[1:0];
reg [31:0] wdata_s;
reg [7:0]  wmask_s;

always @(*) begin
    rdata = 0;
    lw = 0;
    if (mem_read) begin
        lw = pmem_read(raddr);   
        case (func3)
            3'b000: begin // LB 
            case (off_r)
                2'b00: rdata = {{24{lw[7]}},  lw[7:0]};
                2'b01: rdata = {{24{lw[15]}}, lw[15:8]};
                2'b10: rdata = {{24{lw[23]}}, lw[23:16]};
                2'b11: rdata = {{24{lw[31]}}, lw[31:24]};
            endcase
            end
            3'b100: begin // LBU 
            case (off_r)
                2'b00: rdata = {24'b0, lw[7:0]};
                2'b01: rdata = {24'b0, lw[15:8]};
                2'b10: rdata = {24'b0, lw[23:16]};
                2'b11: rdata = {24'b0, lw[31:24]};
            endcase
            end
            3'b001: begin // LH 
            case (off_r[1])
                1'b0: rdata = {{16{lw[15]}}, lw[15:0]};
                1'b1: rdata = {{16{lw[31]}}, lw[31:16]};
            endcase
            end
            3'b101: begin // LHU 
            case (off_r[1])
                1'b0: rdata = {16'b0, lw[15:0]};
                1'b1: rdata = {16'b0, lw[31:16]};
            endcase
            end
            3'b010: rdata = lw;        // LW
            default: rdata = 32'b0;
        endcase
    end
        if (mem_write) begin
        case (func3)
            3'b000: begin // SB
                wdata_s = wdata << (8 * off);
                wmask_s = 8'h01 << off;
            end
            3'b001: begin // SH 
                wdata_s = wdata << (8 * off);
                wmask_s = 8'h03 << off;
            end
            3'b010: begin // SW
                wdata_s = wdata;
                wmask_s = 8'h0F;
            end
            default: begin
                wdata_s = 32'b0;
                wmask_s = 8'h00;
            end
        endcase
        end
end

always @(posedge clk) begin
    if (mem_write) pmem_write(waddr, wdata_s, wmask_s);
end

endmodule
