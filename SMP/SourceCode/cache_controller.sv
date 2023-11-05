
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
	input [12:0] BOCI,
	input [15:0] other_proc_data,
	input [15:0] bus_data,
	input grant,
	input u_rdy,
	input [63:0] u_rd_data,
	input [1:0] cpu_datasel,
	input reg cpu_dmem_permission,
	input invalidate_from_other_cpu,
	
	output reg d_rdy,					// data cache ready
	output hit,
	output [15:0] rd_data,
	//output dirty,
	output cpu_search_found,
	output [15:0] send_other_proc_data,
	output reg read_miss,
	output reg write_miss,
	output reg invalidate,
	output [10:0] u_addr,
	output reg u_we,
	output reg u_re,
	output [63:0] d_line,
	output reg [12:0] BICO
	);
	
	//wire [63:0] d_line;			// line read from Dcache
	wire [63:0] wrt_line;		// line to write to Dcache when it is a replacement from itself
	wire dirty;
	//wire hit;
	wire [63:0] other_proc_data_line_wire;
	reg evicting;
	reg d_we;
	reg d_re;
	//logic set_dirty;
	blk_state_t wstate;
	blk_state_t rstate;
	
	typedef enum reg [2:0] {IDLE, R_EVICT, W_EVICT, R_READMEM, W_READMEM, DEF} state_t;
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
		evicting = 0;
		u_we = 0;
		u_re = 0;
		d_we = 0;
		d_re = re;
		d_rdy = 1;
		BICO = addr;
		nxt_state = IDLE;
		case (state) 
			IDLE: begin
				if (we) begin  // if Dcache write
				
					d_re = 1; 			// have to read prior to write to check and have fill data
					
					// hit in write situation, we continue on to IDLE to look for new signals
					if(!hit) begin
						d_rdy = 0;
						if(blk_state_t'(rstate)==INVALID) begin
						// write miss only possible if the block is invalid 
							wstate = MODIFIED;
							write_miss = 1;
							nxt_state = IDLE;
							/* if (dirty) begin
				   				////////////////////////////////////////////////////////////////////////////
				   				// Need to evict this line then read in a new one and write the new data //
				   				//////////////////////////////////////////////////////////////////////////
				   				evicting = 1;
				   				nxt_state = W_EVICT;
				   				u_we = 1;				// start the write to unified
				 			end else begin
				   				//////////////////////////////////////////////////////////////////
				   				// Need to read a new line from unified and write the new data //
				   				////////////////////////////////////////////////////////////////
				   				nxt_state = W_READMEM;
							end */
						end else
						// not possible by definition
							nxt_state = IDLE;
					
					end else begin
						d_rdy = 1;
						d_we = 1;
						nxt_state = IDLE;
						set_dirty = 1;
						//////////////////////////////////////////////////////////////////
				   		// if shared, invalidate, if modified, keep state			   //
				   		////////////////////////////////////////////////////////////////
						if (blk_state_t'(rstate)==SHARED) begin
							wstate = MODIFIED;
							invalidate = 1;
						end else if (blk_state_t'(rstate)==MODIFIED) begin
							wstate = MODIFIED;
						end else begin
							nxt_state = IDLE;
						end
						
					end
				end else if (re) begin // if Dcache read
					if(!hit) begin
						d_rdy = 0;
						if (dirty) begin
							evicting = 1;
			       			nxt_state = R_EVICT;
			       			//u_we = 1;
						// read miss only possible if the block is invalid 
						end else if(blk_state_t'(rstate)==INVALID) begin
							wstate = SHARED;
							read_miss = 1;
							nxt_state = IDLE;
						end else
							// not possible by definition
								nxt_state = R_READMEM;
							// hit in read situation, we continue on to IDLE to look for new signals
					end 
				end else
					nxt_state = IDLE;
			end

			R_EVICT: begin
				/* stay in this state till dmem is free then write */
				d_rdy = 0;
				if (!u_rdy | !cpu_dmem_permission)
					nxt_state = R_EVICT;
				else if (u_rdy & cpu_dmem_permission) begin
					nxt_state = IDLE;
					u_we = 1;
				end else
					nxt_state = IDLE;
				
			end
			W_EVICT: begin
				/* stay in this state till dmem is free then write */
				d_rdy = 0;
				if (!u_rdy | !cpu_dmem_permission)
					nxt_state = W_EVICT;
				else if (u_rdy & cpu_dmem_permission) begin
					nxt_state = IDLE;
					u_we = 1;
				end else
					nxt_state = IDLE;
			end
			W_READMEM: begin
				d_rdy = 0;
				u_re = 1;
			    d_we = u_rdy;
			    d_re = 0;
				if (!u_rdy | !cpu_dmem_permission)
					nxt_state = W_READMEM;
				else if (u_rdy & cpu_dmem_permission) begin
					nxt_state = IDLE;
					u_re = 1;
				end else
					nxt_state = IDLE;
				
			end
			R_READMEM: begin
				d_rdy = 0;
				u_re = 1;
			    d_we = u_rdy;
			    d_re = 0;
				if (!u_rdy | !cpu_dmem_permission)
					nxt_state = R_READMEM;
				else if (u_rdy & cpu_dmem_permission) begin
					nxt_state = IDLE;
					u_re = 1;
				end else
					nxt_state = IDLE;
			end
			default: begin
			
			end

		endcase
	end
		 
	assign wrt_line = ((addr[1:0]==2'b00)&& hit) ? {d_line[63:16],wr_data} :
                  ((addr[1:0]==2'b01)&& hit) ? {d_line[63:32],wr_data,d_line[15:0]} :
                  ((addr[1:0]==2'b10)&& hit) ? {d_line[63:48],wr_data,d_line[31:0]} :
				  ((addr[1:0]==2'b11)&& hit) ? {wr_data,d_line[47:0]} :
				  ((addr[1:0]==2'b00)&& !hit && (cpu_datasel==2'b00)) ? {d_line[63:16], u_rd_data[15:0]} :
				  ((addr[1:0]==2'b01)&& !hit && (cpu_datasel==2'b00)) ? {d_line[63:32], u_rd_data[31:16], d_line[15:0]} :
				  ((addr[1:0]==2'b10)&& !hit && (cpu_datasel==2'b00)) ? {d_line[63:48], u_rd_data[47:32], d_line[31:0]} :
				  ((addr[1:0]==2'b11)&& !hit && (cpu_datasel==2'b00)) ? {u_rd_data[63:48], d_line[47:0]} :
				  ((addr[1:0]==2'b00)&& !hit && (cpu_datasel==2'b01)) ? {d_line[63:16], other_proc_data} :
				  ((addr[1:0]==2'b01)&& !hit && (cpu_datasel==2'b01)) ? {d_line[63:32], other_proc_data, d_line[15:0]} :
				  ((addr[1:0]==2'b10)&& !hit && (cpu_datasel==2'b01)) ? {d_line[63:48], other_proc_data, d_line[31:0]} :
				  ((addr[1:0]==2'b11)&& !hit && (cpu_datasel==2'b01)) ? {other_proc_data, d_line[47:0]} :
				  {d_line};
		
	assign rd_data = (addr[1:0]==2'b00) ? d_line[15:0] :
                 (addr[1:0]==2'b01) ? d_line[31:16] :
			     (addr[1:0]==2'b10) ? d_line[47:32] :
			     d_line[63:48];
				 
	assign send_other_proc_data = (BOCI[1:0]==2'b00) ? other_proc_data_line_wire[15:0] :
                 (BOCI[1:0]==2'b01) ? other_proc_data_line_wire[31:16] :
			     (BOCI[1:0]==2'b10) ? other_proc_data_line_wire[47:32] :
			     other_proc_data_line_wire[63:48];				
				 
				 
	assign u_addr = addr[12:2];

	/////////////////////////
	// Instantiate Dcache //
	///////////////////////
	msi_cache Dcache(.clk(clk), .rst_n(rst_n), .addr(addr[12:2]), .wr_data(wrt_line), 
		.wstate(wstate), .we(d_we), .re(d_re), .cpu_search(cpu_search), .BOCI(BOCI[12:2]), .hit(hit), .dirty(dirty), .rstate(rstate), 
		.rd_data(d_line),
		.tag_out(tag_out), .cpu_search_found(cpu_search_found), .other_proc_data_line_wire(other_proc_data_line_wire));
endmodule

