module ButtonDetector(
    input i_rst_n,
    input i_clk,
    input i_key, 
	output o_key
);

parameter S_IDLE = 1'b0 ;
parameter S_KEY = 1'b1 ;

logic state_r, state_w ;
logic keypressed_r, keypressed_w ;

assign o_key = keypressed_r ;

always_comb begin
	case (state_r)
		S_IDLE: begin
			if (i_key) begin
				state_w = S_KEY;
				keypressed_w = 0 ;
			end
			else begin
				state_w = S_IDLE;
				keypressed_w = 0 ;
			end
		end
		S_KEY: begin
			if (!i_key) begin
				state_w = S_IDLE;
				keypressed_w = 1 ;
			end
			else begin
				state_w = S_KEY;
				keypressed_w = 0 ;
			end
		end
	endcase
end



always_ff @(posedge i_clk or negedge i_rst_n) begin
	if (!i_rst_n) begin
		state_r <= S_IDLE ;
		keypressed_r <= 0 ;
	end
	else begin	
		state_r <= state_w ;
		keypressed_r <= keypressed_w ;
	end
end

endmodule