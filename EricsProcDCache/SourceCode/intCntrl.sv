module intCntrl
  import common::*;				// import all encoding definitions
  (input clk,rst_n,
   input [3:0] int_src,
   input stall_IM_ID,
   input [15:0] mm_addr,		// memory mapped address bus
   input mm_we,					// memory mapped read/write enable
   input [15:0] mm_wdata,
   output [15:0] mm_rdata,
   output int_occurred,
   output [15:0] int_vec
  );
  
  
  ////////////////////////////////////////////
  // declare any needed internal registers //
  //////////////////////////////////////////
  reg [3:0] int_hold;		// hold onto transient interrupt
  reg GIE; 			// global interrupt enable
  reg [3:0] IEs;	// individual interrupt enables
  
  wire [3:0] int_cap;	// int_src | int_hold;
  wire [3:0] int_enbld;	// int_cap & IEs

  //////////////////////////////////////////////////////
  // MSB of INT_EN is the global interrupt enable.   //
  // Lower 4-bits are individual enables for src3-0 //
  ///////////////////////////////////////////////////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n) begin
	  GIE <= 1'b0;
	  IEs <= 4'h0;
	end else if ((mm_addr==INT_EN) & mm_we) begin
	  GIE <= mm_wdata[15];
	  IEs <= mm_wdata[3:0];
	end
	
  assign mm_rdata = {GIE,11'h000,IEs};
	
  ///////////////////////////////////////////////////
  // If there is a stall, but interrupt source is //
  // only around for 1 clock we need to hold on  //
  // to fact that it happened.                  //
  ///////////////////////////////////////////////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  int_hold <= 4'h0;
	else if (stall_IM_ID)
	  int_hold <= int_cap;
	else
	  int_hold <= 4'h0;
	  
  assign int_cap = int_src | int_hold;
  
  /////////////////////////////////////
  // int_src[0] is highest priority //
  ///////////////////////////////////
  assign int_vec = (int_cap[0]) ? int0vec :
                   (int_cap[1]) ? int1vec :
				   (int_cap[2]) ? int2vec :
				   int3vec;

  ///////////////////////////////////////
  // interrupt only occurs if enabled //
  /////////////////////////////////////
  assign int_enbld = int_cap & IEs;
  
  assign int_occurred = GIE & |int_enbld;
  
endmodule

  
 
  