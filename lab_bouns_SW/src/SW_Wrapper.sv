
`define REF_MAX_LENGTH              128
`define READ_MAX_LENGTH             128

`define REF_LENGTH                  128
`define READ_LENGTH                 128

//* Score parameters
`define DP_SW_SCORE_BITWIDTH        10

`define CONST_MATCH_SCORE           1
`define CONST_MISMATCH_SCORE        -4
`define CONST_GAP_OPEN              -6
`define CONST_GAP_EXTEND            -1

module SW_Wrapper (
    input         avm_rst,
    input         avm_clk,
    output  [4:0] avm_address,
    output        avm_read,
    input  [31:0] avm_readdata,
    output        avm_write,
    output [31:0] avm_writedata,
    input         avm_waitrequest
);

localparam RX_BASE     = 0*4;
localparam TX_BASE     = 1*4;
localparam STATUS_BASE = 2*4;
localparam TX_OK_BIT   = 6;
localparam RX_OK_BIT   = 7;

logic [1:0] state_r, state_w;
localparam S_GET_DATA = 0;
localparam S_WAIT_CALAULATE = 1;
localparam S_SEND_DATA = 2;

logic [`REF_LENGTH + `READ_LENGTH -1:0] sequence_ref_r, sequence_ref_w, sequence_read_r, sequence_read_w;
logic sw_o_ready, sw_o_finished;
logic sw_i_ready_r, sw_i_ready_w;
logic sw_i_valid_r, sw_i_valid_w;

logic [$clog2(`REF_LENGTH)-1:0] sw_row;
logic [$clog2(`READ_LENGTH)-1:0] sw_col;
logic signed [`DP_SW_SCORE_BITWIDTH-1:0] sw_score;

logic [6:0] bytes_counter_r, bytes_counter_w;

logic [4:0] avm_address_r, avm_address_w;
logic avm_read_r, avm_read_w, avm_write_r, avm_write_w;

logic data_state_r, data_state_w;
localparam S_DATA_REF = 0;
localparam S_DATA_READ = 1;

logic [255:0] ans_r, ans_w;

logic [$clog2(`REF_MAX_LENGTH):0] length_r, length_w;

assign avm_address = avm_address_r;
assign avm_read = avm_read_r;
assign avm_write = avm_write_r;
assign avm_writedata = ans_r[247-:8];

// Feel free to design your own FSM!

// Remember to complete the port connection
SW_core sw_core(
    .clk				(avm_clk),
    .rst				(avm_rst),

	.o_ready			(sw_o_ready),
    .i_valid			(sw_i_valid_r),
    .i_sequence_ref		(sequence_ref_r),
    .i_sequence_read	(sequence_read_r),
    .i_seq_ref_length	(length_r),
    .i_seq_read_length	(length_r),
    
    .i_ready			(sw_i_ready_r),
    .o_valid			(sw_finished),
    .o_alignment_score	(sw_score),
    .o_column			(sw_col),
    .o_row				(sw_row)
);

task StartRead;
    input [4:0] addr;
    begin
        avm_read_w = 1;
        avm_write_w = 0;
        avm_address_w = addr;
    end
endtask
task StartWrite;
    input [4:0] addr;
    begin
        avm_read_w = 0;
        avm_write_w = 1;
        avm_address_w = addr;
    end
endtask

// TODO
always_comb begin
    state_w = state_r;
    sequence_ref_w = sequence_ref_r;
    sequence_read_w = sequence_read_r;
    sw_i_ready_w = sw_i_ready_r;
    sw_i_valid_w = sw_i_valid_r;
    data_state_w = data_state_r;
    ans_w = ans_r;
    avm_address_w = avm_address_r;
    avm_read_w = avm_read_r;
    avm_write_w = avm_write_r;
    bytes_counter_w = bytes_counter_r;
    length_w = length_r;

    case(state_r)
        S_GET_DATA:begin
            if(!avm_waitrequest)begin
                if(avm_address == STATUS_BASE && avm_readdata[RX_OK_BIT] == 1)begin
                    StartRead(RX_BASE);
                end
                else if (avm_address == RX_BASE)begin
                    case(data_state_r)
                        S_DATA_REF:begin
                            sequence_ref_w = (sequence_ref_r << 8) + avm_readdata[7:0];
                            bytes_counter_w = bytes_counter_r + 1;
                            StartRead(STATUS_BASE);
                            if(bytes_counter_r == 31)begin
                                bytes_counter_w = 0;
                                data_state_w = S_DATA_READ;
                            end
                        end
                        S_DATA_READ:begin
                             sequence_read_w = (sequence_read_r << 8) + avm_readdata[7:0];
                            bytes_counter_w = bytes_counter_r + 1;
                            StartRead(STATUS_BASE);
                            if(bytes_counter_r == 31)begin
                                bytes_counter_w = 0;
                                state_w = S_WAIT_CALAULATE;
                                sw_i_valid_w = 1;
                                data_state_w = S_DATA_REF;
                            end
                        end
                    endcase
                end
                       
            end
        end
        S_WAIT_CALAULATE:begin
            sw_i_ready_w = 1;
            if(sw_i_valid_r)begin
                sw_i_valid_w = 0;
            end
            else if(sw_finished)begin
                state_w = S_SEND_DATA;
                ans_w = {8'b0,56'b0,57'b0,sw_col,57'b0,sw_row,54'b0,sw_score};
                sw_i_ready_w = 0;
            end
        end
        S_SEND_DATA:begin
            if(!avm_waitrequest)begin
                if(avm_address == STATUS_BASE && avm_readdata[TX_OK_BIT] == 1)begin
                    StartWrite(TX_BASE);
                end
                else if(avm_address == TX_BASE)begin
                    ans_w = ans_r << 8;
                    bytes_counter_w = bytes_counter_r + 1;
                    StartRead(STATUS_BASE);
                    if(bytes_counter_r == 30)begin
                        bytes_counter_w = 0;
                        state_w = S_GET_DATA;
                    end
                end
            end
        end
    endcase
end

// TODO
always_ff @(posedge avm_clk or posedge avm_rst) begin
    if (avm_rst) begin
        state_r <= S_GET_DATA;
    	sequence_ref_r <= 0;
        sequence_read_r <= 0;
        sw_i_ready_r <= 0;
        sw_i_valid_r <= 0;
        data_state_r <= S_DATA_REF;
        ans_r <= 0;
        avm_address_r <= STATUS_BASE;
        avm_read_r <= 1;
        avm_write_r <= 0;
        bytes_counter_r <= 0;
        length_r <= `REF_LENGTH;
    end
	else begin
    	state_r <= state_w;
    	sequence_ref_r <= sequence_ref_w;
        sequence_read_r <= sequence_read_w;
        sw_i_ready_r <= sw_i_ready_w;
        sw_i_valid_r <= sw_i_valid_w;
        data_state_r <= data_state_w;
        ans_r <= ans_w;
        avm_address_r <= avm_address_w;
        avm_read_r <= avm_read_w;
        avm_write_r <= avm_write_w;
        bytes_counter_r <= bytes_counter_w;
        length_r <= length_w;
    end
end

endmodule
