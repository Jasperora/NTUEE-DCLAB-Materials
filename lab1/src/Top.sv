
module Top (
	input        i_clk,
	input        i_rst_n,//key1
	input        i_start,//key0
	input        i_mem,//key2
	output [3:0] o_random_out
);

parameter S_IDLE = 1'b0;
parameter S_PROC = 1'b1;

logic state_r, state_w;

logic [28:0] counter_r, counter_w;

logic [3:0] o_ans_r, o_ans_w;

logic [5:0] o_help_r, o_help_w;

logic [4:0] o_seed_r, o_seed_w;

logic [3:0] o_mem_r, o_mem_w;

assign o_random_out = o_ans_r;

always_comb begin
	o_ans_w = o_ans_r;
	state_w = state_r;
	counter_w = counter_r;
	o_help_w = o_help_r;
	o_seed_w = o_seed_r;
	o_mem_w = o_mem_r;

	case(state_r)
		S_IDLE:begin
			if(i_start) begin
				state_w = S_PROC;
			end
		end

		S_PROC:begin
			counter_w = counter_r + 1;
			if(counter_w >> o_help_w) begin
				o_ans_w = (counter_w == 2) ? o_seed_r : (5*o_ans_r + o_seed_r) % 16;
				o_help_w = o_help_r + 1;
			end
			else begin
				o_ans_w = o_ans_r;
			end
			if(!i_mem) begin
				o_ans_w = o_mem_r;
				state_w = S_IDLE;
			end
			if(counter_w == 29'd268435455 || i_start) begin
				state_w = S_IDLE;
				counter_w = 0;
				o_help_w = 0;
				o_seed_w = (5*o_seed_r + 9) % 16;
				o_mem_w = o_ans_r;
			end
			
		end
	endcase
end

always_ff @(posedge i_clk or negedge i_rst_n) begin
	// reset
	if (!i_rst_n) begin
		state_r        <= S_IDLE;
		counter_r	   <= 29'd0;
		o_ans_r 	   <= 4'd0;
		o_help_r	   <= 6'd1;
		o_seed_r       <= 5'd1;
		o_mem_r        <= 4'd0;
	end
	else begin
		state_r        <= state_w;
		counter_r 	   <= counter_w;
		o_ans_r 	   <= o_ans_w;
		o_help_r 	   <= o_help_w;
		o_seed_r       <= o_seed_w;
		o_mem_r        <= o_mem_w;
	end

end

// please check out the working example in lab1 README (or Top_exmaple.sv) first

endmodule
