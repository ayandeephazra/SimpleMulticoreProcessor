module bus(clk, rst_n, read_miss_0, read_miss_1,
	write_miss_0, write_miss_1, block_state_0, block_state_1, addr_in, addr_out,
	cpu1_search_found, cpu0_search_found, invalidate_0, invalidate_1, cpu_doing_curr_op, 
	grant_0, grant_1, cpu0_datasel, cpu1_datasel, cpu0_invalidate_tag, cpu1_invalidate_tag,
	cpu0_wback_dmem, cpu1_wback_dmem, cpu0_search, cpu1_search);
	
import common::*;				// import all encoding definitions

input clk, rst_n;
input read_miss_0; // input from cpu0 that tells the bus it has had a read miss
input read_miss_1; // input from cpu1 that tells the bus it has had a read miss
input write_miss_0; // input from cpu0 that tells the bus it has had a write miss
input write_miss_1; // input from cpu1 that tells the bus it has had a write miss
input [1:0] block_state_0;
input [1:0] block_state_1;
input [10:0] addr_in; // FULL ADDRESS
input [10:0] addr_out; /*used in conjunction with below signals to verify existence of valid cache block*/
input cpu1_search_found; /*return signal that verifies if addr_out was in cpu0 or not*/
input cpu0_search_found; 
input invalidate_0;
input invalidate_1;
output reg cpu_doing_curr_op; // SEP INTO 2 SIGNALS GRANT1 AND GRANT0
output reg grant_0;
output reg grant_1;
output reg cpu0_datasel; /*if forwarding needed from other cpu, this is high*/
output reg cpu1_datasel; 
output reg cpu1_invalidate_tag; /* if a shared block is written to, then the other cpu must invalidate it's copy */
output reg cpu0_invalidate_tag;
output reg cpu0_wback_dmem; /*on write miss, we signal the cpu issuing the miss to write new data to dmem*/
output reg cpu1_wback_dmem;
output reg cpu0_search; /*signal that notifies cpu0 to search its d-cache for a valid block ref'd by addr_out*/
output reg cpu1_search; 


localparam SOURCE_DMEM = 1'b0;
localparam SOURCE_OTHER_PROC = 1'b1;
localparam BLOCK_STATE_MODIFIED = 2'b00;
localparam BLOCK_STATE_SHARED = 2'b01;
localparam BLOCK_STATE_INVALID = 2'b10;

/*typedef enum logic [1:0] {NOOP, READ_MISS_0, READ_MISS_1, WRITE_MISS_0, WRITE_MISS_1, INVALIDATE} bus_op_t;*/
bus_op_t state, nxt_state;

reg [1:0] count_to_4;
always @ (posedge clk or negedge rst_n)
	if (!rst_n)
		count_to_4 <= 4'h0;
	else if (rst_ct4)
		count_to_4 <= 4'h0;
	else	
		count_to_4 <= count_to_4 + 1;

////////////////////////////////
// infer state machine flops //
//////////////////////////////
always @(posedge clk, negedge rst_n)
  if (!rst_n)
    state <= NOOP;
  else
    state <= nxt_state;

////////////////////////////////
// state machine case logic  //
//////////////////////////////
always @ (*) begin

cu_doing_curr_op = cpu_doing_curr_op;
grant_0 = 0;
grant_1 = 0;
nxt_state = NOOP;
addr_out = 11'bxxxxxxxxxxx;
cpu1_search = 0;
cpu0_search = 0;
cpu1_datasel = SOURCE_BUS;
cpu0_datasel = SOURCE_BUS;
cpu0_invalidate_tag = 0;
cpu1_invalidate_tag = 0;
cpu0_wback_dmem = 0;
cpu1_wback_dmem = 0;

case (state) 
	NOOP: begin
		if (read_miss_0 == 1) begin
			cpu_doing_curr_op = 1'b0;
			grant_0 = 1;
			grant_1 = 0;
			/* stall cpu 1 and check if tag match? */
			// We search in cpu because of lower latency in retrieving data, 
			// but if cpu1 does not have it, we retrieve it from main memory
			addr_out = addr_in;
			cpu1_search = 1;
			
			nxt_state = READ_MISS_0;
		end
		else if (read_miss_1 == 1) begin
			cpu_doing_curr_op = 1'b1;
			grant_0 = 0;
			grant_1 = 1;
			/* stall cpu 0 and check if tag match? */
			// We search in cpu because of lower latency in retrieving data, 
			// but if cpu1 does not have it, we retrieve it from main memory
			addr_out = addr_in;
			cpu0_search = 1;
			
			nxt_state = READ_MISS_1;
		end
		else if (write_miss_0 == 1) begin
			cpu_doing_curr_op = 1'b0;
			grant_0 = 1;
			grant_1 = 0;
			nxt_state = WRITE_MISS_0;
		end
		else if (write_miss_1 == 1) begin
			cpu_doing_curr_op = 1'b1;
			grant_0 = 0;
			grant_1 = 1;
			nxt_state = WRITE_MISS_1;
		end
		else if (invalidate_0 == 1) begin
			grant_0 = 1;
			grant_1 = 0;
			nxt_state = INVALIDATE_0;
		end
		else if (invalidate_1 == 1) begin
			grant_0 = 0;
			grant_1 = 1;
			nxt_state = INVALIDATE_1;
		end
		else
			nxt_state = NOOP;
		end
	end
	READ_MISS_0: begin		
		grant_0 = 1;
		grant_1 = 0;
		if(cpu1_search_found)// make data available for 2 cycles at least
			cpu0_datasel = SOURCE_OTHER_PROC; // 1 is other processor, 0 is bus
		else 
			cpu0_datasel = SOURCE_DMEM;
		/* route data from cpu1 to cpu0 */
	end
	READ_MISS_1: begin
		if(cpu0_search_found)// make data available for 2 cycles at least
			cpu1_datasel = SOURCE_OTHER_PROC; // 1 is other processor, 0 is bus
		else 
			cpu1_datasel = SOURCE_DMEM;
		/* route data from cpu0 to cpu1 */
	end
	WRITE_MISS_0: begin
		grant_0 = 1;
		grant_1 = 0;
		if(block_state_0==BLOCK_STATE_INVALID) begin
			/* invalidate on active copy on cpu1, write to block on cpu0 with addr, write back to dmem*/
			addr_out = addr_in;
			cpu1_invalidate_tag = 1;
			/* block written by default on cpu0? */
			cpu0_wback_dmem = 1;
		end else
			/*error*/
			nxt_state = NOOP;
	end
	WRITE_MISS_1: begin
		grant_0 = 0;
		grant_1 = 1;
		if(block_state_1==BLOCK_STATE_INVALID) begin
			/* invalidate on active copy on cpu0, write to block on cpu1 with addr, write back to dmem*/
			addr_out = addr_in;
			cpu0_invalidate_tag = 1;
			/* block written by default on cpu1? */
			cpu1_wback_dmem = 1;
		end else
			/*error*/
			nxt_state = NOOP;
	end
	INVALIDATE_0:  begin
		grant_0 = 1;
		grant_1 = 0;
		addr_out = addr_in;
		cpu1_invalidate_tag = 1;
		cpu0_wback_dmem = 1;
	end
	/* INVALIDATE_1 */
	default: begin
		grant_0 = 0;
		grant_1 = 1;
		addr_out = addr_in;
		cpu0_invalidate_tag = 1;
		cpu1_wback_dmem = 1;
	end
endcase
	

end



	
endmodule