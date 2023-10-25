module dmem_hierarchy(clk,rst_n,addr,re,we,wrt_data,cpu_search,rd_data,d_rdy,cpu_search_found,
	u_addr,u_re,u_we,d_line,u_rd_data,u_rdy);

input clk,rst_n;
input [12:0] addr;			// address for data memory
input re,we;				// read enable and write enable for data memory
input [15:0] wrt_data;		// write data
input cpu_search;

output d_rdy;
output [15:0] rd_data;
output cpu_search_found;
output [10:0] u_addr;		// address to unified memory
output reg u_re; 				// read enable and write enable to unified memory
output reg u_we;
output [63:0] d_line;		// line read from Dcache
output [63:0] u_rd_data;	// data read from unified memory
output u_rdy;				// indicates unified memory read/write operation finished

//wire [63:0] u_rd_data;		// data read from unified memory
//wire [63:0] d_line;			// line read from Dcache
wire [63:0] wrt_line;		// line to write to Dcache when it is a replacement from itself
wire [4:0] dtag;			// tag bits from data cache read.  Need this for address formation on evict

//wire u_rdy;				    // indicates unified memory read/write operation finished
wire d_hit;					// hit signal from Dcache
wire dirty_bit;				// dirty bit from Dcache
//wire [10:0] u_addr;			// address to unified memory
wire [63:0] Dwrt_line;		// 64-bit data to write to Dcache	

//////////////////////////////////////////////
// registers needed for control logic next //
////////////////////////////////////////////
//reg u_we,u_re;				// read enable and write enable to unified memory
reg d_we,d_re;				// read enable and write enable to Dcache
reg set_dirty;				// When writing to Dcache from CPU set the dirty bit
reg d_rdy;					// data cache read/write is ready.
reg evicting;
reg dfill;					// asserted when purely filling a Dcache line from unified on a read

typedef enum reg[2:0] {IDLE,R_EVICT,R_DATA_RD,W_EVICT,W_DATA_RD} state_t;
state_t state,nxt_state;


////////////////////////////////
// infer state machine flops //
//////////////////////////////
always @(posedge clk, negedge rst_n)
  if (!rst_n)
    state <= IDLE;
  else
    state <= nxt_state;
	
/////////////////////////
// Control logic next //
///////////////////////
always @(*) begin
  /////////////////////////////////////////////////////
  // default to most common case for all SM outputs //
  ///////////////////////////////////////////////////
  d_re = re;
  d_we = 0;
  set_dirty = 0;
  u_re = 0;
  u_we = 0;
  nxt_state = IDLE;
  evicting = 0;
  d_rdy = 1;			// data from Dcache is ready
  dfill = 0;
  case (state)
      IDLE : if (re) begin				// if Dcache read
	           if (!d_hit) begin		// if it is a miss
			     d_rdy = 0;					// data cache is not ready
	             ////////////////////////////////////////////////////////
			     // Either a fill or a replace depending on dirty bit //
			     //////////////////////////////////////////////////////
			     if (dirty_bit) begin
			       //////////////////////////////////////////////////
			       // Need to write out dirty line before filling //
			       ////////////////////////////////////////////////
				   evicting = 1;
			       nxt_state = R_EVICT;
			       u_we = 1;
			     end else begin
			       ///////////////////////////////////////////////
			       // Simpler case of simply a cache line fill //
			       /////////////////////////////////////////////
			       nxt_state = R_DATA_RD;
			       u_re = 1;				// start read of unified memory
			     end
			   end else						// Dcache hit and Icache hit do nothing
			     nxt_state = IDLE;			// it is a hit and we stay in idle
		     end else if (we) begin
			   ///////////////////////////////////////////////////////////////////
			   // Dcache write.  We have to read first to see if we have a hit //
			   /////////////////////////////////////////////////////////////////
			   d_re = 1;					// have to read prior to write to check and have fill data
			   if (d_hit) begin
			     ///////////////////////////////////////
				 // We have the right line in Dcache //
				 /////////////////////////////////////
				 d_rdy = 1;
				 d_we = 1;
				 set_dirty = 1;
			     nxt_state = IDLE;			// it is a hit and we stay in idle
			   end else begin
			     /////////////////////////////////////////////////////
				 // We need to either fill a line, or evict a line //
				 ///////////////////////////////////////////////////
				 d_rdy = 0;
				 if (dirty_bit) begin
				   ////////////////////////////////////////////////////////////////////////////
				   // Need to evict this line then read in a new one and write the new data //
				   //////////////////////////////////////////////////////////////////////////
				   evicting = 1;
				   nxt_state = W_EVICT;
				   u_we = 1;				// start the write to unified
				 end else begin
				   //////////////////////////////////////////////////////////////////
				   // Need to read a new line from unified and write the new data //
				   ////////////////////////////////////////////////////////////////
				   nxt_state = W_DATA_RD;
				 end
			   end
	         end else						// Dcache idle, do nothing
			   nxt_state = IDLE;
   R_EVICT : begin
	           evicting = 1;
			   d_re = 1;
			   u_we = 1;
			   d_rdy = 0;				// not ready while evicting
			   if (u_rdy) 
			     nxt_state = R_DATA_RD;
			   else
			     nxt_state = R_EVICT;
			end
  R_DATA_RD : begin
			    u_re = 1;
			    d_we = u_rdy;
			    d_re = 0;
			    dfill = 1;
			    d_rdy = 0;
			    if (u_rdy)
                  nxt_state = IDLE;				
	            else
			      nxt_state = R_DATA_RD;
              end	
    W_EVICT : begin
		        evicting = 1;
			    u_we = 1;
	            d_rdy = 0;
			    d_re = 1;				// continue reading Dcache line being EVICTED
			    if (u_rdy)
	              nxt_state = W_DATA_RD;
			    else
				  nxt_state = W_EVICT;
              end
    default : begin		// this is W_DATA_RD
				 u_re = 1;
				 d_we = u_rdy;
				 d_re = 0;
				 set_dirty = 1;
				 d_rdy = 0;
				 if (u_rdy)
                   nxt_state = IDLE;				
	             else
			       nxt_state = W_DATA_RD;
               end
  endcase
	
