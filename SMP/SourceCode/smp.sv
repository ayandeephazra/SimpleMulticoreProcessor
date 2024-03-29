module smp(
	input clk, rst_n
	);

	//wire clk, rst_n;
	
	wire [15:0] mm_rdata_0, mm_addr_0, mm_wdata_0;
	wire mm_re_0, mm_we_0;
	wire int_occurred_0;
	wire [15:0] int_vec_0;

	wire [15:0] mm_rdata_1, mm_addr_1, mm_wdata_1;
	wire mm_re_1, mm_we_1;
	wire int_occurred_1;
	wire [15:0] int_vec_1;

	wire read_miss_0, write_miss_0;
	wire read_miss_1, write_miss_1; 
	logic [1:0] block_state_0, block_state_1;
	wire invalidate_0, invalidate_1;
	wire cpu_curr_op;
	wire [1:0] cpu0_datasel, cpu1_datasel;
	wire [12:0] bus_addr_out;
	wire [12:0] cpu0_to_bus_addr, cpu1_to_bus_addr;
	wire cpu0_search, cpu1_search;
	wire cpu0_search_found, cpu1_search_found;
	wire grant_0, grant_1;
	wire cpu1_inv_from_cpu0, cpu0_inv_from_cpu1;
	wire cpu0_invalidate_dmem, cpu1_invalidate_dmem;
	wire [63:0] cpu0_1, cpu1_0; // data forwarding between cpus
	

	///////////////////////////////////
	/////  CPU0 - DMEM INTERFACE  ////
	/////////////////////////////////
	wire [10:0] cpu0_u_addr;
	wire cpu0_u_re;
	wire cpu0_u_we;
	wire [63:0] cpu0_d_line;
	
	///////////////////////////////////
	/////  CPU1 - DMEM INTERFACE  ////
	/////////////////////////////////
	wire [10:0] cpu1_u_addr;
	wire cpu1_u_re;
	wire cpu1_u_we;
	wire [63:0] cpu1_d_line;
	
	// common dmem interface
	wire dmem_rdy;
	wire [63:0] u_rd_data;
	wire we, re;
	wire [10:0] mem_addr;
	wire [63:0] mem_wdata_line;
	reg [63:0] mem_rdata_reg;
	
	reg cpu0_dmem_permission, cpu1_dmem_permission;
	
	///////////////////////////////////
	/////     INSTANTIATE CPU0    ////
	/////////////////////////////////
	cpu #("test_readmiss0.hex") iCPU0(.clk(clk), .rst_n(rst_n), .int_occurred(int_occurred_0), .int_vec(int_vec_0), .mm_rdata(mm_rdata_0),			
		.mm_addr(mm_addr_0), .mm_re(mm_re_0), .mm_we(mm_we_0), .stall_IM_ID(stall_IM_ID_0), .mm_wdata(mm_wdata_0), 
			.invalidate_from_other_cpu(cpu0_inv_from_cpu1), .other_proc_data(cpu1_0), .read_miss(read_miss_0), 
				.write_miss(write_miss_0), /*op*/.invalidate(invalidate_0), .block_state(block_state_0),
					/*ip*/.BOCI(bus_addr_out), /*ip*/.grant(grant_0), /*ip*/.cpu_datasel(cpu0_datasel),
						/*ip*/.cpu_search(cpu0_search), /*op*/.cpu_search_found(cpu0_search_found),
							/*op*/.BICO(cpu0_to_bus_addr), .cpu_invalidate_dmem(cpu0_invalidate_dmem), .send_other_proc_data(cpu0_1),
								 .u_addr(cpu0_u_addr), .u_re(cpu0_u_re), .u_we(cpu0_u_we), .d_line(cpu0_d_line), 
									.u_rd_data(u_rd_data), .u_rdy(dmem_rdy));
		
	///////////////////////////////////
	/////     INSTANTIATE CPU1    ////
	/////////////////////////////////
	cpu #("test_readmiss1.hex") iCPU1(.clk(clk), .rst_n(rst_n), .int_occurred(int_occurred_1), .int_vec(int_vec_1), .mm_rdata(mm_rdata_1),			
		.mm_addr(mm_addr_1), .mm_re(mm_re_0), .mm_we(mm_we_1), .stall_IM_ID(stall_IM_ID_1), .mm_wdata(mm_wdata_1), 
			.invalidate_from_other_cpu(cpu1_inv_from_cpu0), .other_proc_data(cpu0_1), .read_miss(read_miss_1), 
				.write_miss(write_miss_1), /*op*/.invalidate(invalidate_1), .block_state(block_state_1),
					/*ip*/.BOCI(bus_addr_out), /*ip*/.grant(grant_1), /*ip*/.cpu_datasel(cpu1_datasel),
						/*ip*/.cpu_search(cpu1_search), /*op*/.cpu_search_found(cpu1_search_found),
							/*op*/.BICO(cpu1_to_bus_addr), .cpu_invalidate_dmem(cpu1_invalidate_dmem), .send_other_proc_data(cpu1_0), 
								.u_addr(cpu1_u_addr), .u_re(cpu1_u_re), .u_we(cpu1_u_we), .d_line(cpu1_d_line), 
									.u_rd_data(u_rd_data), .u_rdy(dmem_rdy));
			
	///////////////////////////////////
	/////     INSTANTIATE BUS     ////
	/////////////////////////////////
	bus iBUS0(.clk(clk), .rst_n(rst_n), .read_miss_0(read_miss_0), .read_miss_1(read_miss_1), 
		.write_miss_0(write_miss_0), .write_miss_1(write_miss_1), .block_state_0(block_state_0), 
			.block_state_1(block_state_1), .BICO_0(cpu0_to_bus_addr), .BICO_1(cpu1_to_bus_addr),
				.cpu1_search_found(cpu1_search_found), .cpu0_search_found(cpu0_search_found), 
					.invalidate_0(invalidate_0), .invalidate_1(invalidate_1), .u_we_0(cpu0_u_we), 
						.u_we_1(cpu1_u_we), .u_re_0(cpu0_u_re), .u_re_1(cpu1_u_re), .u_rdy(dmem_rdy),
							.cpu_doing_curr_op(cpu_curr_op), 
							.grant_0(grant_0), .grant_1(grant_1), .cpu0_datasel(cpu0_datasel), .cpu1_datasel(cpu1_datasel), 
								.BOCI(bus_addr_out), .cpu1_inv_from_cpu0(cpu1_inv_from_cpu0),
									.cpu0_inv_from_cpu1(cpu0_inv_from_cpu1), .cpu0_invalidate_dmem(cpu0_invalidate_dmem), 
										.cpu1_invalidate_dmem(cpu1_invalidate_dmem), 
											.cpu0_search(cpu0_search), .cpu1_search(cpu1_search), .we(we), .re(re));
		
	d_mem iDMEM0(.clk(clk), .rst_n(rst_n), .addr(mem_addr), .re(re), .we(we), .wdata(mem_wdata_line), .rd_data(u_rd_data),
		.rdy(dmem_rdy));
	
	assign mem_addr = (grant_0)? cpu0_u_addr:
					  (grant_1)? cpu1_u_addr:
					  11'h0;
					  
	assign mem_wdata_line =	(grant_0)? cpu0_d_line:
					  		(grant_1)? cpu1_d_line:
					  		64'h0000;				  
	
	

	///////////////////////////////////////
    // Instantiate interrupt controller //
  	/////////////////////////////////////
  	intCntrl iINT0(.clk(clk),.rst_n(rst_n),.int_src({2'b00,tmr_ov,fft_buff_vld}),
                .stall_IM_ID(stall_IM_ID_0),.mm_addr(mm_addr_0),
			    .mm_we(mm_we_0),.mm_wdata(mm_wdata_0),
			    .mm_rdata(mm_rdata_0),.int_occurred(int_occurred_0),
			    .int_vec(int_vec_0));

	intCntrl iINT1(.clk(clk),.rst_n(rst_n),.int_src({2'b00,tmr_ov,fft_buff_vld}),
                .stall_IM_ID(stall_IM_ID_1),.mm_addr(mm_addr_1),
			    .mm_we(mm_we_1),.mm_wdata(mm_wdata_1),
			    .mm_rdata(mm_rdata_1),.int_occurred(int_occurred_1),
			    .int_vec(int_vec_1));
endmodule