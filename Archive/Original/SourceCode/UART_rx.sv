module UART_rx(clk,rst_n,RX,baud_reload,queue_empty,num_entries,
               rx_data,read_entry);

input clk,rst_n;			// clock and active low reset
input RX;					// rx is the asynch serial input (need to double flop)
input read_entry;			// indicates a byte from the queue is being read
input [12:0] baud_reload;	// From register, baud_cnt counts down from this amt
output queue_empty;			// Receive queue is empty
output [7:0] num_entries;	// number of bytes in receive queue
output [7:0] rx_data;		// data that was received first (head of queue)

//// Define state as enumerated type /////
typedef enum reg {IDLE, RX_STATE} state_t;
state_t state, nxt_state;

reg [8:0] shift_reg;		// shift reg (9-bits), MSB will contain stop bit when finished
reg [3:0] bit_cnt;			// bit counter (need extra bit for stop bit)
reg [12:0] baud_cnt;		// baud rate counter (50MHz/9600) = div of 5208
reg rx_ff1, rx_ff2;			// back to back flops for meta-stability
reg [7:0] rd_ptr,wrt_ptr;	// pointers into circular queue

logic start, trnsfr, receiving;		// using type logic for outputs of SM

wire shift,queue_full;
wire w_entry;

 
////////////////////////////
// Infer state flop next //
//////////////////////////
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    state <= IDLE;
  else
    state <= nxt_state;

/////////////////////////
// Infer bit_cnt next //
///////////////////////
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    bit_cnt <= 4'b0000;
  else if (start)
    bit_cnt <= 4'b0000;
  else if (shift)
    bit_cnt <= bit_cnt+1;

//////////////////////////
// Infer baud_cnt next //
////////////////////////
always_ff @(posedge clk)
  //// shift is asserted when baud_cnt hits zero ////
  if (start)
    baud_cnt <= baud_reload>>1;			// start 1/2 way to zero 
  else if (shift)
    baud_cnt <= baud_reload;			// reset when baud count is full
  else if (receiving)
    baud_cnt <= baud_cnt-1;		// only burn power incrementing if transmitting

////////////////////////////////
// Infer shift register next //
//////////////////////////////
always_ff @(posedge clk)
  if (shift)
    shift_reg <= {rx_ff2,shift_reg[8:1]};   // LSB comes in first

/////////////////////////////////////////////
// Implement pointers into circular queue //
///////////////////////////////////////////
always_ff @(posedge clk, negedge rst_n)
  if (!rst_n)
    rd_ptr <= 8'h00;
  else if ((read_entry) && (!queue_empty))
    rd_ptr <= rd_ptr + 1;

always_ff @(posedge clk, negedge rst_n)
  if (!rst_n)
    wrt_ptr <= 8'h00;
  else if ((trnsfr) && (!queue_full))
    wrt_ptr <= wrt_ptr + 1;	

assign num_entries = wrt_ptr-rd_ptr;
assign queue_full = (num_entries==8'h80) ? 1'b1 : 1'b0;
assign queue_empty = (rd_ptr==wrt_ptr) ? 1'b1 : 1'b0;

/////////////////////////////////////
// Instantiate UART receive queue //
///////////////////////////////////
assign w_entry = trnsfr & ~queue_full;
UART_Q iRCV(.clk(clk), .waddr(wrt_ptr[6:0]), .wdata(shift_reg), .we(w_entry),
            .raddr(rd_ptr[6:0]), .rdata(rx_data));

	
////////////////////////////////////////////////
// RX is asynch, so need to double flop      //
// prior to use for meta-stability purposes //
/////////////////////////////////////////////
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    begin
      rx_ff1 <= 1'b1;			// reset to idle state
      rx_ff2 <= 1'b1;
    end
  else
    begin
      rx_ff1 <= RX;
      rx_ff2 <= rx_ff1;
    end

//////////////////////////////////////////////
// Now for hard part...State machine logic //
////////////////////////////////////////////
always_comb
  begin
    //////////////////////////////////////
    // Default assign all output of SM //
    ////////////////////////////////////
    start         = 0;
    trnsfr    = 0;
    receiving     = 0;
    nxt_state     = IDLE;	// always a good idea to default to IDLE state
    
    case (state)
      IDLE : begin
        if (!rx_ff2)		// did fall of start bit occur?
          begin
            nxt_state = RX_STATE;
            start = 1;
          end
        else nxt_state = IDLE;
      end
      RX_STATE : begin		// this is RX state
        if (bit_cnt==4'b1010)
          begin
            trnsfr = 1;
            nxt_state = IDLE;
          end
        else
          nxt_state = RX_STATE;
        receiving = 1;
      end
    endcase
  end

///////////////////////////////////
// Continuous assignment follow //
/////////////////////////////////
assign shift = ~|baud_cnt; 						// shift wen baud_cnt is zero

endmodule
