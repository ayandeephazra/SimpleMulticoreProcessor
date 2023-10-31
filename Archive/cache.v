module cache(clk,rst_n,addr,wr_data,wdirty,we,re,cpu_search,BOCI, 
	rd_data,tag_out,hit,dirty,cpu_search_found,other_proc_data_line_wire);

input clk,rst_n;
input [10:0] addr;		// address to be read or written, 2-LSB's are dropped
input [63:0] wr_data;	// 64-bit cache line to write (4 words/line)
input wdirty;			// dirty bit to be written
input we;				// write enable for cache line
input re;				// read enable (for power purposes only)
input cpu_search;
input [10:0] BOCI;

output hit;
output dirty;
output [63:0] rd_data;	// 64-bit cache line read out
output [4:0] tag_out;	// 5-bit tag.  This is needed during evictions
output reg cpu_search_found;
output [63:0] other_proc_data_line_wire;

reg [70:0]mem[0:63];	// {valid,dirty,tag[7:0],wdata[63:0]}
reg [6:0] x;
reg [70:0] line;
reg [70:0] other_proc_data_line;
reg we_del;

wire we_filt;

//////////////////////////
// Glitch filter on we //
////////////////////////
always @(we)
  we_del <= we;

assign we_filt = we & we_del;

///////////////////////////////////////////////////////
// Model cache write, including reset of valid bits //
/////////////////////////////////////////////////////
always @(clk or we_filt or negedge rst_n)
  if (!rst_n)
    for (x=0; x<64;  x = x + 1)
	  mem[x] = {2'b00,{69{1'bx}}};		// only valid & dirty bit are cleared, all others are x
  else if (~clk && we_filt)
    mem[addr[5:0]] = {1'b1,wdirty,addr[10:6],wr_data};

////////////////////////////////////////////////////////////
// Model cache read including 4:1 muxing of 16-bit words //
//////////////////////////////////////////////////////////
always @(clk or re or addr) begin
	if (clk && re)				// read is on clock high
		line = mem[addr[5:0]];
    // if the valid bit in address is high, then there is a match
	if (clk && cpu_search && mem[BOCI[5:0]][70] == 1'b1) begin
		cpu_search_found = 1;
		other_proc_data_line = mem[BOCI[5:0]];
	end else
		cpu_search_found = 0;
end

	
/////////////////////////////////////////////////////////////
// If tag bits match and line is valid then we have a hit //
///////////////////////////////////////////////////////////
assign hit = ((line[68:64]==addr[10:6]) && (re | we)) ? line[70] : 1'b0;
assign dirty = line[70]&line[69];						// if line is valid and dirty bit set
assign rd_data = line[63:0];
assign other_proc_data_line_wire = other_proc_data_line[63:0];
assign tag_out = line[68:64];							// need the tag for evictions
	
endmodule