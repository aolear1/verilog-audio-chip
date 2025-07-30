`timescale 10ns / 1ns

module tb_pulse;
    // Clocks
    logic clk_50mhz = 0;
    logic clk_8khz = 0;
    logic clk_48khz = 0;
    logic reset_n = 0;

    // Registers
    logic [7:0] reg_0, reg_1, reg_2, reg_3, reg_4;

    // File handler
    reg [4:0] test_count = 5'd0;
    integer sample_count = 0;
    integer outfile;
    string test_name;
    // Audio Outputs
    logic signed [15:0] audio_out_left;
    logic signed [15:0] audio_out_right;
    logic dummy;

    // Instantiate DUT
    pulse dut (
        .clk_50mhz(clk_50mhz),
        .clk_8khz(clk_8khz),
        .clk_48khz(clk_48khz),
        .reset_n(reset_n),
        .reg_0(reg_0), .reg_1(reg_1), .reg_2(reg_2), .reg_3(reg_3), .reg_4(reg_4),
        .audio_out_left(audio_out_left),
        .audio_out_right(audio_out_right),
        .dummy(dummy)
    );

    initial begin clk_50mhz = 0; forever #1 clk_50mhz = ~clk_50mhz; end
    initial begin clk_48khz = 0; forever #1042 clk_48khz = ~clk_48khz; end
    initial begin clk_8khz  = 0; forever #6250 clk_8khz = ~clk_8khz; end

    task rst();
        reset_n = 0;
        #12500;
        reset_n = 1;
    endtask

    task test(int suc);
        $display("%s test %0d is a %s", test_name, test_count, (suc) ? "Success" : "Failure");
        test_count = test_count + 1;
    endtask

    initial begin
        outfile = $fopen("audio.raw", "wb");
        test_name = "LFSR Mode";
        test_count = 0;

        // Fixed envelope & panning setup
        reg_0 = 8'b00111111;   // Dummy bit low initially, volume = 0
        reg_1 = 8'h88;         // Attack = 8, Decay = 8
        reg_2 = 8'h88;         // Sustain = 8, Release = 8
        reg_4 = 8'b00010000;   // No looping,

        rst();

        // Cycle through LFSR modes (0 to 7)
        for (int mode = 0; mode < 32; mode++) begin
            reg_3 = {3'd2, mode[4:0]}; // Set mode and timer_sel

            // Flip dummy bit to retrigger envelope
            reg_0[6] = ~reg_0[6];

            $display("Testing LFSR N: %0d, Dummy: %0b", mode, reg_0[6]);

            // Play for enough samples (approx 0.5s at 48kHz = 24000 samples)
            #(1042 * 24000);
        end

        $display("Total Tests Run: %0d", test_count);
        $fclose(outfile);
        $stop;
    end

    always_ff @(posedge clk_48khz) begin
        $fwrite(outfile, "%c%c%c%c",
                audio_out_left[7:0], audio_out_left[15:8],
                audio_out_right[7:0], audio_out_right[15:8]);
    end

endmodule
