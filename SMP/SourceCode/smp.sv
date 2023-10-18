module smp()

	wire clk, rst_n;
	wire read_miss_0, write_miss_0, block_state_0;
	wire read_miss_1, write_miss_1, block_state_1;
	wire cpu_curr_op;
	wire cpu0_datasel, cpu1_datasel;
	wire [10:0] bus_addr_out;
	wire cpu0_search, cpu1_search;
	wire cpu0_search_found, cpu1_search_found;
	wire grant_0, grant_1;
	
	cpu cpu0(.clk(clk), .rst_n(rst_n), .int_occurred(), .int_vec(), .mm_rdata(),			
		.mm_addr(), .mm_re(), .mm_we(), .stall_IM_ID(),	.mm_wdata(), .read_miss(read_miss_0), 
			.write_miss(write_miss_0), .block_state(block_state_0),
				/*ip*/.addr_in(bus_addr_out), /*ip*/.cpu_datasel(cpu0_datasel),
				/*ip*/.cpu_search(cpu0_search), /*op*/.cpu_search_found(cpu0_search_found));
	
	cpu cpu1(.clk(clk), .rst_n(rst_n), .int_occurred(), .int_vec(), .mm_rdata(),			
		.mm_addr(), .mm_re(), .mm_we(), .stall_IM_ID(),	.mm_wdata(), .read_miss(read_miss_1), 
			.write_miss(write_miss_1), .block_state(block_state_1),
				/*ip*/.addr_in(bus_addr_out), /*ip*/.cpu_datasel(cpu1_datasel),
				/*ip*/.cpu_search(cpu1_search), /*op*/.cpu_search_found(cpu1_search_found));
			
	bus bus0(.clk(clk), .rst_n(rst_n), .read_miss_0(read_miss_0), .read_miss_1(read_miss_1), 
		.write_miss_0(write_miss_0), .write_miss_1(write_miss_1), .block_state_0(block_state_0), 
			.block_state_1(block_state_1), .addr_in(addr_in), .cpu1_search_found(cpu1_search_found), 
				.cpu0_search_found(cpu1_search_found), .invalidate_0(), .invalidate_1(),
					.cpu_doing_curr_op(cpu_curr_op), 
					.grant_0(grant_0), .grant_1(grant_1), .cpu0_datasel(cpu0_datasel), 
						.cpu1_datasel(cpu1_datasel), .addr_out(bus_addr_out), .cpu0_invalidate_tag(),
							.cpu1_invalidate_tag(), .cpu0_wback_dmem(), .cpu1_wback_dmem(),
								.cpu0_search(cpu0_search), .cpu1_search(cpu1_search));
endmodule