library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use ieee.std_logic_arith; 
use ieee.numeric_std.all;

ENTITY ADCtoSENT IS
	PORT(
		CLOCK			: in  std_logic;
		KEY			: in  std_logic_vector (0 downto 0);
		ch0			: out std_logic_vector(11 downto 0);
		ADC_SCLK		: out std_logic;
		ADC_CS_N		: out std_logic;
		ADC_SDAT		: in  std_logic;
		ADC_SADDR	: out std_logic;
		SENT			: out std_logic;
		LED			: out std_logic_vector(7 downto 0)
	);
END ADCtoSENT;



	 
ARCHITECTURE a OF ADCtoSENT IS

	component adc_control is
		port (
			CLOCK    : in  std_logic                     := 'X'; -- clk
			RESET    : in  std_logic                     := 'X'; -- reset
			CH0      : out std_logic_vector(11 downto 0);        -- CH0
			ADC_SCLK : out std_logic;                            -- SCLK
			ADC_CS_N : out std_logic;                            -- CS_N
			ADC_DOUT : in  std_logic                     := 'X'; -- DOUT
			ADC_DIN  : out std_logic                             -- DIN
		);
	end component adc_control;
	 
	signal reset : std_logic;
	signal chan0 : std_logic_vector(11 downto 0);
	
	--State Machine--
	type   state is (init, sync, comm, data, check, pause);
	signal pe : state :=init;	--Present State
	signal ne : state; 			--Next State
	
	
	----SENT Frame Generation Signals----
	--CRC Look-Up Table:
	type  TABLE is array (0 to 15) of std_logic_vector(3 downto 0);
	constant crcLookup 	: TABLE := (x"0",x"D",x"7",x"A",x"E",x"3",x"9",x"4",x"1",x"C",x"6",x"B",x"F",x"2",x"8",x"5");
	signal calculatedCRC : std_logic_vector(3 downto 0);
	signal tmpCRC : std_logic_vector(3 downto 0);
	signal miLookActual : std_logic_vector(3 downto 0);
	--Flow Control:
	constant tickLength	: std_logic_vector(9 downto 0):="1111101000"; --1000 ticks @ 50MHz Clk. 1 SENT tick = 20us.
	signal busy 		: std_logic := '0';
	signal synced		: std_logic := '0';
	signal comm_start	: std_logic := '0';
	signal sentData	: std_logic := '0';
	signal sentCRC		: std_logic := '0';
	signal finished	: std_logic := '0';
	--Data transmission
	signal message		: std_logic_vector(11 downto 0);
	signal nibble		: std_logic_vector(3 downto 0);
	signal dataFrame	: std_logic := '0';
	signal tickCnt		: std_logic_vector(5 downto 0); --Max count will be 56 ticks.
	signal clkCnt		: std_logic_vector(9 downto 0); --Max count will be tickLength.
	signal nibbleCnt	: std_logic_vector(1 downto 0); --Max count will be 3 nibbles (messageLength/4); (12bits/4).
	signal j				: integer range 0 to 11 := 11;	--Used as an index variable to divide the 12-bits message in nibbles.
	--signal index		: integer range 1 to 3 := 1;	--Used as an index variable to divide the 12-bits message in nibbles.
	signal crcOpDone	: std_logic := '0';	--Flag. Tells if the CRC has been calculated or not.
	signal pauseCnt	: std_logic_vector(24 downto 0):= "0000000000000000000000000";
	signal tickCondition : std_logic_vector(5 downto 0) := "000000";

	

	 
