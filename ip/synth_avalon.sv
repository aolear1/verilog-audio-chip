module synth_avalon (
    input  logic         clk_50mhz,
    input  logic         clk_48khz,
    input  logic         reset_n,

    // Avalon-MM slave interface
    input  logic  [5:0]  avs_address,
    input  logic         avs_write,
    input  logic [7:0]   avs_writedata,
    input  logic         avs_chipselect,

    // Audio outputs
    output logic signed [15:0] audio_out_left,
    output logic signed [15:0] audio_out_right
);

    logic [7:0] regs[0:35];

    logic dummy_en;
    always_comb begin
        case (avs_address)
            6'd0, 6'd9, 6'd18, 6'd24, 6'd30: dummy_en = 1'b1;
            default: dummy_en = 1'b0;
        endcase
    end

    always_ff @(posedge clk_50mhz) begin
        if (!reset_n) begin
            for (int i = 0; i < 36; i++) regs[i] <= 8'd0;
        end else if (avs_write & avs_chipselect & avs_address <= 6'd35) begin
            if (dummy_en) begin
                regs[avs_address] <= {
                    avs_writedata[7],                        // bit 7 from new data
                    regs[avs_address][6] ^ 1'b1,             // toggle bit 6
                    avs_writedata[5:0]                       // rest from new data
                };
            end else begin
                regs[avs_address] <= avs_writedata;
            end
        end
    end

    synth_core core (
        .clk_50mhz(clk_50mhz),
        .clk_48khz(clk_48khz),
        .reset_n(reset_n),
        .regs(regs),
        .audio_out_left(audio_out_left),
        .audio_out_right(audio_out_right)
    );

endmodule
