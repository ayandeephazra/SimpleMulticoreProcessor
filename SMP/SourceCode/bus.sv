module bus(clk, rst_n, read_miss_0, read_miss_1,
	write_miss_0, write_miss_1, write_miss_state_0, write_miss_state_1, 
	op, cpu_doing_curr_op);
	
import common::*;				// import all encoding definitions

input clk, rst_n;
input read_miss_0;
input read_miss_1;
input write_miss_0;
input write_miss_1;
input [1:0] write_miss_state_0;
input [1:0] write_miss_state_1;
output bus_op_t [1:0] op;
output reg cpu_doing_curr_op;

always_ff @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		op <= NOOP;
		cpu_doing_curr_op <= 1'b0;
	end
	else if (read_miss_0 == 1) begin
		op <= READ_MISS;
		cpu_doing_curr_op <= 1'b0;
	end
	else if (read_miss_1 == 1) begin
		op <= READ_MISS;
		cpu_doing_curr_op <= 1'b1;
	end
	else if (write_miss_0 == 1) begin
		op <= WRITE_MISS;
		cpu_doing_curr_op <= 1'b0;
	end
	else if (write_miss_1 == 1) begin
		op <= WRITE_MISS;
		cpu_doing_curr_op <= 1'b1;
	end
end



	
endmodule