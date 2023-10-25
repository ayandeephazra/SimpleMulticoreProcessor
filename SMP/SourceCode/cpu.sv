module cpu
  import common::*;						// import all encoding definitions
  (input clk,rst_n,
   input int_occurred,
   input [15:0] int_vec,
   inout [15:0] mm_rdata,				// memory mapped read data
   output [15:0] mm_addr,
   output mm_re,
   output mm_we,
   output stall_IM_ID,					// interrupt controller needs this
   output [15:0] mm_wdata,
   /*implement from below*/
   input cpu_search,					      // search within this cpu's cache with below tag	
   input [10:0] BOCI,				      	// Bus Out CPU In
   input grant,							        // did this cpu's requested operation get granted
   input cpu_datasel,					      // where should this cpu get its data from?
   input invalidate_from_other_cpu,	// other cpu requests an invalidate on "now" stale copy that this guy his
   output logic read_miss,				  // read miss within cpu cache
   output logic write_miss,				  // write miss **
   output logic invalidate,				  // invalidate other cpu's copy
   output logic [1:0] block_state,	// block state
   output reg cpu_search_found,			// cpu search within the cache has returned a found value
   output logic [10:0] BICO,			  // Bus In CPU Out
   output cpu_invalidate_dmem,			// invalidate using above tag on dmem 
   /* mem hierarchy feedback */
   output [10:0] u_addr,        		// address to unified memory
   output reg u_re, 				            // read enable and write enable to unified memory
   output reg u_we,
   output [63:0] d_line,		        // line read from Dcache
   output [63:0] u_rd_data,	        // data read from unified memory
   output u_rdy				              // indicates unified memory read/write operation finished
  );

wire [19:0] instr;				// instruction from IM
wire [14:0] instr_ID_EX;		// immediate bus
wire [15:0] src0,src1;			// operand busses into ALU
wire [15:0] dst_EX_DM;			// result from ALU
wire [15:0] MULH_EX_DM;			// high word of multiply result
wire [15:0] dst_ID_EX;			// result from ALU for branch destination
wire [15:0] pc_ID_EX;			// nxt_pc to source mux for JR
wire [15:0] pc_EX_DM;			// nxt_pc to store in reg15 for JAL
wire [15:0] pc;
wire [15:0] iaddr;				// instruction address
wire [15:0] dm_rd_data_EX_DM;	// data memory read data (from data memory)
wire [15:0] rd_data_EX_DM;		// muxing of external(mm) and internal DM
wire [15:0] rf_w_data_DM_WB;	// register file write data
wire [15:0] p0,p1;				// read ports from RF
wire [3:0] rf_p0_addr;			// address for port 0 reads
wire [3:0] rf_p1_addr;			// address for port 1 reads
wire [3:0] rf_dst_addr_DM_WB;	// address for RF write port
alu_op_t alu_func_ID_EX;		// specifies operation ALU should perform
src0sel_t src0sel_ID_EX;		// select for src0 bus
src1sel_t src1sel_ID_EX;		// select for src1 bus
wire [2:0] cc_ID_EX;			// condition code pipeline from instr[11:9]
wire [15:0] p0_EX_DM;			// data to be stored for SW
wire dm_re_EX_DM;
wire dm_we_EX_DM;
wire DM_we;
wire rti_EX_DM;
wire [3:0] PSW_EX_DM;			// {C,OV,N,Z}
wire update_all_ID_EX, update_nz_ID_EX;
wire int_occurred_IM_ID;
wire d_rdy;						// essentially hit signal from dCache
wire rti_ID_EX;
wire [15:0] SP;					// stack pointer
wire movc_instr_ID_EX;
wire movc_instr_EX_DM;
wire negflag_EX_DM,zeroflag_EX_DM;
wire byp_NZ_EX_DM;
wire stall_ID_EX;
wire stall_EX_DM;
wire stall_DM_WB;

reg set_dirty;				// When writing to Dcache from CPU set the dirty bit
wire d_hit;
wire [4:0] dtag;
wire dirty_bit;
	   
assign mm_addr = dst_EX_DM;

