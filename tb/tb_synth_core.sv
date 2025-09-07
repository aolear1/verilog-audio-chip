`timescale 10ns / 1ns

module tb_synth_core;

    // Clock
    logic clk_50mhz;
    logic clk_10hz;
    logic clk_48khz, clk_8khz;
    logic reset_n = 0;
    reg eof;


    // File IO
    integer outfile;
    integer infile;
    string test_name;
    int i;

    // Audio Outputs
    logic signed [15:0] audio_out_left;
    logic signed [15:0] audio_out_right;
    logic dummys[0:4];
    logic [7:0] regs[0:35];

    // Clock generators
    initial begin clk_50mhz = 0; forever begin #1; clk_50mhz = ~clk_50mhz; end end
    initial begin clk_48khz = 0; forever begin #1042; clk_48khz = ~clk_48khz; end end
    initial begin clk_8khz = 0; forever begin #6250; clk_8khz = ~clk_8khz; end end
    initial begin clk_10hz = 0; forever begin #5000000; clk_10hz = ~clk_10hz; end end


    // DUT
   synth_core dut (
        .clk_50mhz(clk_50mhz),
        .clk_48khz(clk_48khz),
        .reset_n(reset_n),
        .regs(regs),
        .audio_out_left(audio_out_left),
        .audio_out_right(audio_out_right),
        .dummys(dummys)
    );

    // Reset task
    task rst();
        reset_n = 0;
        #12500;
        reset_n = 1;
    endtask


    // Dump audio
    always @(posedge clk_48khz) begin
        $fwrite(outfile, "%c%c%c%c",
            audio_out_left[7:0], audio_out_left[15:8],
            audio_out_right[7:0], audio_out_right[15:8]);
    end

    function logic [7:0] apply_dummy_logic(input logic [5:0] addr, input logic [7:0] val,
                                           input logic [7:0] current);
        case (addr)
            6'd0, 6'd9, 6'd18, 6'd24, 6'd30:
                apply_dummy_logic = { val[7], current[6] ^ 1'b1, val[5:0] };
            default:
                apply_dummy_logic = val;
        endcase
    endfunction


    logic [7:0] reg_index, reg_value;
    always @(posedge clk_10hz) begin
        if($feof(infile)) begin
            //do nothing and wait for sound to play out
            eof = 1'b1;
        end else begin
            while (1) begin
                if ($fread(reg_index, infile) != 1) break;

                if (reg_index == 8'hFF) begin
                    break;
                end else begin
                    if ($fread(reg_value, infile) != 1) break;
                    regs[reg_index] = apply_dummy_logic(reg_index, reg_value, regs[reg_index]);
                    $display("t=%0t: Register[%0d] <= %0d",
                            $time, reg_index, reg_value);
                end
            end
        end
    end


    initial begin
        outfile = $fopen("audio.raw", "wb");
        infile = $fopen("reg_changes.bin", "rb");
        eof = 1'b0;

        if (infile == 0) begin
            $error("Could not open reg_changes.bin for reading!");
            $stop;
        end

        for(i = 0; i <= 35; i++) begin
            regs[i] = 8'd0;
        end

        rst();

        wait (eof == 1'b1);
        repeat (48000) @(posedge clk_48khz); // 1 second extra

        $display("Test Complete. Output saved to audio.raw");
        $fclose(outfile);
        $fclose(infile);
        $stop;
    end

endmodule
