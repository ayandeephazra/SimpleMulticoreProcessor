module smp_test();

	
reg clk,rst_n;

wire [15:0] mm_rdata, mm_addr, mm_wdata;
wire mm_re, mm_we;
wire int_occurred;
wire [15:0] int_vec;

smp iSMP0(.clk(clk), .rst_n(rst_n));

initial begin
  clk = 0;
  rst_n = 0;
  @(negedge clk);
  rst_n = 1;
  repeat(30000) @(posedge clk);
  
  
  $stop();
end
  
always
  #5 clk = ~clk;
  
endmodule
