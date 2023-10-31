
module cache_controller
    import common::*;				// import all encoding definitions
	(
	input clk,
	input rst_n,
	input [12:0] addr,
	input reg [15:0] wr_data,
	input we,
	input re,
	input cpu_search,
	input [10:0] BOCI,
	output [15:0] rd_data,

	//output dirty,
	output cpu_search_found,
	output [15:0] send_other_proc_data,
	output reg read_miss,
	output reg write_miss,
	output reg invalidate
	);
	
	wire [63:0] d_line;			// line read from Dcache
	wire [63:0] wrt_line;		// line to write to Dcache when it is a replacement from itself
	wire dirty;
	wire hit;
	wire [63:0] other_proc_data_line_wire;
	//logic set_dirty;
	blk_state_t wstate;
	blk_state_t rstate;
	
	typedef enum reg [1:0] {IDLE, READ, WRITE} state_t;
	state_t state, nxt_state;
	
	always_ff @ (posedge clk, negedge rst_n) begin
		if (rst_n) 
			state <= IDLE;
		else
			state <= nxt_state;
	end
	
	always_comb begin
		read_miss = 0;
		write_miss = 0;
		invalidate = 0;
		wstate = rstate;
		nxt_state = IDLE;
		case (state) 
			IDLE: begin
				if (we) begin
					if(!hit) begin
						if(blk_state_t'(rstate)==INVALID) begin
						// write miss only possible if the block is invalid 
							wstate = MODIFIED;
							write_miss = 1;
						end else if (blk_state_t'(rstate)==SHARED) begin
							wstate = MODIFIED;
							invalidate = 1;
						end else
						// not possible by definition
							nxt_state = IDLE;
					// hit in write situation, we continue on to IDLE to look for new signals
					end else
						nxt_state = IDLE;
				end else if (re) begin // if Dcache read
					if(!hit) begin
					// read miss only possible if the block is invalid 
						if(blk_state_t'(rstate)==INVALID) begin
							wstate = SHARED;
							read_miss = 1;
						end else
							// not possible by definition
								nxt_state = IDLE;
							// hit in read situation, we continue on to IDLE to look for new signals
					end 
				end else
					nxt_state = IDLE;
			end
			READ: begin
				nxt_state = IDLE;
				
				end
			default: begin // WRITE state
				nxt_state = IDLE;
				
			end

		endcase
	end
		 
	assign wrt_line = ((addr[1:0]==2'b00)&& hit) ? {d_line[63:16],wr_data} :
                  ((addr[1:0]==2'b01)&& hit) ? {d_line[63:32],wr_data,d_line[15:0]} :
                  ((addr[1:0]==2'b10)&& hit) ? {d_line[63:48],wr_data,d_line[31:0]} :
				  ((addr[1:0]==2'b11)&& hit) ? {wr_data,d_line[47:0]} :
				  {d_line};
				  
	assign rd_data = (addr[1:0]==2'b00) ? d_line[15:0] :
                 (addr[1:0]==2'b01) ? d_line[31:16] :
			     (addr[1:0]==2'b10) ? d_line[47:32] :
			     d_line[63:48];
				 
	assign send_other_proc_data = (BOCI[1:0]==2'b00) ? other_proc_data_line_wire[15:0] :
                 (BOCI[1:0]==2'b01) ? other_proc_data_line_wire[31:16] :
			     (BOCI[1:0]==2'b10) ? other_proc_data_line_wire[47:32] :
			     other_proc_data_line_wire[63:48];				 

	/////////////////////////
	// Instantiate Dcache //
	///////////////////////
	msi_cache Dcache(.clk(clk), .rst_n(rst_n), .addr(addr[12:2]), .wr_data(wrt_line), 
		.wstate(wstate), .we(we), .re(re), .cpu_search(cpu_search), .BOCI(BOCI), .hit(hit), .dirty(dirty), .rstate(rstate), .rd_data(d_line),
		.tag_out(tag_out), .cpu_search_found(cpu_search_found), .other_proc_data_line_wire(other_proc_data_line_wire));
endmodule

