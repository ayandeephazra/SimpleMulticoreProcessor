module icarusTest(clk,rst_n,en,count);

  input clk;
  input rst_n;
  input en;
  
  output logic [7:0] count;
  
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  count <= 8'h00;
	else if (en)
	  count <= count + 1;
	  
endmodule
  