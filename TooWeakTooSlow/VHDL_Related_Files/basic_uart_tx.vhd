-- Eric Bainville
-- Mar 2013

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.math_real.all;

entity basic_uart_tx is
  generic (
    DIVISOR: natural  -- DIVISOR = 100,000,000 / (16 x BAUD_RATE)
    -- 2400 -> 2604
    -- 9600 -> 651
    -- 115200 -> 54
    -- 1562500 -> 4
    -- 2083333 -> 3
  );
  port (
    clk: in std_logic;                         -- clock
    reset: in std_logic;                       -- reset
    
    -- Client interface
    tx_data: in std_logic_vector(7 downto 0);  -- byte to send
    tx_enable: in std_logic;                   -- validates byte to send if tx_ready is '1'
    tx_ready: out std_logic;                   -- if '1', we can send a new byte, otherwise we won't take it
    
    -- Physical interface
    tx: out std_logic
  );
end basic_uart_tx;

architecture Behavioral of basic_uart_tx is
  constant COUNTER_BITS : natural := integer(ceil(log2(real(DIVISOR))));
  type fsm_state_t is (idle, active); -- common to both RX and TX FSM
  type tx_state_t is
  record
    fsm_state: fsm_state_t; -- FSM state
    counter: std_logic_vector(3 downto 0); -- tick count
    bits: std_logic_vector(8 downto 0); -- bits to emit, includes start bit
    nbits: std_logic_vector(3 downto 0); -- number of bits left to send
    ready: std_logic; -- signal we are accepting a new byte
  end record;

  signal tx_state,tx_state_next: tx_state_t;
  signal sample: std_logic; -- 1 clk spike at 16x baud rate
  signal sample_counter: std_logic_vector(COUNTER_BITS-1 downto 0); -- should fit values in 0..DIVISOR-1
  
begin

  -- sample signal at 16x baud rate, 1 CLK spikes
  sample_process: process (clk,reset) is
  begin
    if reset = '1' then
      sample_counter <= (others => '0');
      sample <= '0';
    elsif rising_edge(clk) then
      if sample_counter = DIVISOR-1 then
        sample <= '1';
        sample_counter <= (others => '0');
      else
        sample <= '0';
        sample_counter <= sample_counter + 1;
      end if;
    end if;
  end process;

  -- RX, TX state registers update at each CLK, and RESET
  reg_process: process (clk,reset) is
  begin
    if reset = '1' then
      tx_state.fsm_state <= idle;
      tx_state.bits <= (others => '1');
      tx_state.nbits <= (others => '0');
      tx_state.ready <= '1';
    elsif rising_edge(clk) then
      tx_state <= tx_state_next;
    end if;
  end process;
  
  -- TX FSM
  tx_process: process (tx_state,sample,tx_enable,tx_data) is
  begin
    case tx_state.fsm_state is
    
    when idle =>
      if tx_enable = '1' then
        -- start a new bit
        tx_state_next.bits <= tx_data & '0';  -- data & start
        tx_state_next.nbits <= "0000" + 10; -- send 10 bits (includes '1' stop bit)
        tx_state_next.counter <= (others => '0');
        tx_state_next.fsm_state <= active;
        tx_state_next.ready <= '0';
      else
        -- keep idle
        tx_state_next.bits <= (others => '1');
        tx_state_next.nbits <= (others => '0');
        tx_state_next.counter <= (others => '0');
        tx_state_next.fsm_state <= idle;
        tx_state_next.ready <= '1';
      end if;
      
    when active =>
      tx_state_next <= tx_state;
      if sample = '1' then
        if tx_state.counter = 15 then
          -- send next bit
          if tx_state.nbits = 0 then
            -- turn idle
            tx_state_next.bits <= (others => '1');
            tx_state_next.nbits <= (others => '0');
            tx_state_next.counter <= (others => '0');
            tx_state_next.fsm_state <= idle;
            tx_state_next.ready <= '1';
          else
            tx_state_next.bits <= '1' & tx_state.bits(8 downto 1);
            tx_state_next.nbits <= tx_state.nbits - 1;
          end if;
        end if;
        tx_state_next.counter <= tx_state.counter + 1;
      end if;
      
    end case;
  end process;

  -- TX output
  tx_output: process (tx_state) is
  begin
    tx_ready <= tx_state.ready;
    tx <= tx_state.bits(0);
  end process;

end Behavioral;

