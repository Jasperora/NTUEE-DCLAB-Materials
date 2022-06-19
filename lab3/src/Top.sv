module Top (
	input i_rst_n,
	input i_clk,
	input i_key_0,
	input i_key_1,
	input i_key_2,
	input [3:0] i_speed, // design how user can decide mode on your own
	input i_interpolation_mode,
	input i_reverse_mode,
	// AudDSP and SRAM
	output [19:0] o_SRAM_ADDR,
	inout  [15:0] io_SRAM_DQ,
	output        o_SRAM_WE_N,
	output        o_SRAM_CE_N,
	output        o_SRAM_OE_N,
	output        o_SRAM_LB_N,
	output        o_SRAM_UB_N,
	
	// I2C
	input  i_clk_100k,
	output o_I2C_SCLK,
	inout  io_I2C_SDAT,
	
	// AudPlayer
	input  i_AUD_ADCDAT,
	inout  i_AUD_ADCLRCK,
	inout  i_AUD_BCLK,
	inout  i_AUD_DACLRCK,
	output o_AUD_DACDAT,


	//SEVENHEXDECODER (DISPLAY THE STATE)
	output [3:0] o_statenow,
	output [4:0] o_addr_display,

	// SEVENDECODER (optional display)
	// output [5:0] o_record_time,
	// output [5:0] o_play_time
	output [5:0] o_time

	// LCD (optional display)
	/*
	input        i_clk_800k,
	inout  [7:0] o_LCD_DATA,
	output       o_LCD_EN,
	output       o_LCD_RS,
	output       o_LCD_RW,
	output       o_LCD_ON,
	output       o_LCD_BLON,
	*/
	// LED
	//output  [8:0] o_ledg,
	//output [17:0] o_ledr
);

// design the FSM and states as you like
parameter S_IDLE       = 0;
parameter S_I2C        = 1;
parameter S_RECD       = 2;
parameter S_RECD_PAUSE = 3;
parameter S_PLAY       = 4;
parameter S_PLAY_PAUSE = 5;
parameter S_PLAY_STOP  = 6;
parameter S_PLAY_REVERSE = 7;

logic i2c_oen, i2c_sdat;
logic [19:0] addr_record, addr_play;
logic [15:0] data_record, data_play, dac_data;
logic [2:0] state_r, state_w;
logic i2c_valid;
logic rec_finish;
logic player_en, record_en, i2c_start;
//=== own ===============
logic [4:0] addr_display_w, addr_display_r;
logic restart;

assign o_addr_display = addr_display_r;
assign restart = (addr_play >= cur_address_r) && (state_r == S_PLAY);

//logic player_stop;
logic record_stop;

logic [5:0] record_time_r, record_time_w;
logic [5:0] play_time_r, play_time_w;
logic [23:0] recsec_counter_r, recsec_counter_w;
logic [23:0] plysec_counter_r, plysec_counter_w;
logic [19:0] cur_address_r,cur_address_w;
assign io_I2C_SDAT = (i2c_oen) ? i2c_sdat : 1'bz;
//====== own =======================================================
//assign addr_display = o_SRAM_ADDR[4:0];

assign o_SRAM_ADDR = (state_r == S_RECD) ? addr_record : addr_play[19:0];
assign io_SRAM_DQ  = (state_r == S_RECD) ? data_record : 16'dz; // sram_dq as output
assign data_play   = (state_r != S_RECD) ? io_SRAM_DQ : 16'd0; // sram_dq as input

//Display the state 
assign o_statenow = state_r;

assign o_SRAM_WE_N = (state_r == S_RECD) ? 1'b0 : 1'b1;
assign o_SRAM_CE_N = 1'b0;
assign o_SRAM_OE_N = 1'b0;
assign o_SRAM_LB_N = 1'b0;
assign o_SRAM_UB_N = 1'b0;

assign player_en = (state_r == S_PLAY) ? 1'b1 : 1'b0; 
assign record_en = (state_r == S_RECD) ? 1'b1 : 1'b0; 
assign i2c_start = (state_r == S_I2C)  ? 1'b1 : 1'b0;
assign player_stop = (state_r == S_PLAY_STOP) ? 1'b1 : 1'b0;
assign record_stop = ((state_r == S_RECD)|| (state_r == S_RECD_PAUSE)) ? 1'b0 : 1'b1;

