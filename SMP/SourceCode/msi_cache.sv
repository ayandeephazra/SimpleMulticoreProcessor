module msi_cache
  import common::*;				// import all encoding definitions
  (input clk,rst_n,
   input [10:0] addr,			// address to be read or written, 2-LSB's are dropped
   input [63:0] wr_data,		// 64-bit cache line to write (4 words/line)
   input blk_state_t wstate,	// state to write {INVALID,SHARED,MODIFIED,EXCLUSIVE}
   input we,					// write enable for cache line
   input re,					// read enable (for power purposes only)
   input cpu_search,
   input [10:0] BOCI,
   input invalidate_from_other_cpu,

   output dirty,
   output hit,
   output blk_state_t rstate,	// state of block just read
   output [63:0] rd_data,		// 64-bit cache line read out
   output [4:0] tag_out,			// 5-bit tag.  This is needed during evictions
   output reg cpu_search_found,
   output [63:0] other_proc_data_line_wire,
   output reg [1:0] block_state
  );

  /*
       typedef enum logic [1:0] {INVALID, SHARED, MODIFIED} blk_state_t;
  */

reg [70:0]mem[0:63];	// {blk_state,tag[4:0],wdata[63:0]}
reg [6:0] x;
reg [70:0] line;
reg we_del;
reg [70:0] other_proc_data_line;

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
	  mem[x] = {INVALID,{69{1'bx}}};		// only state is cleared to invalid, all others are x
  else if (~clk && we_filt)
    mem[addr[5:0]] = {wstate,addr[10:6],wr_data};
  else if (~clk && invalidate_from_other_cpu)
    mem[BOCI[5:0]] = {2'b00,BOCI[10:6],wr_data};

////////////////////////////////////////////////////////////
// Model cache read including 4:1 muxing of 16-bit words //
//////////////////////////////////////////////////////////
always @(clk or re or addr)
  if (clk && re) begin				// read is on clock high
    line = mem[addr[5:0]];
  // if the valid bit in address is high, then there is a match
  end else if (clk && cpu_search && (^mem[BOCI[5:0]][70:69] == 1'b1)) begin
		cpu_search_found = 1;
		other_proc_data_line = mem[BOCI[5:0]];
        block_state = blk_state_t'(mem[BOCI[5:0]][70:69]);
  end else
		cpu_search_found = 0;
	
/////////////////////////////////////////////////////////////
// If tag bits match and line is valid then we have a hit //
///////////////////////////////////////////////////////////
assign dirty = (blk_state_t'(line[70:69])==MODIFIED);
assign hit = ((line[68:64]==addr[10:6]) && (re | we) && (blk_state_t'(line[70:69])!=INVALID)) ? 1'b1 : 1'b0;
assign rstate = blk_state_t'(line[70:69]);
assign rd_data = line[63:0];
assign tag_out = line[68:64];							// need the tag for evictions
assign other_proc_data_line_wire = other_proc_data_line[63:0];

endmodule