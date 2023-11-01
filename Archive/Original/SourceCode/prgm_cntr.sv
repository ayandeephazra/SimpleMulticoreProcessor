module pc
  import common::*;				// import all encoding definitions
  (input clk,rst_n,
   input int_occurred,			// interrupt occurred
   input [15:0] int_vec,
   input flow_change_ID_EX,		// asserted from branch boolean on jump or taken branch
   input rti_ID_EX,				// causes pop of PC
   input stall_IM_ID,			// asserted if we need to stall the pipe
   input stall_ID_EX,
   input stall_EX_DM,
   input [15:0] dst_ID_EX,		// branch target address comes in on this bus

   output reg [15:0] pc,		// the PC, forms address to instruction memory
   output reg [15:0] pc_ID_EX,	// needed in EX stage for Branch instruction
   output reg [15:0] pc_EX_DM	// needed in dst_mux for JAL instruction
  );

////////////////////////////////////////////////////////////////////////////\
// This module implements the program counter logic. It normally increments \\
// the PC by 1, but when a branch is taken will add the 12-bit immediate     \\
// field to the PC+1.  In case of a jmp_imm it will add the 15-bit immediate //
// field to the PC+1.  In the case of a jmp_reg it will use the register    //
// port zero (p0) register access as the new value of the PC.  It also     //
// provides PC+1 as nxt_pc for JAL instructions.                          //
///////////////////////////////////////////////////////////////////////////

reg [15:0] pc_IM_ID;
reg [15:0] newPC_stalled;
reg [15:0] pc_saved;		// 1-deep stack for context save of PC during int
reg in_ISR;
reg flow_change_last_stalled;

///////////////////////////////////////////////////////////
// Nested ISRs not supported, once in ISR ints disabled //
/////////////////////////////////////////////////////////
always_ff @(posedge clk, negedge rst_n)
  if (!rst_n)
    in_ISR <= 1'b0;
  else if (rti_ID_EX)
    in_ISR <= 1'b0;
  else if (int_occurred && !stall_IM_ID)
    in_ISR <= 1'b1;

//////////////////////////////////////////////////////////////
// The following became necessary with the introduction of //
// MOVC instruction.  Prior a stall_IM_ID and a           //
// flow_change_ID_EX could not happen simultaneously, but// 
// a MOVC followed by a branch can cause this scenario. // 
/////////////////////////////////////////////////////////
always_ff @(posedge clk, negedge rst_n)
  if (!rst_n)
    flow_change_last_stalled <= 1'b0;
  else if (stall_IM_ID)
    flow_change_last_stalled <= flow_change_ID_EX;
  else
    flow_change_last_stalled <= 1'b0;

always_ff @(posedge clk)
  if (stall_IM_ID)
    newPC_stalled <= dst_ID_EX;	 // capture PC that went with branch after MOVC
	
	
////////////////////////////////
// Implement the PC register //
//////////////////////////////
always @(posedge clk, negedge rst_n)
  if (!rst_n)
    pc <= 16'h0000;
  else if (!stall_IM_ID)	// all stalls stall the PC
    if (rti_ID_EX)
	  pc <= pc_saved;		// pop from 1 deep stack for interrupts
	else if (int_occurred)
	  pc <= int_vec;
    else if (flow_change_ID_EX)
      pc <= dst_ID_EX;
	else if (flow_change_last_stalled)
	  pc <= newPC_stalled;
    else
	  pc <= pc + 1;


//////////////////////////////////////////////////
// Implement 1-deep stack for int context save //
////////////////////////////////////////////////	
always @(posedge clk)
  if (int_occurred && !stall_IM_ID)
    pc_saved <= (flow_change_ID_EX) ? dst_ID_EX :	// if instruction finishing is branch we 
                (flow_change_last_stalled) ? newPC_stalled:	// need to capture the changed PC
				pc_IM_ID - 1;	// throw away current instruction in IM_ID
  
////////////////////////////////////////////////
// Implement the PC pipelined register IM_ID //
//////////////////////////////////////////////
always @(posedge clk)
  if (!stall_IM_ID)
    pc_IM_ID <= pc + 1;		// pipeline PC points to next instruction
	
////////////////////////////////////////////////
// Implement the PC pipelined register ID_EX //
//////////////////////////////////////////////
always @(posedge clk)
  if (!stall_ID_EX)
    pc_ID_EX <= pc_IM_ID;	// pipeline it down to EX stage for jumps
	
////////////////////////////////////////////////
// Implement the PC pipelined register EX_DM //
//////////////////////////////////////////////
always @(posedge clk)
  if (!stall_EX_DM)
    pc_EX_DM <= pc_ID_EX;	// pipeline it down to DM stage for saved register for JAL

endmodule