/*********************************for led diplay********************************/
/*
assign o_ledr[15] = i_key_0;
assign o_ledr[16] = i_key_1;
assign o_ledr[17] = i_key_2;
*/
assign o_time = (state_r == S_RECD || state_r == S_RECD_PAUSE)? record_time_r[5:0]:(state_r == S_PLAY || state_r == S_PLAY_PAUSE)? play_time_r[5:0] : 6'd0;
// assign o_record_time = record_time_r[5:0];
// assign o_play_time = play_time_r[5:0];

// below is a simple example for module division
// you can design these as you like

ButtonDetector key0(
	.i_rst_n(i_rst_n),
	.i_clk(i_clk),  
	.i_key(i_key_0), 
	.o_key(key0_pressed)
);

ButtonDetector key1(
	.i_rst_n(i_rst_n),
	.i_clk(i_clk),  
	.i_key(i_key_1), 
	.o_key(key1_pressed)
);

ButtonDetector key2(
	.i_rst_n(i_rst_n),
	.i_clk(i_clk),  
	.i_key(i_key_2), 
	.o_key(key2_pressed)
);

// === I2cInitializer ===
// sequentially sent out settings to initialize WM8731 with I2C protocal
I2cInitializer init0(
	.i_rst_n(i_rst_n),
	.i_clk(i_clk_100k),
	.i_start(i2c_start),
	.o_finished(i2c_valid),
	.o_sclk(o_I2C_SCLK),
	.o_sdat(i2c_sdat),
	.o_oen(i2c_oen) // you are outputing (you are not outputing only when you are "ack"ing.)
);

// === AudDSP ===
// responsible for DSP operations including fast play and slow play at different speed
// in other words, determine which data addr to be fetch for player 
AudDSP dsp0(
	.i_rst_n(i_rst_n),
	.i_clk(i_clk),
	.i_start(player_en),
	.i_pause(!player_en),
	.i_stop(player_stop),
	.i_speed(i_speed[2:0]),
	.i_fast(i_speed[3]),
	.i_slow_0(!i_interpolation_mode && !i_speed[3]), // constant interpolation
	.i_slow_1(i_interpolation_mode && !i_speed[3]), // linear interpolation
	.i_reverse(i_reverse_mode),
	.i_compare_address(addr_record),
	.i_daclrck(i_AUD_DACLRCK),
	.i_sram_data(data_play),
	.i_restart(restart),
	.o_dac_data(dac_data),
	.o_sram_addr(addr_play)
);

// === AudPlayer ===
// receive data address from DSP and fetch data to sent to WM8731 with I2S protocal
AudPlayer player0(
	.i_rst_n(i_rst_n),
	.i_bclk(i_AUD_BCLK),//i_AUD_BCLK
	.i_daclrck(i_AUD_DACLRCK),
	.i_en(player_en), // enable AudPlayer only when playing audio, work with AudDSP
	.i_dac_data(dac_data), //dac_data
	.o_aud_dacdat(o_AUD_DACDAT)
);

