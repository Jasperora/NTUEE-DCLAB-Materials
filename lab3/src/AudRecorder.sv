`timescale 1ns/10ps
module AudRecorder(
	input  		  i_rst_n,
	input  		  i_clk,
	input  		  i_lrc,
	input  		  i_start,
	input  		  i_pause,
	input  	      i_stop,
	input  		  i_data,
	output [19:0] o_address,
	output [15:0] o_data,
	output        o_finished
);

parameter S_IDLE     = 0;
parameter S_PREP     = 1;
parameter S_RECORD   = 2;
parameter S_PAUSE    = 3;
parameter S_STOP     = 4;


reg        finished_w, finished_r;
reg [4:0]  state_w, state_r, count16_w, count16_r;
reg [15:0] data_w, data_r;
reg [19:0] address_w, address_r;


assign o_data     = (count16_r == 17) ? data_r: 16'bz;
assign o_address  = address_r;
assign o_finished = finished_r;


//============ Combinational logic ==============

always_comb begin
	state_w = state_r;
	data_w = data_r;
	address_w = address_r;
	count16_w = count16_r;
	finished_w = finished_r;

	case (state_r)
		S_IDLE: begin
			finished_w = 0;
			if(i_start) begin
				state_w = S_RECORD;
			end
			else begin
				state_w = S_IDLE;
			end
		end
		S_PREP: begin
			if(i_stop) begin
				state_w = S_STOP;
			end
			else if(i_pause) begin
				state_w = S_PAUSE;
			end
			else if(i_lrc) begin
				state_w = S_RECORD;
			end
			else begin
				state_w = S_PREP;
			end
		end
		S_RECORD: begin
			if(i_stop) begin
				state_w = S_STOP;
			end
			else if(i_pause) begin
				state_w = S_PAUSE;
			end
			else if(!i_lrc) begin
				if(address_r > 1023999) begin
					address_w = 0;
					state_w = S_STOP;
				end
				else begin
					if(count16_r == 17) begin
						address_w = address_r + 1;
						count16_w = 0;
						state_w = S_PREP;
					end
					else if(count16_r == 0) begin
						count16_w = count16_r + 1;
						state_w = S_RECORD;
					end
					else begin
						data_w[15-(count16_r-1)] = i_data;
						count16_w = count16_r + 1;
						state_w = S_RECORD;
					end
				end
			end
			else begin
				state_w = S_RECORD;
			end
		end
		S_PAUSE: begin
			count16_w = 0;
			if(i_start) begin
				state_w = S_PREP;
			end
			else if(i_stop) begin
				state_w = S_STOP;
			end
			else begin
				state_w = S_PAUSE;
			end
		end
		S_STOP: begin
			finished_w = 1;
			count16_w = 0;
			state_w = S_IDLE;
		end
		default : state_w = state_r/* default */;
	endcase
end

//=========== Sequential logic ===================

always_ff @(posedge i_clk or negedge i_rst_n) begin
	if(~i_rst_n) begin
		state_r <= 0;
		data_r <= 0;
		address_r <= 0;
		count16_r <= 0;
		finished_r <= 0;


	end else begin
		state_r <= state_w;
		data_r <= data_w;
		address_r <= address_w;
		count16_r <= count16_w;
		finished_r <= finished_w;
	end
end


endmodule