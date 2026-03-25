-- =============================================================================
-- top_level.vhd
-- Computer Structure I - Examination 4 | Altera DE2-115
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_level is
    Port (
        CLOCK_50    : in  std_logic;
        KEY         : in  std_logic_vector(3 downto 0);
        SW          : in  std_logic_vector(17 downto 0);
        VGA_R       : out std_logic_vector(9 downto 0);
        VGA_G       : out std_logic_vector(9 downto 0);
        VGA_B       : out std_logic_vector(9 downto 0);
        VGA_HS      : out std_logic;
        VGA_VS      : out std_logic;
        VGA_CLK     : out std_logic;
        VGA_BLANK_N : out std_logic;
        VGA_SYNC_N  : out std_logic;
        PS2_CLK     : in  std_logic;
        PS2_DAT     : in  std_logic;
        LCD_ON      : out std_logic;
        LCD_EN      : out std_logic;
        LCD_RS      : out std_logic;
        LCD_RW      : out std_logic;
        LCD_DATA    : out std_logic_vector(7 downto 4);
        HEX0        : out std_logic_vector(6 downto 0);
        HEX1        : out std_logic_vector(6 downto 0);
        HEX2        : out std_logic_vector(6 downto 0);
        HEX3        : out std_logic_vector(6 downto 0);
        HEX4        : out std_logic_vector(6 downto 0);
        HEX5        : out std_logic_vector(6 downto 0);
        HEX6        : out std_logic_vector(6 downto 0);
        HEX7        : out std_logic_vector(6 downto 0)
    );
end top_level;

architecture Behavioral of top_level is

    component pll_pixel_clk is
        port (
            areset : in  std_logic;
            inclk0 : in  std_logic;
            c0     : out std_logic;
            c1     : out std_logic;
            locked : out std_logic
        );
    end component;

    component vga_controller is
        Port (
            clk_pixel : in  std_logic;
            reset     : in  std_logic;
            mode      : in  std_logic_vector(1 downto 0);
            hsync     : out std_logic;
            vsync     : out std_logic;
            h_active  : out std_logic;
            v_active  : out std_logic;
            pixel_x   : out std_logic_vector(10 downto 0);
            pixel_y   : out std_logic_vector(10 downto 0)
        );
    end component;

    component ps2_keyboard is
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
    end component;

    component lcd_controller is
        Port (
            clk      : in  std_logic;
            reset    : in  std_logic;
            line1    : in  std_logic_vector(127 downto 0);
            line2    : in  std_logic_vector(127 downto 0);
            lcd_en   : out std_logic;
            lcd_rs   : out std_logic;
            lcd_rw   : out std_logic;
            lcd_data : out std_logic_vector(7 downto 4)
        );
    end component;

    component image_rom is
        Port (
            clk     : in  std_logic;
            pixel_x : in  std_logic_vector(10 downto 0);
            pixel_y : in  std_logic_vector(10 downto 0);
            red     : out std_logic_vector(7 downto 0);
            green   : out std_logic_vector(7 downto 0);
            blue    : out std_logic_vector(7 downto 0)
        );
    end component;

    component seg7_decoder is
        Port (
            hex_in  : in  std_logic_vector(3 downto 0);
            seg_out : out std_logic_vector(6 downto 0)
        );
    end component;

    type display_state_t is (DISP_BLACK, DISP_PICTURE);
    type nibble_array_t is array (0 to 7) of std_logic_vector(3 downto 0);
    type seg_array_t    is array (0 to 7) of std_logic_vector(6 downto 0);

    constant SC_P : std_logic_vector(7 downto 0) := x"4D";
    constant SC_B : std_logic_vector(7 downto 0) := x"32";

    constant BLANK_LINE    : std_logic_vector(127 downto 0) := x"20202020202020202020202020202020";
    constant MSG_PICTURE   : std_logic_vector(127 downto 0) := x"50696374757265202020202020202020";
    constant MSG_BLACK_LCD : std_logic_vector(127 downto 0) := x"426C61636B2020202020202020202020";

    signal reset          : std_logic;
    signal clk_25         : std_logic := '0';
    signal clk_40         : std_logic;
    signal clk_65         : std_logic;
    signal pll_locked     : std_logic;
    signal clk_pixel      : std_logic;
    signal vga_mode       : std_logic_vector(1 downto 0);
    signal h_active       : std_logic;
    signal v_active       : std_logic;
    signal pixel_x        : std_logic_vector(10 downto 0);
    signal pixel_y        : std_logic_vector(10 downto 0);
    signal img_red        : std_logic_vector(7 downto 0);
    signal img_green      : std_logic_vector(7 downto 0);
    signal img_blue       : std_logic_vector(7 downto 0);
    signal out_red        : std_logic_vector(7 downto 0);
    signal out_green      : std_logic_vector(7 downto 0);
    signal out_blue       : std_logic_vector(7 downto 0);

    signal scan_code      : std_logic_vector(7 downto 0) := (others => '0');
    signal scan_ready     : std_logic;
    signal key_pressed    : std_logic;
    signal key_valid      : std_logic;
    signal make_code      : std_logic_vector(7 downto 0) := (others => '0');
    signal break_code     : std_logic_vector(7 downto 0) := (others => '0');
    signal make_extended  : std_logic := '0';
    signal break_extended : std_logic := '0';
    signal make_event     : std_logic := '0';
    signal break_event    : std_logic := '0';

    signal lcd_line2      : std_logic_vector(127 downto 0) := BLANK_LINE;
    signal disp_state     : display_state_t := DISP_BLACK;

    signal hex_digit      : nibble_array_t := (others => (others => '0'));
    signal hex_seg        : seg_array_t;
    signal hex_blank      : std_logic_vector(7 downto 0) := (others => '1');

