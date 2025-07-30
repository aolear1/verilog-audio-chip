`timescale 10ns / 1ns

module tb_triangle_saw;

    // Clocks
    logic clk_50mhz = 0;
    logic clk_8khz = 0;
    logic clk_48khz = 0;
    logic reset_n = 0;

    // Register Inputs
    logic [7:0] reg_0, reg_1, reg_2, reg_3, reg_4, reg_5;

    // File IO
    integer outfile;
    string test_name;
    int test_count = 0;

    // Audio Outputs
    logic signed [15:0] audio_out_left;
    logic signed [15:0] audio_out_right;
    logic dummy;

    // Clock generators
    initial forever #1     clk_50mhz = ~clk_50mhz;   // 50 MHz
    initial forever #6250  clk_8khz   = ~clk_8khz;    // 8 kHz
    initial forever #1042  clk_48khz  = ~clk_48khz;   // 48 kHz

    // DUT
    triangle_saw dut (
        .clk_50mhz(clk_50mhz),
        .clk_8khz(clk_8khz),
        .clk_48khz(clk_48khz),
        .reset_n(reset_n),
        .reg_0(reg_0),
        .reg_1(reg_1),
        .reg_2(reg_2),
        .reg_3(reg_3),
        .reg_4(reg_4),
        .reg_5(reg_5),
        .audio_out_left(audio_out_left),
        .audio_out_right(audio_out_right),
        .dummy(dummy)
    );

    // Reset task
    task rst();
        reset_n = 0;
        #12500;
        reset_n = 1;
    endtask

    // Test report
    task test(int suc);
        $display("%s test %0d is a %s", test_name, test_count, (suc ? "Success" : "Failure"));
        test_count++;
    endtask

    // Dump audio
    always_ff @(posedge clk_48khz) begin
        $fwrite(outfile, "%c%c%c%c",
            audio_out_left[7:0], audio_out_left[15:8],
            audio_out_right[7:0], audio_out_right[15:8]);
    end

    initial begin
        outfile = $fopen("audio.raw", "wb");
        test_name = "tri Wave Test";
        test_count = 0;

        // Constant volume = 63 (max), no envelope (env_mode = 0), dummy = 0
        reg_0 = 8'b00111111;

        // Envelope (unused): attack, decay, sustain, release
        reg_1 = 8'h00;
        reg_2 = 8'h00;

        // Pan center (pan = 16)
        reg_3 = 8'b00010000;

        // Timer: choose middle frequency for audible tone
        reg_5[2:0] = 3'b000;       // Timer high bits
        reg_4[7:0] = 8'd1000;        // Timer low = 32 => ~750Hz wave
        reg_5[7:5] = 3'b100;       // repeat, delay = 0

        rst();

        // -------------------------------
        // Triangle Wave: 1 second
        // -------------------------------
        reg_5[4] = 1'b1;   // wave_type = 1 = triangle
        reg_0[6] = ~reg_0[6]; // Toggle dummy bit to retrigger
        $display("Running Triangle Wave...");
        #(1042 * 48000);  // 1 second at 48kHz

        // -------------------------------
        // Sawtooth Wave: 1 second
        // -------------------------------
        reg_5[4] = 1'b0;   // wave_type = 0 = sawtooth
        reg_0[6] = ~reg_0[6]; // Toggle dummy again
        $display("Running Sawtooth Wave...");
        #(1042 * 48000);  // 1 second at 48kHz

        $display("Test Complete. Output saved to audio.raw");
        $fclose(outfile);
        $stop;
    end

endmodule
