-- =============================================================================
-- lcd_controller.vhd
-- HD44780-Compatible LCD Controller for DE2-115 (16x2 LCD)
-- Sends 4-bit nibbles using the standard initialization sequence.
-- DE2-115 LCD pins: LCD_EN, LCD_RS, LCD_RW, LCD_DATA[7:4] (upper nibble)
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity lcd_controller is
    Port (
        clk         : in  std_logic;   -- 50 MHz system clock
        reset       : in  std_logic;

        -- Message inputs
        -- Line 1: 16 characters (first  line of LCD)
        -- Line 2: 16 characters (second line of LCD)
        line1       : in  std_logic_vector(127 downto 0);  -- 16 bytes, MSB = leftmost char
        line2       : in  std_logic_vector(127 downto 0);

        -- LCD physical interface (4-bit mode)
        lcd_en      : out std_logic;
        lcd_rs      : out std_logic;
        lcd_rw      : out std_logic;
        lcd_data    : out std_logic_vector(7 downto 4)
    );
end lcd_controller;

architecture Behavioral of lcd_controller is

    -- -------------------------------------------------------------------------
    -- Timing: 50 MHz -> 1 µs = 50 counts; 5 ms = 250,000 counts
    -- -------------------------------------------------------------------------
    constant CLK_FREQ      : integer := 50_000_000;
    constant DELAY_15MS    : integer := 750_000;   -- 15 ms  power-on delay
    constant DELAY_5MS     : integer := 250_000;   -- 5  ms  init delay
    constant DELAY_200US   : integer := 10_000;    -- 200 µs init delay
    constant DELAY_50US    : integer := 2_500;     -- 50  µs execution delay
    constant EN_PULSE_US   : integer := 25;        -- 0.5 µs EN pulse (25 * 20 ns)

    -- -------------------------------------------------------------------------
    -- State machine
    -- -------------------------------------------------------------------------
    type lcd_state_t is (
        S_INIT_WAIT,        -- Wait 15 ms after power-on
        S_FUNC_SET1,        -- Function set (8-bit) #1
        S_FUNC_SET2,        -- Function set (8-bit) #2
        S_FUNC_SET3,        -- Function set (4-bit switch)
        S_FUNC_SET4,        -- Function set (4-bit, 2 lines, 5x8 font)
        S_DISPLAY_OFF,      -- Display off
        S_CLEAR,            -- Clear display
        S_ENTRY_MODE,       -- Entry mode set
        S_DISPLAY_ON,       -- Display on, cursor off
        S_WRITE,            -- Write characters
        S_IDLE              -- Steady state; waits for line change
    );

    signal state      : lcd_state_t := S_INIT_WAIT;
    signal delay_cnt  : integer range 0 to 750_000 := 0;
    signal en_cnt     : integer range 0 to 50 := 0;
    signal en_phase   : std_logic := '0';  -- '0' = setup, '1' = hold

    -- Character write state
    signal char_index : integer range 0 to 31 := 0;  -- 0..15 line1, 16..31 line2

    -- Nibble state: each byte requires 2 nibbles (high then low)
    signal nibble_sel : std_logic := '0';  -- '0' = high nibble, '1' = low nibble

    -- Data / command to write
    signal lcd_rs_reg  : std_logic := '0';
    signal lcd_data_hi : std_logic_vector(3 downto 0) := (others => '0');
    signal lcd_data_lo : std_logic_vector(3 downto 0) := (others => '0');

    -- Last-seen message (detect changes to trigger refresh)
    signal line1_prev  : std_logic_vector(127 downto 0) := (others => '0');
    signal line2_prev  : std_logic_vector(127 downto 0) := (others => '0');
    signal refresh     : std_logic := '0';

    -- Helper: extract character byte from line vector
    function get_char(line : std_logic_vector(127 downto 0); idx : integer)
        return std_logic_vector is
        variable byte_idx : integer;
    begin
        byte_idx := 15 - idx;  -- MSB = char 0
        return line(byte_idx*8+7 downto byte_idx*8);
    end function;

    function get_char2(line : std_logic_vector(127 downto 0); idx : integer)
        return std_logic_vector is
        variable byte_idx : integer;
    begin
        byte_idx := 15 - idx;
        return line(byte_idx*8+7 downto byte_idx*8);
    end function;

