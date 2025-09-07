module synth_core (
    input  logic         clk_50mhz,
    input  logic         clk_48khz,
    input  logic         reset_n,
    input  logic  [7:0]  regs[0:34],
    output logic         dummys[0:4],

    output logic signed [15:0] audio_out_left,
    output logic signed [15:0] audio_out_right
);

    logic [1:0] div_cnt = 0;
    logic       clk_8khz = 0;

    always_ff @(posedge clk_48khz) begin
        if (div_cnt == 2) begin
            div_cnt  <= 0;
            clk_8khz <= ~clk_8khz;   // toggle every 6 cycles of 48kHz
        end else begin
            div_cnt <= div_cnt + 1;
        end
    end

    /* Channel Instantiations */
    logic signed [15:0] p0_l, p0_r, p1_l, p1_r;
    logic signed [15:0] ts0_l, ts0_r, ts1_l, ts1_r;
    logic signed [15:0] n0_l, n0_r;

    pulse pulse0 (
        .clk_8khz(clk_8khz), .clk_48khz(clk_48khz), .clk_50mhz(clk_50mhz), .reset_n(reset_n),
        .reg_0(regs[0]),  .reg_1(regs[1]),  .reg_2(regs[2]),
        .reg_3(regs[3]),  .reg_4(regs[4]),  .reg_5(regs[5]),
        .reg_6(regs[6]),  .reg_7(regs[7]),  .reg_8(regs[8]),
        .audio_out_left(p0_l), .audio_out_right(p0_r), .dummy(dummys[0])
    );

    pulse pulse1 (
        .clk_8khz(clk_8khz), .clk_48khz(clk_48khz), .clk_50mhz(clk_50mhz), .reset_n(reset_n),
        .reg_0(regs[9]),  .reg_1(regs[10]), .reg_2(regs[11]),
        .reg_3(regs[12]), .reg_4(regs[13]), .reg_5(regs[14]),
        .reg_6(regs[15]), .reg_7(regs[16]), .reg_8(regs[17]),
        .audio_out_left(p1_l), .audio_out_right(p1_r), .dummy(dummys[1])
    );

    triangle_saw ts0 (
        .clk_8khz(clk_8khz), .clk_48khz(clk_48khz), .clk_50mhz(clk_50mhz), .reset_n(reset_n),
        .reg_0(regs[18]), .reg_1(regs[19]), .reg_2(regs[20]),
        .reg_3(regs[21]), .reg_4(regs[22]), .reg_5(regs[23]),
        .audio_out_left(ts0_l), .audio_out_right(ts0_r), .dummy(dummys[2])
    );

    triangle_saw ts1 (
        .clk_8khz(clk_8khz), .clk_48khz(clk_48khz), .clk_50mhz(clk_50mhz), .reset_n(reset_n),
        .reg_0(regs[24]), .reg_1(regs[25]), .reg_2(regs[26]),
        .reg_3(regs[27]), .reg_4(regs[28]), .reg_5(regs[29]),
        .audio_out_left(ts1_l), .audio_out_right(ts1_r), .dummy(dummys[3])
    );

    noise noise0 (
        .clk_8khz(clk_8khz), .clk_48khz(clk_48khz), .clk_50mhz(clk_50mhz), .reset_n(reset_n),
        .reg_0(regs[30]), .reg_1(regs[31]), .reg_2(regs[32]),
        .reg_3(regs[33]), .reg_4(regs[34]),
        .audio_out_left(n0_l), .audio_out_right(n0_r), .dummy(dummys[4])
    );

    /* Audio Mix and Clamp */
    logic signed [19:0] sum_l, sum_r;

    always_ff @(posedge clk_48khz) begin
        sum_l <= (p0_l >>> 2) +
                (p1_l >>> 2) +
                (ts0_l >>> 2) +
                (ts1_l >>> 2)+
                (n0_l >>> 2);

        sum_r <= (p0_r >>> 2) +
                (p1_r >>> 2)  +
                (ts0_r >>> 2) +
                (ts1_r >>> 2) +
                (n0_r >>> 2);
    end

    function automatic logic signed [15:0] clamp_to_16bit(input logic signed [19:0] val);
        if (val > 32767)
            return 16'sd32767;
        else if (val < -32768)
            return 16'sh8000;
        else
            return $signed(val[15:0]);
    endfunction

    assign audio_out_left  = clamp_to_16bit(sum_l);
    assign audio_out_right = clamp_to_16bit(sum_r);

endmodule
