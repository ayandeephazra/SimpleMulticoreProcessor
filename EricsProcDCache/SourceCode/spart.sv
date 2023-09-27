//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:   
// Design Name: 
// Module Name:    spart 
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
module spart(
    input clk,				// 50MHz clk
    input rst_n,			// asynch active low reset
    input iocs_n,			// active low chip select (decode address range)
    input iorw_n,			// high for read, low for write
    output tx_q_full,		// indicates transmit queue is full
    output rx_q_empty,		// indicates receive queue is empty
    input [1:0] ioaddr,		// Read/write 1 of 4 internal 8-bit registers
    inout [7:0] databus,	// bi-directional data bus
    output TX,				// UART TX line
    input RX				// UART RX line
    );

  logic trmt;
  
  reg [7:0] DBL;		// baud division bytes low
  reg [4:0] DBH;		// baud division high (only needs to be 5-bits)

  wire [3:0] tx_entries_left;
  wire [3:0] rx_entries;
  wire [7:0] rx_data;		// byte from receiver
  wire read_entry;
 
  ////////////////////////////////////////
  // Implement Baud division byte high //
  //////////////////////////////////////  
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  DBH <= 5'h01;					// default to 115200 baud
	else if (!iocs_n && !iorw_n && (ioaddr==2'b11))
	  DBH <= databus[4:0];
	  
  ///////////////////////////////////////
  // Implement Baud division byte low //
  /////////////////////////////////////  
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  DBL <= 8'hB2;					// default to 115200 baud
	else if (!iocs_n && !iorw_n && (ioaddr==2'b10))
	  DBL <= databus;	  
  
  assign trmt = (!iocs_n && !iorw_n && (ioaddr==2'b00)) ? 1'b1 : 1'b0;
  //////////////////////////////
  // Instantiate transmitter //
  ////////////////////////////
  UART_tx iTX(.clk(clk),.rst_n(rst_n),.TX(TX),.trmt(trmt),.tx_data(databus),
          .baud_reload({DBH,DBL}),.queue_full(tx_q_full),.entries_left(tx_entries_left));
		  
  assign read_entry = (!iocs_n && iorw_n && (ioaddr==2'b00)) ? 1'b1 : 1'b0;
  ///////////////////////////
  // Instantiate receiver //
  /////////////////////////
  UART_rx iRX(.clk(clk),.rst_n(rst_n),.RX(RX),.baud_reload({DBH,DBL}),
           .queue_empty(rx_q_empty),.num_entries(rx_entries),
          .rx_data(rx_data),.read_entry(read_entry));
	
	
  assign databus = (read_entry) ? rx_data :
                   (!iocs_n && iorw_n && (ioaddr==2'b01)) ? {tx_entries_left,rx_entries} :
				   (!iocs_n && iorw_n && (ioaddr==2'b10)) ? DBL :
				   (!iocs_n && iorw_n && (ioaddr==2'b11)) ? {3'b000,DBH} : 8'hzz;
				   
endmodule