end

assign wrt_line = ((addr[1:0]==2'b00)&& d_hit) ? {d_line[63:16],wrt_data} :
                  ((addr[1:0]==2'b01)&& d_hit) ? {d_line[63:32],wrt_data,d_line[15:0]} :
                  ((addr[1:0]==2'b10)&& d_hit) ? {d_line[63:48],wrt_data,d_line[31:0]} :
				  ((addr[1:0]==2'b11)&& d_hit) ? {wrt_data,d_line[47:0]} :
				  (addr[1:0]==2'b00) ? {u_rd_data[63:16],wrt_data} :
				  (addr[1:0]==2'b01) ? {u_rd_data[63:32],wrt_data,u_rd_data[15:0]} :
				  (addr[1:0]==2'b10) ? {u_rd_data[63:48],wrt_data,u_rd_data[31:0]} :
				  {wrt_data,u_rd_data[47:0]};

assign Dwrt_line = (dfill) ? u_rd_data : wrt_line;
				  
//////////////////////////////////////////////////////////////////////
// Address to unified memory...is from Icache or Dcahce operation? //
// If Dcache are we evicting and have to use dtag for address?    //
///////////////////////////////////////////////////////////////////
assign u_addr = (evicting) ? {dtag,addr[7:2]} :
				addr[12:2];					// address is forcibly aligned to 64-bit boundary
				  
			 
/////////////////////////
// Instantiate Dcache //
///////////////////////
cache Dcache(.clk(clk), .rst_n(rst_n), .addr(addr[12:2]), .wr_data(Dwrt_line), .wdirty(set_dirty),
             .we(d_we), .re(d_re), .cpu_search(cpu_search), .rd_data(d_line), .tag_out(dtag), .hit(d_hit), .dirty(dirty_bit), 
			 .cpu_search_found(cpu_search_found));
			 
assign rd_data = (addr[1:0]==2'b00) ? d_line[15:0] :
                 (addr[1:0]==2'b01) ? d_line[31:16] :
			     (addr[1:0]==2'b10) ? d_line[47:32] :
			     d_line[63:48];
			   
/////////////////////////////////
// Instantiate unified memory //
///////////////////////////////
/*d_mem iDMEM(.clk(clk), .rst_n(rst_n), .addr(u_addr), .re(u_re), .we(u_we), .wdata(d_line),
                     .rd_data(u_rd_data), .rdy(u_rdy));
*/					 
endmodule