module bus(	clk, rst_n, read_miss_0, read_miss_1, write_miss_0, write_miss_1, 
	block_state_0, block_state_1, BICO_0, BICO_1, BOCI, cpu1_search_found, cpu0_search_found, 
	invalidate_0, invalidate_1, u_we_0, u_we_1, u_re_0, u_re_1, u_rdy, cpu_doing_curr_op, 
	grant_0, grant_1, cpu0_datasel, cpu1_datasel, cpu1_inv_from_cpu0, cpu0_inv_from_cpu1,
	cpu0_invalidate_dmem, cpu1_invalidate_dmem, cpu0_search, cpu1_search, we, re);
	
import common::*;				// import all encoding definitions

input clk, rst_n;
input read_miss_0; // input from cpu0 that tells the bus it has had a read miss
input read_miss_1; // input from cpu1 that tells the bus it has had a read miss
input write_miss_0; // input from cpu0 that tells the bus it has had a write miss
input write_miss_1; // input from cpu1 that tells the bus it has had a write miss
input [1:0] block_state_0;
input [1:0] block_state_1;
input logic [12:0] BICO_0; // FULL ADDRESS
input logic [12:0] BICO_1; // FULL ADDRESS
input logic cpu1_search_found; /*return signal that verifies if BOCI was in cpu0 or not*/
input logic cpu0_search_found; 
input invalidate_0; /* input from cpu that tells bus it has had an invalidate */
input invalidate_1;
input u_we_0;
input u_we_1;
input u_re_0;
input u_re_1;
input u_rdy;
output reg cpu_doing_curr_op; // SEP INTO 2 SIGNALS GRANT1 AND GRANT0
output reg grant_0;
output reg grant_1;
output reg [1:0] cpu0_datasel; /*if forwarding needed from other cpu, this is high*/
output reg [1:0] cpu1_datasel; 
output reg [12:0] BOCI; /*used in conjunction with below signals to verify existence of valid cache block*/
output reg cpu1_inv_from_cpu0; /* if a shared block is written to, then the other cpu must invalidate it's copy */
output reg cpu0_inv_from_cpu1;
/*output reg cpu0_wback_dmem; 
output reg cpu1_wback_dmem;*/
output reg cpu0_invalidate_dmem; /* signal the cpu to invalidate data to dmem*/
output reg cpu1_invalidate_dmem;
output reg cpu0_search; /*signal that notifies cpu0 to search its d-cache for a valid block ref'd by BOCI*/
output reg cpu1_search;
output reg we;
output reg re;


localparam SOURCE_DMEM = 2'b00;
localparam SOURCE_OTHER_PROC = 2'b01;
localparam BLOCK_STATE_MODIFIED = 2'b10;
localparam BLOCK_STATE_SHARED = 2'b01;
localparam BLOCK_STATE_INVALID = 2'b00;

/*typedef enum logic [2:0] {NOOP, READ_MISS_0, READ_MISS_1, WRITE_MISS_0, WRITE_MISS_1, INVALIDATE_0, INVALIDATE_1} bus_op_t;*/
bus_op_t state, nxt_state;

reg [1:0] count_to_4;
reg rst_ct4;

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

cpu_doing_curr_op = cpu_doing_curr_op;
grant_0 = 0;
grant_1 = 0;
nxt_state = NOOP;
BOCI = 13'bxxxxxxxxxxxxx;
cpu1_search = 0;
cpu0_search = 0;
cpu1_datasel = 2'b11;
cpu0_datasel = 2'b11;
cpu1_inv_from_cpu0 = 0;
cpu0_inv_from_cpu1 = 0;
cpu0_invalidate_dmem = 0;
cpu1_invalidate_dmem = 0;
we = 0;
re = 0;

