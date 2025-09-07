/*
 * Noise Generator
 *
*/
module triangle_saw (
    /* CLOCKS */
    input  logic        clk_8khz,       /* 8 kHz clock for envelope timing */
    input  logic        clk_48khz,      /* 48 kHz audio sample clock (DAC rate) */
    input  logic        clk_50mhz,      /* 50 MHz system clock */
    input  logic        reset_n,        /* System reset signal*/

    /* REGISTER INPUTS */
    input  logic [7:0]  reg_0,          /* Envelope mode, dummmy, volume/sustain level (6 bits) */
    input  logic [7:0]  reg_1,          /* Attack time (4 bits), decay(4 bits) */
    input  logic [7:0]  reg_2,          /* Sustain 4 bits, decay 4 bits */
    input  logic [7:0]  reg_3,          /* Timer high 3 bits + stereo pan (5 bits) */
    input  logic [7:0]  reg_4,          /* Timer low 8 bits */
    input  logic [7:0]  reg_5,          /* Repeat mode 1 bit + repeat delay (2 bits) + wave type 1 triangle 0 sawtooth +  + 3 unnused */

    /* AUDIO OUTPUTS */
    output logic signed [15:0] audio_out_left,   /* Left channel 16-bit signed output */
    output logic signed [15:0] audio_out_right,  /* Right channel 16-bit signed output */

    output logic               dummy
);

assign dummy = reg_0[6];

/*Magic Numbers*/
parameter [5:0] MAX_VOL = 6'd63;

/*Register Processing for code readability*/
//Envelope Signals
wire [3:0] atk_time    = reg_1[7:4];
wire [3:0] dcy_time    = reg_1[3:0];
wire [3:0] sus_time    = reg_2[7:4];
wire [3:0] rel_time    = reg_2[3:0];
wire       env_mode    = reg_0[7];
wire [5:0] sus_vol     = reg_0[5:0];
wire       loop_flag   = reg_5[7];
wire [1:0] loop_dly    = reg_5[6:5];

//WAve Generation Signals
wire [10:0] timer      = {reg_3[7:5],reg_4};
wire wave_type         = reg_5[4];

//Panning
wire [4:0] pan         = reg_3[4:0];


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


//1024 bits movelent in a period
//saw -511,511
//triangle -255,255,-255
//0,1023
//256,768,256
//shift 1 more if square and val is less than or eqal to 768
reg [9:0] wave_out;
reg increasing;
reg [11:0] freq_div_cnt;


always_ff @(posedge clk_50mhz) begin
    if(~reset_n) begin
        wave_out <= 10'd511;
        freq_div_cnt <= 11'd0;
        increasing <= 1'b1;
    end else begin
        freq_div_cnt <= freq_div_cnt + 1;
        if (freq_div_cnt >= timer) begin
            freq_div_cnt <= 11'd0;
            //Subtract if triangle , between 767 and 255
            // Triangle: up/down; Sawtooth: always up
            wave_out <= (wave_type == 1'b0) ? wave_out + 10'd1 :
                        (increasing        ? wave_out + 10'd1 : wave_out - 10'd1);

            // Only update `increasing` if triangle wave
            increasing <= (wave_type == 1'b1) ?
                          ((increasing && wave_out >= 10'd766) ? 1'b0 :
                           (!increasing && wave_out <= 10'd256) ? 1'b1 :
                           increasing)
                         : increasing;
        end
    end
end

reg [9:0] unstable_wave_out, stable_wave_out;
always_ff @(posedge clk_48khz) begin
    unstable_wave_out <= wave_out;
    stable_wave_out <= unstable_wave_out;
end

wire signed [9:0] shifted_wave = $signed(stable_wave_out - 10'd511);
wire shift = (wave_type && shifted_wave < 10'd255 && shifted_wave > -10'sd256);

wire signed [16:0] pan_left  = (32 - pan) << 10;
wire signed [16:0] pan_right = pan << 10;
wire signed [15:0] scaled_amp;
assign scaled_amp = (shifted_wave * vol_out) <<< wave_type;

/* Update sound */
wire signed [31:0] left_channel, right_channel;
assign left_channel  = (scaled_amp * pan_left)  >>> 15;
assign right_channel = (scaled_amp * pan_right) >>> 15;

always_ff @(posedge clk_48khz) begin
    audio_out_left <= left_channel;
    audio_out_right <= right_channel;
end

endmodule
