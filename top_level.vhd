-- =============================================================================
-- top_level.vhd
-- Computer Structure I - Examination 4 | Altera DE2-115
-- Autor: Equipo | Fecha: 2026
--
-- Cambios v2:
--   - HEX3:HEX2 muestra make code (tecla presionada)
--   - HEX1:HEX0 muestra break code (tecla soltada)
--   - LCD muestra "Picture" o "Black" segun estado
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

    -- =========================================================================
    -- Componentes
    -- =========================================================================
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
            clk         : in  std_logic;
            reset       : in  std_logic;
            ps2_clk     : in  std_logic;
            ps2_data    : in  std_logic;
            scan_code   : out std_logic_vector(7 downto 0);
            scan_ready  : out std_logic;
            key_pressed : out std_logic;
            key_valid   : out std_logic
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

    -- =========================================================================
    -- LCD controller embebido directamente (mas simple y robusto)
    -- =========================================================================
    -- Se implementa como proceso en este mismo archivo
    -- para evitar problemas de timing en la inicializacion

    -- =========================================================================
    -- Senales
    -- =========================================================================
    signal reset      : std_logic;
    signal clk_40     : std_logic;
    signal clk_65     : std_logic;
    signal pll_locked : std_logic;
    signal clk_25     : std_logic := '0';
    signal clk_pixel  : std_logic;
    signal vga_mode   : std_logic_vector(1 downto 0);

    signal h_active   : std_logic;
    signal v_active   : std_logic;
    signal pixel_x    : std_logic_vector(10 downto 0);
    signal pixel_y    : std_logic_vector(10 downto 0);

    signal img_red    : std_logic_vector(7 downto 0);
    signal img_green  : std_logic_vector(7 downto 0);
    signal img_blue   : std_logic_vector(7 downto 0);
    signal out_red    : std_logic_vector(7 downto 0);
    signal out_green  : std_logic_vector(7 downto 0);
    signal out_blue   : std_logic_vector(7 downto 0);

    signal scan_code   : std_logic_vector(7 downto 0) := (others => '0');
    signal scan_ready  : std_logic;
    signal key_pressed : std_logic;
    signal key_valid   : std_logic;

    -- Registros separados para make y break code
    signal make_code  : std_logic_vector(7 downto 0) := (others => '0');
    signal break_code : std_logic_vector(7 downto 0) := (others => '0');

    type display_state_t is (DISP_BLACK, DISP_PICTURE);
    signal disp_state : display_state_t := DISP_BLACK;

    constant SC_P : std_logic_vector(7 downto 0) := x"4D";
    constant SC_B : std_logic_vector(7 downto 0) := x"32";

    -- =========================================================================
    -- LCD directo (sin componente separado)
    -- =========================================================================
    -- Estados de la maquina LCD
    type lcd_state_t is (
        LCD_POWER_UP,
        LCD_INIT_1, LCD_INIT_2, LCD_INIT_3, LCD_INIT_4,
        LCD_FUNC_SET, LCD_DISP_OFF, LCD_CLEAR, LCD_ENTRY, LCD_DISP_ON,
        LCD_GOTO_L1, LCD_WRITE_L1,
        LCD_GOTO_L2, LCD_WRITE_L2,
        LCD_IDLE
    );
    signal lcd_state    : lcd_state_t := LCD_POWER_UP;
    signal lcd_delay    : integer range 0 to 1_000_000 := 0;
    signal lcd_char_idx : integer range 0 to 15 := 0;
    signal lcd_nibble   : std_logic := '0';  -- 0=high nibble, 1=low nibble
    signal lcd_en_sig   : std_logic := '0';
    signal lcd_rs_sig   : std_logic := '0';
    signal lcd_data_sig : std_logic_vector(7 downto 4) := (others => '0');
    signal lcd_byte     : std_logic_vector(7 downto 0) := (others => '0');
    signal lcd_en_cnt   : integer range 0 to 100 := 0;
    signal lcd_en_phase : std_logic := '0';
    signal lcd_refresh  : std_logic := '0';

    -- Mensajes LCD fijos (ASCII, 16 chars)
    -- Linea 1: "  VGA DISPLAY   "
    type char_array is array(0 to 15) of std_logic_vector(7 downto 0);
    constant LINE1 : char_array := (
        x"20", x"20", x"56", x"47", x"41", x"20",
        x"44", x"49", x"53", x"50", x"4C", x"41",
        x"59", x"20", x"20", x"20"
    );
    -- "Picture        "
    constant MSG_PIC : char_array := (
        x"50", x"69", x"63", x"74", x"75", x"72",
        x"65", x"20", x"20", x"20", x"20", x"20",
        x"20", x"20", x"20", x"20"
    );
    -- "Black          "
    constant MSG_BLK : char_array := (
        x"42", x"6C", x"61", x"63", x"6B", x"20",
        x"20", x"20", x"20", x"20", x"20", x"20",
        x"20", x"20", x"20", x"20"
    );

    signal lcd_line2 : char_array := MSG_BLK;
    signal disp_prev  : display_state_t := DISP_PICTURE; -- forzar primer refresh

