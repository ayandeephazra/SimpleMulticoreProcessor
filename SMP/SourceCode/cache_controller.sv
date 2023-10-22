/*cache_controller iCC0(.clk(clk), .rst_n(rst_n), .addr(dst_EX_DM), .wr_data(p0_EX_DM), .we(DM_we),
	.re(dm_re_EX_DM), .cpu_search(cpu_search), .rd_data(dm_rd_data_EX_DM),
.tag_out(dtag), .hit(dhit), .dirty(dirty_bit), .cpu_search_found(cpu_search_found)); */
module cache_controller(
	input clk,
	input rst_n,
	input [12:0] addr,
	input reg [15:0] wr_data,
	input we,
	input re,
	input cpu_search,
	output [63:0] rd_data,
	output [4:0] tag_out,
	output hit,
	output dirty,
	output cpu_search_found	
	);
	
	wire [63:0] d_line;			// line read from Dcache
	wire [63:0] wrt_line;		// line to write to Dcache when it is a replacement from itself
	logic set_dirty;
	/* ripping out state machine logic that controls set_dirty/wdirty */
	always_ff @ (posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			set_dirty = 0;
		end
		// we = DM_we
		// we set dirty bit to 1 when it's a we and d cache hit
		else if (we & hit) begin
			set_dirty = 1;
		end
		// what are the other default cases?
		else
			set_dirty = 0;
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
				 
	/////////////////////////
	// Instantiate Dcache //
	///////////////////////
	cache Dcache(.clk(clk), .rst_n(rst_n), .addr(addr[12:2]), .wr_data(wrt_line), 
		.wdirty(set_dirty), .we(we), .re(re), .cpu_search(cpu_search), .rd_data(d_line),
			.tag_out(tag_out), .hit(hit), .dirty(dirty), .cpu_search_found(cpu_search_found));
endmodule

