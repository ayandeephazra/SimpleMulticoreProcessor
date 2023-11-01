module UART_tx(clk,rst_n,TX,trmt,tx_data,baud_reload,queue_full,entries_left);

input clk,rst_n;			// clock and active low reset
input trmt;					// trmt tells TX section to transmit tx_data
input [7:0] tx_data;		// byte to transmit
input [12:0] baud_reload;	// baud_cnt counts down from this amount
output queue_full;			// transmit queue is full
output [7:0] entries_left;	// number of bytes remaining in transmit queue
output TX;					// serial output line

reg [8:0] shift_reg;		// 1-bit wider to store start bit
reg [3:0] bit_cnt;			// bit counter
reg [12:0] baud_cnt;		// baud rate counter (50MHz/19200) = div of 2604
reg [7:0] rd_ptr,wrt_ptr;	// pointers into circular queue

logic load, trnsmttng;		// assigned in state machine

wire shift;
wire queue_empty;
wire w_entry;
wire [7:0] tdata;

////////////////////////////////
// Define state as enum type //
//////////////////////////////
typedef enum reg {IDLE,TX_STATE} state_t;
state_t state,nxt_state;

////////////////////////////
// Infer state flop next //
//////////////////////////
always @(posedge clk or negedge rst_n)
  if (!rst_n)
    state <= IDLE;
  else
    state <= nxt_state;

/////////////////////////
// Infer bit_cnt next //
///////////////////////
always @(posedge clk or negedge rst_n)
  if (!rst_n)
    bit_cnt <= 4'b0000;
  else if (load)
    bit_cnt <= 4'b0000;
  else if (shift)
    bit_cnt <= bit_cnt+1;

//////////////////////////
// Infer baud_cnt next //
////////////////////////
always @(posedge clk)
  if (load || shift)
    baud_cnt <= baud_reload;			// baud of 19200 with 50MHz clk
  else if (trnsmttng)
    baud_cnt <= baud_cnt-1;		// only burn power incrementing if tranmitting

////////////////////////////////
// Infer shift register next //
//////////////////////////////
always @(posedge clk or negedge rst_n)
  if (!rst_n)
    shift_reg <= 9'h1FF;		// reset to idle state being transmitted
  else if (load)
    shift_reg <= {tdata,1'b0};	// start bit is loaded as well as data to TX
  else if (shift)
    shift_reg <= {1'b1,shift_reg[8:1]};	// LSB shifted out and idle state shifted in 

/////////////////////////////////////////////
// Implement pointers into circular queue //
///////////////////////////////////////////
always_ff @(posedge clk, negedge rst_n)
  if (!rst_n)
    rd_ptr <= 8'h00;
  else if (load)
    rd_ptr <= rd_ptr + 1;

always_ff @(posedge clk, negedge rst_n)
  if (!rst_n)
    wrt_ptr <= 8'h00;
  else if ((trmt) && (!queue_full))
    wrt_ptr <= wrt_ptr + 1;	

assign entries_left = 8'h80 - (wrt_ptr-rd_ptr);
assign queue_full = (entries_left==8'h00) ? 1'b1 : 1'b0;
assign queue_empty = (rd_ptr==wrt_ptr) ? 1'b1 : 1'b0;

	 
//////////////////////////////////////
// Instantiate UART transmit queue //
////////////////////////////////////
assign w_entry = trmt & ~queue_full;
UART_Q iTRMT(.clk(clk), .waddr(wrt_ptr[6:0]), .wdata(tx_data), .we(w_entry),
            .raddr(rd_ptr[6:0]), .rdata(tdata));

//////////////////////////////////////////////
// Now for hard part...State machine logic //
////////////////////////////////////////////
always_comb
  begin
    //////////////////////////////////////
    // Default assign all output of SM //
    ////////////////////////////////////
    load         = 0;
    trnsmttng = 0;
    nxt_state    = IDLE;	// always a good idea to default to IDLE state
    
    case (state)
      IDLE : begin
        if (!queue_empty)
          begin
            nxt_state = TX_STATE;
            load = 1;
          end
        else nxt_state = IDLE;
      end
      default : begin		// this is TX state
        if (bit_cnt==4'b1010)
          nxt_state = IDLE;
        else
          nxt_state = TX_STATE;
        trnsmttng = 1;
      end
    endcase
  end

////////////////////////////////////
// Continuous assignement follow //
//////////////////////////////////
assign shift = ~|baud_cnt;
assign TX = shift_reg[0];		// LSB of shift register is TX

endmodule

