module Rsa256Core (
	input          i_clk,
	input          i_rst,
	input          i_start,
	input  [255:0] i_a, // cipher text y
	input  [255:0] i_d, // private key
	input  [255:0] i_n,
	output [255:0] o_a_pow_d, // plain text x
	output         o_finished
);

// operations for RSA256 decryption

localparam S_IDLE = 2'd0;
localparam S_PROC = 2'd1;
localparam S_MONT = 2'd2;
localparam S_ENDL = 2'd3;

//Name
logic [1:0] state_core_w, state_core_r;
logic [255:0] anscore_w, anscore_r;
logic [257:0] ansmamt_w, ansmamt_r;
logic [257:0] ansmamtt_w, ansmamtt_r;
logic [257:0] ansmatt_w, ansmatt_r;
logic [257:0] ansmp_w, ansmp_r;
logic o_finished_w, o_finished_r;
//
logic [257:0] t_w, t_r;
logic [9:0] counter_prep_w, counter_prep_r;
//
logic [9:0] counter_mont_w, counter_mont_r;
logic [9:0] counter_inmt_w, counter_inmt_r;
logic [9:0] counter_intt_w, counter_intt_r;
logic [255:0] i_d_r,i_d_w,i_n_r,i_n_w;
//

//Assign
assign o_a_pow_d = anscore_r;
assign o_finished = o_finished_r;
//

//
always_comb begin
	//Init
	i_d_w = i_d_r;
	i_n_w = i_n_r;
	ansmp_w = ansmp_r;
	ansmamt_w = ansmamt_r;
	ansmamtt_w = ansmamtt_r;
	ansmatt_w = ansmatt_r;
	counter_prep_w = counter_prep_r;
	counter_mont_w = counter_mont_r;
	counter_inmt_w = counter_inmt_r;
	counter_intt_w = counter_intt_r;
	anscore_w = anscore_r;
	o_finished_w = o_finished_r;
	state_core_w = state_core_r;
	t_w = t_r;
	//
	case (state_core_r)
	S_IDLE:begin
		if(i_start)begin
			ansmp_w = i_a;
			state_core_w = S_PROC;
			i_d_w = i_d;
			i_n_w = i_n;
		end
		else begin
			state_core_w = S_IDLE;
			o_finished_w = 1'b0;
			anscore_w    = 258'd0;
			t_w = 258'd0;
			counter_prep_w = 10'd0;
			counter_mont_w = 10'd0;
			counter_inmt_w = 10'd0;
			counter_intt_w = 10'd0;
			ansmamt_w = 258'd0;
			ansmamtt_w = 258'd0;
			ansmatt_w = 258'd0;
			i_d_w = 256'd0;
			i_n_w = 256'd0;
		end
	end
	S_PROC:begin
		if(counter_prep_r < 10'd257)begin
			if(counter_prep_r == 10'd256)begin
				t_w = ((t_r + ansmp_r) >= i_n_r) ? t_r + ansmp_r - i_n_r : t_r + ansmp_r;
				ansmp_w = ((ansmp_r + ansmp_r) > i_n_r) ? ansmp_r + ansmp_r - i_n_r : ansmp_r + ansmp_r;
				counter_prep_w = counter_prep_r + 1;
			end
			else begin
				ansmp_w = ((ansmp_r + ansmp_r) > i_n_r) ? ansmp_r + ansmp_r - i_n_r : ansmp_r + ansmp_r;
				counter_prep_w = counter_prep_r + 1;
			end
		end
		else begin
			counter_prep_w = 10'd0;
			state_core_w = S_MONT;
			anscore_w = 258'd1;
		end
	end
	S_MONT:begin
		if(counter_mont_r < 10'd256)begin
			if(i_d_r[counter_mont_r])begin
				if(counter_inmt_r < 10'd256)begin
					ansmamt_w = (anscore_r[counter_inmt_r]) ? 
					(((ansmamt_r + t_r) % 2) ? ((ansmamt_r + t_r + i_n_r) >> 1) : ((ansmamt_r + t_r) >> 1)) 
					: ((ansmamt_r % 2) ? ((ansmamt_r + i_n_r) >> 1) : (ansmamt_r >> 1));

					ansmamtt_w = (t_r[counter_inmt_r]) ? 
					(((ansmamtt_r + t_r) % 2) ? ((ansmamtt_r + t_r + i_n_r) >> 1) : ((ansmamtt_r + t_r) >> 1)) 
					: ((ansmamtt_r % 2) ? ((ansmamtt_r + i_n_r) >> 1) : (ansmamtt_r >> 1));
					
					counter_inmt_w = counter_inmt_r + 1;
				end
				else begin
					anscore_w = (ansmamt_r >= i_n_r) ? ansmamt_r - i_n_r : ansmamt_r;
					t_w = (ansmamtt_r >= i_n_r) ? ansmamtt_r - i_n_r : ansmamtt_r;
					counter_mont_w = counter_mont_r + 1;
					counter_inmt_w = 10'd0;
					ansmamtt_w = 258'd0;
					ansmamt_w = 258'd0;
				end
			end
			else begin
				if(counter_intt_r < 10'd256)begin
					ansmatt_w = (t_r[counter_intt_r]) ? 
					(((ansmatt_r + t_r) % 2) ? ((ansmatt_r + t_r + i_n_r) >> 1) : ((ansmatt_r + t_r) >> 1)) 
					: ((ansmatt_r % 2) ? ((ansmatt_r + i_n_r) >> 1) : (ansmatt_r >> 1));
					counter_intt_w = counter_intt_r + 1;
				end
				else begin
					t_w = (ansmatt_r >= i_n_r) ? ansmatt_r - i_n_r : ansmatt_r;
					counter_mont_w = counter_mont_r + 1;
					ansmatt_w = 258'd0;
					counter_intt_w = 10'd0;
				end
			end
		end
		else begin
			state_core_w = S_IDLE;
			o_finished_w = 1'b1;
		end
	end
	endcase
end
//

always_ff @(posedge i_clk or posedge i_rst)begin
	if(i_rst)begin
		ansmp_r <= 258'd0;
		o_finished_r <= 1'b0;
		anscore_r    <= 258'd0;
		state_core_r <= 2'd0;
		t_r <= 258'd0;
		counter_prep_r <= 10'd0;
		counter_mont_r <= 10'd0;
		counter_inmt_r <= 10'd0;
		counter_intt_r <= 10'd0;
		ansmamt_r <= 258'd0;
		ansmamtt_r <= 258'd0;
		ansmatt_r <= 258'd0;
		i_d_r <= 0;
		i_n_r <= 0;
	end
	else begin
		ansmp_r <= ansmp_w;
		o_finished_r <= o_finished_w;
		anscore_r <= anscore_w;
		state_core_r <= state_core_w;
		t_r <= t_w;
		counter_prep_r <= counter_prep_w;
		counter_mont_r <= counter_mont_w;
		counter_inmt_r <= counter_inmt_w;
		counter_intt_r <= counter_intt_w;
		ansmamt_r <= ansmamt_w;
		ansmamtt_r <= ansmamtt_w;
		ansmatt_r <= ansmatt_w;
		i_d_r <= i_d_w;
		i_n_r <= i_n_w;
	end
end
endmodule