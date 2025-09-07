/*
 * Noise Generator
 *
*/
module noise (
    /* CLOCKS */
    input  logic        clk_8khz,       /* 8 kHz clock for envelope timing */
    input  logic        clk_48khz,      /* 48 kHz audio sample clock (DAC rate) */
    input  logic        clk_50mhz,      /* 50 MHz system clock */
    input  logic        reset_n,        /* System reset signal*/

    /* REGISTER INPUTS */
    input  logic [7:0]  reg_0,          /* Envelope mode, dummmy, volume/sustain level (6 bits) */
    input  logic [7:0]  reg_1,          /* Attack time (4 bits), decay(4 bits) */
    input  logic [7:0]  reg_2,          /* Sustain 4 bits, decay 4 bits */
    input  logic [7:0]  reg_3,          /* mode flag (3 bits), timer period (5 bits)*/
    input  logic [7:0]  reg_4,          /* Repeat mode, repeat delay (2 bits) + stereo pan (5 bits) */

    /* AUDIO OUTPUTS */
    output logic signed [15:0] audio_out_left,   /* Left channel 16-bit signed output */
    output logic signed [15:0] audio_out_right,  /* Right channel 16-bit signed output */

    output logic               dummy
);

assign dummy = reg_0[6];

/*Magic Numbers*/
parameter [5:0] MAX_VOL = 6'd63;
parameter [4:0] SQR_CLK_DIV = 4'd28;

/*Register Processing for code readability*/
//Envelope Signals
wire [3:0] atk_time    = reg_1[7:4];
wire [3:0] dcy_time    = reg_1[3:0];
wire [3:0] sus_time    = reg_2[7:4];
wire [3:0] rel_time    = reg_2[3:0];
wire       env_mode    = reg_0[7];
wire [5:0] sus_vol     = reg_0[5:0];
wire       loop_flag   = reg_4[7];
wire [1:0] loop_dly    = reg_4[6:5];

//Noise Generation Signals
wire [2:0] lsfr_mode   = reg_3[7:5];
wire [4:0] timer_sel   = reg_3[4:0];

//Panning
wire [4:0] pan         = reg_4[4:0];


/* Envelope State Machine Logic */
enum {Swait, Sattack, Sdecay, Ssustain, Srelease} env_state;
logic [5:0] env_vol;
logic [12:0] env_time;
logic       env_trigger;
logic [15:0] env_oR;
logic signed [6:0] vol_out;


const bit[7:0] adsrtable[16] = '{
    8'h02, 8'h05, 8'h0F, 8'h1E,
    8'h2D, 8'h3C, 8'h46, 8'h50,
    8'h5A, 8'h64, 8'h6E, 8'h78,
    8'h8C, 8'hAA, 8'hC8, 8'hFA };

assign vol_out = env_mode ? env_vol : sus_vol;

always_ff @(posedge clk_8khz) begin
    if (env_oR != {reg_0,reg_1}) begin
        env_trigger <= 1'b1;
        env_oR <= {reg_0,reg_1};
    end


    if(~reset_n | env_trigger) begin
        env_trigger <= 1'b0;
        env_state <= Sattack;
        env_vol <= 6'd0;
        env_time <= 8'd0;
        env_oR <= {reg_0,reg_1};
    end else begin

        case(env_state)
            Swait: begin
                env_vol <= 6'd0;
                if (env_time >= (adsrtable[loop_dly << 2] << 6)) begin
                    env_time <= 9'd0;
                    env_state <= loop_flag ? Sattack : Swait;
                end else begin
                    env_time <= env_time + 1;
                end
            end

            Sattack: begin
                if(env_time >= adsrtable[atk_time]) begin
                    env_time <= 9'd0;
                    if (env_vol == MAX_VOL) begin
                        env_state <= Sdecay;
                    end else begin
                        env_vol <= env_vol + 1;
                    end
                end else begin
                    env_time <= env_time + 1;
                end
            end

            Sdecay: begin
                if(env_time >= adsrtable[dcy_time] << 6) begin
                    env_time <= 9'd0;
                    if (env_vol == sus_vol) begin
                        env_state <= Ssustain;
                    end else begin
                        env_vol <= env_vol - 1;
                    end
                end else begin
                    env_time <= env_time + 1;
                end
            end

            Ssustain: begin
                if (env_time >= (adsrtable[sus_time] << 6)) begin
                    env_time <= 9'd0;
                    env_state <= Srelease;
                end else begin
                    env_time <= env_time + 1;
                end
            end

            Srelease: begin
                if(env_time >= adsrtable[rel_time]) begin
                    env_time <= 9'd0;
                    if (env_vol == 6'd0) begin
                        env_state <= Swait;
                    end else begin
                        env_vol <= env_vol - 1;
                    end
                end else begin
                    env_time <= env_time + 1;
                end
            end
        endcase
    end
end

/* LSFR Generator Logic*/

const bit[11:0] timer_period[32] = '{
    12'h4,   12'h6,   12'h8,   12'hC,
    12'h10,  12'h18,  12'h20,  12'h30,
    12'h40,  12'h50,  12'h60,  12'h70,
    12'h80,  12'h90,  12'hA0,  12'hB5,
    12'hCA,  12'hE4,  12'hFE,  12'h13D,
    12'h17C, 12'h1BC, 12'h1FC, 12'h27B,
    12'h2FA, 12'h37C, 12'h3F8, 12'h5F5,
    12'h7F2, 12'h889, 12'hBFD, 12'hFEC
};


