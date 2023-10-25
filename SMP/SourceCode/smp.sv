module smp();

	wire clk, rst_n;
	wire read_miss_0, write_miss_0;
	wire read_miss_1, write_miss_1; 
	logic [1:0] block_state_0, block_state_1;
	wire invalidate_0, invalidate_1;
	wire cpu_curr_op;
	wire [1:0] cpu0_datasel, cpu1_datasel;
	wire [12:0] bus_addr_out;
	wire [10:0] cpu0_to_bus_addr, cpu1_to_bus_addr;
	wire cpu0_search, cpu1_search;
	wire cpu0_search_found, cpu1_search_found;
	wire grant_0, grant_1;
	wire cpu1_inv_from_cpu0, cpu0_inv_from_cpu1;
	wire cpu0_invalidate_dmem, cpu1_invalidate_dmem;
	wire [15:0] cpu0_1, cpu1_0; // data forwarding between cpus
	
	///////////////////////////////////
	/////     INSTANTIATE CPU0    ////
	/////////////////////////////////
	cpu iCPU0(.clk(clk), .rst_n(rst_n), .int_occurred(), .int_vec(), .mm_rdata(),			
		.mm_addr(), .mm_re(), .mm_we(), .stall_IM_ID(),	.mm_wdata(), 
			.invalidate_from_other_cpu(cpu0_inv_from_cpu1), .other_proc_data(cpu1_0), .read_miss(read_miss_0), 
				.write_miss(write_miss_0), /*op*/.invalidate(invalidate_0), .block_state(block_state_0),
					/*ip*/.BOCI(bus_addr_out), /*ip*/.grant(grant_0), /*ip*/.cpu_datasel(cpu0_datasel),
						/*ip*/.cpu_search(cpu0_search), /*op*/.cpu_search_found(cpu0_search_found),
							/*op*/.BICO(cpu0_to_bus_addr), .cpu_invalidate_dmem(cpu0_invalidate_dmem),
								.send_other_proc_data(cpu0_1),
								.u_addr(), .u_re(), .u_we(), .d_line(), .u_rd_data(), .u_rdy());
		
	///////////////////////////////////
	/////     INSTANTIATE CPU1    ////
	/////////////////////////////////
	cpu iCPU1(.clk(clk), .rst_n(rst_n), .int_occurred(), .int_vec(), .mm_rdata(),			
		.mm_addr(), .mm_re(), .mm_we(), .stall_IM_ID(),	.mm_wdata(), 
			.invalidate_from_other_cpu(cpu1_inv_from_cpu0), .other_proc_data(cpu0_1), .read_miss(read_miss_1), 
				.write_miss(write_miss_1), /*op*/.invalidate(invalidate_1), .block_state(block_state_1),
					/*ip*/.BOCI(bus_addr_out), /*ip*/.grant(grant_1), /*ip*/.cpu_datasel(cpu1_datasel),
						/*ip*/.cpu_search(cpu1_search), /*op*/.cpu_search_found(cpu1_search_found),
							/*op*/.BICO(cpu1_to_bus_addr), .cpu_invalidate_dmem(cpu1_invalidate_dmem),
								.send_other_proc_data(cpu1_0),
								.u_addr(), .u_re(), .u_we(), .d_line(), .u_rd_data(), .u_rdy());
			
	///////////////////////////////////
	/////     INSTANTIATE BUS     ////
	/////////////////////////////////
	bus iBUS0(.clk(clk), .rst_n(rst_n), .read_miss_0(read_miss_0), .read_miss_1(read_miss_1), 
		.write_miss_0(write_miss_0), .write_miss_1(write_miss_1), .block_state_0(block_state_0), 
			.block_state_1(block_state_1), .BICO_0(cpu0_to_bus_addr), .BICO_1(cpu1_to_bus_addr),
				.cpu1_search_found(cpu1_search_found), 
					.cpu0_search_found(cpu0_search_found), .invalidate_0(invalidate_0), 
						.invalidate_1(invalidate_1), .cpu_doing_curr_op(cpu_curr_op), .grant_0(grant_0), 
							.grant_1(grant_1), .cpu0_datasel(cpu0_datasel), .cpu1_datasel(cpu1_datasel), 
								.BOCI(bus_addr_out), .cpu1_inv_from_cpu0(cpu1_inv_from_cpu0),
									.cpu0_inv_from_cpu1(cpu0_inv_from_cpu1), .cpu0_invalidate_dmem(cpu0_invalidate_dmem), 
										.cpu1_invalidate_dmem(cpu1_invalidate_dmem), 
											.cpu0_search(cpu0_search), .cpu1_search(cpu1_search));
		
	d_mem iDMEM0(.clk(clk), .rst_n(rst_n), .addr(), .re(), .we(), .wdata(), .rd_data(), .rdy());
endmodule