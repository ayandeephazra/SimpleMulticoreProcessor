module rf_mem_blk(clk,raddr,waddr,rdata,wdata,we);

  input clk;
  input [3:0] raddr;
  input [3:0] waddr;
  input [15:0] wdata;
  input we;
  output reg [15:0] rdata;
  
  reg [15:0]mem[0:15];
  
  always @(negedge clk) begin
    if (we)
	  mem[waddr] <= wdata;
	rdata <= mem[raddr];
  end
  
endmodule
  