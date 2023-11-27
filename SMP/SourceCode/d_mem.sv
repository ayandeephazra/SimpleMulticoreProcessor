module d_mem(clk,rst_n,addr,re,we,wdata,rd_data,rdy);

////////////////////////////////////////////////////////////////////
// Data memory with 4-clock access times for reads & writes.     //
// Organized as 2048 64-bit words (i.e. same width a cache line //
/////////////////////////////////////////////////////////////////
input clk,rst_n;
input re,we;
input [10:0] addr;				// 2 LSB's are dropped since accessing as four 16-bit words
input [63:0] wdata;

output reg [63:0] rd_data;
output reg rdy;					// deasserted when memory operation completed

reg [63:0]mem[0:2047];			// entire memory space at 64-bits wide
reg [10:0] init_indx;

initial 
	for (init_indx=11'h000; init_indx < 11'h7FF; init_indx=init_indx + 1)
		mem[init_indx] = {init_indx, init_indx, init_indx, init_indx, init_indx, 1'b1,init_indx[7:0]};

//////////////////////////
// Define states of SM //
////////////////////////
typedef enum reg[1:0] {IDLE, WRITE, READ} state_t;
state_t state, nxt_state;

reg [10:0] addr_capture;								// capture the address at start of read
reg [1:0] wait_state_cnt;								// counter for 4-clock access time
reg clr_cnt,int_we,int_re;								// state machine outputs

  
/////////////////////////////////////////////////
// Capture address at start of read or write  //
// operation to ensure address is held       //
// stable during entire access time.        //
/////////////////////////////////////////////
always @(posedge clk)
  if (re | we)
    addr_capture <= addr;			// this is actual address used to access memory

//////////////////////////
// Model memory writes //
////////////////////////
always @(clk,int_we)
  if (clk & int_we)				// write occurs on clock high during 4th clock cycle
      mem[addr_capture] <= wdata;
	
/////////////////////////
// Model memory reads //
///////////////////////
always @(clk,int_re)
  if (clk & int_re)				// reads occur on clock high during 4th clock cycle
    rd_data = mem[addr_capture];
	 
	
////////////////////////
// Infer state flops //
//////////////////////
always @(posedge clk, negedge rst_n)
  if (!rst_n)
    state <= IDLE;
  else
    state <= nxt_state;
	
/////////////////////////
// wait state counter //
///////////////////////
always @(posedge clk, negedge rst_n)
  if (!rst_n)
    wait_state_cnt <= 2'b00;
  else
    if (clr_cnt)
      wait_state_cnt <= 2'b00;
	else
      wait_state_cnt <= wait_state_cnt + 1;
	
always_comb
  begin
    ////////////////////////////
	// default outputs of SM //
	//////////////////////////
    clr_cnt = 1;	// hold count in reset
	int_we = 0;		// wait till 4th clock
	int_re = 0;		// wait till 4th clock
	rdy = 0;
	nxt_state = IDLE;
	case (state)
	  IDLE : if (we) begin
	           clr_cnt = 0;
		       nxt_state = WRITE;
	         end else if (re) begin
			   clr_cnt = 0;
			   nxt_state = READ;
			 end else rdy = 1;
	  WRITE : if (&wait_state_cnt) begin
	            int_we = 1;		// write completes and next state is IDLE
				rdy = 1;
			  end else begin
			    clr_cnt = 0;
				nxt_state = WRITE;
			  end
	  default : if (&wait_state_cnt) begin	// this state is READ
		          int_re = 1;	// read completes and next state is IDLE
				  rdy = 1;
			    end else begin
				  clr_cnt = 0;
			      nxt_state = READ;
			    end
	endcase
  end

 endmodule
			   
			   
		
	