// === AudRecorder ===
// receive data from WM8731 with I2S protocal and save to SRAM
AudRecorder recorder0(
	.i_rst_n(i_rst_n), 
	.i_clk(i_AUD_BCLK),//i_AUD_BCLK
	.i_lrc(i_AUD_ADCLRCK),
	.i_start(record_en),
	.i_pause(!record_en),
	.i_stop(record_stop),
	.i_data(i_AUD_ADCDAT),
	.o_address(addr_record),
	.o_data(data_record),
	//.o_finished(rec_finish)
);
/*
LCD lcd(
    .i_rst_n(i_rst_n),
    .i_clk(i_clk_800k),        
    .i_state(state_r), 
    .i_speed(i_speed),
    .i_interpolation(i_interpolation_mode),
    
    .o_LCD_DATA(o_LCD_DATA),
    .o_LCD_EN(o_LCD_EN),
    .o_LCD_RS(o_LCD_RS),
    .o_LCD_RW(o_LCD_RW),
    .o_LCD_ON(o_LCD_ON),
    .o_LCD_BLON(o_LCD_BLON)

);
*/
always_comb begin
	// design your control here
	state_w = state_r;
	record_time_w = record_time_r;
	play_time_w = play_time_r;
	recsec_counter_w = recsec_counter_r;
	plysec_counter_w = plysec_counter_r;
	addr_display_w = addr_display_r;
	cur_address_w  = addr_record;
	case (state_r)
		S_IDLE: begin
			if (key0_pressed) //key0_pressed
			begin
				state_w = S_I2C;
			end
			else begin
				state_w = S_IDLE;
			end
		end

		S_I2C: begin
			if (i2c_valid) begin
				state_w = S_RECD_PAUSE;
			end
			else begin
				state_w = S_I2C;
			end
		end

		S_RECD: begin
			if (recsec_counter_r == 24'd46000000) begin
				recsec_counter_w = 24'b0;
				record_time_w = record_time_r + 6'b1;
			end
			else begin
				recsec_counter_w = recsec_counter_r + 24'b1;
				record_time_w = record_time_r;
			end

			if (key0_pressed) begin   
				state_w = S_RECD_PAUSE;
			end
			else if (key1_pressed || key2_pressed) begin// || rec_finish) begin
				state_w = S_PLAY_PAUSE;				
			end
			else begin
				if(addr_record > 50) addr_display_w = 5;
				else                 addr_display_w = 0;
				state_w = S_RECD;
			end
		end

		S_RECD_PAUSE: begin
			if (key0_pressed) begin
				state_w = S_RECD;
			end
			else if (key1_pressed) begin
				state_w = S_PLAY;				
			end
			else if (key2_pressed) begin
				state_w = S_PLAY_PAUSE;
			end
			else begin
				state_w = S_RECD_PAUSE;
			end
		end
		
		S_PLAY: begin

			if (plysec_counter_r == 24'd46000000) begin
				plysec_counter_w = 24'b0;
				
				if(i_reverse_mode)begin 
					if(play_time_r>0)begin 
						play_time_w = play_time_r - 6'b1;
					end
					else begin 
						play_time_w = 0;
					end
				end
				else if (play_time_w >=record_time_r)begin 
					play_time_w = 0;
				end
				else begin 
					play_time_w = play_time_r + 6'b1;
				end
			end
			else begin
				plysec_counter_w = plysec_counter_r + 24'b1;
				play_time_w = play_time_r;
			end

			if (key2_pressed) begin
				state_w = S_PLAY_STOP;
			end
			else if (key1_pressed) begin
				state_w = S_PLAY_PAUSE;
			end
			else begin
				state_w = S_PLAY;
			end
		end	

		S_PLAY_PAUSE: begin
			if (key2_pressed) begin
				state_w = S_PLAY_STOP;
			end
			else if (key1_pressed) begin
				state_w = S_PLAY;
			end				
			else begin
				state_w = S_PLAY_PAUSE;
			end
		end

		S_PLAY_STOP: begin
			plysec_counter_w = 0;
			play_time_w = 0;
			if (key1_pressed) begin
				state_w = S_PLAY;
			end	
			else begin
				state_w = S_PLAY_STOP;
			end	
		end
		S_PLAY_REVERSE:begin 

		end
		default : /* default */;
	endcase
end

always_ff @(posedge i_clk or negedge i_rst_n) begin
	if (!i_rst_n) begin
		state_r <= S_IDLE;	
		record_time_r <= 6'b0;	
		play_time_r <= 6'b0;
		recsec_counter_r <= 24'b0;
		plysec_counter_r <= 24'b0;
		addr_display_r <= 0;
		cur_address_r <= 0;
	end
	else begin
		state_r <= state_w;
		record_time_r <= record_time_w;	
		play_time_r <= play_time_w;
		recsec_counter_r <= recsec_counter_w;
		plysec_counter_r <= plysec_counter_w;
		addr_display_r <= addr_display_w;
		cur_address_r <= cur_address_w;
	end
end

endmodule