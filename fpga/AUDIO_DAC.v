module AUDIO_DAC (	//	Audio Signals
					AUD_BCK,
					AUD_DATA,
					AUD_LRCK,
					//	Control Signals
				    CLK_18_4,
					RST_N,
					//	Sound Signals
					left_sample,
					right_sample
					);

					parameter	SIN_SAMPLE_DATA	=	48;
parameter	REF_CLK			=	18432000;	//	18.432	MHz
parameter	SAMPLE_RATE		=	48000;		//	48		KHz
parameter	DATA_WIDTH		=	16;			//	16		Bits
parameter	CHANNEL_NUM		=	2;			//	Dual Channel


//	Audio Signals
output			AUD_DATA;
output			AUD_LRCK;
output	reg		AUD_BCK;
//	Control Signals
input			CLK_18_4;
input			RST_N;

//Sound Signals
input[15:0]			left_sample;
input[15:0]			right_sample;

//	Internal Registers and Wires
reg		[3:0]	BCK_DIV;
reg		[8:0]	LRCK_1X_DIV;
reg		[7:0]	LRCK_2X_DIV;
reg		[6:0]	LRCK_4X_DIV;
reg		[3:0]	SEL_Cont;
reg		[5:0]	SIN_Cont;


////////////////////////////////////
reg		[DATA_WIDTH-1:0]	Sin_Out;
reg							LRCK_1X;
reg							LRCK_2X;
reg							LRCK_4X;

////////////	AUD_BCK Generator	//////////////
always@(posedge CLK_18_4 or negedge RST_N)
begin
	if(!RST_N)
	begin
		BCK_DIV		<=	0;
		AUD_BCK	<=	0;
	end
	else
	begin
		if(BCK_DIV >= REF_CLK/(SAMPLE_RATE*DATA_WIDTH*CHANNEL_NUM*2)-1 )
		begin
			BCK_DIV		<=	0;
			AUD_BCK	<=	~AUD_BCK;
		end
		else
		BCK_DIV		<=	BCK_DIV+1;
	end
end
//////////////////////////////////////////////////
////////////	AUD_LRCK Generator	//////////////
always@(posedge CLK_18_4 or negedge RST_N)
begin
	if(!RST_N)
	begin
		LRCK_1X_DIV	<=	0;
		LRCK_2X_DIV	<=	0;
		LRCK_4X_DIV	<=	0;
		LRCK_1X		<=	0;
		LRCK_2X		<=	0;
		LRCK_4X		<=	0;
	end
	else
	begin
		//	LRCK 1X
		if(LRCK_1X_DIV >= REF_CLK/(SAMPLE_RATE*2)-1 )
		begin
			LRCK_1X_DIV	<=	0;
			LRCK_1X	<=	~LRCK_1X;
		end
		else
		LRCK_1X_DIV		<=	LRCK_1X_DIV+1;
		//	LRCK 2X
		if(LRCK_2X_DIV >= REF_CLK/(SAMPLE_RATE*4)-1 )
		begin
			LRCK_2X_DIV	<=	0;
			LRCK_2X	<=	~LRCK_2X;
		end
		else
		LRCK_2X_DIV		<=	LRCK_2X_DIV+1;
		//	LRCK 4X
		if(LRCK_4X_DIV >= REF_CLK/(SAMPLE_RATE*8)-1 )
		begin
			LRCK_4X_DIV	<=	0;
			LRCK_4X	<=	~LRCK_4X;
		end
		else
		LRCK_4X_DIV		<=	LRCK_4X_DIV+1;
	end
end
assign	AUD_LRCK	=	LRCK_1X;

//////////	Sin LUT ADDR Generator	//////////////
always@(negedge LRCK_1X or negedge RST_N)
begin
	if(!RST_N)
	SIN_Cont	<=	0;
	else
	begin
		if(SIN_Cont < SIN_SAMPLE_DATA-1 )
		SIN_Cont	<=	SIN_Cont+1;
		else
		SIN_Cont	<=	0;
	end
end

//////////	16 Bits PISO MSB First	//////////////
always@(negedge AUD_BCK or negedge RST_N)
begin
	if(!RST_N)
	SEL_Cont	<=	0;
	else
	SEL_Cont	<=	SEL_Cont+1;
end
assign	AUD_DATA	= 	(LRCK_1X) ? right_sample[~SEL_Cont] : left_sample[~SEL_Cont];



endmodule