begin

    -- =========================================================================
    -- Reset
    -- =========================================================================
    reset <= not KEY(0);

    -- =========================================================================
    -- 25 MHz divisor por 2
    -- =========================================================================
    process(CLOCK_50, reset)
    begin
        if reset = '1' then
            clk_25 <= '0';
        elsif rising_edge(CLOCK_50) then
            clk_25 <= not clk_25;
        end if;
    end process;

    -- =========================================================================
    -- PLL
    -- =========================================================================
    PLL_INST : pll_pixel_clk
        port map (
            areset => reset,
            inclk0 => CLOCK_50,
            c0     => clk_40,
            c1     => clk_65,
            locked => pll_locked
        );

    -- =========================================================================
    -- Seleccion modo VGA
    -- =========================================================================
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

    -- =========================================================================
    -- VGA Controller
    -- =========================================================================
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

    -- =========================================================================
    -- Image ROM
    -- =========================================================================
    IMG_ROM : image_rom
        port map (
            clk     => clk_pixel,
            pixel_x => pixel_x,
            pixel_y => pixel_y,
            red     => img_red,
            green   => img_green,
            blue    => img_blue
        );

    -- =========================================================================
    -- Mux VGA
    -- =========================================================================
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

    -- =========================================================================
    -- PS/2 Keyboard
    -- =========================================================================
    KB_CTRL : ps2_keyboard
        port map (
            clk         => CLOCK_50,
            reset       => reset,
            ps2_clk     => PS2_CLK,
            ps2_data    => PS2_DAT,
            scan_code   => scan_code,
            scan_ready  => scan_ready,
            key_pressed => key_pressed,
            key_valid   => key_valid
        );

    -- =========================================================================
    -- Manejador de teclas
    -- Separa make codes y break codes en registros distintos
    -- =========================================================================
    process(CLOCK_50, reset)
    begin
        if reset = '1' then
            disp_state <= DISP_BLACK;
            make_code  <= (others => '0');
            break_code <= (others => '0');
            lcd_line2  <= MSG_BLK;
        elsif rising_edge(CLOCK_50) then
            if key_valid = '1' then
                if key_pressed = '1' then
                    -- Tecla presionada: guardar make code
                    make_code <= scan_code;
                    -- Cambiar display segun tecla
                    if scan_code = SC_P then
                        disp_state <= DISP_PICTURE;
                        lcd_line2  <= MSG_PIC;
                    elsif scan_code = SC_B then
                        disp_state <= DISP_BLACK;
                        lcd_line2  <= MSG_BLK;
                    end if;
                else
                    -- Tecla soltada: guardar break code
                    break_code <= scan_code;
                end if;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- LCD Controller embebido (maquina de estados robusta)
    -- Maneja: inicializacion + escritura de 2 lineas + refresco al cambiar
    -- =========================================================================
    process(CLOCK_50, reset)
        variable en_cnt : integer range 0 to 2000 := 0;
    begin
        if reset = '1' then
            lcd_state    <= LCD_POWER_UP;
            lcd_delay    <= 0;
            lcd_char_idx <= 0;
            lcd_nibble   <= '0';
            lcd_en_sig   <= '0';
            lcd_rs_sig   <= '0';
            lcd_data_sig <= (others => '0');
            en_cnt       := 0;
            lcd_refresh  <= '0';
            disp_prev    <= DISP_PICTURE;

        elsif rising_edge(CLOCK_50) then

            -- Detectar cambio de mensaje para forzar refresco
            if disp_state /= disp_prev then
                disp_prev   <= disp_state;
                lcd_refresh <= '1';
            end if;

            case lcd_state is

                -- Esperar 15 ms al encender (50MHz * 0.015s = 750000 ciclos)
                when LCD_POWER_UP =>
                    lcd_en_sig <= '0';
                    if lcd_delay = 750000 then
                        lcd_delay <= 0;
                        lcd_state <= LCD_INIT_1;
                    else
                        lcd_delay <= lcd_delay + 1;
                    end if;

                -- Init secuencia 8-bit x3 (simplificada)
                when LCD_INIT_1 =>
                    lcd_rs_sig   <= '0';
                    lcd_data_sig <= "0011";
                    if en_cnt < 25 then
                        lcd_en_sig <= '1';
                        en_cnt := en_cnt + 1;
                    elsif en_cnt < 250025 then
                        lcd_en_sig <= '0';
                        en_cnt := en_cnt + 1;
                    else
                        en_cnt := 0;
                        lcd_state <= LCD_INIT_2;
                    end if;

                when LCD_INIT_2 =>
                    lcd_rs_sig   <= '0';
                    lcd_data_sig <= "0011";
                    if en_cnt < 25 then
                        lcd_en_sig <= '1';
                        en_cnt := en_cnt + 1;
                    elsif en_cnt < 10025 then
                        lcd_en_sig <= '0';
                        en_cnt := en_cnt + 1;
                    else
                        en_cnt := 0;
                        lcd_state <= LCD_INIT_3;
                    end if;

                when LCD_INIT_3 =>
                    lcd_rs_sig   <= '0';
                    lcd_data_sig <= "0011";
                    if en_cnt < 25 then
                        lcd_en_sig <= '1';
                        en_cnt := en_cnt + 1;
                    elsif en_cnt < 2525 then
                        lcd_en_sig <= '0';
                        en_cnt := en_cnt + 1;
                    else
                        en_cnt := 0;
                        lcd_state <= LCD_INIT_4;
                    end if;

                -- Cambiar a modo 4 bits
                when LCD_INIT_4 =>
                    lcd_rs_sig   <= '0';
                    lcd_data_sig <= "0010";
                    if en_cnt < 25 then
                        lcd_en_sig <= '1';
                        en_cnt := en_cnt + 1;
                    elsif en_cnt < 2525 then
                        lcd_en_sig <= '0';
                        en_cnt := en_cnt + 1;
                    else
                        en_cnt    := 0;
                        lcd_byte  <= x"28";  -- funcion: 4bit, 2 lineas
                        lcd_nibble <= '0';
                        lcd_state <= LCD_FUNC_SET;
                    end if;

                -- Funcion set: 0x28 (dos nibbles)
                when LCD_FUNC_SET =>
                    lcd_rs_sig <= '0';
                    if lcd_nibble = '0' then
                        lcd_data_sig <= lcd_byte(7 downto 4);
                        if en_cnt < 25 then
                            lcd_en_sig <= '1'; en_cnt := en_cnt + 1;
                        elsif en_cnt < 2525 then
                            lcd_en_sig <= '0'; en_cnt := en_cnt + 1;
                        else
                            en_cnt := 0; lcd_nibble <= '1';
                        end if;
                    else
                        lcd_data_sig <= lcd_byte(3 downto 0);
                        if en_cnt < 25 then
                            lcd_en_sig <= '1'; en_cnt := en_cnt + 1;
                        elsif en_cnt < 2525 then
                            lcd_en_sig <= '0'; en_cnt := en_cnt + 1;
                        else
                            en_cnt := 0; lcd_nibble <= '0';
                            lcd_byte  <= x"08";
                            lcd_state <= LCD_DISP_OFF;
                        end if;
                    end if;

                -- Display off: 0x08
                when LCD_DISP_OFF =>
                    lcd_rs_sig <= '0';
                    if lcd_nibble = '0' then
                        lcd_data_sig <= x"0";
                        if en_cnt < 25 then lcd_en_sig <= '1'; en_cnt := en_cnt + 1;
                        elsif en_cnt < 2525 then lcd_en_sig <= '0'; en_cnt := en_cnt + 1;
                        else en_cnt := 0; lcd_nibble <= '1'; end if;
                    else
                        lcd_data_sig <= x"8";
                        if en_cnt < 25 then lcd_en_sig <= '1'; en_cnt := en_cnt + 1;
                        elsif en_cnt < 2525 then lcd_en_sig <= '0'; en_cnt := en_cnt + 1;
                        else en_cnt := 0; lcd_nibble <= '0'; lcd_state <= LCD_CLEAR; end if;
                    end if;

                -- Clear: 0x01
                when LCD_CLEAR =>
                    lcd_rs_sig <= '0';
                    if lcd_nibble = '0' then
                        lcd_data_sig <= x"0";
                        if en_cnt < 25 then lcd_en_sig <= '1'; en_cnt := en_cnt + 1;
                        elsif en_cnt < 100025 then lcd_en_sig <= '0'; en_cnt := en_cnt + 1;
                        else en_cnt := 0; lcd_nibble <= '1'; end if;
                    else
                        lcd_data_sig <= x"1";
                        if en_cnt < 25 then lcd_en_sig <= '1'; en_cnt := en_cnt + 1;
                        elsif en_cnt < 100025 then lcd_en_sig <= '0'; en_cnt := en_cnt + 1;
                        else en_cnt := 0; lcd_nibble <= '0'; lcd_state <= LCD_ENTRY; end if;
                    end if;

                -- Entry mode: 0x06
                when LCD_ENTRY =>
                    lcd_rs_sig <= '0';
                    if lcd_nibble = '0' then
                        lcd_data_sig <= x"0";
                        if en_cnt < 25 then lcd_en_sig <= '1'; en_cnt := en_cnt + 1;
                        elsif en_cnt < 2525 then lcd_en_sig <= '0'; en_cnt := en_cnt + 1;
                        else en_cnt := 0; lcd_nibble <= '1'; end if;
                    else
                        lcd_data_sig <= x"6";
                        if en_cnt < 25 then lcd_en_sig <= '1'; en_cnt := en_cnt + 1;
                        elsif en_cnt < 2525 then lcd_en_sig <= '0'; en_cnt := en_cnt + 1;
                        else en_cnt := 0; lcd_nibble <= '0'; lcd_state <= LCD_DISP_ON; end if;
                    end if;

                -- Display on: 0x0C
                when LCD_DISP_ON =>
                    lcd_rs_sig <= '0';
                    if lcd_nibble = '0' then
                        lcd_data_sig <= x"0";
                        if en_cnt < 25 then lcd_en_sig <= '1'; en_cnt := en_cnt + 1;
                        elsif en_cnt < 2525 then lcd_en_sig <= '0'; en_cnt := en_cnt + 1;
                        else en_cnt := 0; lcd_nibble <= '1'; end if;
                    else
                        lcd_data_sig <= x"C";
                        if en_cnt < 25 then lcd_en_sig <= '1'; en_cnt := en_cnt + 1;
                        elsif en_cnt < 2525 then lcd_en_sig <= '0'; en_cnt := en_cnt + 1;
                        else
                            en_cnt := 0; lcd_nibble <= '0';
                            lcd_char_idx <= 0;
                            lcd_state <= LCD_GOTO_L1;
                        end if;
                    end if;

                -- Ir al inicio de linea 1: cmd 0x80
                when LCD_GOTO_L1 =>
                    lcd_rs_sig <= '0';
                    if lcd_nibble = '0' then
                        lcd_data_sig <= x"8";
                        if en_cnt < 25 then lcd_en_sig <= '1'; en_cnt := en_cnt + 1;
                        elsif en_cnt < 2525 then lcd_en_sig <= '0'; en_cnt := en_cnt + 1;
                        else en_cnt := 0; lcd_nibble <= '1'; end if;
                    else
                        lcd_data_sig <= x"0";
                        if en_cnt < 25 then lcd_en_sig <= '1'; en_cnt := en_cnt + 1;
                        elsif en_cnt < 2525 then lcd_en_sig <= '0'; en_cnt := en_cnt + 1;
                        else
                            en_cnt := 0; lcd_nibble <= '0';
                            lcd_char_idx <= 0;
                            lcd_state <= LCD_WRITE_L1;
                        end if;
                    end if;

                -- Escribir 16 caracteres de linea 1
                when LCD_WRITE_L1 =>
                    lcd_rs_sig <= '1';
                    lcd_byte <= LINE1(lcd_char_idx);
                    if lcd_nibble = '0' then
                        lcd_data_sig <= LINE1(lcd_char_idx)(7 downto 4);
                        if en_cnt < 25 then lcd_en_sig <= '1'; en_cnt := en_cnt + 1;
                        elsif en_cnt < 2525 then lcd_en_sig <= '0'; en_cnt := en_cnt + 1;
                        else en_cnt := 0; lcd_nibble <= '1'; end if;
                    else
                        lcd_data_sig <= LINE1(lcd_char_idx)(3 downto 0);
                        if en_cnt < 25 then lcd_en_sig <= '1'; en_cnt := en_cnt + 1;
                        elsif en_cnt < 2525 then lcd_en_sig <= '0'; en_cnt := en_cnt + 1;
                        else
                            en_cnt := 0; lcd_nibble <= '0';
                            if lcd_char_idx = 15 then
                                lcd_char_idx <= 0;
                                lcd_state <= LCD_GOTO_L2;
                            else
                                lcd_char_idx <= lcd_char_idx + 1;
                            end if;
                        end if;
                    end if;

                -- Ir al inicio de linea 2: cmd 0xC0
                when LCD_GOTO_L2 =>
                    lcd_rs_sig <= '0';
                    if lcd_nibble = '0' then
                        lcd_data_sig <= x"C";
                        if en_cnt < 25 then lcd_en_sig <= '1'; en_cnt := en_cnt + 1;
                        elsif en_cnt < 2525 then lcd_en_sig <= '0'; en_cnt := en_cnt + 1;
                        else en_cnt := 0; lcd_nibble <= '1'; end if;
                    else
                        lcd_data_sig <= x"0";
                        if en_cnt < 25 then lcd_en_sig <= '1'; en_cnt := en_cnt + 1;
                        elsif en_cnt < 2525 then lcd_en_sig <= '0'; en_cnt := en_cnt + 1;
                        else
                            en_cnt := 0; lcd_nibble <= '0';
                            lcd_char_idx <= 0;
                            lcd_state <= LCD_WRITE_L2;
                        end if;
                    end if;

                -- Escribir 16 caracteres de linea 2 (lcd_line2 es dinamico)
                when LCD_WRITE_L2 =>
                    lcd_rs_sig <= '1';
                    if lcd_nibble = '0' then
                        lcd_data_sig <= lcd_line2(lcd_char_idx)(7 downto 4);
                        if en_cnt < 25 then lcd_en_sig <= '1'; en_cnt := en_cnt + 1;
                        elsif en_cnt < 2525 then lcd_en_sig <= '0'; en_cnt := en_cnt + 1;
                        else en_cnt := 0; lcd_nibble <= '1'; end if;
                    else
                        lcd_data_sig <= lcd_line2(lcd_char_idx)(3 downto 0);
                        if en_cnt < 25 then lcd_en_sig <= '1'; en_cnt := en_cnt + 1;
                        elsif en_cnt < 2525 then lcd_en_sig <= '0'; en_cnt := en_cnt + 1;
                        else
                            en_cnt := 0; lcd_nibble <= '0';
                            if lcd_char_idx = 15 then
                                lcd_char_idx <= 0;
                                lcd_refresh  <= '0';
                                lcd_state    <= LCD_IDLE;
                            else
                                lcd_char_idx <= lcd_char_idx + 1;
                            end if;
                        end if;
                    end if;

                -- Esperar cambio de mensaje
                when LCD_IDLE =>
                    lcd_en_sig <= '0';
                    if lcd_refresh = '1' then
                        lcd_state <= LCD_GOTO_L2;
                    end if;

                when others =>
                    lcd_state <= LCD_POWER_UP;

            end case;
        end if;
    end process;

    LCD_EN   <= lcd_en_sig;
    LCD_RS   <= lcd_rs_sig;
    LCD_RW   <= '0';
    LCD_DATA <= lcd_data_sig;

    -- =========================================================================
    -- 7 segmentos:
    --   HEX3:HEX2 -> make code  (ultima tecla presionada)
    --   HEX1:HEX0 -> break code (ultima tecla soltada)
    --   HEX7-HEX4 -> apagados
    -- =========================================================================
    SEG_MAKE_HI : seg7_decoder port map (hex_in => make_code(7 downto 4),  seg_out => HEX3);
    SEG_MAKE_LO : seg7_decoder port map (hex_in => make_code(3 downto 0),  seg_out => HEX2);
    SEG_BRK_HI  : seg7_decoder port map (hex_in => break_code(7 downto 4), seg_out => HEX1);
    SEG_BRK_LO  : seg7_decoder port map (hex_in => break_code(3 downto 0), seg_out => HEX0);

    HEX4 <= "1111111";
    HEX5 <= "1111111";
    HEX6 <= "1111111";
    HEX7 <= "1111111";

end Behavioral;
