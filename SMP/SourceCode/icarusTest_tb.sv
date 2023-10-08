module icarusTest_tb();

  logic clk;
  logic rst_n;
  logic en;
  
  wire [7:0] count;
  
  icarusTest iDUT(.clk(clk),.rst_n(rst_n),.en(en),.count(count));
  
  initial begin
    $dumpfile("dump.vcd");
	$dumpvars(0,icarusTest_tb);
    clk = 0;
	rst_n = 0;
	en = 0;
	@(negedge clk);
	rst_n = 1;
	@(negedge clk)
	en = 1;
	repeat(20) @(negedge clk);
	$finish();
  end
  
  always
    #5 clk = ~clk;
  
endmodule