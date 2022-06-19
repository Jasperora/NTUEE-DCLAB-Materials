module AudDSP(
    input         i_rst_n,
    input         i_clk,
    input         i_start,
    input         i_pause,
    input         i_stop,
    input [2:0]   i_speed,
    input         i_fast,
    input         i_slow_0,
    input         i_slow_1,
    input		  i_reverse,
    input		  i_compare_address,	
    input         i_daclrck,
    input [15:0]  i_sram_data,
    input [19:0]  i_stop_addr,
    input         i_restart,
    output [15:0] o_dac_data,
    output [19:0] o_sram_addr
);

localparam S_IDLE = 0;
localparam S_PLAY = 1;
localparam S_PAUSE = 2;
logic [1:0] state;

logic prev_lrck;
logic signed [15:0] dac_data, prev_data, next_prev_data, curr_data;
logic [19:0] sram_addr, next_sram_addr;
assign o_sram_addr = sram_addr;
assign o_dac_data = (i_daclrck == 1)? dac_data: 20'bZ;

logic [2:0] speed_counter, next_speed_counter;

always_comb begin
    curr_data = i_sram_data;
    dac_data = i_sram_data;
    next_prev_data = prev_data;
    next_sram_addr = sram_addr;
    next_speed_counter = speed_counter;

    if (i_reverse) begin
        
        if(sram_addr <= i_compare_address/4)begin 
        	next_sram_addr = i_compare_address;
        end
        else begin 
        	next_sram_addr = sram_addr - 1;
        end
    end else if (i_speed == 0)begin 
    	next_sram_addr = sram_addr + 1;
    end else if (i_fast) begin
        next_sram_addr = sram_addr + (i_speed + 1);
    end else if (i_slow_0) begin
        if (speed_counter == i_speed) begin
            next_sram_addr = sram_addr + 1;
            next_speed_counter = 0;
        end else begin
            next_speed_counter = speed_counter + 1;
        end
    end else if (i_slow_1) begin
        dac_data = (prev_data * (1 + signed'(i_speed) - signed'(speed_counter)) 
		+ curr_data * signed'(speed_counter)) / signed'(1 + i_speed);
        if (speed_counter == i_speed) begin
            next_prev_data = signed'(i_sram_data);
            next_sram_addr = sram_addr + 1;
            next_speed_counter = 0;
        end else begin
            next_speed_counter = speed_counter + 1;
        end

    end 
    else begin
        next_sram_addr = sram_addr + 1;
    end

    if (next_sram_addr > i_stop_addr) begin
        next_sram_addr = next_sram_addr - i_stop_addr;
    end
end

always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        sram_addr <= 0;
        speed_counter <= 0;
        prev_data <= 0;
        state <= S_IDLE;
    end else begin
        case(state)
            S_IDLE: begin
                if (i_start) begin
                    state <= S_PLAY;
                end
            end
            S_PLAY: begin
                if (i_pause) begin
                    state <= S_PAUSE;
                end else if (i_stop || i_restart) begin
                    sram_addr <= 0;
                    speed_counter <= 0;
                    prev_data <= 0;
                    state <= S_IDLE;
                end else begin
                    if (prev_lrck == 0 && i_daclrck == 1) begin
                        prev_data <= next_prev_data;
                        sram_addr <= next_sram_addr;
                        speed_counter <= next_speed_counter;
                    end
                    prev_lrck <= i_daclrck;
                end
            end
            S_PAUSE: begin
                if (i_start) begin
                    state <= S_PLAY;
                end else if (i_stop) begin
                    state <= S_IDLE;
                    sram_addr <= 0;
                end
            end
        endcase

    end
end
endmodule
