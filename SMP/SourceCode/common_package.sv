package common;
  /// alu op types ///
  typedef enum logic [3:0] {ADD, ADDC, SUB, SUBB, AND, OR, NAND, XOR, SLL, SRL, SRA, LHB,
                            MUL} alu_op_t;
	
  /// opcode types ///
  typedef enum logic [4:0] {ADDi, ADDCi, SUBi, SUBBi, ANDi, ORi, NANDi, XORi, ADDIi, ADDIEQi, ADDINEi,
                            ADDIGTi, SUBIi, ANDIi, ORIi, XORIi, SLLi, SRLi, SRAi, Bi, LWi, SWi, LHBi, 
							LLBi, JALi, JRi, RTIi, PUSHi, POPi, MOVCi, MULi, XMULHi} opcode_t;
  /// Src0 sources ///						
  typedef enum logic [2:0] {RF2SRC0, IMM7_2SRC0, IMM12_2SRC0, IMM15_2SRC0, ZERO2SRC0,
                            SP2SRC0, MULH2SRC0} src0sel_t;

  /// Src1 sources ///
  typedef enum logic [1:0] {RF2SRC1, IMM8_2SRC1, NPC2SRC1, ZERO2SRC1} src1sel_t;

  /// SM bus op ///
  typedef enum logic [3:0] {NOOP, READ_MISS_0, READ_MISS_0_WAIT, READ_MISS_1, READ_MISS_1_WAIT, WRITE_MISS_0, 
      WRITE_MISS_1, INVALIDATE_0, INVALIDATE_1} bus_op_t;
  
  /// Cache Block State ///
  typedef enum logic [1:0] {INVALID, SHARED, MODIFIED} blk_state_t;
  
  localparam int0vec = 16'h0010;
  localparam int1vec = 16'h0020;
  localparam int2vec = 16'h0030;
  localparam int3vec = 16'h0040;
  
  /// Stack pointer start address ///
  localparam SP_start = 16'h01F0;	// Mem ends at 0x01F0 so only 15 bytes of stack

  /// memory mapped register addresses ////
  localparam LED_AD = 16'hC000;
  localparam SW_AD = 16'hC001;
   
  localparam INT_EN = 16'hC002;		// interrupt enable

  localparam SPART_RX_TX = 16'hC004;
  localparam SPART_STAT = 16'hC005;
  localparam SPART_BD	= 16'hC006;
  
  localparam BMP_CTL =  16'hC008;
  localparam BMP_XLOC = 16'hC009;
  localparam BMP_YLOC = 16'hC00A;
  
  localparam FFT_BASE = 16'hC080;
  /// FFT out buffer extends to 16'hC0FF ///
  
  
endpackage