assign mm_re = |dst_EX_DM[15:14] & dm_re_EX_DM;  // External and a read
assign mm_we = |dst_EX_DM[15:14] & dm_we_EX_DM;  // External and a write

assign mm_wdata = p0_EX_DM;
  
//////////////////////////////////
// Instantiate program counter //
////////////////////////////////
pc iPC(.clk(clk), .rst_n(rst_n), .int_occurred(int_occurred),
       .int_vec(int_vec), .flow_change_ID_EX(flow_change_ID_EX), .rti_ID_EX(rti_ID_EX),
	   .stall_IM_ID(stall_IM_ID), .stall_ID_EX(stall_ID_EX), .stall_EX_DM(stall_EX_DM),
	   .dst_ID_EX(dst_ID_EX), .pc(pc), .pc_ID_EX(pc_ID_EX), .pc_EX_DM(pc_EX_DM)
	  );

assign iaddr = (movc_instr_EX_DM) ? dst_EX_DM : pc;
/////////////////////////////////////
// Instantiate instruction memory //
///////////////////////////////////
IM iIM(.clk(clk), .addr(iaddr[12:0]), .instr(instr));

//////////////////////////////////////////////
// Instantiate register instruction decode //
////////////////////////////////////////////
id	iID(.clk(clk), .rst_n(rst_n), .instr(instr), .PSW_EX_DM(PSW_EX_DM), .flow_change_ID_EX(flow_change_ID_EX),
        .int_occurred(int_occurred), .jmp_imm_ID_EX(jmp_imm_ID_EX),
		.jmp_reg_ID_EX(jmp_reg_ID_EX),.br_instr_ID_EX(br_instr_ID_EX), 
		.jmp_imm_EX_DM(jmp_imm_EX_DM), .rf_re0(rf_re0),.rf_re1(rf_re1), .rf_we_DM_WB(rf_we_DM_WB),
		.rf_p0_addr(rf_p0_addr), .rf_p1_addr(rf_p1_addr), .rf_dst_addr_DM_WB(rf_dst_addr_DM_WB),
		.alu_func_ID_EX(alu_func_ID_EX), .src0sel_ID_EX(src0sel_ID_EX), .src1sel_ID_EX(src1sel_ID_EX),
		.dm_re_EX_DM(dm_re_EX_DM), .dm_we_EX_DM(dm_we_EX_DM), .update_all_ID_EX(update_all_ID_EX),
		.update_nz_ID_EX(update_nz_ID_EX), .instr_ID_EX(instr_ID_EX), .cc_ID_EX(cc_ID_EX), 
		.stall_IM_ID(stall_IM_ID), .stall_ID_EX(stall_ID_EX), .stall_EX_DM(stall_EX_DM),
		.stall_DM_WB(stall_DM_WB), .byp0_EX(byp0_EX), .byp0_DM(byp0_DM), .byp1_EX(byp1_EX),
		.byp1_DM(byp1_DM), .rti_ID_EX(rti_ID_EX), .rti_EX_DM(rti_EX_DM), .SP(SP),
		.movc_instr_ID_EX(movc_instr_ID_EX), .movc_instr_EX_DM(movc_instr_EX_DM),
		.int_occurred_IM_ID(int_occurred_IM_ID),.d_rdy(d_rdy)
		);
		
	   
////////////////////////////////
// Instantiate register file //
//////////////////////////////
rf iRF(.clk(clk), .p0_addr(rf_p0_addr), .p1_addr(rf_p1_addr), .p0(p0), .p1(p1),
       .re0(rf_re0), .re1(rf_re1), .dst_addr(rf_dst_addr_DM_WB), .dst(rf_w_data_DM_WB),
 	   .we(rf_we_DM_WB));
	   
