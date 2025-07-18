`timescale 10ns / 1ns

module tb_pulse;
    // Clocks
    logic clk_50mhz = 0;
    logic clk_8khz = 0;
    logic clk_48khz = 0;
    logic reset_n = 0;

    // Registers
    logic [7:0] reg_0, reg_1, reg_2, reg_3, reg_4, reg_5, reg_6, reg_7, reg_8;


    // File handler
    reg [4:0] test_count = 5'd0;
    integer sample_count = 0;
    integer outfile;
    string test_name;
    // Audio Outputs
    logic signed [15:0] audio_out_left;
    logic signed [15:0] audio_out_right;
    logic dummy, bruh;

    // Instantiate your design
    pulse dut (
        .clk_50mhz(clk_50mhz),
        .clk_8khz(clk_8khz),
        .clk_48khz(clk_48khz),
        .reset_n(reset_n),
        .reg_0(reg_0), .reg_1(reg_1), .reg_2(reg_2), .reg_3(reg_3),
        .reg_4(reg_4), .reg_5(reg_5), .reg_6(reg_6), .reg_7(reg_7), .reg_8(reg_8),
        .audio_out_left(audio_out_left),
        .audio_out_right(audio_out_right),
        .dummy(dummy)
    );

    initial begin clk_50mhz = 0; forever begin #1; clk_50mhz = ~clk_50mhz; end end
    initial begin clk_48khz = 0; forever begin #1042; clk_48khz = ~clk_48khz; end end
    initial begin clk_8khz = 0; forever begin #6250; clk_8khz = ~clk_8khz; end end

    task rst();
        reset_n = 0;
        #12500;
        reset_n = 1;
    endtask

    task test(int suc);
        $display("%s test %d is a %s", test_name, test_count, (suc) ? "Success" : "Failure");
        test_count = test_count+1;
    endtask

    initial begin

        outfile = $fopen("audio.raw", "wb");
        test_count = 0;

        // Set test register values
        reg_0 = 8'b10_100000;   // Envelope mode, volume
        reg_1 = 8'd10;          // Attack time
        reg_2 = 8'd10;          // Decay time
        reg_3 = 8'b010100_00;  // Sustain time + shift
        reg_4 = 8'd60;          // Release time
        reg_5 = 8'b100_10000;   // Duty + pan
        reg_6 = 8'd30;         // Timer low
        reg_7 = 8'b0001_0_000; // Timer high
        reg_8 = 8'b1_0_000_010;   //sweep

        rst();

         #(1042*3*24000);

         $display("Test Count: %d", test_count);
        $fclose(outfile);
        $stop;
    end

    always_ff @(posedge clk_48khz) begin
        $fwrite(outfile, "%c%c%c%c",
                audio_out_left[7:0], audio_out_left[15:8],   // Left channel, little-endian
                audio_out_right[7:0], audio_out_right[15:8]  // Right channel, little-endian
        );
        $display("Left: %d, Right %d", audio_out_left, audio_out_right);
        if(audio_out_left < -9844) test_count <= test_count+1;
    end

    // always_ff @(negedge clk_48khz) begin
    //     $fwrite(outfile, "%c%c",audio_out_right[7:0], audio_out_right[15:8]);
    // end
endmodule
