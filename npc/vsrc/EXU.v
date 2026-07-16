module EXU(
  input  [31:0] exu_in1,
  input  [31:0] exu_in2,
  input  [3:0]  alu_op,
  input  [2:0]  func3,
  input         is_branch,
  output reg    branch,
  output reg [31:0] exu_out
);

  wire [4:0] shamt = exu_in2[4:0];
  always @(*) begin
    case (alu_op)
      4'b0000:   exu_out = exu_in1 + exu_in2;
      4'b0001:   exu_out = exu_in1 - exu_in2;
      4'b0010:   exu_out = {31'b0, $signed(exu_in1) < $signed(exu_in2)};
      4'b0011:   exu_out = {31'b0, exu_in1 < exu_in2};
      4'b0100:   exu_out = exu_in1 ^ exu_in2;
      4'b0101:   exu_out = exu_in1 | exu_in2;
      4'b0110:   exu_out = exu_in1 & exu_in2;
      4'b0111:   exu_out = exu_in1 << shamt;
      4'b1000:   exu_out = exu_in1 >> shamt;
      4'b1001:   exu_out = $signed(exu_in1) >>> shamt;
      4'b1010:   exu_out = exu_in2;
      default:   exu_out = 32'b0;                  
    endcase
  end

  always @(*) begin
    branch = 1'b0;
    if (is_branch) begin
      case (func3)
        3'b000: branch = (exu_in1 == exu_in2);                    
        3'b001: branch = (exu_in1 != exu_in2);                    
        3'b100: branch = ($signed(exu_in1) <  $signed(exu_in2)); 
        3'b101: branch = ($signed(exu_in1) >= $signed(exu_in2));  
        3'b110: branch = (exu_in1 <  exu_in2);                    
        3'b111: branch = (exu_in1 >= exu_in2);                   
        default: branch = 1'b0;
      endcase
    end
  end
endmodule