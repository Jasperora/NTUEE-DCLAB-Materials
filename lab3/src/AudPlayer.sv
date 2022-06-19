module AudPlayer (
	input			i_rst_n, 
	input 			i_bclk,		// little
	input 			i_daclrck,  // big
	input 			i_en,
	input  [15:0] 	i_dac_data,
	output			o_aud_dacdat
	);

logic o_aud_dacdat_r, o_aud_dacdat_w ;
logic daclrck_r, daclrck_w ;
logic [15:0] dac_data_r, dac_data_w;
logic [4:0] counter_r, counter_w ;
logic state_r, state_w ;

localparam IDLE = 1'b0;
localparam WORK = 1'b1;

assign o_aud_dacdat = o_aud_dacdat_r ;

always_comb
begin
	daclrck_w 		= i_daclrck;
	dac_data_w 		= dac_data_r; 
	o_aud_dacdat_w 	= o_aud_dacdat_r;
	counter_w		= counter_r ;
	if(i_en)
	begin
		case(state_r)
			1'b0:
			begin
				if (i_daclrck != daclrck_r)
				begin
					dac_data_w = i_dac_data ;
					state_w = WORK ;
					o_aud_dacdat_w = dac_data_w[15];
				end 
				else 
				begin
					dac_data_w = dac_data_r ;
					o_aud_dacdat_w = 0 ;
					counter_w = counter_r ;
					state_w = IDLE ;
				end
			end
			1'b1:
			begin
				if(!i_daclrck) 
				begin
					if(counter_r==14) // changed
					begin
						state_w = IDLE ;
						counter_w = 0; 
						o_aud_dacdat_w = dac_data_r[15-counter_r-1] ;
					end
					else 
					begin
						state_w = state_r ;
						counter_w = counter_r + 1 ; 
						o_aud_dacdat_w = dac_data_r[15-counter_r-1] ;
					end
				end
				else 
				begin
					if(counter_r==14) // changed
					begin
						state_w = IDLE ;
						counter_w = 0; 
						o_aud_dacdat_w = dac_data_r[15-counter_r-1] ;
					end
					else 
					begin
						state_w = state_r ;
						counter_w = counter_r + 1 ; 
						o_aud_dacdat_w = dac_data_r[15-counter_r-1] ;
					end
				end
			end
		endcase
	end
	else 
	begin
		dac_data_w = 0;
		o_aud_dacdat_w = 0 ;
		counter_w = 0 ;
		state_w = IDLE ;
	end
end

always_ff @(posedge i_bclk or negedge i_rst_n)
begin
	if(!i_rst_n)
	begin
		daclrck_r 		<= 0;
		dac_data_r 		<= 0; 
		o_aud_dacdat_r 	<= 0;
		counter_r		<= 0;
		state_r         <= 0;
	end
	else 
	begin
		daclrck_r 		<= daclrck_w;
		dac_data_r 		<= dac_data_w; 
		o_aud_dacdat_r 	<= o_aud_dacdat_w;
		counter_r		<= counter_w ;
		state_r 		<= state_w ;
	end
end



endmodule