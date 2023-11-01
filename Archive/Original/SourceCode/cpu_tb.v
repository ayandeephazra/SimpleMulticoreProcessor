module cpu_tb();

reg clk,rst_n;

wire [15:0] mm_rdata, mm_addr, mm_wdata;
wire mm_re, mm_we;
wire int_occurred;
wire [15:0] int_vec;


//////////////////////
// Instantiate CPU //
////////////////////
cpu iCPU(.clk(clk), .rst_n(rst_n), .int_occurred(int_occurred),.int_vec(int_vec),
         .mm_rdata(mm_rdata), .mm_addr(mm_addr), .mm_re(mm_re), .mm_we(mm_we),
		 .stall_IM_ID(stall_IM_ID), .mm_wdata(mm_wdata)); 

  ///////////////////////////////////////
  // Instantiate interrupt controller //
  /////////////////////////////////////
  intCntrl iINT(.clk(clk),.rst_n(rst_n),.int_src({2'b00,tmr_ov,fft_buff_vld}),
                .stall_IM_ID(stall_IM_ID),.mm_addr(mm_addr),
			    .mm_we(mm_we),.mm_wdata(mm_wdata),
			    .mm_rdata(mm_rdata),.int_occurred(int_occurred),
			    .int_vec(int_vec));

initial begin
  clk = 0;
  rst_n = 0;
  @(negedge clk);
  rst_n = 1;
  repeat(300) @(posedge clk);
  
  
  $stop();
end
  
always
  #5 clk = ~clk;
  
endmodule