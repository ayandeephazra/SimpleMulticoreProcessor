module smp()

	wire clk, rst_n;
	wire read_miss_0, write_miss_0, write_miss_state_0;
	wire read_miss_1, write_miss_1, write_miss_state_1;
	wire cpu_curr_op;
	wire cpu0_datasel, cpu1_datasel;
	wire bus_tag_out;
	wire cpu0_search, cpu1_search;
	wire cpu0_search_found, cpu1_search_found;
	
	cpu cpu0(.clk(clk), .rst_n(rst_n), .int_occurred(), .int_vec(), .mm_rdata(),			
		.mm_addr(), .mm_re(), .mm_we(), .stall_IM_ID(),	.mm_wdata(), .read_miss(read_miss_0), 
			.write_miss(write_miss_0), .write_miss_state(write_miss_state_0),
				/*ip*/.tag_in(bus_tag_out), /*ip*/.cpu_datasel(cpu0_datasel),
				/*ip*/.cpu_search(cpu0_search), /*op*/.cpu_search_found(cpu0_search_found));
	
	cpu cpu1(.clk(clk), .rst_n(rst_n), .int_occurred(), .int_vec(), .mm_rdata(),			
		.mm_addr(), .mm_re(), .mm_we(), .stall_IM_ID(),	.mm_wdata(), .read_miss(read_miss_1), 
			.write_miss(write_miss_1), .write_miss_state(write_miss_state_1),
				/*ip*/.tag_in(bus_tag_out), /*ip*/.cpu_datasel(cpu1_datasel),
				/*ip*/.cpu_search(cpu1_search), /*op*/.cpu_search_found(cpu1_search_found));
			
	bus bus0(.clk(clk), .rst_n(rst_n), .read_miss_0(read_miss_0), .read_miss_1(read_miss_1), 
		.write_miss_0(write_miss_0), .write_miss_1(write_miss_1), .write_miss_state_0(write_miss_state_0), 
			.write_miss_state_1(write_miss_state_1), .cpu_doing_curr_op(cpu_curr_op), .cpu0_datasel(cpu0_datasel), 
				.cpu1_datasel(cpu1_datasel), .tag_out(bus_tag_out), .cpu0_search(cpu0_search), .cpu1_search(cpu1_search), 
					.cpu1_search_found(cpu1_search_found), .cpu0_search_found(cpu1_search_found));
endmodule