begin

    lcd_rw <= '0';  -- Always write

    -- -------------------------------------------------------------------------
    -- Main state machine
    -- -------------------------------------------------------------------------
    process(clk, reset)
        variable current_char : std_logic_vector(7 downto 0);
    begin
        if reset = '1' then
            state      <= S_INIT_WAIT;
            delay_cnt  <= 0;
            en_cnt     <= 0;
            en_phase   <= '0';
            char_index <= 0;
            nibble_sel <= '0';
            lcd_en     <= '0';
            lcd_rs     <= '0';
            lcd_data   <= (others => '0');
            refresh    <= '0';
            line1_prev <= (others => '0');
            line2_prev <= (others => '0');

        elsif rising_edge(clk) then

            -- Detect message change
            if (line1 /= line1_prev or line2 /= line2_prev) then
                line1_prev <= line1;
                line2_prev <= line2;
                refresh    <= '1';
            end if;

            case state is

                -- ---------------------------------------------------------
                when S_INIT_WAIT =>
                    lcd_en <= '0';
                    if delay_cnt = DELAY_15MS then
                        delay_cnt <= 0;
                        state     <= S_FUNC_SET1;
                    else
                        delay_cnt <= delay_cnt + 1;
                    end if;

                -- ---------------------------------------------------------
                -- Initialization: send 0x3 three times in 8-bit mode
                -- ---------------------------------------------------------
                when S_FUNC_SET1 =>
                    lcd_rs   <= '0';
                    lcd_data <= "0011";  -- 0x3_ function set
                    if en_phase = '0' then
                        lcd_en   <= '1';
                        en_cnt   <= en_cnt + 1;
                        if en_cnt = EN_PULSE_US then
                            en_cnt  <= 0;
                            en_phase <= '1';
                        end if;
                    else
                        lcd_en <= '0';
                        if delay_cnt = DELAY_5MS then
                            delay_cnt <= 0;
                            en_phase  <= '0';
                            state     <= S_FUNC_SET2;
                        else
                            delay_cnt <= delay_cnt + 1;
                        end if;
                    end if;

                when S_FUNC_SET2 =>
                    lcd_rs   <= '0';
                    lcd_data <= "0011";
                    if en_phase = '0' then
                        lcd_en <= '1';
                        en_cnt <= en_cnt + 1;
                        if en_cnt = EN_PULSE_US then
                            en_cnt   <= 0;
                            en_phase <= '1';
                        end if;
                    else
                        lcd_en <= '0';
                        if delay_cnt = DELAY_200US then
                            delay_cnt <= 0;
                            en_phase  <= '0';
                            state     <= S_FUNC_SET3;
                        else
                            delay_cnt <= delay_cnt + 1;
                        end if;
                    end if;

                when S_FUNC_SET3 =>
                    lcd_rs   <= '0';
                    lcd_data <= "0011";  -- 8-bit one last time
                    if en_phase = '0' then
                        lcd_en <= '1';
                        en_cnt <= en_cnt + 1;
                        if en_cnt = EN_PULSE_US then
                            en_cnt   <= 0;
                            en_phase <= '1';
                        end if;
                    else
                        lcd_en <= '0';
                        if delay_cnt = DELAY_50US then
                            delay_cnt <= 0;
                            en_phase  <= '0';
                            state     <= S_FUNC_SET4;
                        else
                            delay_cnt <= delay_cnt + 1;
                        end if;
                    end if;

                when S_FUNC_SET4 =>
                    -- Switch to 4-bit mode: send 0x2 (only high nibble)
                    lcd_rs   <= '0';
                    lcd_data <= "0010";
                    if en_phase = '0' then
                        lcd_en <= '1';
                        en_cnt <= en_cnt + 1;
                        if en_cnt = EN_PULSE_US then
                            en_cnt   <= 0;
                            en_phase <= '1';
                        end if;
                    else
                        lcd_en <= '0';
                        if delay_cnt = DELAY_50US then
                            delay_cnt <= 0;
                            en_phase  <= '0';
                            -- Now send full 4-bit cmd: 0x28 (2 lines, 5x8)
                            lcd_data_hi <= "0010";
                            lcd_data_lo <= "1000";
                            lcd_rs_reg  <= '0';
                            state       <= S_DISPLAY_OFF;
                        else
                            delay_cnt <= delay_cnt + 1;
                        end if;
                    end if;

                -- ---------------------------------------------------------
                -- From here, all commands are sent as two 4-bit nibbles
                -- Display off: 0x08
                -- ---------------------------------------------------------
                when S_DISPLAY_OFF =>
                    lcd_data_hi <= "0000";
                    lcd_data_lo <= "1000";
                    lcd_rs_reg  <= '0';
                    -- Send via nibble engine below
                    state <= S_CLEAR;

                when S_CLEAR =>
                    lcd_data_hi <= "0000";
                    lcd_data_lo <= "0001";
                    lcd_rs_reg  <= '0';
                    state <= S_ENTRY_MODE;

                when S_ENTRY_MODE =>
                    lcd_data_hi <= "0000";
                    lcd_data_lo <= "0110";  -- Increment, no shift
                    lcd_rs_reg  <= '0';
                    state <= S_DISPLAY_ON;

                when S_DISPLAY_ON =>
                    lcd_data_hi <= "0000";
                    lcd_data_lo <= "1100";  -- Display on, cursor off, blink off
                    lcd_rs_reg  <= '0';
                    state       <= S_WRITE;
                    char_index  <= 0;

                -- ---------------------------------------------------------
                -- Write all 32 characters (16 line1 + 16 line2)
                -- ---------------------------------------------------------
                when S_WRITE =>
                    if char_index < 16 then
                        current_char := get_char(line1, char_index);
                    elsif char_index < 32 then
                        current_char := get_char2(line2, char_index - 16);
                    else
                        current_char := x"20";  -- Space
                    end if;

                    -- Set DDRAM address at start of each line
                    if char_index = 0 then
                        lcd_data_hi <= "1000";  -- Cmd 0x80: DDRAM addr = 0x00
                        lcd_data_lo <= "0000";
                        lcd_rs_reg  <= '0';
                    elsif char_index = 16 then
                        lcd_data_hi <= "1100";  -- Cmd 0xC0: DDRAM addr = 0x40
                        lcd_data_lo <= "0000";
                        lcd_rs_reg  <= '0';
                    else
                        lcd_data_hi <= current_char(7 downto 4);
                        lcd_data_lo <= current_char(3 downto 0);
                        lcd_rs_reg  <= '1';  -- Data write
                    end if;

                    -- Advance index (address commands don't advance char_index char count)
                    if char_index /= 0 and char_index /= 16 then
                        if char_index = 31 then
                            char_index <= 0;
                            state      <= S_IDLE;
                        else
                            char_index <= char_index + 1;
                        end if;
                    else
                        char_index <= char_index + 1;
                    end if;

                -- ---------------------------------------------------------
                when S_IDLE =>
                    if refresh = '1' then
                        refresh    <= '0';
                        char_index <= 0;
                        state      <= S_WRITE;
                    end if;

                when others =>
                    state <= S_INIT_WAIT;

            end case;

            -- -----------------------------------------------------------------
            -- 4-bit nibble engine: drives EN, RS, DATA for two nibbles
            -- This runs concurrently with state transitions above
            -- (Simplified: states set lcd_data_hi/lo, engine drives pins)
            -- -----------------------------------------------------------------
            if state /= S_IDLE and state /= S_INIT_WAIT then
                if nibble_sel = '0' then
                    lcd_rs   <= lcd_rs_reg;
                    lcd_data <= lcd_data_hi;
                    lcd_en   <= '1';
                    en_cnt   <= en_cnt + 1;
                    if en_cnt >= EN_PULSE_US then
                        lcd_en     <= '0';
                        en_cnt     <= 0;
                        nibble_sel <= '1';
                    end if;
                else
                    lcd_rs   <= lcd_rs_reg;
                    lcd_data <= lcd_data_lo;
                    lcd_en   <= '1';
                    en_cnt   <= en_cnt + 1;
                    if en_cnt >= EN_PULSE_US then
                        lcd_en     <= '0';
                        en_cnt     <= 0;
                        nibble_sel <= '0';
                    end if;
                end if;
            end if;

        end if;
    end process;

end Behavioral;
