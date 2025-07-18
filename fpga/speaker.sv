module speaker(
input logic                 CLOCK_50,
input logic [3:0]           KEY,
output logic [9:0] 			LEDR,

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

//AUDIO EXPORTS
assign FPGA_I2C_SDAT		= 1'bz;
assign FPGA_I2C_SCLK		= 1'bz;


logic reset_n;
assign reset_n = KEY[3];

logic CLOCK_18_4;
assign AUD_XCK = CLOCK_18_4;

logic [15:0] shoot_left, shoot_right;
logic shoot_busy;
logic shoot_go;


//////////// INSTANCES  //////////

pll pll(
			.ref_clk_clk(CLOCK_50),
			.ref_reset_reset(~reset_n),
			.audio_clk_clk(CLOCK_18_4),
			.reset_source_reset());


I2C_AV_Config aud_conf( .iCLK(CLOCK_50),
                        .iRST_N(reset_n),
                        .I2C_SCLK(FPGA_I2C_SCLK),
                        .I2C_SDAT(FPGA_I2C_SDAT)	);

AUDIO_DAC  sound(	//	Audio Side
					.AUD_BCK(AUD_BCLK),
					.AUD_DATA(AUD_DACDAT),
					.AUD_LRCK(AUD_DACLRCK),
					//	Control Signals
					.source(~KEY[1]),
				    .CLK_18_4(CLOCK_18_4),
					.RST_N(reset_n),
					// Sample Signals
					.left_sample(shoot_left),
					.right_sample(shoot_right));

shoot gun(			.clk(AUD_DACLRCK),
					.reset_n(reset_n),
					.shoot_trigger(~KEY[0]),
					.shoot_busy(LEDR[0]),
					.left_sample(shoot_left),
					.right_sample(shoot_right));


endmodule
