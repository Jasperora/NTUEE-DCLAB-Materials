`timescale 1ns/10ps
module I2cInitializer (
	input  i_rst_n,
	input  i_clk,
	input  i_start,
	output o_finished,
	output o_sclk,
	output o_sdat,
	output o_oen 
);

//state
parameter S_IDLE       = 0;
parameter S_START      = 1;
parameter S_READ_1     = 2;
parameter S_TRANSMIT_1 = 3;
parameter S_READ_2     = 4;
parameter S_TRANSMIT_2 = 5;
parameter S_READ_3     = 6;
parameter S_TRANSMIT_3 = 7;
parameter S_READ_4     = 8;
parameter S_TRANSMIT_4 = 9;
parameter S_READ_5     = 10;
parameter S_TRANSMIT_5 = 11;
parameter S_READ_6     = 12;
parameter S_TRANSMIT_6 = 13;
parameter S_HOLD       = 14;
parameter S_ACK        = 15;
parameter S_OUT        = 16;
parameter S_EXTRA_1    = 17;
// parameter S_EXTRA_2    = 18;

//register data
parameter bit [23:0] data1 = 24'b0011_0100_000_0100_0_0001_0101; //Analogue Audio Path Control
parameter bit [23:0] data2 = 24'b0011_0100_000_0101_0_0000_0000; //Digital Audio Path Control
parameter bit [23:0] data3 = 24'b0011_0100_000_0110_0_0000_0000; //Power Down Control
parameter bit [23:0] data4 = 24'b0011_0100_000_0111_0_0100_0010; //Digital Audio Interface Format
parameter bit [23:0] data5 = 24'b0011_0100_000_1000_0_0001_1001; //Sampling Control
parameter bit [23:0] data6 = 24'b0011_0100_000_1001_0_0000_0001; //Active Control 
parameter bit [23:0] data7 = 24'b0011_0100_000_1111_0_0000_0000; //Reset


logic [4:0] state_w, state_r;
logic sclk_r, sclk_w, sdat_r, sdat_w, finished_r, finished_w, o_oen_r, o_oen_w;

logic [2:0] count8_r, count8_w, count_mode_r, count_mode_w;
logic [4:0] count24_r, count24_w;


assign o_finished = finished_r;
assign o_sclk = sclk_r;
assign o_sdat = sdat_r;
assign o_oen = o_oen_r; 

//============ Combinational logic ==============

always_comb begin
	state_w = state_r;
	finished_w = finished_r;
	sclk_w = sclk_r;
	sdat_w = sdat_r;
	o_oen_w = o_oen_r;
	count8_w = count8_r;
	count24_w = count24_r;
	count_mode_w = count_mode_r;

	case (state_r)
		S_IDLE: begin
			sclk_w = 1;
			sdat_w = 1;
			o_oen_w = 1 ;
			//finihed_w = 0;
			if(count_mode_r == 6) begin
				finished_w = 1;
                state_w = S_IDLE ;
			end
			else begin
				if(i_start) begin
					state_w = S_START;
				end
				else begin
					state_w = S_IDLE;
				end
			end
			
		end
		S_START: begin
			sdat_w = 0;
			//o_oen_w = 1;
			state_w = (count_mode_r == 0) ? S_READ_1:
					  (count_mode_r == 1) ? S_READ_2:
					  (count_mode_r == 2) ? S_READ_3:
					  (count_mode_r == 3) ? S_READ_4:
					  (count_mode_r == 4) ? S_READ_5: S_READ_6;
		end
		//============ 1 =====================
		S_READ_1:begin
			sclk_w = 0;
			sdat_w = data1[23-count24_r];
			o_oen_w = 1;
			count24_w = count24_r + 1;
			//$display("count24_w", count24_w);
			state_w = S_TRANSMIT_1;
		end
		S_TRANSMIT_1: begin
			sclk_w = 1;
			if(count8_r == 7) begin
				count8_w = 0;
				state_w = S_HOLD;
			end
			else begin
				count8_w = count8_r + 1;
				state_w = S_READ_1;
			end
		end
		//=========== 2 =====================
		S_READ_2:begin
			sclk_w = 0;
			o_oen_w = 1;
			sdat_w = data2[23-count24_r];
			count24_w = count24_r + 1;
			state_w = S_TRANSMIT_2;
		end
		S_TRANSMIT_2: begin
			sclk_w = 1;
			if(count8_r == 7) begin
				count8_w = 0;
				state_w = S_HOLD;
			end
			else begin
				count8_w = count8_r + 1;
				state_w = S_READ_2;
			end
		end
		//========== 3 =======================
		S_READ_3:begin
			sclk_w = 0;
			o_oen_w = 1;
			sdat_w = data3[23-count24_r];
			count24_w = count24_r + 1;
			state_w = S_TRANSMIT_3;
		end
		S_TRANSMIT_3: begin
			sclk_w = 1;
			if(count8_r == 7) begin
				count8_w = 0;
				state_w = S_HOLD;
			end
			else begin
				count8_w = count8_r + 1;
				state_w = S_READ_3;
			end
		end
		//=========== 4 ======================
		S_READ_4:begin
			sclk_w = 0;
			o_oen_w = 1;
			sdat_w = data4[23-count24_r];
			count24_w = count24_r + 1;
			state_w = S_TRANSMIT_4;
		end
		S_TRANSMIT_4: begin
			sclk_w = 1;
			if(count8_r == 7) begin
				count8_w = 0;
				state_w = S_HOLD;
			end
			else begin
				count8_w = count8_r + 1;
				state_w = S_READ_4;
			end
		end
		//========== 5 =======================
		S_READ_5:begin
			sclk_w = 0;
			o_oen_w = 1;
			sdat_w = data5[23-count24_r];
			count24_w = count24_r + 1;
			state_w = S_TRANSMIT_5;
		end
		S_TRANSMIT_5: begin
			sclk_w = 1;
			if(count8_r == 7) begin
				count8_w = 0;
				state_w = S_HOLD;
			end
			else begin
				count8_w = count8_r + 1;
				state_w = S_READ_5;
			end
		end
		//========= 6 =======================
		S_READ_6:begin
			sclk_w = 0;
			o_oen_w = 1;
			sdat_w = data6[23-count24_r];
			count24_w = count24_r + 1;
			state_w = S_TRANSMIT_6;
		end
		S_TRANSMIT_6: begin
			sclk_w = 1;
			if(count8_r == 7) begin
				count8_w = 0;
				state_w = S_HOLD;
			end
			else begin
				count8_w = count8_r + 1;
				state_w = S_READ_6;
			end
		end

		S_HOLD: begin
			o_oen_w = 0;
			sclk_w = 0;
			sdat_w = 1;
			state_w = S_ACK;
		end
		S_ACK: begin
			sclk_w = 1;
			if(count24_r == 24) begin
				count24_w = 0;
				count_mode_w = count_mode_r + 1;
				//state_w = S_EXTRA_1;
				state_w = S_EXTRA_1;
			end
			else begin
				state_w = (count_mode_r == 0) ? S_READ_1:
						  (count_mode_r == 1) ? S_READ_2:
						  (count_mode_r == 2) ? S_READ_3:
						  (count_mode_r == 3) ? S_READ_4:
						  (count_mode_r == 4) ? S_READ_5: S_READ_6;
			end
		end 
		S_EXTRA_1:begin
			sclk_w = 0;
			sdat_w = 0 ;
            o_oen_w = 1 ;
			state_w = S_OUT;
		end
		// S_EXTRA_2:begin
		// 	sclk_w = 1;
		// 	state_w = S_START;
		// end
		S_OUT: begin
			 sclk_w = 1 ;
			state_w = S_IDLE;
		end
	
		default : state_w = state_r /* default */;
	endcase

end

//=========== Sequential logic ===================

always_ff @(posedge i_clk or negedge i_rst_n) begin
	if(~i_rst_n) begin
		state_r <= 0;
		finished_r <= 0;
		sclk_r <= 0;
		sdat_r <= 0;
		o_oen_r <= 1;
		count8_r <= 0;
		count24_r <= 0;
		count_mode_r <= 0;

	end else begin
		state_r <= state_w;
		finished_r <= finished_w;
		sclk_r <= sclk_w;
		sdat_r <= sdat_w;
		o_oen_r <= o_oen_w;
		count8_r <= count8_w;
		count24_r <= count24_w;
		count_mode_r <= count_mode_w;
	end
end


endmodule