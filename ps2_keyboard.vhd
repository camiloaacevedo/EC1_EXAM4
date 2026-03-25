-- =============================================================================
-- ps2_keyboard.vhd
-- Interfaz PS/2 para teclado
-- Recibe scan codes Set 2, detecta make y break codes
-- Autor: Equipo | 2026
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ps2_keyboard is
    Port (
        clk            : in  std_logic;
        reset          : in  std_logic;
        ps2_clk        : in  std_logic;
        ps2_data       : in  std_logic;
        scan_code      : out std_logic_vector(7 downto 0);
        scan_ready     : out std_logic;
        key_pressed    : out std_logic;
        key_valid      : out std_logic;
        make_code      : out std_logic_vector(7 downto 0);
        break_code     : out std_logic_vector(7 downto 0);
        make_extended  : out std_logic;
        break_extended : out std_logic;
        make_event     : out std_logic;
        break_event    : out std_logic
    );
end ps2_keyboard;

architecture Behavioral of ps2_keyboard is

    signal clk_s0, clk_s1, clk_s2 : std_logic := '1';
    signal data_s                 : std_logic := '1';
    signal falling_edge_ps2       : std_logic;

    signal shift_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal bit_cnt    : integer range 0 to 11 := 0;
    signal receiving  : std_logic := '0';
    signal byte_ready : std_logic := '0';
    signal rx_byte    : std_logic_vector(7 downto 0) := (others => '0');

    signal break_flag       : std_logic := '0';
    signal extended_flag    : std_logic := '0';
    signal last_make_code   : std_logic_vector(7 downto 0) := (others => '0');
    signal last_make_ext    : std_logic := '0';
    signal key_is_held      : std_logic := '0';

begin

    process(clk, reset)
    begin
        if reset = '1' then
            clk_s0 <= '1';
            clk_s1 <= '1';
            clk_s2 <= '1';
            data_s <= '1';
        elsif rising_edge(clk) then
            clk_s0 <= ps2_clk;
            clk_s1 <= clk_s0;
            clk_s2 <= clk_s1;
            data_s <= ps2_data;
        end if;
    end process;

    falling_edge_ps2 <= clk_s2 and (not clk_s1);

    process(clk, reset)
    begin
        if reset = '1' then
            shift_reg  <= (others => '0');
            bit_cnt    <= 0;
            receiving  <= '0';
            byte_ready <= '0';
            rx_byte    <= (others => '0');
        elsif rising_edge(clk) then
            byte_ready <= '0';

            if falling_edge_ps2 = '1' then
                if receiving = '0' then
                    if data_s = '0' then
                        receiving <= '1';
                        bit_cnt   <= 0;
                    end if;
                else
                    if bit_cnt < 8 then
                        shift_reg <= data_s & shift_reg(7 downto 1);
                        bit_cnt   <= bit_cnt + 1;
                    elsif bit_cnt = 8 then
                        bit_cnt <= bit_cnt + 1;
                    else
                        receiving  <= '0';
                        bit_cnt    <= 0;
                        byte_ready <= '1';
                        rx_byte    <= shift_reg;
                    end if;
                end if;
            end if;
        end if;
    end process;

    process(clk, reset)
    begin
        if reset = '1' then
            scan_code      <= (others => '0');
            scan_ready     <= '0';
            key_pressed    <= '0';
            key_valid      <= '0';
            make_code      <= (others => '0');
            break_code     <= (others => '0');
            make_extended  <= '0';
            break_extended <= '0';
            make_event     <= '0';
            break_event    <= '0';
            break_flag     <= '0';
            extended_flag  <= '0';
            last_make_code <= (others => '0');
            last_make_ext  <= '0';
            key_is_held    <= '0';
        elsif rising_edge(clk) then
            scan_ready  <= '0';
            key_valid   <= '0';
            make_event  <= '0';
            break_event <= '0';

            if byte_ready = '1' then
                scan_code  <= rx_byte;
                scan_ready <= '1';

                if rx_byte = x"E0" then
                    extended_flag <= '1';

                elsif rx_byte = x"F0" then
                    break_flag <= '1';

                else
                    if break_flag = '1' then
                        key_pressed    <= '0';
                        key_valid      <= '1';
                        break_event    <= '1';
                        break_code     <= rx_byte;
                        break_extended <= extended_flag;
                        break_flag     <= '0';
                        extended_flag  <= '0';
                        key_is_held    <= '0';

                    else
                        if not (key_is_held = '1' and last_make_code = rx_byte and last_make_ext = extended_flag) then
                            key_pressed    <= '1';
                            key_valid      <= '1';
                            make_event     <= '1';
                            make_code      <= rx_byte;
                            make_extended  <= extended_flag;
                            last_make_code <= rx_byte;
                            last_make_ext  <= extended_flag;
                            key_is_held    <= '1';
                        end if;

                        extended_flag <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;

end Behavioral;