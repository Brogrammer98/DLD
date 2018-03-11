library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

architecture rtl of swled is
	-- Flags for display on the 7-seg decimal points
	signal flags                   : std_logic_vector(3 downto 0);

	-- Registers implementing the channels
	signal checksum, checksum_next : std_logic_vector(15 downto 0) := (others => '0');
	signal reg0, reg0_next, temp, output     : std_logic_vector(7 downto 0)  := (others => '0');
	signal inp_data, out_data				: std_logic_vector(63 downto 0)  := (others => '0');
	signal counter				: std_logic_vector(2 downto 0)  := (others => '0');
	signal c, counter_gen_output : std_logic_vector(4 downto 0)  := (others => '0');
	signal d  : std_logic_vector(25 downto 0)  := (others => '0');
	signal inp_done_check, out_done_check, reset_dec, enable_dec, start_decryption, end_decryption, reset_gen_output, end_gen_output, generate_output, enable_gen_output, output_ready  : std_logic  := '0';
	signal N0 : std_logic_vector(5 downto 0) := "000000";
	signal counter_dec : std_logic_vector(5 downto 0) := "000000";
	signal dP, K : std_logic_vector(31 downto 0);
	signal T : std_logic_vector(3 downto 0) := "0000";
	signal i : std_logic_vector(5 downto 0) := "000000";
	signal part : std_logic_vector(1 downto 0)  := (others => '0');

begin                                                                     --BEGIN_SNIPPET(registers)
	-- Infer registers
	process(clk_in)
	begin
		if ( rising_edge(clk_in) ) then
	
			if ( reset_in = '1' ) then
				reg0 <= (others => '0');
			else
				if ( d = "10110111000110110000000000" and out_done_check = '1') then
					if(c < "01000") then
						led_out <= out_data(to_integer(unsigned(c))*8+7 downto (to_integer(unsigned(c)))*8);
						d <= (others => '0');
						c <= c + 1;					
					else 
						led_out <= (others => '0');
						out_done_check <= '0';
						inp_done_check <= '0';
						c <= (others => '0');
					end if;
				end if;
				d <= d + 1;
				

				if(reg0 /= reg0_next and inp_done_check = '0') then
					if (counter = "000") then
						inp_data(7 downto 0) <= reg0_next;
					elsif (counter = "001") then
						inp_data(15 downto 8) <= reg0_next;
					elsif (counter = "010") then
						inp_data(23 downto 16) <= reg0_next;
					elsif (counter = "011") then
						inp_data(31 downto 24) <= reg0_next;
					elsif (counter = "100") then
						inp_data(39 downto 32) <= reg0_next;
					elsif (counter = "101") then
						inp_data(47 downto 40) <= reg0_next;
					elsif (counter = "110") then
						inp_data(55 downto 48) <= reg0_next;
					elsif (counter = "111") then
						inp_data(63 downto 56) <= reg0_next;
						inp_done_check <= '1';
						start_decryption <= '1';
						d <= (others => '0');
					end if;
					counter <= counter + 1;
					reg0 <= reg0_next;
				end if;
				
				-- Decryption
				if (start_decryption = '1') then
					enable_dec <= '1';
					reset_dec <= '1';
					part <= "00";
					start_decryption <= '0';
					end_decryption <= '0';
				end if;

				if (end_decryption = '0' and enable_dec = '1') then
					if(part < "10") then
						if (reset_dec = '1') then
							N0 <= "000000";
							i <= "000000";
							counter_dec <= "000000";
							K <= "00000000000000000000000000000001"; -- hard-coded for now
							reset_dec <= '0';
						else
							if counter_dec = 0 then
								dP <= inp_data(32*to_integer(unsigned(part))+31 downto 32*to_integer(unsigned(part)));
								T(3) <= K(31) xor K(27) xor K(23) xor K(19) xor K(15) xor K(11) xor K(7) xor K(3);
								T(2) <= K(30) xor K(26) xor K(22) xor K(18) xor K(14) xor K(10) xor K(6) xor K(2);
								T(1) <= K(29) xor K(25) xor K(21) xor K(17) xor K(13) xor K(09) xor K(5) xor K(1);
								T(0) <= K(28) xor K(24) xor K(20) xor K(16) xor K(12) xor K(08) xor K(4) xor K(0);
							elsif counter_dec = 1 then
								T <= T + 15;
							end if;
							if counter_dec < 32 then
								N0 <= N0 + 1 - K(to_integer(unsigned(counter_dec)));
								counter_dec <= counter_dec + 1;
							else
								if i < N0 then
									dP(31 downto 28) <= dP(31 downto 28) xor T;
									dP(27 downto 24) <= dP(27 downto 24) xor T;
									dP(23 downto 20) <= dP(23 downto 20) xor T;
									dP(19 downto 16) <= dP(19 downto 16) xor T;
									dP(15 downto 12) <= dP(15 downto 12) xor T;
									dP(11 downto 8) <= dP(11 downto 8) xor T;
									dP(7 downto 4) <= dP(7 downto 4) xor T;
									dP(3 downto 0) <= dP(3 downto 0) xor T;
									T <= T + 15;
									i <= i + 1;
								elsif i = N0 then
									inp_data(32*to_integer(unsigned(part))+31 downto 32*to_integer(unsigned(part))) <= dP;
									i <= i + 1;
									reset_dec <= '1';
									part <= part + 1;
								end if;			
							end if;
						end if;
					else
						-- All data has been decrypted.
						end_decryption <= '1';
						generate_output <= '1';
					end if;
				end if;

				if (generate_output = '1') then
					enable_gen_output <= '1';
					reset_gen_output <= '1';
					generate_output <= '0';
					end_gen_output <= '0';
				end if;	

				-- Generate Output Data
				if (end_gen_output = '0') then
					if(reset_gen_output = '1') then
						temp <= inp_data(7 downto 0);
						counter_gen_output <= "00001";
						reset_gen_output <= '0';
						output_ready <= '0';
					else	
						if (counter_gen_output < "01001") then
							-- Output preparation
							if(output_ready = '1') then
								out_data(to_integer(unsigned(counter_gen_output))*8-1 downto (to_integer(unsigned(counter_gen_output)))*8-8) <= output;
								output_ready <= '0';
							else 
								output(4 downto 3) <= "00";
								output(7 downto 5) <= "000";
								output(2 downto 0) <= temp(5 downto 3);
						
								if (temp(7) = '1' and temp(6) = '1') then
									if (temp(2 downto 1) = "00") then
										output(6) <= '1';
									else
										output(5) <= '1';		
									end if;
								else
									output(7) <= '1';		
								end if;
								
								counter_gen_output <= counter_gen_output + 1;
								temp <= inp_data(to_integer(unsigned(counter_gen_output))*8+7 downto (to_integer(unsigned(counter_gen_output)))*8);
								output_ready <= '1';
							end if;	
						else
							end_gen_output <= '1';
							out_done_check <= '1';
						end if;
					end if;
				end if;

			end if;	

		end if;
	end process;

	-- Drive register inputs for each channel when the host is writing
	reg0_next <=
		h2fData_in when chanAddr_in = "0000000" and h2fValid_in = '1'
		else reg0;

	-- Select values to return for each channel when the host is reading
	with chanAddr_in select f2hData_out <=
		sw_in                 when "0000000",
		checksum(15 downto 8) when "0000001",
		checksum(7 downto 0)  when "0000010",
		x"00" when others;

	-- Assert that there's always data for reading, and always room for writing
	f2hValid_out <= '1';
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
