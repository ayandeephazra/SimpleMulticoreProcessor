module src_mux
  import common::*;				// import all encoding definitions
  (input clk,
   input src1sel_t src1sel_ID_EX,	// mux selectors for src0 and src1 busses
   input src0sel_t src0sel_ID_EX,
   input [15:0] p0,					// port 0 from register file
   input [15:0] p1,					// port 1 from register file
   input [15:0] pc_ID_EX,			// Next PC for JAL instruction
   input [15:0] MULH_EX_DM,			// For XMULH instruction result
   input [14:0] imm_ID_EX,			// immediate from instruction stream goes on src0
   input [15:0] dst_EX_DM,			// EX_DM results for bypassing RF reads
   input [15:0] dst_DM_WB,			// DM_WB results for bypassing RF reads
   input [15:0] SP,					// Stack pointer from ID.
   input byp0_EX,byp1_EX,			// From ID, selects EX results to bypass RF sources
   input byp0_DM,byp1_DM,			// From ID, selects DM results to bypass RF sources
   input stall_ID_EX,
   input stall_EX_DM,
   output reg [15:0] p0_EX_DM,		// need to output this as data for SW instructions
   output [15:0] src0,src1			// source busses
  );

  /////////////////////////////////
  // registers needed for flops //
  ///////////////////////////////
  reg [15:0] p0_ID_EX,p1_ID_EX;		// need to flop register file outputs to form _ID_EX versions

  wire[15:0] RF_p0,RF_p1;			// output of bypass muxes for RF sources


  /////////////////////////////////////////////////
  // Flop the read ports from the register file //
  ///////////////////////////////////////////////
  always @(posedge clk)
    if (!stall_ID_EX)
      begin
	    p0_ID_EX <= p0;
	    p1_ID_EX <= p1;
	  end
	
  /////////////////////////////
  // Bypass Muxes for port0 //
  ///////////////////////////
  assign RF_p0 = (byp0_EX) ? dst_EX_DM :		// EX gets priority because it represents more recent data
                 (byp0_DM) ? dst_DM_WB :
			     p0_ID_EX;
	
  /////////////////////////////
  // Bypass Muxes for port1 //
  ///////////////////////////
  assign RF_p1 = (byp1_EX) ? dst_EX_DM :		// EX gets priority because it represents more recent data
                 (byp1_DM) ? dst_DM_WB :
			     p1_ID_EX;	
			   
  ////////////////////////////////////////////////////
  // Need to pipeline the data to be stored for SW //
  //////////////////////////////////////////////////
  always @(posedge clk)
    if (!stall_EX_DM)
	  p0_EX_DM <= RF_p0;

//////////////////////////////////////
// Now for the actual source muxes //
////////////////////////////////////	
assign src0 = (src0sel_ID_EX == RF2SRC0) ? RF_p0 : 
              (src0sel_ID_EX == IMM7_2SRC0) ? {{9{imm_ID_EX[6]}},imm_ID_EX[6:0]} :		// Reg imm & MOVC & LW/SW
			  (src0sel_ID_EX == IMM12_2SRC0) ? {{4{imm_ID_EX[11]}},imm_ID_EX[11:0]} :	// Branch instr
			  (src0sel_ID_EX == IMM15_2SRC0) ? {imm_ID_EX[14],imm_ID_EX[14:0]} :		// JAL
			  (src0sel_ID_EX == SP2SRC0) ? SP :
			  (src0sel_ID_EX == MULH2SRC0) ? MULH_EX_DM :								// XMULH
			  16'h0000;																	// zero is default

assign src1 = (src1sel_ID_EX == RF2SRC1) ? RF_p1 :
              (src1sel_ID_EX == IMM8_2SRC1) ? {{8{imm_ID_EX[7]}},imm_ID_EX[7:0]} :		// LHB/LLB
              (src1sel_ID_EX == NPC2SRC1) ? pc_ID_EX :									// for JAL
			  16'h0000;																	// zero is default
			  
endmodule

