module UART_Q(clk,we,waddr,wdata,raddr,rdata);

  input clk;
  input we;
  input [6:0] waddr;
  input [7:0] wdata;
  input [6:0] raddr;
  output reg [7:0] rdata;
  
  reg [7:0]mem[0:127];
  
  always @(posedge clk) begin
    if (we)
	  mem[waddr] <= wdata;
  end
  
  assign rdata = mem[raddr];

endmodule