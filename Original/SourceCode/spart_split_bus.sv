//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:   
// Design Name: 
// Module Name:    spart with split bus
// Project Name: 
// Target Devices: DE1_SOC board
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module spart_split_bus
  import common::*;				// import all encoding definitions
   (
    input clk,				// 50MHz clk
    input rst_n,			// asynch active low reset
	input [15:0] mm_addr,	// memory mapped address from proc
	input mm_re,mm_we,		// read and write enable from proc
	input [15:0] mm_wdata,	// memory mapped write data from proc
	output [15:0] mm_rdata,	// memory mapped read data to proc
    output tx_q_full,		// indicates transmit queue is full
    output rx_q_empty,		// indicates receive queue is empty
    output TX,				// UART TX line
    input RX				// UART RX line
    );

  logic trmt;
  
  reg [12:0] DB;		// baud division buffer

  wire [7:0] tx_entries_left;
  wire [7:0] rx_entries;
  wire [7:0] rx_data;		// byte from receiver
  wire read_entry;
 
  ////////////////////////////////////////
  // Implement Baud division byte high //
  //////////////////////////////////////  
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  DB <= 13'h01B2;					// default to 115200 baud
	else if ((mm_addr==SPART_BD) && mm_we)
	  DB <= mm_wdata[12:0];
  
  assign trmt = ((mm_addr==16'hC004) && mm_we) ? 1'b1 : 1'b0;
  //////////////////////////////
  // Instantiate transmitter //
  ////////////////////////////
  UART_tx iTX(.clk(clk),.rst_n(rst_n),.TX(TX),.trmt(trmt),.tx_data(mm_wdata[7:0]),
          .baud_reload(DB),.queue_full(tx_q_full),.entries_left(tx_entries_left));
		  
  assign read_entry = ((mm_addr==SPART_RX_TX) && mm_re) ? 1'b1 : 1'b0;
  ///////////////////////////
  // Instantiate receiver //
  /////////////////////////
  UART_rx iRX(.clk(clk),.rst_n(rst_n),.RX(RX),.baud_reload(DB),
           .queue_empty(rx_q_empty),.num_entries(rx_entries),
          .rx_data(rx_data),.read_entry(read_entry));
	
	
  assign mm_rdata = (read_entry) ? {8'h00,rx_data} :
                    ((mm_addr==SPART_STAT) && mm_re) ? {tx_entries_left,rx_entries} :
				    ((mm_addr==SPART_BD) && mm_re) ? {3'b000,DB} :
				    16'hzzzz;
				   
endmodule
