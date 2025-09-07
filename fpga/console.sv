module console(
input logic                 CLOCK_50,
input logic [3:0]           KEY,
output logic [9:0] 			LEDR,
input logic [9:0]			SW,
output logic [6:0]          HEX0,
output logic [6:0]          HEX1,
output logic [6:0]          HEX2,
output logic [6:0]          HEX3,
output logic [6:0]          HEX4,


//////////// Audio //////////
input                       AUD_ADCDAT,
inout                       AUD_ADCLRCK,
inout                       AUD_BCLK,
output                      AUD_DACDAT,
inout                       AUD_DACLRCK,
output                      AUD_XCK,

//////////// I2C for Audio  //////////
output                      FPGA_I2C_SCLK,
inout                       FPGA_I2C_SDAT
);

/**/

assign AUD_DACLRCK 		= 1'bz;
assign AUD_DACDAT 		= 1'bz;
assign AUD_BCLK 		   = 1'bz;
assign AUD_XCK 		   = 1'bz;

assign FPGA_I2C_SDAT		= 1'bz;
assign FPGA_I2C_SCLK		= 1'bz;


/* Clocks */
logic AUD_CTRL_CLK, clk_48kHz, reset_n;
assign AUD_XCK = AUD_CTRL_CLK;
assign clk_48kHz = AUD_DACLRCK;

/* Register increment logic*/
logic [5:0] reg_count = 0;
logic [3:0] tens, ones;

/* register profiles */
logic [7:0] regs [0:34][0:3];   // 36 x 4 array of 8-bit regs
logic [7:0] regs_out[0:34];
logic       dummys[0:4];
logic [1:0] profile;
assign profile = SW[9:8];

