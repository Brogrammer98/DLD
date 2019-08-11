-- EB Mar 2013
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity uart_tx_c is
port(
  sys_clk: in std_logic; -- 100 MHz system clock
  data_in: in std_logic_vector(7 downto 0);
  uart_tx: out std_logic;
  start: in std_logic;
  reset_btn: in std_logic
);
end uart_tx_c;

architecture Behavioral of uart_tx_c is

component basic_uart_tx is
generic (
  DIVISOR: natural
);
port (
  clk: in std_logic;   -- system clock
  reset: in std_logic;
  tx_data: in std_logic_vector(7 downto 0);  -- byte to send
  tx_enable: in std_logic;  -- validates byte to send if tx_ready is '1'
  tx_ready: out std_logic;  -- if '1', we can send a new byte, otherwise we won't take it
  tx: out std_logic
);
end component;

type fsm_state_t is (idle, emitting);
type state_t is
record
  fsm_state: fsm_state_t; -- FSM state
  tx_data: std_logic_vector(7 downto 0);
  tx_enable: std_logic;
end record;

signal reset: std_logic;
signal uart_tx_data: std_logic_vector(7 downto 0);
signal uart_tx_enable: std_logic;
signal uart_tx_ready: std_logic;

signal state,state_next: state_t;

begin

  basic_uart_inst: basic_uart_tx
  generic map (DIVISOR => 1250) -- 2400
  port map (
    clk => sys_clk, reset => reset,
    tx_data => uart_tx_data, tx_enable => uart_tx_enable, tx_ready => uart_tx_ready,
    tx => uart_tx
  );

  reset_control: process (reset_btn) is
  begin
    if reset_btn = '1' then
      reset <= '0';
    else
      reset <= '1';
    end if;
  end process;
  
  fsm_clk: process (sys_clk,reset) is
  begin
    if reset = '1' then
      state.fsm_state <= idle;
      state.tx_data <= (others => '0');
      state.tx_enable <= '0';
    else
      if rising_edge(sys_clk) then
        state <= state_next;
      end if;
    end if;
  end process;

  fsm_next: process (state,uart_tx_ready,start) is
  begin
    state_next <= state;
    case state.fsm_state is
    
    when idle =>
      if (start = '1' and uart_tx_ready = '1') then
        state_next.tx_data <= data_in;
        state_next.tx_enable <= '1';
        state_next.fsm_state <= emitting;
      end if;
      
    when emitting =>
      if (start = '0' or uart_tx_ready = '0') then
        state_next.tx_enable <= '0';
        state_next.fsm_state <= idle;
      end if;
      
    end case;
  end process;
  
  fsm_output: process (state) is
  begin
    uart_tx_enable <= state.tx_enable;
    uart_tx_data <= state.tx_data;
  end process;
  
end Behavioral;