begin

    reset   <= not KEY(0);
    LCD_ON  <= '1';

    process(CLOCK_50, reset)
    begin
        if reset = '1' then
            clk_25 <= '0';
        elsif rising_edge(CLOCK_50) then
            clk_25 <= not clk_25;
        end if;
    end process;

    PLL_INST : pll_pixel_clk
        port map (
            areset => reset,
            inclk0 => CLOCK_50,
            c0     => clk_40,
            c1     => clk_65,
            locked => pll_locked
        );

    process(SW)
    begin
        if SW(2) = '1' then
            vga_mode <= "00";
        elsif SW(1) = '1' then
            vga_mode <= "01";
        elsif SW(0) = '1' then
            vga_mode <= "10";
        else
            vga_mode <= "00";
        end if;
    end process;

    clk_pixel  <= clk_65 when vga_mode = "10" else
                  clk_40 when vga_mode = "01" else
                  clk_25;

    VGA_CLK    <= clk_pixel;
    VGA_SYNC_N <= '0';

    VGA_CTRL : vga_controller
        port map (
            clk_pixel => clk_pixel,
            reset     => reset,
            mode      => vga_mode,
            hsync     => VGA_HS,
            vsync     => VGA_VS,
            h_active  => h_active,
            v_active  => v_active,
            pixel_x   => pixel_x,
            pixel_y   => pixel_y
        );

    VGA_BLANK_N <= h_active and v_active;

    IMG_ROM : image_rom
        port map (
            clk     => clk_pixel,
            pixel_x => pixel_x,
            pixel_y => pixel_y,
            red     => img_red,
            green   => img_green,
            blue    => img_blue
        );

    process(h_active, v_active, disp_state, img_red, img_green, img_blue)
    begin
        if h_active = '1' and v_active = '1' then
            if disp_state = DISP_PICTURE then
                out_red   <= img_red;
                out_green <= img_green;
                out_blue  <= img_blue;
            else
                out_red   <= (others => '0');
                out_green <= (others => '0');
                out_blue  <= (others => '0');
            end if;
        else
            out_red   <= (others => '0');
            out_green <= (others => '0');
            out_blue  <= (others => '0');
        end if;
    end process;

    VGA_R <= out_red   & "00";
    VGA_G <= out_green & "00";
    VGA_B <= out_blue  & "00";

    KB_CTRL : ps2_keyboard
        port map (
            clk            => CLOCK_50,
            reset          => reset,
            ps2_clk        => PS2_CLK,
            ps2_data       => PS2_DAT,
            scan_code      => scan_code,
            scan_ready     => scan_ready,
            key_pressed    => key_pressed,
            key_valid      => key_valid,
            make_code      => make_code,
            break_code     => break_code,
            make_extended  => make_extended,
            break_extended => break_extended,
            make_event     => make_event,
            break_event    => break_event
        );

    process(CLOCK_50, reset)
        variable next_digit : nibble_array_t;
        variable next_blank : std_logic_vector(7 downto 0);
    begin
        if reset = '1' then
            disp_state <= DISP_BLACK;
            lcd_line2  <= BLANK_LINE;
            hex_digit  <= (others => (others => '0'));
            hex_blank  <= (others => '1');
        elsif rising_edge(CLOCK_50) then
            if make_event = '1' then
                next_digit := (others => (others => '0'));
                next_blank := (others => '1');

                if make_extended = '1' then
                    next_blank(7) := '0';
                    next_blank(6) := '0';
                    next_blank(5) := '0';
                    next_blank(4) := '0';
                    next_digit(7) := x"E";
                    next_digit(6) := x"0";
                    next_digit(5) := make_code(7 downto 4);
                    next_digit(4) := make_code(3 downto 0);
                    lcd_line2      <= BLANK_LINE;
                else
                    next_blank(5) := '0';
                    next_blank(4) := '0';
                    next_digit(5) := make_code(7 downto 4);
                    next_digit(4) := make_code(3 downto 0);

                    if make_code = SC_P then
                        disp_state <= DISP_PICTURE;
                        lcd_line2  <= MSG_PICTURE;
                    elsif make_code = SC_B then
                        disp_state <= DISP_BLACK;
                        lcd_line2  <= MSG_BLACK_LCD;
                    else
                        lcd_line2  <= BLANK_LINE;
                    end if;
                end if;

                hex_digit <= next_digit;
                hex_blank <= next_blank;

            elsif break_event = '1' then
                next_digit := (others => (others => '0'));
                next_blank := (others => '1');

                if break_extended = '1' then
                    next_blank(5) := '0';
                    next_blank(4) := '0';
                    next_blank(3) := '0';
                    next_blank(2) := '0';
                    next_blank(1) := '0';
                    next_blank(0) := '0';
                    next_digit(5) := x"E";
                    next_digit(4) := x"0";
                    next_digit(3) := x"F";
                    next_digit(2) := x"0";
                    next_digit(1) := break_code(7 downto 4);
                    next_digit(0) := break_code(3 downto 0);
                else
                    next_blank(3) := '0';
                    next_blank(2) := '0';
                    next_blank(1) := '0';
                    next_blank(0) := '0';
                    next_digit(3) := x"F";
                    next_digit(2) := x"0";
                    next_digit(1) := break_code(7 downto 4);
                    next_digit(0) := break_code(3 downto 0);
                end if;

                hex_digit <= next_digit;
                hex_blank <= next_blank;
                lcd_line2 <= BLANK_LINE;
            end if;
        end if;
    end process;

    LCD_CTRL : lcd_controller
        port map (
            clk      => CLOCK_50,
            reset    => reset,
            line1    => BLANK_LINE,
            line2    => lcd_line2,
            lcd_en   => LCD_EN,
            lcd_rs   => LCD_RS,
            lcd_rw   => LCD_RW,
            lcd_data => LCD_DATA
        );

    SEG_GEN : for i in 0 to 7 generate
    begin
        SEG_INST : seg7_decoder
            port map (
                hex_in  => hex_digit(i),
                seg_out => hex_seg(i)
            );
    end generate;

    HEX0 <= "1111111" when hex_blank(0) = '1' else hex_seg(0);
    HEX1 <= "1111111" when hex_blank(1) = '1' else hex_seg(1);
    HEX2 <= "1111111" when hex_blank(2) = '1' else hex_seg(2);
    HEX3 <= "1111111" when hex_blank(3) = '1' else hex_seg(3);
    HEX4 <= "1111111" when hex_blank(4) = '1' else hex_seg(4);
    HEX5 <= "1111111" when hex_blank(5) = '1' else hex_seg(5);
    HEX6 <= "1111111" when hex_blank(6) = '1' else hex_seg(6);
    HEX7 <= "1111111" when hex_blank(7) = '1' else hex_seg(7);

end Behavioral;