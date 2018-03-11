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
	signal inp_data				: std_logic_vector(63 downto 0)  := (others => '0');
	signal counter				: std_logic_vector(2 downto 0)  := (others => '0');
	signal c 	: std_logic_vector(4 downto 0)  := (others => '0');
	signal d  : std_logic_vector(25 downto 0)  := (others => '0');
	signal inp_done_check  : std_logic  := '0';

begin                                                                     --BEGIN_SNIPPET(registers)
	-- Infer registers
	process(clk_in)
	begin
		if ( rising_edge(clk_in) ) then
			if ( d = "10110111000110110000000000" and inp_done_check = '1') then
				if(c < "01001") then
					temp <= inp_data(to_integer(unsigned(c))*8+15 downto (to_integer(unsigned(counter)))*8+8);
					led_out <= output;
					d <= (others => '0');
					-- Output preparation
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
					c <= c + 1;
				elsif(c < "10000") then
					led_out <= (others => '0');
					c <= c + 1;
				else
					inp_done_check <= '0';
					c <= (others => '0');
					output <= (others => '0');
				end if;
			end if;

			d <= d + 1;
	
			if ( reset_in = '1' ) then
				reg0 <= (others => '0');
				checksum <= (others => '0');
			else
				if(reg0 /= reg0_next) then
				-- checksum <= checksum_next;
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
						d <= "10110111000110110000000000";
						temp <= inp_data(7 downto 0);
					end if;
					counter <= counter + 1;
					reg0 <= reg0_next;
				end if;
			end if;
			
		end if;
	end process;

	-- Drive register inputs for each channel when the host is writing
	reg0_next <=
		h2fData_in when chanAddr_in = "0000000" and h2fValid_in = '1'
		else reg0;
	checksum_next <=
		std_logic_vector(unsigned(checksum) + unsigned(h2fData_in))
			when chanAddr_in = "0000000" and h2fValid_in = '1'
		else h2fData_in & checksum(7 downto 0)
			when chanAddr_in = "0000001" and h2fValid_in = '1'
		else checksum(15 downto 8) & h2fData_in
			when chanAddr_in = "0000010" and h2fValid_in = '1'
		else checksum;
	
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