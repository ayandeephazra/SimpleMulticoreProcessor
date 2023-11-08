module id
import common::*;					// import all encoding definitions
  (input clk,rst_n,
   input [19:0] instr,				// instruction to decode and execute direct from IM, flop first
   input [3:0] PSW_EX_DM,			// zero flag from ALU (used for ADDZ)
   input flow_change_ID_EX,
   input int_occurred,				// from interrupt controller
   input d_rdy,						// essentially the hit signal from the dCache
   output reg jmp_imm_ID_EX,
   output reg jmp_reg_ID_EX,
   output reg br_instr_ID_EX,			// set if instruction is branch instruction
   output reg jmp_imm_EX_DM,			// needed for JAL in dst_mux
   output reg rf_re0,					// asserted if instruction needs to read operand 0 from RF
   output reg rf_re1,					// asserted if instruction needs to read operand 1 from RF
   output reg rf_we_DM_WB,				// set if instruction is writing back to RF
   output reg [3:0] rf_p0_addr,			// normally instr[3:0] but for LHB and SW it is instr[11:8]
   output reg [3:0] rf_p1_addr,			// normally instr[7:4]
   output reg [3:0] rf_dst_addr_DM_WB,	// normally instr[11:8] but for JAL it is forced to 15
   output alu_op_t alu_func_ID_EX,		// select ALU operation to be performed
   output src0sel_t src0sel_ID_EX,	// select source for src0 bus
   output src1sel_t src1sel_ID_EX,	// select source for src1 bus
   output reg dm_re_EX_DM,				// asserted on loads
   output reg dm_we_EX_DM,				// asserted on stores
   output reg update_all_ID_EX,			// asserted for instructions that should modify zero flag
   output reg update_nz_ID_EX,			// asserted for instructions that should modify negative and ov flags
   output reg [14:0] instr_ID_EX,			// lower 15-bits needed for immediate based instructions
   output [2:0] cc_ID_EX,				// condition code bits for branch determination from instr[11:9]
   output stall_IM_ID,					// asserted for hazards & cache misses, stalls IM_ID flops
   output stall_ID_EX,
   output stall_EX_DM,
   output stall_DM_WB,
   output reg byp0_EX,byp0_DM,			// bypasing controls for RF_p0
   output reg byp1_EX,byp1_DM,			// bypassing controls for RF_p
   output reg rti_ID_EX,				// RTI instruction occurring
   output reg rti_EX_DM,				// later version of RTI occurring
   output reg [15:0] SP,				// Stack Pointer goes to srcmux
   output reg movc_instr_ID_EX,
   output reg movc_instr_EX_DM,
   output reg int_occurred_IM_ID		// goes to ALU for PSW save
  );

  /////////////////////////////////////////////////////////////
  // logic type needed for assignment in combinational case //
  ///////////////////////////////////////////////////////////
  logic br_instr;
  logic jmp_imm;
  logic jmp_reg;
  logic rf_we;
  logic [3:0] rf_dst_addr;
  alu_op_t alu_func;
  src0sel_t src0sel;
  src1sel_t src1sel;
  logic dm_re;
  logic dm_we;
  logic update_all;
  logic update_nz;
  logic cond_ex;
  logic rti;
  logic inc_sp;
  logic dec_sp;
  logic movc_instr;

  ////////////////////////////////
  // Needed internal registers //
  //////////////////////////////
  reg [19:0] instr_IM_ID;			// flop capturing the instruction to be decoded
  reg rf_we_ID_EX,rf_we_EX_DM;
  reg [3:0] rf_dst_addr_ID_EX,rf_dst_addr_EX_DM;
  reg dm_re_ID_EX;
  reg dm_we_ID_EX;
  reg flow_change_EX_DM;		// needed to pipeline flow_change_ID_EX
  reg cond_ex_ID_EX;			// needed for ADDIEQ, ADDINE, ADDIGT for knock down of rf_we
  reg inc_sp_ID_EX;
  reg [15:0] SP_saved;
  opcode_t opcode_ID_EX;

  wire load_use_hazard,flush;
  opcode_t opcode_IM_ID;
  wire cond_ex_disable;

  ///////////////////////////////////
  // Flop the instruction from IM //
  /////////////////////////////////
  always @(posedge clk, negedge rst_n)
    if (!rst_n)
      instr_IM_ID <= 20'hb0000;			// LLB R0, #0000
    else if (!stall_IM_ID)
      instr_IM_ID <= instr;				// flop raw instruction from IM
	  
  ///////////////////////////////////////
  // Upper 5-bit of instr form opcode //
  /////////////////////////////////////  
  assign opcode_IM_ID = opcode_t'(instr_IM_ID[19:15]);
	
  /////////////////////////////////////////////////////////////////////////////
  // Pipeline control signals needed in EX stage and beyond that need reset //
  ///////////////////////////////////////////////////////////////////////////
  always @(posedge clk, negedge rst_n)
    if (!rst_n) begin
	  br_instr_ID_EX 		<= 1'b0;
	  jmp_imm_ID_EX   	<= 1'b0;
	  jmp_reg_ID_EX   	<= 1'b0;
	  rf_we_ID_EX     	<= 1'b0;
	  dm_re_ID_EX       	<= 1'b0;
	  dm_we_ID_EX       	<= 1'b0;
	  update_all_ID_EX	<= 1'b0;
	  update_nz_ID_EX		<= 1'b0;
	  movc_instr_ID_EX <= 1'b0;
	  cond_ex_ID_EX 		<= 1'b0;
      rti_ID_EX           <= 1'b0;
	  inc_sp_ID_EX        <= 1'b0;	  
	end else if (!stall_ID_EX) begin
	  br_instr_ID_EX 		<= br_instr & !flush;
	  jmp_imm_ID_EX   	<= jmp_imm & !flush;
	  jmp_reg_ID_EX   	<= jmp_reg & !flush;
	  rf_we_ID_EX     	<= rf_we & !stall_IM_ID & !flush;
	  dm_re_ID_EX       	<= dm_re & !stall_IM_ID & !flush;
	  dm_we_ID_EX       	<= dm_we & !stall_IM_ID & !flush;
	  update_all_ID_EX	<= update_all & !stall_IM_ID & !flush;
	  update_nz_ID_EX		<= update_nz & !stall_IM_ID & !flush;
	  movc_instr_ID_EX    <= movc_instr;
	  cond_ex_ID_EX 		<= cond_ex;
      rti_ID_EX           <= rti & !stall_IM_ID & !flush;
	  inc_sp_ID_EX        <= inc_sp & !stall_IM_ID & !flush;
	end
	  
 ////////////////////////////////////////////////////////////////////////////////////
  // Pipeline control signals needed in EX stage and beyond that don't need reset //
  /////////////////////////////////////////////////////////////////////////////////
  always @(posedge clk)
    if (!stall_ID_EX) begin
	  rf_dst_addr_ID_EX	<= rf_dst_addr;
	  alu_func_ID_EX    	<= alu_func;
	  src0sel_ID_EX		<= src0sel;
	  src1sel_ID_EX		<= src1sel;
	  opcode_ID_EX      <= opcode_IM_ID;  
	  instr_ID_EX			<= instr_IM_ID[14:0];
	end
	
  /////////////////////////////////////////
  // Form IM_ID vertion of int_occurred //
  ///////////////////////////////////////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  int_occurred_IM_ID <= 1'b0;
	else if (!stall_IM_ID)
	  int_occurred_IM_ID <= int_occurred;

  //////////////////////////////////////////////////////////////////
  // Determine when to toss results for ADDIEQ, ADDINE, & ADDIGT //
  ////////////////////////////////////////////////////////////////  
  assign cond_ex_disable = (opcode_ID_EX==ADDIEQi) ? !PSW_EX_DM[0] :
                           (opcode_ID_EX==ADDINEi) ? PSW_EX_DM[0] :
						   !PSW_EX_DM[0] & !PSW_EX_DM[1];				// ADDIGT case
						   
  //////////////////////////////////////////////////////////////////////////////
  // Pipeline control signals needed in MEM stage and beyond that need reset //
  ////////////////////////////////////////////////////////////////////////////
  always @(posedge clk, negedge rst_n)
    if (!rst_n) begin
		rf_we_EX_DM			<= 1'b0;
        dm_re_EX_DM			<= 1'b0;
	    dm_we_EX_DM			<= 1'b0;
	    jmp_imm_EX_DM 		<= 1'b0;
		rti_EX_DM 			<= 1'b0;
		movc_instr_EX_DM    <= 1'b0;
	end else if (!stall_EX_DM) begin
	    rf_we_EX_DM			<= rf_we_ID_EX & (!(cond_ex_ID_EX & cond_ex_disable));
        dm_re_EX_DM			<= dm_re_ID_EX;
	    dm_we_EX_DM			<= dm_we_ID_EX;
	    jmp_imm_EX_DM 		<= jmp_imm_ID_EX;
		rti_EX_DM 			<= rti_ID_EX;
		movc_instr_EX_DM    <= movc_instr_ID_EX;
	end
	  
  ////////////////////////////////////////////////////////////////////////////////////
  // Pipeline control signals needed in MEM stage and beyond that don't need reset //
  //////////////////////////////////////////////////////////////////////////////////
  always @(posedge clk)
    if (!stall_EX_DM)
	    rf_dst_addr_EX_DM 	<= rf_dst_addr_ID_EX;
	  
	
  //////////////////////////////////////////////////////////////////
  // Pipeline control signals needed in WB stage that need reset //
  ////////////////////////////////////////////////////////////////	
  always @(posedge clk, negedge rst_n)
    if (!rst_n)
	  rf_we_DM_WB 		<= 1'b0;
	else if (!stall_DM_WB)
      rf_we_DM_WB 		<= rf_we_EX_DM;
  
  
  ////////////////////////////////////////////////////////////////////////
  // Pipeline control signals needed in WB stage that don't need reset //
  //////////////////////////////////////////////////////////////////////	
  always @(posedge clk)
    if (!stall_DM_WB)
      rf_dst_addr_DM_WB 	<= rf_dst_addr_EX_DM;


  /////////////////////////////////////////////////////////////
  // Flops for bypass control logic (these are ID_EX flops) //
  ///////////////////////////////////////////////////////////
  always @(posedge clk, negedge rst_n)
    if (!rst_n) 
      begin
	    byp0_EX <= 1'b0;
	    byp0_DM <= 1'b0;
	    byp1_EX <= 1'b0;
	    byp1_DM <= 1'b0;
	  end
    else if (!stall_ID_EX)
      begin
	    byp0_EX <= (rf_dst_addr_ID_EX==rf_p0_addr) ? (rf_we_ID_EX) : 1'b0;
	    byp0_DM <= (rf_dst_addr_EX_DM==rf_p0_addr) ? (rf_we_EX_DM) : 1'b0;
	    byp1_EX <= (rf_dst_addr_ID_EX==rf_p1_addr) ? (rf_we_ID_EX) : 1'b0;
	    byp1_DM <= (rf_dst_addr_EX_DM==rf_p1_addr) ? (rf_we_EX_DM) : 1'b0;
	  end
	
  //////////////////////////////////////////
  // Have to pipeline flow_change so can //
  // flush the 2 following instructions //
  ///////////////////////////////////////	
  always @(posedge clk, negedge rst_n)
    if (!rst_n)
      flow_change_EX_DM <= 1'b0;
    else if (!stall_EX_DM)
      flow_change_EX_DM <= flow_change_ID_EX; // | (rti_ID_EX & !stall_IM_ID & !flush);

  assign flush = flow_change_ID_EX | flow_change_EX_DM | int_occurred | int_occurred_IM_ID;

  ////////////////////////////////
  // Load Use Hazard Detection //
  //////////////////////////////	
  assign load_use_hazard = (((rf_dst_addr_ID_EX==rf_p0_addr) && rf_re0) || 
                            ((rf_dst_addr_ID_EX==rf_p1_addr) && rf_re1)) ? dm_re_ID_EX : 1'b0;
						  
  assign stall_IM_ID = load_use_hazard | movc_instr_EX_DM | ~d_rdy;
  assign stall_ID_EX = ~d_rdy;
  assign stall_EX_DM = ~d_rdy;
  assign stall_DM_WB = ~d_rdy;

  assign cc_ID_EX = instr_ID_EX[14:12];
  
  
  //////////////////////////////
  // Implement Stack Pointer //
  ////////////////////////////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  SP <= SP_start;
	else if ((dec_sp && !stall_IM_ID & !flush) & inc_sp_ID_EX)
	  SP <= SP;		// in strage case of inc and dec PUSH followed by POP then do nothing
	else if (inc_sp_ID_EX)
	  SP <= SP + 1;
	else if (dec_sp && !stall_IM_ID & !flush)
	  SP <= SP - 1;
	else if (rti_EX_DM)
	  SP <= SP_saved;

  ////////////////////////////////
  // Implement SP context save //
  //////////////////////////////
  always_ff @(posedge clk)
	if (int_occurred_IM_ID)
	  SP_saved <= SP;	  
	  

  //////////////////////////////////////////////////////////////
  // default to most common state and override base on instr //
  ////////////////////////////////////////////////////////////
  always_comb begin
    br_instr = 0;
    jmp_imm = 0;
    jmp_reg = 0;
    rf_re0 = 0;
    rf_re1 = 0;
    rf_we = 0;
    rf_p0_addr = instr_IM_ID[6:3];
    rf_p1_addr = instr_IM_ID[10:7];
    rf_dst_addr = instr_IM_ID[14:11];
    alu_func = ADD;
    src0sel = RF2SRC0;
    src1sel = RF2SRC1;
    dm_re = 0;
    dm_we = 0;
    update_all = 0;
    update_nz = 0;
    cond_ex = 0;
	rti = 0;
	inc_sp = 0;
	dec_sp = 0;
	movc_instr = 0;
  
  case (opcode_IM_ID)
    ADDi : begin
	  rf_re0 = 1;
	  rf_re1 = 1;
	  rf_we = 1;
      update_all = 1;
	end
	ADDCi : begin
	  rf_re0 = 1;
	  rf_re1 = 1;
	  rf_we = 1;
	  alu_func = ADDC;
      update_all = 1;
	end
	SUBi : begin
	  rf_re0 = 1;
	  rf_re1 = 1;
	  rf_we = 1;
      alu_func = SUB;	
      update_all = 1;
	end
	SUBBi : begin
	  rf_re0 = 1;
	  rf_re1 = 1;
	  rf_we = 1;
      alu_func = SUBB;	
      update_all = 1;
	end
	ANDi : begin
	  rf_re0 = 1;
	  rf_re1 = 1;
	  rf_we = 1;
      alu_func = AND;
	  update_nz = 1;
	end
	ORi : begin
	  rf_re0 = 1;
	  rf_re1 = 1;
	  rf_we = 1;
      alu_func = OR;
	  update_nz = 1;
	end
	NANDi : begin
	  rf_re0 = 1;
	  rf_re1 = 1;
	  rf_we = 1;
      alu_func = NAND;
	  update_nz = 1;
	end
	XORi : begin
	  rf_re0 = 1;
	  rf_re1 = 1;
	  rf_we = 1;
      alu_func = XOR;
	  update_nz = 1;
	end
    ADDIi : begin
	  src0sel = IMM7_2SRC0;
	  rf_re1 = 1;	  
	  rf_we = 1;
      update_all = 1;
	end
    ADDIEQi,ADDINEi,ADDIGTi : begin
	  src0sel = IMM7_2SRC0;
	  rf_re1 = 1;	  
	  rf_we = 1;
	  cond_ex = 1;
      update_all = 1;
	end
    SUBIi : begin
	  src0sel = IMM7_2SRC0;
	  rf_re1 = 1;	  
	  rf_we = 1;
	  alu_func = SUB;
      update_all = 1;
	end
    ANDIi : begin
	  src0sel = IMM7_2SRC0;
	  rf_re1 = 1;	  
	  rf_we = 1;
	  alu_func = AND;
      update_nz = 1;
	end
    ORIi : begin
	  src0sel = IMM7_2SRC0;
	  rf_re1 = 1;	  
	  rf_we = 1;
	  alu_func = OR;
      update_nz = 1;
	end
    XORIi : begin
	  src0sel = IMM7_2SRC0;
	  rf_re1 = 1;	  
	  rf_we = 1;
	  alu_func = XOR;
      update_nz = 1;
	end
	SLLi : begin
	  rf_re1 = 1;
	  rf_we = 1;
      alu_func = SLL;
	  update_nz = 1;
	end	
	SRLi : begin
	  rf_re1 = 1;
	  rf_we = 1;
      alu_func = SRL;
	  update_nz = 1;
	end	
	SRAi : begin
	  rf_re1 = 1;
	  rf_we = 1;
      alu_func = SRA;
	  update_nz = 1;
	end
    Bi : begin
	  src0sel = IMM12_2SRC0;		// 12-bit SE immediate
	  src1sel = NPC2SRC1;			// nxt_pc is routed to source 1
	  br_instr = 1;
	end
	LWi : begin
	  src0sel = IMM7_2SRC0;
	  rf_re1 = 1;
	  rf_we = 1;
	  update_nz = 1;
	  dm_re = 1;
	end
	SWi : begin
	  src0sel = IMM7_2SRC0;					// sign extended address offset
	  rf_re1 = 1;							// read register that contains address base
	  rf_re0 = 1;							// read register to be stored
	  rf_p0_addr = instr_IM_ID[14:11];		// register to be stored is encoded in [14:11]
	  dm_we = 1;
	end
	LHBi : begin
	  rf_re0 = 1;							// need to read target word so can maintin low byte
	  rf_p0_addr = instr_IM_ID[14:11];		// need to preserve lower byte, access it so can be recycled
	  src1sel = IMM8_2SRC1;					// access 8-bit immediate.
	  rf_we = 1;
	  alu_func = LHB;
	end
	LLBi : begin
	  src0sel = ZERO2SRC0;			 		// reg0 contains zero
	  src1sel = IMM8_2SRC1;					// access 8-bit immediate
	  rf_we = 1;
	end
	JALi : begin
	  src0sel = IMM15_2SRC0;				// 15-bit SE immediate
	  src1sel = NPC2SRC1;					// nxt_pc is routed to source 1
	  rf_we = 1;
	  rf_dst_addr = 4'hF;					// for JAL we write nxt_pc to R15
	  jmp_imm = 1;
	end
	JRi : begin
	  src0sel = ZERO2SRC0;			 		// reg0 contains zero
	  rf_re1 = 1;							// read register to jump to on src1
	  jmp_reg = 1;
	end
	RTIi : begin
	  rti = 1;
	end
	PUSHi : begin
	  src0sel = SP2SRC0;					// SP is address
	  src1sel = ZERO2SRC1;					// add zero to SP
	  rf_re0 = 1;							// read register to be stored
	  rf_p0_addr = instr_IM_ID[14:11];		// register to be stored is encoded in [14:11]
	  dm_we = 1;
	  inc_sp = 1;
	end
	POPi : begin
	  src0sel = SP2SRC0;					// SP will be decremented before it is added.
	  src1sel = ZERO2SRC1;					// add zero to SP
	  rf_we = 1;
	  dm_re = 1;
	  dec_sp = 1;
	end
	MOVCi : begin
	  src0sel = IMM7_2SRC0;
	  rf_re1 = 1;
	  rf_we = 1;
	  update_nz = 1;
	  movc_instr = ~movc_instr_EX_DM;	// prevent deadlock if instr 2 before was MOVC
	end
	MULi : begin
	  rf_re0 = 1;
	  rf_re1 = 1;
	  rf_we = 1;
	  alu_func = MUL;
      update_nz = 1;
	end
	XMULHi : begin
	  src0sel = MULH2SRC0;
	  src1sel = ZERO2SRC1;
	  rf_we = 1;
      update_nz = 1;
	end
	
  endcase
end

endmodule
  
  