///////////////////////////////////
// Instantiate register src mux //
/////////////////////////////////
src_mux ISRCMUX(.clk(clk), .src0sel_ID_EX(src0sel_ID_EX), .src1sel_ID_EX(src1sel_ID_EX), .p0(p0),
                .p1(p1), .pc_ID_EX(pc_ID_EX), .MULH_EX_DM(MULH_EX_DM), .imm_ID_EX(instr_ID_EX), 
				.dst_EX_DM(dst_EX_DM), .dst_DM_WB(rf_w_data_DM_WB), .SP(SP), .byp0_EX(byp0_EX), 
				.byp0_DM(byp0_DM), .byp1_EX(byp1_EX),.byp1_DM(byp1_DM), .p0_EX_DM(p0_EX_DM),
				.src0(src0), .src1(src1), .stall_ID_EX(stall_ID_EX), .stall_EX_DM(stall_EX_DM));
	   
//////////////////////
// Instantiate ALU //
////////////////////
alu iALU(.clk(clk), .rst_n(rst_n), .src0(src0), .src1(src1), .func(alu_func_ID_EX),
         .int_occurred(int_occurred_IM_ID), .rti_instr(rti_EX_DM), .update_all(update_all_ID_EX),
		 .update_nz(update_nz_ID_EX), .shamt(instr_ID_EX[3:0]), .dst(dst_ID_EX), 
         .dst_EX_DM(dst_EX_DM), .MULH_EX_DM(MULH_EX_DM), .negflag_EX_DM(negflag_EX_DM),
		 .zeroflag_EX_DM(zeroflag_EX_DM), .byp_NZ_EX_DM(byp_NZ_EX_DM), .PSW_EX_DM(PSW_EX_DM),
		 .stall_EX_DM(stall_EX_DM));	

//////////////////////////////
// Instantiate data memory //
////////////////////////////
assign DM_we = ~|dst_EX_DM[15:13] & dm_we_EX_DM;	// qualified internal DM we


dmem_hierarchy iDM(.clk(clk),.rst_n(rst_n),.addr(dst_EX_DM[12:0]),.re(dm_re_EX_DM),
.we(DM_we),.wrt_data(p0_EX_DM), .cpu_search(cpu_search), .rd_data(dm_rd_data_EX_DM),.d_rdy(d_rdy), 
.cpu_search_found(cpu_search_found), .u_addr(u_addr), .u_re(u_re), .u_we(u_we), .d_line(d_line),
.u_rd_data(u_rd_data), .u_rdy(u_rdy));				

assign rd_data_EX_DM = (|dst_EX_DM[15:13]) ? mm_rdata : dm_rd_data_EX_DM;

////////////////////////////////////////////
// Establish N & Z flags for LW and MOVC //
//////////////////////////////////////////
assign byp_NZ_EX_DM = (dm_re_EX_DM | movc_instr_EX_DM);
assign negflag_EX_DM = rd_data_EX_DM[15]&dm_re_EX_DM | instr[15]&movc_instr_EX_DM;
assign zeroflag_EX_DM = ~|rd_data_EX_DM&dm_re_EX_DM | ~|instr[15:0]&movc_instr_EX_DM;

//////////////////////////
// Instantiate dst mux //
////////////////////////
dst_mux iDSTMUX(.clk(clk), .dm_re_EX_DM(dm_re_EX_DM), .dm_rd_data_EX_DM(rd_data_EX_DM),
                .dst_EX_DM(dst_EX_DM), .pc_EX_DM(pc_EX_DM), .rf_w_data_DM_WB(rf_w_data_DM_WB),
				.jmp_imm_EX_DM(jmp_imm_EX_DM), .movc_instr_EX_DM(movc_instr_EX_DM),
				.stall_DM_WB(stall_DM_WB), .instr(instr[15:0]));
	
/////////////////////////////////////////////
// Instantiate branch determination logic //
///////////////////////////////////////////
br_bool iBRL(.PSW(PSW_EX_DM), .br_instr_ID_EX(br_instr_ID_EX), .jmp_imm_ID_EX(jmp_imm_ID_EX),
			 .jmp_reg_ID_EX(jmp_reg_ID_EX), .rti_ID_EX(rti_ID_EX), .cc_ID_EX(cc_ID_EX),
			 .flow_change_ID_EX(flow_change_ID_EX));	
			 
			   
	   
endmodule