case (state) 
	NOOP: begin
		if (u_we_0) begin
			grant_0 = 1;
			grant_1 = 0;
			we = 1;
		end else if (u_we_1) begin
			grant_0 = 0;
			grant_1 = 1;
			we = 1;
		end else if (u_re_0) begin
			grant_0 = 1;
			grant_1 = 0;
			re = 1;
		end else if (u_re_1) begin
			grant_0 = 0;
			grant_1 = 1;
			re = 1;
		end else if (read_miss_0 == 1) begin
			cpu_doing_curr_op = 1'b0;
			grant_0 = 1;
			grant_1 = 0;
			/* stall cpu 1 and check if tag match? */
			// We search in cpu because of lower latency in retrieving data, 
			// but if cpu1 does not have it, we retrieve it from main memory
			BOCI = BICO_0;
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
			BOCI = BICO_1;
			cpu0_search = 1;
			
			nxt_state = READ_MISS_1;
		end
		else if (write_miss_0 == 1) begin
			cpu_doing_curr_op = 1'b0;
			grant_0 = 0;
			grant_1 = 1;
			
			BOCI = BICO_0;
			cpu1_search = 1;
			nxt_state = WRITE_MISS_0;
		end
		else if (write_miss_1 == 1) begin
			cpu_doing_curr_op = 1'b1;
			grant_0 = 1;
			grant_1 = 0;
			
			BOCI = BICO_1;
			cpu0_search = 1;
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
		else begin
			nxt_state = NOOP;
		end
	end
	READ_MISS_0: begin		
		grant_0 = 1;
		grant_1 = 0;
		BOCI = BICO_0;
		if(cpu1_search_found)// make data available for 2 cycles at least
			cpu0_datasel = SOURCE_OTHER_PROC; // 1 is other processor, 0 is bus
		else begin
			//cpu0_datasel = SOURCE_DMEM;
			re = 1;
			grant_0 = 1;
			nxt_state = READ_MISS_0_WAIT;
		end
		/* route data from cpu1 to cpu0 */
	end
	READ_MISS_0_WAIT: begin
		if (!u_rdy)
			nxt_state = READ_MISS_0_WAIT;
		else
			cpu0_datasel = SOURCE_DMEM;
			
	end
	READ_MISS_1: begin
	    grant_0 = 0;
		grant_1 = 1;
		BOCI = BICO_1;
		if(cpu0_search_found)// make data available for 2 cycles at least
			cpu1_datasel = SOURCE_OTHER_PROC; // 1 is other processor, 0 is bus
		else 
			cpu1_datasel = SOURCE_DMEM;
		/* route data from cpu0 to cpu1 */
	end
	WRITE_MISS_0: begin
		grant_0 = 0;
		grant_1 = 1;
		if(cpu1_search_found) begin
			if(block_state_1==BLOCK_STATE_SHARED) begin
				/* invalidate on active copy on cpu1, write to block on cpu0 with addr, write back to dmem*/
				BOCI = BICO_0;
				cpu1_inv_from_cpu0 = 1;
				/* block written by default on cpu0? */ // invalidate, write back when evict from cache
				cpu0_invalidate_dmem = 1;
			end else if (block_state_1==BLOCK_STATE_MODIFIED) begin
				BOCI = BICO_0;
				cpu1_inv_from_cpu0 = 1;
			end else 
				/*error*/
				nxt_state = NOOP;
		end else
			nxt_state = NOOP;
	end
	WRITE_MISS_1: begin
		grant_0 = 1;
		grant_1 = 0;
		if (cpu0_search_found) begin
			if(block_state_0==BLOCK_STATE_SHARED) begin
				/* invalidate on active copy on cpu0, write to block on cpu1 with addr, write back to dmem*/
				BOCI = BICO_1;
				cpu0_inv_from_cpu1 = 1;
				/* block written by default on cpu1? */
				cpu1_invalidate_dmem = 1;
			end else if (block_state_0==BLOCK_STATE_MODIFIED) begin
				BOCI = BICO_0;
				cpu0_inv_from_cpu1 = 1;
			end else
				/*error*/
				nxt_state = NOOP;
		end else
			nxt_state = NOOP;
	end
	INVALIDATE_0:  begin
		grant_0 = 1;
		grant_1 = 0;
		BOCI = BICO_0;
		/* invalidate data in other cpu*/
		cpu1_inv_from_cpu0 = 1;
		/* invalidate on to dmem, not write back*/
		cpu0_invalidate_dmem = 1;
		nxt_state = NOOP;
	end
	/* INVALIDATE_1 */
	default: begin
		grant_0 = 0;
		grant_1 = 1;
		BOCI = BICO_1;
		/* invalidate data in other cpu */
		cpu0_inv_from_cpu1 = 1;
		/* invalidate on to dmem, not write back*/
		cpu1_invalidate_dmem = 1;
		nxt_state = NOOP;
	end
endcase
	

end



	
endmodule