//lsfr declarations
reg [14:0] shift_reg_15 = 15'd1;
reg [22:0] shift_reg_23 = 15'd1;

logic [5:0]     clk_div_cnt;
logic [11:0]    freq_div_cnt;
logic           sqr_trigger;
logic feedback_15, feedback_23;

assign feedback_15 = (lsfr_mode[0]) ? shift_reg_15[0] ^ shift_reg_15[1] : shift_reg_15[0] ^ shift_reg_15[6];
assign feedback_23 = (lsfr_mode == 3'd6) ? shift_reg_23[0] ^ shift_reg_23[5] ^ shift_reg_23[17] ^ shift_reg_23[20] : shift_reg_23[0] ^ shift_reg_23[5];

always_ff @(posedge clk_50mhz) begin
    if(~reset_n) begin
        clk_div_cnt <= 5'd0;
        freq_div_cnt <= 11'd0;
    end else begin
        clk_div_cnt <= clk_div_cnt + 1;

        if (clk_div_cnt >= SQR_CLK_DIV) begin
            clk_div_cnt <= 5'd0;
            freq_div_cnt <= freq_div_cnt + 1;
            if (freq_div_cnt >= timer_period[timer_sel]) begin
                freq_div_cnt <= 11'd0;
                //update lsfr
                shift_reg_15 <= (shift_reg_15 >> 1) | (feedback_15 << 14);
                shift_reg_23 <= (shift_reg_23 >> 1) | (feedback_23 << 22);
            end
        end
    end
end

//wave generation
reg signed [15:0] noise;

always_comb begin
    case(lsfr_mode)
        3'd0: noise = shift_reg_15[0] ? 16'sd30000 : -16'sd30000;                                     // NES short mode, full swing
        3'd1: noise = shift_reg_15[0] ? 16'sd30000 : -16'sd30000;                                     // NES long mode, lower amplitude
        3'd2: noise = shift_reg_15[0] ? {shift_reg_15[14:0], 1'd0} : -{shift_reg_15[14:0], 1'd0};       // Scaled 8-bit noise from LFSR15    short mode
        3'd3: noise = shift_reg_23[0] ? 16'sd28000 : -16'sd28000;                                     // Full swing 23-bit mode
        3'd4: noise = shift_reg_23[0] ? {shift_reg_23[7:0], 8'd0} : -{shift_reg_23[7:0], 8'd0};       // 8-bit from LFSR23
        3'd5: noise = shift_reg_23[0] ? {shift_reg_23[11:0], 4'd0} : -{shift_reg_23[11:0], 4'd0};     // 12-bit from LFSR23
        3'd6: noise = shift_reg_23[0] ? {shift_reg_23[15:8], shift_reg_15[7:0]} :
                                        -{shift_reg_23[15:8], shift_reg_15[7:0]};                     // 16-bit hybrid mode
        3'd7: noise = (shift_reg_23[0] ^ shift_reg_15[0]) ? 16'sd32000 : -16'sd32000;                 // XOR mode for chaotic high-contrast
    endcase
end

reg signed [15:0] unstable_noise, stable_noise;

always_ff @(posedge clk_48khz) begin
    unstable_noise <= noise;
    stable_noise <= unstable_noise;
end


wire signed [16:0] pan_left  = (32 - pan) << 10;
wire signed [16:0] pan_right = pan << 10;
wire signed [22:0] scaled_amp;
assign scaled_amp = (stable_noise * vol_out) >>> 6;

/* Update sound */
wire signed [31:0] left_channel, right_channel;
assign left_channel  = (scaled_amp * pan_left)  >>> 15;
assign right_channel = (scaled_amp * pan_right) >>> 15;

always_ff @(posedge clk_48khz) begin
    audio_out_left <= left_channel;
    audio_out_right <= right_channel;
end

endmodule
