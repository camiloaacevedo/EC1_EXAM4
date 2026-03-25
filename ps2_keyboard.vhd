-- =============================================================================
-- ps2_keyboard.vhd
-- PS/2 Keyboard Interface
-- Receives serial scan codes from a PS/2 keyboard.
-- DE2-115 PS2_CLK = PIN_G6, PS2_DAT = PIN_H5
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ps2_keyboard is
    Port (
        clk         : in  std_logic;   -- System clock (50 MHz)
        reset       : in  std_logic;

        ps2_clk     : in  std_logic;   -- PS/2 clock line (open collector, pulled up)
        ps2_data    : in  std_logic;   -- PS/2 data line  (open collector, pulled up)

        scan_code   : out std_logic_vector(7 downto 0);  -- Last received byte
        scan_ready  : out std_logic;   -- Pulses high for 1 clock when new byte ready
        key_pressed : out std_logic;   -- '1' = key down, '0' = key up (after F0 break code)
        key_valid   : out std_logic    -- Pulses high for 1 clock on key_pressed update
    );
end ps2_keyboard;

architecture Behavioral of ps2_keyboard is

    -- -------------------------------------------------------------------------
    -- Synchronize PS/2 clock to system clock domain (2-FF synchronizer)
    -- -------------------------------------------------------------------------
    signal ps2_clk_sync0 : std_logic := '1';
    signal ps2_clk_sync1 : std_logic := '1';
    signal ps2_clk_sync2 : std_logic := '1';  -- One more for edge detect
    signal ps2_clk_fall  : std_logic;          -- Falling edge of PS/2 clock

    signal ps2_data_sync : std_logic := '1';

    -- -------------------------------------------------------------------------
    -- Shift register and bit counter for the 11-bit PS/2 frame:
    --   1 start bit (0), 8 data bits (LSB first), 1 odd-parity bit, 1 stop bit (1)
    -- -------------------------------------------------------------------------
    signal shift_reg  : std_logic_vector(10 downto 0) := (others => '0');
    signal bit_count  : integer range 0 to 10 := 0;
    signal rx_busy    : std_logic := '0';

    -- -------------------------------------------------------------------------
    -- Byte assembler and protocol state machine
    -- -------------------------------------------------------------------------
    signal byte_ready     : std_logic := '0';
    signal received_byte  : std_logic_vector(7 downto 0) := (others => '0');

    -- Break code detection (F0h prefix indicates key release)
    signal break_detected : std_logic := '0';

begin

    -- -------------------------------------------------------------------------
    -- Synchronize ps2_clk and ps2_data to system clock
    -- -------------------------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            ps2_clk_sync0 <= '1';
            ps2_clk_sync1 <= '1';
            ps2_clk_sync2 <= '1';
            ps2_data_sync <= '1';
        elsif rising_edge(clk) then
            ps2_clk_sync0 <= ps2_clk;
            ps2_clk_sync1 <= ps2_clk_sync0;
            ps2_clk_sync2 <= ps2_clk_sync1;
            ps2_data_sync <= ps2_data;
        end if;
    end process;

    -- Falling edge of PS/2 clock (synchronized)
    ps2_clk_fall <= ps2_clk_sync2 and (not ps2_clk_sync1);

    -- -------------------------------------------------------------------------
    -- Serial receiver: sample data on falling edge of PS/2 clock
    -- -------------------------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            shift_reg  <= (others => '0');
            bit_count  <= 0;
            rx_busy    <= '0';
            byte_ready <= '0';
        elsif rising_edge(clk) then
            byte_ready <= '0';  -- Default: no new byte

            if ps2_clk_fall = '1' then
                if rx_busy = '0' then
                    -- Waiting for start bit (logic '0')
                    if ps2_data_sync = '0' then
                        rx_busy   <= '1';
                        bit_count <= 0;
                        -- Start bit captured; data bits come next
                    end if;
                else
                    -- Shift in the bit (LSB first → bits 1..8 are data)
                    shift_reg <= ps2_data_sync & shift_reg(10 downto 1);
                    bit_count <= bit_count + 1;

                    if bit_count = 10 then
                        -- All 11 bits received (start + 8 data + parity + stop)
                        -- Basic parity check (odd parity on data bits)
                        rx_busy    <= '0';
                        bit_count  <= 0;
                        byte_ready <= '1';
                        -- Data byte is in shift_reg[8:1] after 10 falling edges
                        received_byte <= shift_reg(8 downto 1);
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- Scan code decoder: detect break code (F0) and emit events
    -- -------------------------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            scan_code     <= (others => '0');
            scan_ready    <= '0';
            key_pressed   <= '0';
            key_valid     <= '0';
            break_detected <= '0';
        elsif rising_edge(clk) then
            scan_ready  <= '0';
            key_valid   <= '0';

            if byte_ready = '1' then
                scan_code  <= received_byte;
                scan_ready <= '1';

                if received_byte = x"F0" then
                    -- Break code prefix: next byte is the released key
                    break_detected <= '1';
                else
                    if break_detected = '1' then
                        -- Key release event
                        key_pressed    <= '0';
                        key_valid      <= '1';
                        break_detected <= '0';
                    else
                        -- Key press event (make code)
                        key_pressed <= '1';
                        key_valid   <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

end Behavioral;