task automatic copy_arr (input logic [7:0] in_array [0:34][0:3],
                         input logic [1:0] col,
                         inout logic [7:0] out_array[0:34]);
    for(int i = 0; i < 35; i++) begin
        if ( (!SW[0] && (i >= 0  && i <= 8))  ||
             (!SW[1] && (i >= 9  && i <= 17)) ||
             (!SW[2] && (i >= 18 && i <= 23)) ||
             (!SW[3] && (i >= 24 && i <= 29)) ||
             (!SW[4] && (i >= 30 && i <= 34)) ) begin

            case (i)
                0:  out_array[i] <= {in_array[i][col][7], dummys[0] ^ 1'b1, in_array[i][col][5:0]};
                9:  out_array[i] <= {in_array[i][col][7], dummys[1] ^ 1'b1, in_array[i][col][5:0]};
                18: out_array[i] <= {in_array[i][col][7], dummys[2] ^ 1'b1, in_array[i][col][5:0]};
                24: out_array[i] <= {in_array[i][col][7], dummys[3] ^ 1'b1, in_array[i][col][5:0]};
                30: out_array[i] <= {in_array[i][col][7], dummys[4] ^ 1'b1, in_array[i][col][5:0]};
                default: out_array[i] <= in_array[i][col];
            endcase
        end
    end
endtask


logic key0_d, key1_d, key2_d, key3_d, mode, mem_trigger;
/* Memory Instantiation*/
logic [6:0] addr;
logic [7:0] data, q;
logic wren;
logic [1:0] curr_reg;
enum {IDLE, WRITE, READ} mem_state;

always_comb begin
    curr_reg = (addr <= 7'd34) ? 2'd0 : (addr <= 7'd69) ? 2'd1 : (addr <= 7'd104) ? 2'd3 : 2'd4;
end

always_ff @(posedge CLOCK_50 or negedge reset_n) begin
    if (!reset_n) begin
        // clear regs
        for (int i = 0; i < 35; i++) begin
            for (int j = 0; j < 4; j++) begin
                regs[i][j] <= 8'd0;
            end
            regs_out[i] <= 8'd0;
        end
        reg_count <= 6'd0;
        mode      <= 1'b0;
        reset_n <= 1'b1;
        mem_trigger <= 1'b0;
		  addr <= 7'd0;
        data <= 8'd0;
        mem_state <= IDLE;
        LEDR[8] <= 1'b0;
    end else begin
        // synchronize keys
        key0_d <= KEY[0];
        key1_d <= KEY[1];
        key2_d <= KEY[2];
        key3_d <= KEY[3];

        mem_trigger <= 1'b0;

        // detect falling edges
        if (key0_d && !KEY[0]) begin
            unique case (mode)
                1'b0: reg_count <= (reg_count == 6'd34) ? 6'd0 : reg_count + 1;  // mode 0 action
                1'b1: copy_arr(regs, 2'd0, regs_out);

            endcase
        end else if (key1_d && !KEY[1]) begin
            unique case (mode)
                1'b0: reg_count <= (reg_count == 6'd0) ? 6'd34 : reg_count - 1;  // mode 0 action
                1'b1: copy_arr(regs, 2'd1, regs_out);
            endcase
        end else if (key2_d && !KEY[2]) begin
            unique case (mode)
                1'b0: begin
                    if(profile == 2'd3) begin
                        mem_trigger <= 1'b1;
                    end else begin
                        regs[reg_count][SW[9:8]] <= SW[7:0];                       // mode 0 action
                    end
                end
                1'b1: copy_arr(regs, 2'd2, regs_out);
            endcase
        end else if (key3_d && !KEY[3]) begin
            if (profile == 2'd3) begin
                reset_n <= 1'b0; // trigger reset
            end else begin
                mode <= ~mode;
            end
        end
		  
		  //update regs from memory if needed, write writes to memory, read reads from memory into regs
		  case(mem_state)
            IDLE: begin
                addr <= 7'd0;
                data <= regs[0][0];
                if(mem_trigger) begin
                    mem_state <= (SW[7]) ? WRITE : READ;
                    wren <= SW[7];
                end
            end

            WRITE: begin
                addr <= addr + 1'b1;
                data <= regs[(addr+1'b1)%35][(addr+1'b1)/35];
                wren <= 1'b1;
                if (addr >= 7'd104) begin
                    mem_state <= IDLE;
                    wren <= 1'd0;
                end
            end

            READ: begin
                addr <= addr + 1'b1;
                regs[(addr-1'b1)%35][(addr-1'b1)/35] <= q;
                if (addr >= 7'd105) mem_state <= IDLE;
            end
        endcase
    end
end


assign LEDR[9] = mode;
assign LEDR[7:0] = mode ? 8'd0: regs[reg_count][profile];
// assign LEDR[0] = regs_out[0][6];
// assign LEDR[1] = regs_out[9][6];
// assign LEDR[2] = regs_out[18][6];
// assign LEDR[3] = regs_out[24][6];
// assign LEDR[4] = regs_out[30][6];

logic [6:0] HEX4_out;

bit6bcd bcd(.clk(CLOCK_50), .ones(ones), .tens(tens), .count(reg_count));
hex7seg hex2(.hexIn(ones), .HEX0(HEX2), .blank(mode | (profile == 2'd3)));
hex7seg hex3(.hexIn(tens), .HEX0(HEX3), .blank(mode | (profile == 2'd3)));
hex7seg hex0(.hexIn(regs[reg_count][profile][3:0]), .HEX0(HEX0), .blank(mode | (profile == 2'd3)));
hex7seg hex1(.hexIn(regs[reg_count][profile][7:4]), .HEX0(HEX1), .blank(mode | (profile == 2'd3)));
hex7seg hex4(.hexIn(profile), .HEX0(HEX4_out), .blank(mode));

assign HEX4 = (profile == 2'd3 & !mode) ? ((SW[7]) ? 7'b0010010 : 7'b1000111): HEX4_out;


//////////// INSTANCES  //////////
logic signed [15:0] left, right;
logic DLY_RST;
//	Reset Delay Timer
Reset_Delay			r0	(
							 .iCLK(CLOCK_50),
							 .oRESET(DLY_RST));

pll  pll     (  .ref_clk_clk        (CLOCK_50),        //      ref_clk.clk
                .ref_reset_reset    (~DLY_RST),    //    ref_reset.reset
                .audio_clk_clk      (AUD_CTRL_CLK),      //    audio_clk.clk
                .reset_source_reset ());  // reset_source.reset


AUDIO_DAC  sound(	//	Audio Side
                    .AUD_BCK(AUD_BCLK),
                    .AUD_DATA(AUD_DACDAT),
                    .AUD_LRCK(AUD_DACLRCK),
                    //	Control Signals
                    .CLK_18_4(AUD_CTRL_CLK),
                    .RST_N(DLY_RST),

                    // Sample Signals
                    .left_sample(left),
                    .right_sample(right));


I2C_AV_Config aud_conf( .iCLK(CLOCK_50),
                        .iRST_N(reset_n),
                        .I2C_SCLK(FPGA_I2C_SCLK),
                        .I2C_SDAT(FPGA_I2C_SDAT));



synth_core core (   .clk_50mhz(CLOCK_50),
                    .clk_48khz(AUD_DACLRCK),
                    .reset_n(reset_n),
                    .regs(regs_out),
                    .dummys(dummys),

                    .audio_out_left(left),
                    .audio_out_right(right));



reg_ram mem (  .address(addr),
                .clock(CLOCK_50),
                .data(data),
                .wren(wren),
                .q(q));

endmodule

module hex7seg( input  logic [3:0] hexIn,
                input logic blank,
                output logic [6:0] HEX0);
    always_comb begin
        if (blank) begin
            HEX0 = 7'b1111111;
        end else begin
            case (hexIn)
                4'h0: HEX0 = 7'b1000000; // 0
                4'h1: HEX0 = 7'b1111001; // 1
                4'h2: HEX0 = 7'b0100100; // 2
                4'h3: HEX0 = 7'b0110000; // 3
                4'h4: HEX0 = 7'b0011001; // 4
                4'h5: HEX0 = 7'b0010010; // 5
                4'h6: HEX0 = 7'b0000010; // 6
                4'h7: HEX0 = 7'b1111000; // 7
                4'h8: HEX0 = 7'b0000000; // 8
                4'h9: HEX0 = 7'b0010000; // 9
                4'hA: HEX0 = 7'b0001000; // A
                4'hB: HEX0 = 7'b0000011; // b
                4'hC: HEX0 = 7'b1000110; // C
                4'hD: HEX0 = 7'b0100001; // d
                4'hE: HEX0 = 7'b0000110; // E
                4'hF: HEX0 = 7'b0001110; // F
                default: HEX0 = 7'b1111111; // blank
            endcase
        end
    end

endmodule

module bit6bcd( input logic [5:0] count,
                input logic clk,
                output logic [3:0] tens,
                output logic [3:0] ones);

    logic [5:0] old_count = 0;
    logic [13:0] bcd;
    logic [2:0] shift_count;
    logic busy;

    always_ff @(posedge clk) begin
        if (!busy && count != old_count) begin
            old_count <= count;
            bcd <= {8'd0, count};
            shift_count <= 0;
            busy <= 1;
        end else if (busy) begin
            // one iteration per clock
            bcd <=  (bcd[9:6] >= 4'd5) ? (bcd + 14'd192) << 1 : bcd << 1;
            shift_count <= shift_count + 1;

            if (shift_count == 6) begin
                busy <= 0;
                ones <= bcd[9:6];
                tens <= bcd[13:10];
            end
        end
    end
endmodule
