module alu
  import common::*;				// import all encoding definitions
  (input clk,
   input rst_n,
   input [15:0] src0,src1,
   input alu_op_t func,
   input int_occurred, rti_instr,
   input [3:0] shamt,				// shift amount
   input update_all,update_nz,		// which PSW bits to update
   input byp_NZ_EX_DM,				// bypassing NZ flags from LW or MOVC in DM stage
   input negflag_EX_DM,				// negflag value from LW or MOVC
   input zeroflag_EX_DM,			// zero flag value from LW or MOVC
   input stall_EX_DM,
   output [15:0] dst,				// ID_EX version for branch/jump targets
   output reg [15:0] dst_EX_DM,
   output reg [15:0] MULH_EX_DM,	// high word of multiply result
   output [3:0] PSW_EX_DM			// {C,OV,N,ZR}
  );
  

wire [15:0] sum;		// output of adder
wire [15:0] src0_1s_cmp;
wire cin;
wire sat_neg,sat_pos;
wire ov;
wire c;
wire [15:0] shft_l1,shft_l2,shft_l4,shft_l;		// intermediates for shift left
wire [15:0] shft_r1,shft_r2,shft_r4,shft_r;		// intermediates for shift right
wire [31:0] prod,produ;
wire signed [31:0] prods;

/////////////////////////////////////
// Declare any internal registers //
///////////////////////////////////
reg [3:0] PSW_saved;
reg [3:0] PSW_EX_DM_reg;

/////////////////////////////////////////////////
// Implement 2s complement logic for subtract //
///////////////////////////////////////////////
assign src0_1s_cmp = ((func==SUB) || (func==SUBB)) ? ~src0 : src0;	// use 2's comp for sub
assign cin = (func==SUB) ? 1 :
             (func==SUBB) ? PSW_EX_DM[3] :			// C if SUBB
			 (func==ADDC) ? PSW_EX_DM[3] :			// C if ADDC
			 1'b0;
			 
//////////////////////
// Implement adder //
////////////////////
assign {c,sum} = src1 + src0_1s_cmp + cin;

////////////////////////////////////////
// Implement signed vs unsigned mult //
//////////////////////////////////////
assign produ = src1*src0;
assign prods = $signed(src1)*$signed(src0);
assign prod = (shamt[0]) ? prods : produ;

///////////////////////////////
// Now for saturation logic //
/////////////////////////////
assign sat_neg = (src1[15] && src0_1s_cmp[15] && ~sum[15]) ? 1 : 0;
assign sat_pos = (~src1[15] && !src0_1s_cmp[15] && sum[15]) ? 1 : 0;

assign ov = sat_pos | sat_neg;
				 
///////////////////////////
// Now for left shifter //
/////////////////////////
assign shft_l1 = (shamt[0]) ? {src1[14:0],1'b0} : src1;
assign shft_l2 = (shamt[1]) ? {shft_l1[13:0],2'b00} : shft_l1;
assign shft_l4 = (shamt[2]) ? {shft_l2[11:0],4'h0} : shft_l2;
assign shft_l = (shamt[3]) ? {shft_l4[7:0],8'h00} : shft_l4;

////////////////////////////
// Now for right shifter //
//////////////////////////
assign shft_in = (func==SRA) ? src1[15] : 0;
assign shft_r1 = (shamt[0]) ? {shft_in,src1[15:1]} : src1;
assign shft_r2 = (shamt[1]) ? {{2{shft_in}},shft_r1[15:2]} : shft_r1;
assign shft_r4 = (shamt[2]) ? {{4{shft_in}},shft_r2[15:4]} : shft_r2;
assign shft_r = (shamt[3]) ? {{8{shft_in}},shft_r4[15:8]} : shft_r4;

///////////////////////////////////////////
// Now for multiplexing function of ALU //
/////////////////////////////////////////
assign dst = (func==AND) ? src1 & src0 :
			 (func==OR) ? src1 | src0 :
			 (func==NAND) ? ~(src1 & src0) :
			 (func==XOR) ? src1 ^ src0 :
			 (func==SLL) ? shft_l :
			 ((func==SRL) || (func==SRA)) ? shft_r :
			 (func==LHB) ? {src1[7:0],src0[7:0]} :
			 (func==MUL) ? prod[15:0] :
			 sum;	 								// default sum (ADD,ADDC,SUB,SUBB)
			 
assign zr = ~|dst;
assign neg = dst[15];

//////////////////////////////
// Implement MULH register //
////////////////////////////
always_ff @(posedge clk)
  if ((func==MUL) && (!stall_EX_DM))
    MULH_EX_DM <= prod[31:16];

////////////////////
// Implement PSW //
//////////////////
always_ff @(posedge clk, negedge rst_n)
  if (!rst_n)
    PSW_EX_DM_reg <= 4'h0;
  else if (!stall_EX_DM) begin
    if (rti_instr)
      PSW_EX_DM_reg <= PSW_saved;
    else if (update_all)
      PSW_EX_DM_reg <= {c,ov,neg,zr};
    else if (update_nz)
      PSW_EX_DM_reg <= {PSW_EX_DM[3:2],neg,zr};
    else if (byp_NZ_EX_DM)	// if LW or MOVC and instruction after not updating
      PSW_EX_DM_reg <= {PSW_EX_DM[3:2],negflag_EX_DM,zeroflag_EX_DM};
  end
	
////////////////////////////////////////////
// Now implement possible bypassing from //
// a LW or MOVC currently in DM stage   //
/////////////////////////////////////////
assign PSW_EX_DM = (byp_NZ_EX_DM) ? {PSW_EX_DM_reg[3:2],negflag_EX_DM,zeroflag_EX_DM} :
                   PSW_EX_DM_reg;
	
////////////////////////////////////
// Implement context save of PSW //
//////////////////////////////////
always_ff @(posedge clk)
  if (int_occurred)
    PSW_saved <= PSW_EX_DM;
  
  
//////////////////////////
// Flop the ALU result //
////////////////////////
always @(posedge clk)
  if (!stall_EX_DM)
    dst_EX_DM <= dst;

endmodule
