
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
	input [63:0] other_proc_data,
	//input [15:0] bus_data,
	input grant,
	input u_rdy,
	input [63:0] u_rd_data,
	input [1:0] cpu_datasel,
	input invalidate_from_other_cpu,
	
	output reg d_rdy,					// data cache ready
	output hit,
	output [15:0] rd_data,
	output cpu_search_found,
	output [63:0] send_other_proc_data,
	output reg read_miss,
	output reg write_miss,
	output reg invalidate,
	output [10:0] u_addr,
	output reg u_we,
	output reg u_re,
	output [63:0] d_line,
	output reg [12:0] BICO,
	output [1:0] block_state
	);
	
	localparam SOURCE_DMEM = 2'b00;
	localparam SOURCE_OTHER_PROC = 2'b01;

	wire [63:0] wrt_line;		// line to write to Dcache when it is a replacement from itself
	wire dirty;					// deprecated but equivalent to state-MODIFIED
	//wire hit;
	wire [63:0] other_proc_data_line_wire;		// data found as a result of cpu_search
	reg evicting;
	reg d_we;					// read enable and write enable to Dcache
	reg d_re;
	reg dfill;
	wire [63:0] Dwrt_line;		// 64-bit data to write to Dcache	
	wire [4:0] tag_out;			// tag bits from data cache read.  Need this for address formation on evict
	reg [12:0] addr_capture;
	wire [12:0] cache_res_addr;
	reg use_flopped_addr;
	reg [63:0] d_line_capture;
	reg [12:0] addr_capture_write_miss;
	reg [63:0] d_line_capture_write_miss;
	
	//logic set_dirty;
	blk_state_t wstate;
	blk_state_t rstate;
	
	typedef enum reg [4:0] {IDLE, READ_MISS, READ_MISS_WAIT, D_RDY, WRITE_MISS, 
		WRITE_MISS_WAIT, R_EVICT, W_EVICT, R_READMEM, W_READMEM, DEF} state_t;
		
	state_t state, nxt_state;
	
	always_ff @ (posedge clk, negedge rst_n) begin
		if (!rst_n) 
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
		dfill = 0;
		use_flopped_addr = 0;
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
							write_miss = 1;
							nxt_state = WRITE_MISS;							
						end /*if (blk_state_t'(rstate)==MODIFIED) begin
			       			//////////////////////////////////////////////////
						   // Need to write out dirty line before filling //
						   ////////////////////////////////////////////////
						   evicting = 1;
						   nxt_state = R_EVICT;
						   u_we = 1;
				   		end */else begin
				   			//////////////////////////////////////////////////////////////////
				   			// Need to read a new line from unified and write the new data //
				   			////////////////////////////////////////////////////////////////
				   			nxt_state = W_READMEM;
							u_re = 1;
						end
					
					end else begin
						//set_dirty = 1;
						d_rdy = 1;
						d_we = 1;
						nxt_state = IDLE;
												
						//////////////////////////////////////////////////////////////////
				   		// if shared, invalidate, if modified, keep state			   //
				   		////////////////////////////////////////////////////////////////
						if (blk_state_t'(rstate)==SHARED) begin
							wstate = MODIFIED;
							invalidate = 1;
						end else if (blk_state_t'(rstate)==MODIFIED) begin
							wstate = MODIFIED;
							////////////////////////////////////////////////////////////////////////////
				   			// Need to evict this line then read in a new one and write the new data //
				   			//////////////////////////////////////////////////////////////////////////
				   			evicting = 1;
				   			nxt_state = W_EVICT;
				   			u_we = 1;				// start the write to unified
						end else begin
							nxt_state = IDLE;
						end
						
					end
				end else if (re) begin // if Dcache read
					if(!hit) begin
						d_rdy = 0;
						// dirty bit in MSI
						if (blk_state_t'(rstate)==MODIFIED) begin
							evicting = 1;
			       			nxt_state = R_EVICT;
			       			u_we = 1;
						// read miss only possible if the block is invalid 
						end else if(blk_state_t'(rstate)==INVALID) begin
							wstate = SHARED;
							read_miss = 1;
							nxt_state = READ_MISS;
						end else
							// not possible by definition
								nxt_state = R_READMEM;
						end 
					end else
						//////////////////////////////////////////////////////////////////
				   		// Dcache hit and Icache hit do nothing - SHARED, MODIFIED     //
				   		////////////////////////////////////////////////////////////////
						nxt_state = IDLE;
						// hit in read situation, we continue on to IDLE to look for new signals
			end
			
			READ_MISS: begin
				d_rdy = 0;
				if (grant) begin
					
					// wait state if dmem is the source, do the datasel mux select once u_rdy
					if (cpu_datasel == SOURCE_OTHER_PROC) begin
						//d_rdy = 1;
						d_we = 1;
						wstate = SHARED;
						nxt_state = D_RDY;
					end else if (!u_rdy ) begin
						//d_re = 1;
						d_rdy = 0;
						nxt_state = READ_MISS_WAIT;
					end else if (u_rdy && cpu_datasel == SOURCE_DMEM) begin
						d_rdy = 0;
						d_we = 1;
						nxt_state = IDLE;
						dfill = 1;
						wstate = SHARED; 
					end
				end else begin
					// wait in IDLE till you are granted access
					nxt_state = IDLE;
				end
			end
						
			READ_MISS_WAIT: begin
				d_rdy = 0;
				if (!u_rdy) 
					nxt_state = READ_MISS_WAIT; 
				else begin
					d_we = 1;
					nxt_state = IDLE;
					dfill = 1;
					wstate = SHARED; 
				end	
			end
			
			D_RDY: begin
				d_rdy = 1;
				nxt_state = IDLE;
			end
			
			WRITE_MISS: begin
				d_rdy = 0;
				if (grant) begin 
					if (!u_rdy) begin
						nxt_state = WRITE_MISS_WAIT;
					end else begin
						d_we = 1;
					 	wstate = MODIFIED;
					 	nxt_state = D_RDY;
					end
					//d_we = 1;
					//nxt_state = IDLE;
				end else begin
					//write_miss = 1;
					nxt_state = IDLE;
				end
			end
			
			WRITE_MISS_WAIT: begin
				d_rdy = 0;
				if (!u_rdy) begin
					nxt_state = WRITE_MISS_WAIT;
				end else begin
					 d_we = 1;
					 wstate = MODIFIED;
					 nxt_state = D_RDY;
				end
			end

			R_EVICT: begin
				/* stay in this state till dmem is free then write */
				evicting = 1;
			   d_re = 1;
			   u_we = 1;
			   d_rdy = 0;	
				if (u_rdy & grant)
					nxt_state = R_READMEM;
				else 
					nxt_state = R_EVICT;
				
			end
			R_READMEM: begin
				d_rdy = 0;
				u_re = 1;
			    d_we = u_rdy;
			    d_re = 0;
				dfill = 1;
				if (u_rdy & grant)
					nxt_state = IDLE;
				else
					nxt_state = R_READMEM;
			end
			W_EVICT: begin
				/* stay in this state till dmem is free then write */
				//d_rdy = 0;
				if (u_rdy & grant)
					nxt_state = W_READMEM;
				else
					nxt_state = W_EVICT;
			end
			W_READMEM: begin
				d_rdy = 0;
				u_re = 1;
			    d_we = u_rdy;
			    d_re = 0;
				dfill = 1;
				if (u_rdy & grant)
					nxt_state = IDLE;
				else
					nxt_state = W_READMEM;
				
			end
			
			default: begin
				nxt_state = IDLE;
			end

		endcase
	end
		 
	assign wrt_line = ((addr_capture[1:0]==2'b00) && use_flopped_addr) ? {d_line_capture[63:16], u_rd_data[15:0]} :
				  ((addr_capture[1:0]==2'b01) && use_flopped_addr) ? {d_line_capture[63:32], u_rd_data[31:16], d_line_capture[15:0]} :
				  ((addr_capture[1:0]==2'b10) && use_flopped_addr) ? {d_line_capture[63:48], u_rd_data[47:32], d_line_capture[31:0]} :
				  ((addr_capture[1:0]==2'b11) && use_flopped_addr) ? {u_rd_data[63:48], d_line_capture[47:0]} :
				  ((addr[1:0]==2'b00)&& hit) ? {d_line[63:16],wr_data} :
                  ((addr[1:0]==2'b01)&& hit) ? {d_line[63:32],wr_data,d_line[15:0]} :
                  ((addr[1:0]==2'b10)&& hit) ? {d_line[63:48],wr_data,d_line[31:0]} :
				  ((addr[1:0]==2'b11)&& hit) ? {wr_data,d_line[47:0]} :
				  ((addr[1:0]==2'b00)&& !hit && (cpu_datasel==2'b01)) ? {other_proc_data[63:16], wr_data} :
				  ((addr[1:0]==2'b01)&& !hit && (cpu_datasel==2'b01)) ? {other_proc_data[63:32], wr_data, other_proc_data[15:0]} :
				  ((addr[1:0]==2'b10)&& !hit && (cpu_datasel==2'b01)) ? {other_proc_data[63:48], wr_data, other_proc_data[31:0]} :
				  ((addr[1:0]==2'b11)&& !hit && (cpu_datasel==2'b01)) ? {wr_data, other_proc_data[47:0]} :
				  (BOCI[1:0]==2'b00 && invalidate_from_other_cpu)? {d_line[63:16], 16'hxxxx} :
				  (BOCI[1:0]==2'b01 && invalidate_from_other_cpu)? {d_line[63:32], 16'hxxxx, d_line[15:0]} :
				  (BOCI[1:0]==2'b10 && invalidate_from_other_cpu)? {d_line[63:48], 16'hxxxx, d_line[31:0]} :
				  (BOCI[1:0]==2'b11 && invalidate_from_other_cpu)? {16'hxxxx, d_line[47:0]} :
				  {d_line};
		
	assign rd_data = (addr[1:0]==2'b00) ? d_line[15:0] :
                 (addr[1:0]==2'b01) ? d_line[31:16] :
			     (addr[1:0]==2'b10) ? d_line[47:32] :
			     d_line[63:48];
				 
	assign send_other_proc_data = other_proc_data_line_wire;/*(BOCI[1:0]==2'b00) ? other_proc_data_line_wire[15:0] :
                 (BOCI[1:0]==2'b01) ? other_proc_data_line_wire[31:16] :
			     (BOCI[1:0]==2'b10) ? other_proc_data_line_wire[47:32] :
	other_proc_data_line_wire[63:48];*/				
				 
	assign Dwrt_line = (dfill) ? u_rd_data : wrt_line;
				 
	//////////////////////////////////////////////////////////////////////
	// Address to unified memory...is from Icache or Dcache operation? //
	// If Dcache are we evicting and have to use dtag for address?    //
	///////////////////////////////////////////////////////////////////
	assign u_addr = (evicting) ? {tag_out,addr[7:2]} :
				addr[12:2];					// address is forcibly aligned to 64-bit boundary	
	
	always_ff @ (posedge clk)
		if (re & !u_rdy) begin
			addr_capture <= addr;
			d_line_capture <= d_line;
		end	
		
	always_ff @ (posedge clk) 
		if (we & !hit) begin
			addr_capture_write_miss <=addr;
			d_line_capture_write_miss <= d_line;
		end
	
	assign cache_res_addr = (use_flopped_addr)? addr_capture: addr;

	/////////////////////////
	// Instantiate Dcache //
	///////////////////////
	msi_cache Dcache(.clk(clk), .rst_n(rst_n), .addr(cache_res_addr[12:2]), .wr_data(Dwrt_line), 
		.wstate(wstate), .we(d_we), .re(d_re), .cpu_search(cpu_search), .BOCI(BOCI[12:2]), 
		.invalidate_from_other_cpu(invalidate_from_other_cpu),
		.hit(hit), .dirty(dirty), .rstate(rstate), .rd_data(d_line), .tag_out(tag_out), 
		.cpu_search_found(cpu_search_found), .other_proc_data_line_wire(other_proc_data_line_wire),
		.block_state(block_state));
endmodule

