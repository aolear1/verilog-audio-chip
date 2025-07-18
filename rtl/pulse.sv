/*
 * Sqare Wave Generator for cool 8 bit sounds
 * Retriggers upon any change to registers, dummy bit can be read/negated to repeat a sound, alternativly on the softweare side,
 * a +-1 change to attack or decay time is unnoticable to alternating slightly different writes also works
 *
*/
module pulse (
    /* CLOCKS */
    input  logic        clk_8khz,       /* 8 kHz clock for envelope timing */
    input  logic        clk_48khz,      /* 48 kHz audio sample clock (DAC rate) */
    input  logic        clk_50mhz,      /* 50 MHz system clock */
    input  logic        reset_n,        /* System reset signal*/

    /* REGISTER INPUTS */
    input  logic [7:0]  reg_0,          /* Envelope mode, dummmy, volume/sustain level (6 bits) */
    input  logic [7:0]  reg_1,          /* Attack time (8 bits) */
    input  logic [7:0]  reg_2,          /* Decay time (8 bits) */
    input  logic [7:0]  reg_3,          /* Sustain time (6 bits) + Sustain Shift (2 bits) */
    input  logic [7:0]  reg_4,          /* Release Time (8 bits)*/
    input  logic [7:0]  reg_5,          /* Duty cycle index (3 bits) + stereo pan (5 bits) */
    input  logic [7:0]  reg_6,          /* Timer low 8 bits */
    input  logic [7:0]  reg_7,          /* Loop counter + reset sweep on loop + Timer high 3 bits */
    input  logic [7:0]  reg_8,          /* Sweep Enable, Sweep Negate, Sweep Shift(3) sweep period (3) */

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
wire [7:0] atk_time    = reg_1[7:0];
wire [7:0] dcy_time    = reg_2[7:0];
wire [1:0] sus_shift   = reg_3[1:0];
wire [8:0] sus_time    = reg_3[7:2] << sus_shift;
wire [7:0] rel_time    = reg_4[7:0];
wire       env_mode    = reg_0[7];
wire [5:0] sus_vol     = reg_0[5:0];
wire [3:0] loop_cnt    = reg_7[7:4];

//Sweep unit signals
wire        swp_en      = reg_8[7];       // Sweep enable
wire        swp_rst_on_loop     = reg_7[3];
wire        swp_neg     = reg_8[6];       // Sweep negate
wire [2:0]  swp_shift   = reg_8[5:3];     // Sweep shift amount
wire [3:0]  swp_period  = {1'b0,reg_8[2:0]};     // Sweep period
logic       swp_trigger;

//Square wave signals
wire [10:0]    sqr_frq_start   = {reg_7[2:0], reg_6[7:0]};
wire [2:0]     sqr_dty         = reg_5[7:5];
wire [4:0]     pan             = reg_5[4:0];

/* Envelope State Machine Logic */
enum {Swait, Sattack, Sdecay, Ssustain, Srelease} env_state;
logic [5:0] env_vol;
logic [8:0] env_time;
logic       env_trigger;
logic [39:0] env_oR;
logic signed [6:0] vol_out;
logic [3:0] loops;

assign vol_out = env_mode ? env_vol : sus_vol;

always_ff @(posedge clk_8khz) begin
    if (env_oR != {reg_0,reg_1,reg_2,reg_3,reg_4}) begin
        env_trigger <= 1'b1;
        env_oR <= {reg_0,reg_1,reg_2,reg_3,reg_4};
    end


    if(~reset_n | env_trigger) begin
        env_trigger <= 1'b0;
        env_state <= Sattack;
        env_vol <= 6'd0;
        env_time <= 8'd0;
        loops <= loop_cnt;
        env_oR <= {reg_0,reg_1,reg_2,reg_3,reg_4};
    end else begin

        case(env_state)
            Swait: begin
                env_vol <= 6'd0;
                env_time <= 9'd0;
            end

            Sattack: begin
                if(env_time >= atk_time) begin
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
                if(env_time >= dcy_time) begin
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
                if (env_time >= sus_time) begin
                    env_time <= 9'd0;
                    env_state <= Srelease;
                end else begin
                    env_time <= env_time + 1;
                end
            end

            Srelease: begin
                if(env_time >= rel_time) begin
                    env_time <= 9'd0;
                    if (env_vol == 6'd0) begin
                        env_state <= (loops > 0) ? Sattack : Swait;
                        loops <= loops - (loops > 0);
                        swp_trigger <= (loops > 0) & swp_rst_on_loop;
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

/* Sweep Unit*/
logic [9:0]             swp_period_sh, swp_div_cnt;
logic [71:0]            swp_oR;
logic                   mute;
logic [10:0]            sqr_frq;
logic signed [12:0]     frq_candidate;

assign swp_period_sh = (swp_period + 1) << 6; //add one and multiply by 64 to account for the faster input clock
assign frq_candidate = (swp_neg) ? sqr_frq - (sqr_frq_start >> swp_shift) : sqr_frq + (sqr_frq_start >> swp_shift);

always_ff @(posedge clk_8khz) begin
    if (swp_oR != {reg_0,reg_1,reg_2,reg_3,reg_4,reg_5,reg_6,reg_7,reg_8}) begin
        swp_trigger <= 1'b1;
        swp_oR <= {reg_0,reg_1,reg_2,reg_3,reg_4,reg_5,reg_6,reg_7,reg_8};
    end

    if(~reset_n | swp_trigger) begin
        swp_trigger <= 1'b0;
        sqr_frq <= sqr_frq_start;
        mute <= 1'b0;
        swp_div_cnt <= swp_period_sh;
        swp_oR <= {reg_0,reg_1,reg_2,reg_3,reg_4,reg_5,reg_6,reg_7,reg_8};
    end else begin
        swp_div_cnt <= swp_div_cnt - 1;

        if (frq_candidate < 5'd10 | frq_candidate > 10'd1023 ) begin
            mute <= 1'b1;
        end

        if (swp_div_cnt == 10'd0) begin
            swp_div_cnt <= swp_period_sh;
            if (swp_en & ~mute) begin
                sqr_frq <= frq_candidate;
            end
        end
    end
end



/* Square Wave Generator Logic*/
//Lookup Table
logic [15:0] duty_bits;
always_comb begin
    case(sqr_dty)
        3'd0: duty_bits = 16'b0110_0000_0000_0000; // ~12.5%
        3'd1: duty_bits = 16'b0111_1000_0000_0000; // ~25%
        3'd2: duty_bits = 16'b0111_1110_0000_0000; // ~37.5%
        3'd3: duty_bits = 16'b0111_1111_1000_0000; // ~50%
        3'd4: duty_bits = 16'b0111_1111_1110_0000; // ~62.5%
        3'd5: duty_bits = 16'b0111_1111_1111_1000; // ~75%
        3'd6: duty_bits = 16'b0111_1111_1111_1110; // ~87.5%
        3'd7: duty_bits = 16'b0111_1111_1111_1111; // ~93.75%
    endcase
end

//bit counter;
logic [3:0]     bit_cnt;
logic [5:0]     clk_div_cnt;
logic [10:0]    freq_div_cnt;
logic           sqr_trigger;

always_ff @(posedge clk_50mhz) begin
    if(~reset_n) begin
        clk_div_cnt <= 5'd0;
        bit_cnt <= 4'd1;
        freq_div_cnt <= 11'd0;
    end else begin
        clk_div_cnt <= clk_div_cnt + 1;

        if (clk_div_cnt == SQR_CLK_DIV) begin
            clk_div_cnt <= 5'd0;
            freq_div_cnt <= freq_div_cnt + 1;
            if (freq_div_cnt >= sqr_frq) begin
                freq_div_cnt <= 11'd0;
                bit_cnt <= bit_cnt + 1;
            end
        end
    end
end

//wave generation
wire signed [15:0] sqr_wave;
wire signed [16:0] pan_left  = (32 - pan) << 10;
wire signed [16:0] pan_right = pan << 10;
wire signed [22:0] scaled_amp;
assign sqr_wave = (vol_out == 0) ? 16'sd0 : (duty_bits[bit_cnt] ? 16'sd30000 : -16'sd30000);
assign scaled_amp = ((env_state == Swait) || mute) ? 22'sd0 : (sqr_wave * vol_out) >>> 6;

/* Update sound */
wire signed [31:0] left_channel, right_channel;
assign left_channel  = (scaled_amp * pan_left)  >>> 15;
assign right_channel = (scaled_amp * pan_right) >>> 15;

always_ff @(posedge clk_48khz) begin
    audio_out_left <= left_channel;
    audio_out_right <= right_channel;
end

endmodule
