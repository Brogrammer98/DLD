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
	signal inp_done_check, out_done_check, reset_dec, enable_dec, start_decryption, end_decryption, reset_enc, enable_enc, start_encryption, end_encryption, reset_gen_output, end_gen_output, generate_output, enable_gen_output, output_ready  : std_logic  := '0';
	signal N0, N1 : std_logic_vector(5 downto 0) := "000000";
	signal counter_dec, counter_enc : std_logic_vector(5 downto 0) := "000000";
	signal dP, K, dC : std_logic_vector(31 downto 0);
	signal T : std_logic_vector(3 downto 0) := "0000";
	signal i : std_logic_vector(5 downto 0) := "000000";
	signal part_dec, part_enc : std_logic_vector(1 downto 0)  := (others => '0');

begin                                                                     --BEGIN_SNIPPET(registers)
	-- Infer registers
	process(clk_in)
	begin
		K <= "00000000000000000000000000000001"; -- hard-coded for now
		if ( rising_edge(clk_in) ) then
	
			if ( reset_in = '1' ) then
				reg0 <= (others => '0');
			else
				if ( d = "10110111000110110000000000" and out_done_check = '1') then
					if(c < "01000") then
						led_out <= out_data(to_integer(unsigned(c))*8+7 downto (to_integer(unsigned(c)))*8);
						d <= (others => '0');
						c <= c + 1;					
					elsif(c < "10000") then
						led_out <= (others => '0');
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
					part_dec <= "00";
					start_decryption <= '0';
					end_decryption <= '0';
				end if;

				if (end_decryption = '0' and enable_dec = '1') then
					if(part_dec < "10") then
						if (reset_dec = '1') then
							N0 <= "000000";
							i <= "000000";
							counter_dec <= "000000";
							reset_dec <= '0';
						else
							if counter_dec = 0 then
								dP <= inp_data(32*to_integer(unsigned(part_dec))+31 downto 32*to_integer(unsigned(part_dec)));
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
									inp_data(32*to_integer(unsigned(part_dec))+31 downto 32*to_integer(unsigned(part_dec))) <= dP;
									i <= i + 1;
									reset_dec <= '1';
									part_dec <= part_dec + 1;
								end if;			
							end if;
						end if;
					else
						-- All data has been decrypted.
						end_decryption <= '1';
						generate_output <= '1';
						enable_dec <= '0';
					end if;
				end if;

				if (generate_output = '1') then
					enable_gen_output <= '1';
					reset_gen_output <= '1';
					generate_output <= '0';
					end_gen_output <= '0';
				end if;	

				-- Generate Output Data
				if (end_gen_output = '0' and enable_gen_output = '1') then
					if(reset_gen_output = '1') then
						temp <= inp_data(7 downto 0);
						counter_gen_output <= "00000";
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
								
								temp <= inp_data(to_integer(unsigned(counter_gen_output))*8+15 downto (to_integer(unsigned(counter_gen_output)))*8+8);
								counter_gen_output <= counter_gen_output + 1;
								output_ready <= '1';
							end if;	
						else
							end_gen_output <= '1';
							start_encryption <= '1';
							-- out_done_check <= '1';
							enable_gen_output <= '0';
						end if;
					end if;
				end if;

				-- Encryption
				if (start_encryption = '1') then
					enable_enc <= '1';
					reset_enc <= '1';
					part_enc <= "00";
					start_encryption <= '0';
					end_encryption <= '0';
				end if;

				if (end_encryption = '0' and enable_enc = '1') then
					if(part_enc < "10") then
						if (reset_enc = '1') then
							N1 <= "000000";
							i <= "000000";
							counter_enc <= "000000";
							reset_enc <= '0';
						else
							if counter_enc = 0 then
								dC <= out_data(32*to_integer(unsigned(part_enc))+31 downto 32*to_integer(unsigned(part_enc)));
								T(3) <= K(31) xor K(27) xor K(23) xor K(19) xor K(15) xor K(11) xor K(7) xor K(3);
								T(2) <= K(30) xor K(26) xor K(22) xor K(18) xor K(14) xor K(10) xor K(6) xor K(2);
								T(1) <= K(29) xor K(25) xor K(21) xor K(17) xor K(13) xor K(09) xor K(5) xor K(1);
								T(0) <= K(28) xor K(24) xor K(20) xor K(16) xor K(12) xor K(08) xor K(4) xor K(0);
							end if;
							if counter_enc < 32 then
								N1 <= N1 + K(to_integer(unsigned(counter_enc)));
								counter_enc <= counter_enc + 1;
							else
								if i < N1 then
									dC(31 downto 28) <= dC(31 downto 28) xor T;
									dC(27 downto 24) <= dC(27 downto 24) xor T;
									dC(23 downto 20) <= dC(23 downto 20) xor T;
									dC(19 downto 16) <= dC(19 downto 16) xor T;
									dC(15 downto 12) <= dC(15 downto 12) xor T;
									dC(11 downto 8) <= dC(11 downto 8) xor T;
									dC(7 downto 4) <= dC(7 downto 4) xor T;
									dC(3 downto 0) <= dC(3 downto 0) xor T;
									T <= T + 1;
									i <= i + 1;
								elsif i = N1 then
									out_data(32*to_integer(unsigned(part_enc))+31 downto 32*to_integer(unsigned(part_enc))) <= dC;
									i <= i + 1;
									reset_enc <= '1';
									part_enc <= part_enc + 1;
								end if;			
							end if;
						end if;
					else
					-- All data has been encrypted.
						end_encryption <= '1';
						out_done_check <= '1';
						enable_enc <= '0';
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
