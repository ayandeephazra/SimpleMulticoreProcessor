module bus(clk, rst_n, read_miss_0, read_miss_1,
	write_miss_0, write_miss_1, write_miss_state_0, write_miss_state_1, 
    cpu_doing_curr_op, cpu0_datasel, cpu1_datasel, tag_out, cpu0_search, cpu1_search,
	cpu1_search_found, cpu0_search_found);
	
import common::*;				// import all encoding definitions

input clk, rst_n;
input read_miss_0;
input read_miss_1;
input write_miss_0;
input write_miss_1;
input [1:0] write_miss_state_0;
input [1:0] write_miss_state_1;
input [4:0] tag_in; // FULL ADDRESS
output reg cpu_doing_curr_op; // SEP INTO 2 SIGNALS GRANT1 AND GRANT0
output reg cpu0_datasel; /*if forwarding needed from other cpu, this is high*/
output reg cpu1_datasel; /*if forwarding needed from other cpu, this is high*/
input [4:0] tag_out; /*used in conjunction with below signals to verify existence of valid cache block*/
output reg cpu0_search; /*signal that notifies cpu0 to search its d-cache for a valid block ref'd by tag_out*/
output reg cpu1_search; /*signal that notifies cpu1 to search its d-cache for a valid block ref'd by tag_out*/
input cpu1_search_found; /*return signal that verifies if tag_out was in cpu0 or not*/
input cpu0_search_found; /*return signal that verifies if tag_out was in cpu0 or not*/

localparam SOURCE_BUS = 1'b0;
localparam SOURCE_OTHER_PROC = 1'b1;
localparam WRITE_MISS_STATE_INV = 2'b01;
localparam WRITE_MISS_STATE_SHARED = 2'b10;

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
nxt_state = NOOP;
tag_out = 5'bxxxxx;
cpu1_search = 0;
cpu0_search = 0;
cpu1_datasel = SOURCE_BUS;
cpu0_datasel = SOURCE_BUS;

case (state) 
	NOOP: begin
		if (read_miss_0 == 1) begin
			cpu_doing_curr_op = 1'b0;
			/* stall cpu 1 and check if tag match? */
			tag_out = tag_in;
			cpu1_search = 1;
			
			nxt_state = READ_MISS_0;
		end
		else if (read_miss_1 == 1) begin
			cpu_doing_curr_op = 1'b1;
			/* stall cpu 0 and check if tag match? */
			tag_out = tag_in;
			cpu0_search = 1;
			
			nxt_state = READ_MISS_1;
		end
		else if (write_miss_0 == 1) begin
			cpu_doing_curr_op = 1'b0;
			nxt_state = WRITE_MISS_0;
		end
		else if (write_miss_1 == 1) begin
			cpu_doing_curr_op = 1'b1;
			nxt_state = WRITE_MISS_1;
		end
		else
			nxt_state = NOOP;
		end
	end
	READ_MISS_0: begin		
		if(!cpu1_search_found)// make data available for 2 cycles at least
			cpu0_datasel = SOURCE_OTHER_PROC; // 1 is other processor, 0 is bus
		/* route data from cpu1 to cpu0 */
	end
	READ_MISS_1: begin
		if(!cpu0_search_found)// make data available for 2 cycles at least
			cpu1_datasel = SOURCE_OTHER_PROC; // 1 is other processor, 0 is bus
		/* route data from cpu0 to cpu1 */
	end
	WRITE_MISS_0: begin
		if(
	end
	WRITE_MISS_1: begin
		
	end
	default: begin
	
	end
endcase
	

end



	
endmodule