BEGIN
		
	reset <= not(KEY(0));
	
	--State Machine Transition
	FSM_CLK: process(CLOCK)
	begin
		if(rising_edge(CLOCK))then
			pe<=ne;
		end if;
	end process;
	
	
	--Finite State Machine
	FSM: process(pe, reset, busy, synced, comm_start, sentData, sentCRC, finished)
	begin
		if(reset='1')then
			ne<=init;
		else
			case pe is
				when init =>
					if(busy='1')then
						ne<=sync;
					else
						ne<=init;
					end if;
				when sync =>
					if(synced='1')then
						ne<=comm;
					else
						ne<=sync;
					end if;
				when comm =>
					if(comm_start='1')then
						ne<=data;
					else
						ne<=comm;
					end if;
				when data =>
					if(sentData='1')then
						ne<=check;
					else
						ne<=data;
					end if;
				when check =>
					if(sentCRC='1')then
						ne<=pause;
					else
						ne<=check;
					end if;
				when pause =>
					if(finished='1')then
						ne<=init;
					else
						ne<=pause;
					end if;
			end case;		
		end if;
	end process;
	
	
	--SENT Frame Generation--
	process(CLOCK)
	begin
		if (rising_edge(CLOCK)) then
			if(busy='0')then
				--If the system is free... Get the ADC's data. It will be the message to transfer over SENT.
				message<=chan0;
				j<=11;
				calculatedCRC<=x"5";
				dataFrame<='1';
				nibbleCnt<="00";
				tickCnt<="000000";
				clkCnt<="0000000000";
				crcOpDone<='0';
				synced<='0';
				comm_start<='0';
				sentData<='0';
				sentCRC<='0';
				finished<='0';
				busy<='1';
			else
				if(synced='0')then
					if(tickCnt<"000101")then		--Protocol SENT: At least 5 ticks at logic '0'.
						dataFrame<='0';
						if(clkCnt<tickLength)then
							clkCnt<=clkCnt+'1';
						else
							clkCnt<="0000000000";
							tickCnt<=tickCnt+'1';
						end if;
					else
						dataFrame<='1';
						if(tickCnt<"111101")then	--Protocol SENT: Sync Pulse is 56 ticks. 5+56=61
							if(clkCnt<tickLength)then
								clkCnt<=clkCnt+'1';
							else
								clkCnt<="0000000000";
								tickCnt<=tickCnt+'1';
							end if;
						else
							tickCnt<="000000";
							clkCnt<="0000000000";
							synced<='1';
						end if;
					end if;
				else
					if(comm_start='0')then
						nibble<=message(11 downto 8);
						if(tickCnt<"000101")then		--Protocol SENT: At least 5 ticks at logic '0'.
							dataFrame<='0';
							if(clkCnt<tickLength)then
								clkCnt<=clkCnt+'1';
							else
								clkCnt<="0000000000";
								tickCnt<=tickCnt+'1';
							end if;
						else
							dataFrame<='1';
							if(tickCnt<"010001")then	--Protocol SENT: Comm Pulse is 12 ticks. 5+12=17
								if(clkCnt<tickLength)then
									clkCnt<=clkCnt+'1';
								else
									clkCnt<="0000000000";
									tickCnt<=tickCnt+'1';
								end if;
							else
								tickCnt<="000000";
								clkCnt<="0000000000";
								comm_start<='1';
							end if;
						end if;
					else
						if(sentData='0')then
							if(nibbleCnt<"11")then
								if(tickCnt<"000101")then		--Protocol SENT: At least 5 ticks at logic '0'.
									dataFrame<='0';
									if(clkCnt<tickLength)then
										clkCnt<=clkCnt+'1';
									else
										clkCnt<="0000000000";
										tickCnt<=tickCnt+'1';
									end if;
									nibble<=message(j downto j-3);
									---LO SUBO AQUI---
									if(tickCnt="000010" and clkCnt="0000000000")then
										--nibble<=message(j downto j-3);
										miLookActual<=crcLookup(to_integer(unsigned(std_logic_vector(calculatedCRC))));
										--tmpCRC<=(miLookActual xor nibble) and x"F";
										tmpCRC<=(crcLookup(to_integer(unsigned(std_logic_vector(calculatedCRC)))) xor nibble) and x"F";
									end if;

									---FIN---
								else
									if(tickCnt="000111" and clkCnt="0000000000")then
										calculatedCRC<=tmpCRC;
										--tmpCRC<=(crcLookup(to_integer(unsigned(std_logic_vector(calculatedCRC)))) xor nibble) and x"F";
									end if;
									dataFrame<='1';
									--calculatedCRC<=tmpCRC;
									---COMENTO AQUI---
									--nibble<=message(j downto j-3);
									tickCondition<=("00" & message(j downto j-3))+"000101"+"001100"; --Protocol SENT: Message is N ticks. 5+12+N. (resize(nibble,6))
									--tmpCRC<=(crcLookup(to_integer(unsigned(std_logic_vector(calculatedCRC)))) xor nibble) and x"F";
									---FIN.---
									if(tickCnt<tickCondition)then
										if(clkCnt<tickLength)then
											clkCnt<=clkCnt+'1';
										else
											clkCnt<="0000000000";
											tickCnt<=tickCnt+'1';
										end if;
									else
										if(tickCnt=tickCondition)then											
											--calculatedCRC<=tmpCRC;
											if(j>3)then --ESTO IGUAL SE PUEDE SUBIR ARRIBA.
												j<=j-4;
											end if;
											nibbleCnt<=nibbleCnt+'1';
											tickCnt<="000000";
											clkCnt<="0000000000";
											--j<=11;
										end if;
									end if;
								end if;
							else
								sentData<='1';
								tickCnt<="000000";
								clkCnt<="0000000000";
							end if;
						else
							if(sentCRC='0')then
								miLookActual<=crcLookup(to_integer(unsigned(std_logic_vector(calculatedCRC))));
								dataFrame<='0';
								
								if(tickCnt<"000101")then		--Protocol SENT: At least 5 ticks at logic '0'.
									dataFrame<='0';
									if(clkCnt<tickLength)then
										clkCnt<=clkCnt+'1';
									else
										clkCnt<="0000000000";
										tickCnt<=tickCnt+'1';
									end if;
								else
									dataFrame<='1';
									if(tickCnt<"000101"+"001100"+miLookActual)then	--Protocol SENT: CRC is 12 ticks. 5+12+CRC
										if(clkCnt<tickLength)then
											clkCnt<=clkCnt+'1';
										else
											clkCnt<="0000000000";
											tickCnt<=tickCnt+'1';
										end if;
									else
										tickCnt<="000000";
										clkCnt<="0000000000";
										sentCRC<='1';
									end if;
								end if;
							else
								if(finished='0')then
									if(tickCnt<"000101")then		--Protocol SENT: At least 5 ticks at logic '0'.
										dataFrame<='0';
										if(clkCnt<tickLength)then
											clkCnt<=clkCnt+'1';
										else
											clkCnt<="0000000000";
											tickCnt<=tickCnt+'1';
										end if;
									else
										dataFrame<='1';
										if(pauseCnt<"1011111010111100001000000")then	--PAUSE. I just want to introduce time between frames. 1 second.
											pauseCnt<=pauseCnt+'1';
										else
											pauseCnt<="0000000000000000000000000";
											busy<='0';
											finished<='1';
										end if;
									end if;
								end if;
							end if;
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;
	
	
	u0 : component adc_control
        port map (
            CLOCK    => CLOCK,		--                clk.clk
            RESET    => reset,		--              reset.reset
            CH0      => chan0,		--           readings.CH0
            ADC_SCLK => ADC_SCLK,	-- external_interface.SCLK
            ADC_CS_N => ADC_CS_N,	--                   .CS_N
            ADC_DOUT => ADC_SDAT,	--                   .DOUT
            ADC_DIN  => ADC_SADDR	--                   .DIN
        );
		  
						
		  
		  
	LED<=chan0(11 downto 4);
	ch0<=chan0;
	SENT<=dataFrame;

		  
end a;