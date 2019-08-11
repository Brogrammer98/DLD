-- EB Mar 2013
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity uart_rx_c is
port(
  sys_clk: in std_logic; -- 100 MHz system clock
  data_recv: out std_logic_vector(7 downto 0);
  uart_rx: in std_logic;
  ready: out std_logic;
  reset_btn: in std_logic
);
end uart_rx_c;

architecture Behavioral of uart_rx_c is

component basic_uart_rx is
generic (
  DIVISOR: natural
);
port (
  clk: in std_logic;   -- system clock
  reset: in std_logic;
  rx_data: out std_logic_vector(7 downto 0); 
  rx_enable: out std_logic;
  rx: in std_logic
);
end component;

type fsm_state_t is (idle, received);
type state_t is
record
  fsm_state: fsm_state_t; 
  rx_data: std_logic_vector(7 downto 0);
  ready: std_logic;
end record;

signal reset: std_logic;
signal uart_rx_data: std_logic_vector(7 downto 0);
signal uart_rx_enable: std_logic;

signal state,state_next: state_t;

begin

  basic_uart_inst: basic_uart_rx
  generic map (DIVISOR => 1250) -- 2400 PLEASE REMEMBER TO CHANGE THIS TO 1250!!!!!!!!!!!!!!!!!!!!!!!!
  port map (
    clk => sys_clk, reset => reset,
    rx_data => uart_rx_data, rx_enable => uart_rx_enable,
    rx => uart_rx
  );

  reset_control: process (reset_btn) is
  begin
    if reset_btn = '1' then
      reset <= '0';
    else
      reset <= '1';
    end if;
  end process;
  
--  pmod_1 <= uart_tx_enable;
--  pmod_2 <= uart_tx_ready;
  
  fsm_clk: process (sys_clk,reset) is
  begin
    if reset = '1' then
      state.fsm_state <= idle;
--      state.tx_data <= (others => '0');
		state.rx_data <= (others => '0');
		state.ready <= '0';
--      state.tx_enable <= '0';
    else
      if rising_edge(sys_clk) then
        state <= state_next;
      end if;
    end if;
  end process;

  fsm_next: process (state,uart_rx_enable,uart_rx_data) is
  begin
    state_next <= state;
    case state.fsm_state is
    
    when idle =>
      if (uart_rx_enable = '1') then
		state_next.rx_data <= uart_rx_data;
		state_next.ready <= '1';
        state_next.fsm_state <= received;
      end if;
      
    when received =>
      if (uart_rx_enable = '0') then
        state_next.fsm_state <= idle;
      end if;
      
    end case;
  end process;
  
  fsm_output: process (state) is
  begin
    data_recv <= state.rx_data;
    ready <= state.ready;
  end process;
  
end Behavioral;

