-- Eric Bainville
-- Mar 2013

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.math_real.all;

entity basic_uart_rx is
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
    rx_data: out std_logic_vector(7 downto 0); -- received byte
    rx_enable: out std_logic;                  -- validates received byte (1 system clock spike)
    
    -- Physical interface
    rx: in std_logic
  );
end basic_uart_rx;

architecture Behavioral of basic_uart_rx is
  constant COUNTER_BITS : natural := integer(ceil(log2(real(DIVISOR))));
  type fsm_state_t is (idle, active); -- common to both RX and TX FSM
  type rx_state_t is
  record
    fsm_state: fsm_state_t;                -- FSM state
    counter: std_logic_vector(3 downto 0); -- tick count
    bits: std_logic_vector(7 downto 0);    -- received bits
    nbits: std_logic_vector(3 downto 0);   -- number of received bits (includes start bit)
    enable: std_logic;                     -- signal we received a new byte
  end record;
  
  signal rx_state,rx_state_next: rx_state_t;
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
      rx_state.fsm_state <= idle;
      rx_state.bits <= (others => '0');
      rx_state.nbits <= (others => '0');
      rx_state.enable <= '0';
    elsif rising_edge(clk) then
      rx_state <= rx_state_next;
    end if;
  end process;
  
  -- RX FSM
  rx_process: process (rx_state,sample,rx) is
  begin
    case rx_state.fsm_state is
    
    when idle =>
      rx_state_next.counter <= (others => '0');
      rx_state_next.bits <= (others => '0');
      rx_state_next.nbits <= (others => '0');
      rx_state_next.enable <= '0';
      if rx = '0' then
        -- start a new byte
        rx_state_next.fsm_state <= active;
      else
        -- keep idle
        rx_state_next.fsm_state <= idle;
      end if;
      
    when active =>
      rx_state_next <= rx_state;
      if sample = '1' then
        if rx_state.counter = 8 then
          -- sample next RX bit (at the middle of the counter cycle)
          if rx_state.nbits = 9 then
            rx_state_next.fsm_state <= idle; -- back to idle state to wait for next start bit
            rx_state_next.enable <= rx; -- OK if stop bit is '1'
          else
            rx_state_next.bits <= rx & rx_state.bits(7 downto 1);
            rx_state_next.nbits <= rx_state.nbits + 1;
          end if;
        end if;
        rx_state_next.counter <= rx_state.counter + 1;
      end if;
      
    end case;
  end process;
  
  -- RX output
  rx_output: process (rx_state) is
  begin
    rx_enable <= rx_state.enable;
    rx_data <= rx_state.bits;
  end process;

end Behavioral;

