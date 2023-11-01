module rf(clk,p0_addr,p1_addr,p0,p1,re0,re1,dst_addr,dst,we);
//////////////////////////////////////////////////////////////////
// Triple ported register file.  Two read ports (p0 & p1), and //
// one write port (dst).  Negative edge triggered  /////////////
////////////////////////////////////////////////////

input clk;
input [3:0] p0_addr, p1_addr;			// two read port addresses
input re0,re1;							// read enables (power not functionality)
input [3:0] dst_addr;					// write address
input [15:0] dst;						// dst bus
input we;								// write enable

output [15:0] p0,p1;  				//output read ports

wire [15:0] p0_data,p1_data;

///////////////////////////////////////
// Internal registers for bypassing //
/////////////////////////////////////
reg [3:0] last_addr;
reg [15:0] last_data;
reg write_last_cycle;
  
rf_mem_blk iBNK0(.clk(clk),.raddr(p0_addr),.waddr(dst_addr),.rdata(p0_data),.wdata(dst),.we(we));
rf_mem_blk iBNK1(.clk(clk),.raddr(p1_addr),.waddr(dst_addr),.rdata(p1_data),.wdata(dst),.we(we));

//////////////////////////
// Implement bypassing //
////////////////////////

always @(negedge clk) begin
  write_last_cycle <= we;
  last_addr <= dst_addr;
  last_data <= dst;
end

assign p0 = (write_last_cycle && re0 && (p0_addr==last_addr)) ? last_data : p0_data;
		
assign p1 = (write_last_cycle && re1 && (p1_addr==last_addr)) ? last_data : p1_data;
	
endmodule
  

