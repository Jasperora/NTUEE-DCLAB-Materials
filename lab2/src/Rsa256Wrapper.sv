module Rsa256Wrapper (
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

// Feel free to design your own FSM!
localparam S_GET_KEY = 0;
localparam S_GET_DATA = 1;
localparam S_WAIT_CALCULATE = 2;
localparam S_SEND_DATA = 3;

localparam S_KEY_N = 0;
localparam S_KEY_D = 1;

logic [255:0] n_r, n_w, d_r, d_w, enc_r, enc_w, dec_r, dec_w;
logic [1:0] state_r, state_w;
logic [6:0] bytes_counter_r, bytes_counter_w;
logic [4:0] avm_address_r, avm_address_w;
logic avm_read_r, avm_read_w, avm_write_r, avm_write_w;

logic rsa_start_r, rsa_start_w;
logic rsa_finished;
logic [255:0] rsa_dec;

logic key_state_r, key_state_w;

assign avm_address = avm_address_r;
assign avm_read = avm_read_r;
assign avm_write = avm_write_r;
assign avm_writedata = dec_r[247-:8];

Rsa256Core rsa256_core(
    .i_clk(avm_clk),
    .i_rst(avm_rst),
    .i_start(rsa_start_r),
    .i_a(enc_r),
    .i_d(d_r),
    .i_n(n_r),
    .o_a_pow_d(rsa_dec),
    .o_finished(rsa_finished)
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

always_comb begin
    n_w = n_r;
    d_w = d_r;
    enc_w = enc_r;
    dec_w = dec_r;
    avm_address_w = avm_address_r;
    avm_read_w = avm_read_r;
    avm_write_w = avm_write_r;
    state_w = state_r;
    bytes_counter_w = bytes_counter_r;
    rsa_start_w = rsa_start_r;

    key_state_w = key_state_r;

    case (state_r)
        S_GET_KEY: begin
            if (!avm_waitrequest) begin
                if (avm_address == STATUS_BASE && avm_readdata[RX_OK_BIT] == 1) begin
                    StartRead(RX_BASE);
                end else if (avm_address == RX_BASE) begin
                    case (key_state_r)
                        S_KEY_N: begin
                            n_w = (n_r << 8) + avm_readdata[7:0];
                            bytes_counter_w = bytes_counter_r + 1;
                            avm_address_w = STATUS_BASE;
                            if (bytes_counter_r == 31) begin
                                bytes_counter_w = 0;
                                key_state_w = S_KEY_D;
                            end
                        end
                        S_KEY_D: begin
                            d_w = (d_r << 8) + avm_readdata[7:0];
                            bytes_counter_w = bytes_counter_r + 1;
                            avm_address_w = STATUS_BASE;
                            if (bytes_counter_r == 31) begin
                                bytes_counter_w = 0;
                                state_w = S_GET_DATA;
                            end
                        end
                    endcase
                end
            end
        end
        S_GET_DATA: begin
            if (!avm_waitrequest) begin
                if (avm_address == STATUS_BASE && avm_readdata[RX_OK_BIT] == 1) begin
                    StartRead(RX_BASE);
                end else if (avm_address == RX_BASE) begin
                    enc_w = (enc_r << 8) + avm_readdata[7:0];
                    bytes_counter_w = bytes_counter_r + 1;
                    StartRead(STATUS_BASE);
                    if (bytes_counter_r == 31) begin
                        bytes_counter_w = 0;
                        state_w = S_WAIT_CALCULATE;
                        rsa_start_w = 1;
                    end
                end
            end
        end
        S_WAIT_CALCULATE: begin
            if (rsa_start_r) begin
                rsa_start_w = 0;
            end else if (rsa_finished) begin
                dec_w = rsa_dec;
                state_w = S_SEND_DATA;
            end
        end
        S_SEND_DATA: begin
            if (!avm_waitrequest) begin
                if (avm_address == STATUS_BASE && avm_readdata[TX_OK_BIT] == 1) begin
                    StartWrite(TX_BASE);
                end else if (avm_address == TX_BASE) begin
                    dec_w = (dec_r << 8);
                    bytes_counter_w = bytes_counter_r + 1;
                    StartRead(STATUS_BASE);
                    if (bytes_counter_r == 30) begin
                        bytes_counter_w = 0;
                        state_w = S_GET_DATA;
                    end
                end
            end
        end
    endcase
end

always_ff @(posedge avm_clk or posedge avm_rst) begin
    if (avm_rst) begin
        n_r <= 0;
        d_r <= 0;
        enc_r <= 0;
        dec_r <= 0;
        avm_address_r <= STATUS_BASE;
        avm_read_r <= 1;
        avm_write_r <= 0;
        state_r <= S_GET_KEY;
        bytes_counter_r <= 0;
        rsa_start_r <= 0;

        key_state_r <= S_KEY_N;
    end else begin
        n_r <= n_w;
        d_r <= d_w;
        enc_r <= enc_w;
        dec_r <= dec_w;
        avm_address_r <= avm_address_w;
        avm_read_r <= avm_read_w;
        avm_write_r <= avm_write_w;
        state_r <= state_w;
        bytes_counter_r <= bytes_counter_w;
        rsa_start_r <= rsa_start_w;

        key_state_r <= key_state_w;
    end
end

endmodule
