library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

architecture rtl of swled is
	-- Flags for display on the 7-seg decimal points
	signal flags                   : std_logic_vector(3 downto 0);
	signal checksum : std_logic_vector(15 downto 0) := (others => '0');
	-- Registers implementing the channels
	----------------------------------------
	-- To be corrected
	constant ack1 : std_logic_vector(31 downto 0) := "10010111011011000110001010011001";
	constant ack2 : std_logic_vector(31 downto 0) := "10011001010001100011011011101001";
	constant send_channel : std_logic_vector(6 downto 0) := "0000110";
	constant recv_channel : std_logic_vector(6 downto 0) := "0000111"; 
	constant coords : std_logic_vector(31 downto 0) := "11111111111111111111111100010010";
	constant K : std_logic_vector(31 downto 0) := "00000000000000000000000000000001";
	constant T0, T1 : std_logic_vector(8 downto 0) := "000010000";
	signal reset_signal : std_logic_vector(31 downto 0) := "00001110000011010000110000001011";
	-----------------
	signal output_send : std_logic_vector(31 downto 0) := (others => '0');
	signal counter_send, counter_send_faulty : std_logic_vector(2 downto 0) := (others => '0');
	signal start_send, done_send, enable_send : std_logic := '0';

	-----------------
	signal inp_data : std_logic_vector(31 downto 0) := (others => '0');
	signal counter_input : std_logic_vector(1 downto 0) := (others => '0');
	signal start_input, done_input, enable_input : std_logic := '0';

	-----------------
	signal out_data : std_logic_vector(31 downto 0) := (others => '0');
	signal counter_enc : std_logic_vector(5 downto 0) := (others => '0');
	signal enable_enc, start_encryption, done_encryption : std_logic := '0';
	signal N1 : std_logic_vector(5 downto 0) := (others => '0');
	signal i_enc : std_logic_vector(5 downto 0) := (others => '0');
	signal T_enc : std_logic_vector(3 downto 0) := (others => '0');
	signal dC : std_logic_vector(31 downto 0) := (others => '0');

	----------------
	signal counter_dec : std_logic_vector(5 downto 0) := (others => '0');
	signal enable_dec, start_decryption, done_decryption : std_logic := '0';
	signal N0 : std_logic_vector(5 downto 0) := (others => '0');
	signal i_dec : std_logic_vector(5 downto 0) := (others => '0');
	signal T_dec : std_logic_vector(3 downto 0) := (others => '0');
	signal dP : std_logic_vector(31 downto 0) := (others => '0');

	-----------------
	signal current_time, timer : std_logic_vector(8 downto 0) := (others => '0');
	signal enable_timer, start_timer, done_timer : std_logic := '0';
	signal d  : std_logic_vector(25 downto 0)  := (others => '0');

	-----------------
	signal state : std_logic_vector(5 downto 0) := "000001";
	signal info : std_logic_vector(63 downto 0) := (others => '0');
	signal rstate : std_logic_vector(1 downto 0) := (others => '0');

	------------------
	signal out_display : std_logic_vector(191 downto 0)  := (others => '0');
	signal counter_compute : integer range 0 to 22 := 0; 
	signal start_compute, done_compute, enable_compute : std_logic := '0';

	------------------
	signal start_display, done_display, enable_display : std_logic := '0';
	signal macro_state : std_logic_vector(4 downto 0) := "00001";
	signal do_fpga, do_uart, do_update : std_logic := '0';
	signal update_data : std_logic_vector(7 downto 0) := (others => '0');
	----------------------------------------------------
	component uart_tx_c is
	port(
	  sys_clk: in std_logic; -- 100 MHz system clock
	  data_in: in std_logic_vector(7 downto 0);
	  uart_tx: out std_logic;
	  start: in std_logic;
	  reset_btn: in std_logic
	);
	end component;

	component uart_rx_c is
	port(
	  sys_clk: in std_logic; -- 100 MHz system clock
	  data_recv: out std_logic_vector(7 downto 0);
	  uart_rx: in std_logic;
	  ready: out std_logic;
	  reset_btn: in std_logic
	);
	end component;

	signal reset: std_logic := '0';
	signal uart_rx_data: std_logic_vector(7 downto 0);
	signal uart_rx_enable: std_logic;
	signal uart_tx_data: std_logic_vector(7 downto 0);
	signal uart_tx_enable: std_logic;
	signal uart_tx_ready: std_logic;
	signal send_data, recv_data : std_logic_vector(7 downto 0);
	signal tx_reset, rx_reset : std_logic := '1'; 
	signal start_tx, ready_rx : std_logic := '0';
	-----------------------------------------------------------------

