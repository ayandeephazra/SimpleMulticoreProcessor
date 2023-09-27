module IM(clk,addr,instr);

input clk;
input [12:0] addr;

output reg [19:0] instr;	//output of insturction memory

reg [19:0]instr_mem[0:8191];

/////////////////////////////////////
// Memory is latched on clock low //
///////////////////////////////////
always @(negedge clk)
    instr <= instr_mem[addr];

initial begin
  $readmemh("C:/Users/EricHoffman/Desktop/EricsNewProcDCache/SourceCode/instr.hex",instr_mem);
end

endmodule