begin 
	
	tx_inst : uart_tx_c
	port map(
	  sys_clk => clk_in, -- 100 MHz system clock
	  data_in => send_data,
	  uart_tx => uart_tx,
	  start => start_tx,
	  reset_btn => tx_reset
	);

	rx_inst : uart_rx_c
	port map(
	  sys_clk => clk_in, -- 100 MHz system clock
	  data_recv => recv_data,
	  uart_rx => uart_rx,
	  ready => ready_rx,
	  reset_btn => rx_reset
	);

    ------------------------------------------------------------------
    --BEGIN_SNIPPET(registers)
	-- Infer registers
	process(clk_in, reset_in)
	begin
		if(reset_in = '1') then
			state <= "000001";
			led_out <= "00000000";
			timer <= "000000000";
			macro_state <= "00001";
		elsif (rising_edge(clk_in)) then	
			--led_out <= "00" & state;
			----------------------------------------------
			
			-- 32-bit Output Module

			if(start_send = '1') then
				enable_send <= '1';
				counter_send <= "000";
				counter_send_faulty <= "000";
				start_send <= '0';
				done_send <= '0';
			end if;

			if(f2hReady_in = '1') then
				if(chanAddr_in = send_channel and done_send = '0' and enable_send = '1') then
					if(counter_send = "100") then
						f2hValid_out <= '0';
						done_send <= '1';
						enable_send <= '0';
					else		
						f2hValid_out <= '1';
						f2hData_out <= output_send(8*to_integer(unsigned(counter_send))+7 downto 8*to_integer(unsigned(counter_send)));
						counter_send <= counter_send + 1;				
					end if;
				else
					if(counter_send_faulty = "100") then
						f2hValid_out <= '0';
						counter_send_faulty <= "000";
					else		
						f2hValid_out <= '1';
						f2hData_out <= "00000000";
						counter_send_faulty <= counter_send_faulty + 1;				
					end if;
				end if;	
			end if;	

			-----------------------------------------------

			-- 4 byte input module
			if(start_input = '1') then
				enable_input <= '1';
				counter_input <= "00";
				start_input <= '0';
				done_input <= '0';
			end if;

			if(h2fValid_in = '1' and chanAddr_in = recv_channel and enable_input = '1' and done_input = '0') then
				if(counter_input = "00") then
					inp_data(7 downto 0) <= h2fData_in;
				elsif (counter_input = "01") then
					inp_data(15 downto 8) <= h2fData_in;
				elsif (counter_input = "10") then
					inp_data(23 downto 16) <= h2fData_in;
				elsif (counter_input = "11") then
					inp_data(31 downto 24) <= h2fData_in;
					done_input <= '1';
					enable_input <= '0';
				end if;
				counter_input <= counter_input + 1;
			end if;	

			---------------------------------------------------

			-- Encryption
			if(start_encryption = '1') then
				enable_enc <= '1';
				N1 <= "000000";
				i_enc <= "000000";
				counter_enc <= "000000";
				start_encryption <= '0';
				done_encryption <= '0';
			end if;

			if (done_encryption = '0' and enable_enc = '1') then
				if counter_enc = "000000" then
					dC <= out_data;
					T_enc(3) <= K(31) xor K(27) xor K(23) xor K(19) xor K(15) xor K(11) xor K(7) xor K(3);
					T_enc(2) <= K(30) xor K(26) xor K(22) xor K(18) xor K(14) xor K(10) xor K(6) xor K(2);
					T_enc(1) <= K(29) xor K(25) xor K(21) xor K(17) xor K(13) xor K(9) xor K(5) xor K(1);
					T_enc(0) <= K(28) xor K(24) xor K(20) xor K(16) xor K(12) xor K(8) xor K(4) xor K(0);
				end if;
				
				if counter_enc < "100000" then
					N1 <= N1 + K(to_integer(unsigned(counter_enc)));
					counter_enc <= counter_enc + 1;
				else
					if i_enc < N1 then
						dC(31 downto 28) <= dC(31 downto 28) xor T_enc;
						dC(27 downto 24) <= dC(27 downto 24) xor T_enc;
						dC(23 downto 20) <= dC(23 downto 20) xor T_enc;
						dC(19 downto 16) <= dC(19 downto 16) xor T_enc;
						dC(15 downto 12) <= dC(15 downto 12) xor T_enc;
						dC(11 downto 8) <= dC(11 downto 8) xor T_enc;
						dC(7 downto 4) <= dC(7 downto 4) xor T_enc;
						dC(3 downto 0) <= dC(3 downto 0) xor T_enc;
						T_enc <= T_enc + 1;
						i_enc <= i_enc + 1;
					elsif i_enc = N1 then
						-- All data has been encrypted.
						out_data <= dC;
						done_encryption <= '1';
						enable_enc <= '0';
					end if;
				end if;				
			end if;

			--------------------------------------------------

			-- Decryption
			if (start_decryption = '1') then
				enable_dec <= '1';
				N0 <= "000000";
				i_dec <= "000000";
				counter_dec <= "000000";
				start_decryption <= '0';
				done_decryption <= '0';
			end if;

			if (done_decryption = '0' and enable_dec = '1') then
				if counter_dec = "000000" then
					dP <= inp_data;
					T_dec(3) <= K(31) xor K(27) xor K(23) xor K(19) xor K(15) xor K(11) xor K(7) xor K(3);
					T_dec(2) <= K(30) xor K(26) xor K(22) xor K(18) xor K(14) xor K(10) xor K(6) xor K(2);
					T_dec(1) <= K(29) xor K(25) xor K(21) xor K(17) xor K(13) xor K(09) xor K(5) xor K(1);
					T_dec(0) <= K(28) xor K(24) xor K(20) xor K(16) xor K(12) xor K(08) xor K(4) xor K(0);
				elsif counter_dec = 1 then
					T_dec <= T_dec + 15;
				end if;

				if counter_dec < "100000" then
					N0 <= N0 + 1 - K(to_integer(unsigned(counter_dec)));
					counter_dec <= counter_dec + 1;
				else
					if i_dec < N0 then
						dP(31 downto 28) <= dP(31 downto 28) xor T_dec;
						dP(27 downto 24) <= dP(27 downto 24) xor T_dec;
						dP(23 downto 20) <= dP(23 downto 20) xor T_dec;
						dP(19 downto 16) <= dP(19 downto 16) xor T_dec;
						dP(15 downto 12) <= dP(15 downto 12) xor T_dec;
						dP(11 downto 8) <= dP(11 downto 8) xor T_dec;
						dP(7 downto 4) <= dP(7 downto 4) xor T_dec;
						dP(3 downto 0) <= dP(3 downto 0) xor T_dec;
						T_dec <= T_dec + 15;
						i_dec <= i_dec + 1;
					elsif i_dec = N0 then
						-- All data has been decrypted
						inp_data <= dP;
						done_decryption <= '1';
						enable_dec <= '0';
					end if;				
				end if;
			end if;

			--------------------------------------------------

			-- Timer Module
			-- Waits for "timer" seconds
			if (start_timer = '1') then
				enable_timer <= '1';
				d <= (others => '0');
				current_time <= (others => '0');
				start_timer <= '0';
				done_timer <= '0';
			end if;

			if (enable_timer = '1' and done_timer = '0') then
				if (d = "10110111000110110000000000") then
					current_time <= current_time + 1;
					d <= (others => '0');
				else
					d <= d + 1;	
				end if;

				if (current_time = timer) then
					done_timer <= '1';
					enable_timer <= '0';
				end if;
			end if;

			-------------------------------------------------

			-- Process 64-bit input
			if (start_compute = '1') then
				enable_compute <= '1';
				counter_compute <= 0;
				start_compute <= '0';
				done_compute <= '0';
				out_display <= (others => '0');
			end if;

			if (enable_compute = '1' and done_compute = '0') then
				if ( counter_compute < 8 ) then
					out_display((8*0 + 24*counter_compute + 2) downto (8*0 + 24*counter_compute + 0)) <= info((counter_compute*8 + 5) downto (counter_compute*8 + 3));
					out_display((8*1 + 24*counter_compute + 2) downto (8*1 + 24*counter_compute + 0)) <= info((counter_compute*8 + 5) downto (counter_compute*8 + 3));
					out_display((8*2 + 24*counter_compute + 2) downto (8*2 + 24*counter_compute + 0)) <= info((counter_compute*8 + 5) downto (counter_compute*8 + 3));
				elsif (counter_compute < 12 ) then
					if (sw_in(counter_compute-8) = '0' and sw_in(counter_compute-4) = '0') then
						out_display(8*0 + 24*(counter_compute-8) + 7) <= '1';
						out_display(8*1 + 24*(counter_compute-8) + 7) <= '1';
						out_display(8*2 + 24*(counter_compute-8) + 7) <= '1';
						out_display(8*0 + 24*(counter_compute-4) + 7) <= '1';
						out_display(8*1 + 24*(counter_compute-4) + 7) <= '1';
						out_display(8*2 + 24*(counter_compute-4) + 7) <= '1';
					elsif (sw_in(counter_compute-8) = '0' and sw_in(counter_compute-4) = '1' and info(((counter_compute-4)*8 + 2) downto ((counter_compute-4)*8 + 0)) = "001") then
						out_display(8*0 + 24*(counter_compute-8) + 7) <= '1';
						out_display(8*1 + 24*(counter_compute-8) + 7) <= '1';
						out_display(8*2 + 24*(counter_compute-8) + 7) <= '1';
						out_display(8*0 + 24*(counter_compute-4) + 6) <= '1';
						out_display(8*1 + 24*(counter_compute-4) + 6) <= '1';
						out_display(8*2 + 24*(counter_compute-4) + 6) <= '1';
					elsif (sw_in(counter_compute-8) = '0' and sw_in(counter_compute-4) = '1') then
						out_display(8*0 + 24*(counter_compute-8) + 7) <= '1';
						out_display(8*1 + 24*(counter_compute-8) + 7) <= '1';
						out_display(8*2 + 24*(counter_compute-8) + 7) <= '1';
						out_display(8*0 + 24*(counter_compute-4) + 5) <= '1';
						out_display(8*1 + 24*(counter_compute-4) + 5) <= '1';
						out_display(8*2 + 24*(counter_compute-4) + 5) <= '1';
					elsif (sw_in(counter_compute-8) = '1' and sw_in(counter_compute-4) = '0' and info(((counter_compute-8)*8 + 2) downto ((counter_compute-8)*8 + 0)) = "001") then
						out_display(8*0 + 24*(counter_compute-8) + 6) <= '1';
						out_display(8*1 + 24*(counter_compute-8) + 6) <= '1';
						out_display(8*2 + 24*(counter_compute-8) + 6) <= '1';
						out_display(8*0 + 24*(counter_compute-4) + 7) <= '1';
						out_display(8*1 + 24*(counter_compute-4) + 7) <= '1';
						out_display(8*2 + 24*(counter_compute-4) + 7) <= '1';
					elsif (sw_in(counter_compute-8) = '1' and sw_in(counter_compute-4) = '0') then
						out_display(8*0 + 24*(counter_compute-8) + 5) <= '1';
						out_display(8*1 + 24*(counter_compute-8) + 5) <= '1';
						out_display(8*2 + 24*(counter_compute-8) + 5) <= '1';
						out_display(8*0 + 24*(counter_compute-4) + 7) <= '1';
						out_display(8*1 + 24*(counter_compute-4) + 7) <= '1';
						out_display(8*2 + 24*(counter_compute-4) + 7) <= '1';
					elsif (sw_in(counter_compute-8) = '1' and sw_in(counter_compute-4) = '1') then
						out_display(8*0 + 24*(counter_compute-8) + 7) <= '1';
						out_display(8*1 + 24*(counter_compute-8) + 7) <= '1';
						out_display(8*2 + 24*(counter_compute-8) + 7) <= '1';
						out_display(8*0 + 24*(counter_compute-4) + 7) <= '1';
						out_display(8*1 + 24*(counter_compute-4) + 6) <= '1';
						out_display(8*2 + 24*(counter_compute-4) + 5) <= '1';
					end if;
				elsif (counter_compute < 20 ) then
					if (info((counter_compute-12)*8+6) = '0') then
						out_display(8*0 + 24*(counter_compute-12) + 7) <= '1';
						out_display(8*0 + 24*(counter_compute-12) + 6) <= '0';
						out_display(8*0 + 24*(counter_compute-12) + 5) <= '0';
						out_display(8*1 + 24*(counter_compute-12) + 7) <= '1';
						out_display(8*1 + 24*(counter_compute-12) + 6) <= '0';
						out_display(8*1 + 24*(counter_compute-12) + 5) <= '0';
						out_display(8*2 + 24*(counter_compute-12) + 7) <= '1';
						out_display(8*2 + 24*(counter_compute-12) + 6) <= '0';
						out_display(8*2 + 24*(counter_compute-12) + 5) <= '0';
					end if;
				else
					done_compute <= '1';
					enable_compute <= '0';
				end if;
				counter_compute <= counter_compute+1;
			end if;
			--------------------------------------------------

			-- Display on Board
			if (start_display = '1') then
				enable_display <= '1';
				start_display <= '0';
				done_display <= '0';
			end if;

			if(enable_display = '1' and done_display = '0') then
				-- Optimise this later
				if(current_time = timer) then
					done_display <= '1';
					enable_display <= '0';
					led_out <= "00000000";
				else	
					led_out <= out_display(8*(to_integer(unsigned(current_time)))+7 downto 8*(to_integer(unsigned(current_time))));
				end if;
			end if;	 

			--------------------------------------------------	

			-------- CONTROLLER ------------

			if(macro_state > 2) then
				if(up_b = '1') then
					do_fpga <= '1';
				end if;
				if(left_b = '1') then
					do_uart <= '1';
				end if;
			end if;

			if(reset_b = '0' and rstate = 0) then	
				if(macro_state = 1) then
					timer <= "000000011";
					start_timer <= '1';
					led_out <= "11111111";
					do_fpga <= '0';
					macro_state <= macro_state + 1;
				elsif(macro_state = 2) then
					if(done_timer = '1') then
						led_out <= "00000000";
						macro_state <= macro_state + 1;
						done_timer <= '0';
					end if;
				elsif(macro_state = 3) then
					if(state = 1) then
						out_data <= coords;
						start_encryption <= '1';
						state <= state + 1;
					elsif(state = 2) then
						if(done_encryption = '1') then
							start_send <= '1';
							output_send <= out_data;
							state <= state + 1;
							timer <= "100000000";
							start_timer <= '1';
							done_encryption <= '0';
						end if;
					elsif(state = 3) then
						if(done_timer = '1') then
							state <= "000001";
							done_timer <= '0';
						elsif(done_send = '1') then
							start_input <= '1';
							state <= state + 1;
							done_send <= '0';
						end if;	
					elsif(state = 4) then
						if(done_timer = '1') then
							state <= "000001";
							done_timer <= '0';
						elsif(done_input = '1') then
							start_decryption <= '1';
							state <= state + 1;
							done_input <= '0';
						end if;
					elsif(state = 5) then
						if(done_timer = '1') then
							state <= "000001";
							done_timer <= '0';
						elsif(done_decryption = '1') then
							if(inp_data = coords) then
								state <= state + 1;
							else
								state <= "000011";
							end if;
							done_decryption <= '0';
						end if;
					elsif(state = 6) then
						out_data <= ack1;
						start_encryption <= '1';
						state <= state + 1;
					elsif(state = 7) then
						if(done_encryption = '1') then
							start_send <= '1';
							output_send <= out_data;
							state <= state + 1;
							timer <= "100000000";
							start_timer <= '1';
							done_encryption <= '0';
						end if;
					elsif(state = 8) then
						if(done_timer = '1') then
							state <= "000001";
							done_timer <= '0';
						elsif(done_send = '1') then
							start_input <= '1';
							state <= state + 1;
							done_send <= '0';
						end if;	
					elsif(state = 9) then
						if(done_timer = '1') then
							state <= "000001";
							done_timer <= '0';
						elsif(done_input = '1') then
							start_decryption <= '1';
							state <= state + 1;
							done_input <= '0';
						end if;
					elsif(state = 10) then
						if(done_timer = '1') then
							state <= "000001";
							done_timer <= '0';
						elsif(done_decryption = '1') then
							if(inp_data = ack2) then
								state <= state + 1;
							else
								state <= "001000";
							end if;
							done_decryption <= '0';
						end if;
					elsif(state = 11) then
						start_input <= '1';
						state <= state + 1;
					elsif(state = 12) then
						if(done_input = '1') then
							start_decryption <= '1';
							state <= state + 1;
							done_input <= '0';
						end if;
					elsif(state = 13) then
						if(done_decryption = '1') then
							info(31 downto 0) <= inp_data;
							out_data <= ack1;
							start_encryption <= '1';
							state <= state + 1;
							done_decryption <= '0';
						end if;
					elsif(state = 14) then
						if(done_encryption = '1') then
							start_send <= '1';
							output_send <= out_data;
							state <= state + 1;
							done_encryption <= '0';
						end if;
					elsif(state = 15) then
						if(done_send = '1') then
							start_input <= '1';
							state <= state + 1;
							done_send <= '0';
						end if;	
					elsif(state = 16) then
						if(done_input = '1') then
							start_decryption <= '1';
							state <= state + 1;
							done_input <= '0';
						end if;	
					elsif(state = 17) then
						if(done_decryption = '1') then
							info(63 downto 32) <= inp_data;
							out_data <= ack1;
							start_encryption <= '1';
							state <= state + 1;
							done_decryption <= '0';
						end if;	
					elsif(state = 18) then
						if(done_encryption = '1') then
							start_send <= '1';
							output_send <= out_data;
							state <= state + 1;
							timer <= "100000000";
							start_timer <= '1';
							done_encryption <= '0';
						end if;
					elsif(state = 19) then
						if(done_timer = '1') then
							state <= "000001";
							done_timer <= '0';
						elsif(done_send = '1') then
							start_input <= '1';
							state <= state + 1;
							done_send <= '0';
						end if;	
					elsif(state = 20) then
						if(done_timer = '1') then
							state <= "000001";
							done_timer <= '0';
						elsif(done_input = '1') then
							start_decryption <= '1';
							state <= state + 1;
							done_input <= '0';
						end if;
					elsif(state = 21) then
						if(done_timer = '1') then
							state <= "000001";
							done_timer <= '0';
						elsif(done_decryption = '1') then
							if(inp_data = ack2) then
								state <= state + 1;
							else
								state <= "010011";
							end if;
							done_decryption <= '0';
						end if;				
					elsif(state = 22) then
						-- Assuming slider input is available in sw_in.
						if(do_update = '1') then
							if(info(8*(to_integer(unsigned(update_data(5 downto 3))))+7) = '1') then
								if(info(8*(to_integer(unsigned(update_data(5 downto 3))))+6) = '1' and update_data(6) = '0') then
									info(8*(to_integer(unsigned(update_data(5 downto 3))))+6) <= '0';
								end if;
								info(8*(to_integer(unsigned(update_data(5 downto 3))))+2 downto 8*(to_integer(unsigned(update_data(5 downto 3))))) <= update_data(2 downto 0);
							end if;
							do_update <= '0';
						end if;
						start_compute <= '1';
						state <= state + 1;
					elsif(state = 23) then
						if(done_compute = '1') then
							start_timer <= '1';
							timer <= "000011000";
							start_display <= '1';
							state <= state + 1;
							done_compute <= '0';
						end if;	
					elsif(state = 24) then	
						if(done_timer = '1') then
							--start_timer <= '1';
							--timer <= "000001000";	
							--state <= state + 1;
							--done_timer <= '0';
							state <= "000001";
							macro_state <= macro_state + 1;
							done_timer <= '0';
						end if;
					--elsif(state = 25) then
					--	if(done_timer = '1') then
					--		--state <= "000001";
					--		macro_state <= macro_state + 1;
					--		done_timer <= '0';
					--	end if;
					end if;	
				elsif(macro_state = 4) then
					if(do_fpga = '1') then
						macro_state <= macro_state + 1;
						state <= "000000";
						timer <= T1;
						start_timer <= '1';
					else
						macro_state <= "00110";	
					end if;
				elsif(macro_state = 5) then
					if(done_timer = '1') then
						macro_state <= "00110";
						done_timer <= '0';
					else
						if(state = 0) then
							if(down_b = '1') then
								state <= state + 1;
							end if;
						elsif(state = 1) then
							out_data <= "111111111111111111111111" & sw_in;
							start_encryption <= '1';
							state <= state + 1;
						elsif(state = 2) then
							if(done_encryption = '1') then
								start_send <= '1';
								output_send <= out_data;
								state <= state + 1;
								done_encryption <= '0';
							end if;
						elsif(state = 3) then
							if(done_send = '1') then
								state <= state + 1;
								macro_state <= macro_state + 1;
								done_send <= '0';
							end if;	
						end if;
					end if;
				elsif(macro_state = 6) then
					if(do_uart = '1') then
						macro_state <= macro_state + 1;
						state <= "000000";
						timer <= T1;
						start_timer <= '1';
						led_out <= "00000110";
					else
						macro_state <= "01000";
					end if;
				elsif(macro_state = 7) then
					if(done_timer = '1') then
						macro_state <= "01000";
						done_timer <= '0';
						led_out <= "00000111";
					else
						led_out <= "10000111";
						if(state = 0) then
							if(right_b = '1') then
								start_tx <= '1';
								send_data <= sw_in;	
								state <= state + 1;
								led_out <= "11"&state;
							end if;
						elsif(state = 1) then
							start_tx <= '0';
							state <= "000000";
							macro_state <= macro_state + 1;
							led_out <= "00001001";
						end if;
					end if;
				elsif(macro_state = 8) then
					led_out <= "00001100";
					if(state = 0) then
						if(ready_rx = '1') then
							update_data <= recv_data;
							do_update <= '1';
							state <= state + 1;
						else
							macro_state <= "01001";
						end if;
					elsif(state = 1) then
						rx_reset <= '0';
						state <= state + 1;
					elsif(state = 2) then
						rx_reset <= '1';
						macro_state <= "01001";
						state <= "000000";
					end if;
				elsif(macro_state = 9) then
					led_out <= "00001111";
					if(state = 0) then
						timer <= T0;
						start_timer <= '1';
						state <= state + 1;
					elsif(state = 1) then
						if(done_timer = '1') then
							done_timer <= '0';
							macro_state <= "00011";
						end if;
					end if;
				end if;
			else
				led_out <= "00000000";	
			end if;

			--------------------------------------------------
			
			if(rstate = 0) then
				if(reset_b = '1') then 
					out_data <= reset_signal;
					start_encryption <= '1';
					rstate <= rstate + 1;
				end if;
			elsif(rstate = 1) then
				if(done_encryption = '1') then
					start_send <= '1';
					output_send <= out_data;
					done_encryption <= '0';
					rstate <= rstate + 1;
				end if;
			elsif(rstate = 2) then
				if(done_send = '1') then
					done_send <= '0';
					macro_state <= "00011";
					state <= "000001";
					rstate <= "00";
				end if;
			end if;


		end if;
	end process;
	-- Select values to return for each channel when the host is reading
--	with chanAddr_in select f2hData_out <=
--		chnl_out(7 downto 0) when "0000000",	-- Yet to be encrypted! (C1)
--		sw_in                 when "0000001",
--		x"00" when others;

	-- Assert that there's always data for reading, and always room for writing
--	f2hValid_out <= '1';
	h2fReady_out <= '1';                                                     --END_SNIPPET(registers)


	-- LEDs and 7-seg display
	-- led_out <= inp_data(15 downto 8);
	flags <= "00" & f2hReady_in & reset_in;
	seven_seg : entity work.seven_seg
		port map(
			clk_in     => clk_in,
			data_in    => checksum,
			dots_in    => flags,
			segs_out   => sseg_out,
			anodes_out => anode_out
		);
end architecture;