-- =============================================================================
-- image_rom.vhd
-- Image ROM – carga image.mif en formato RGB332 (8 bits por pixel)
-- Resolucion: 640x480
-- No requiere cambios en top_level.vhd
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity image_rom is
    Port (
        clk     : in  std_logic;
        pixel_x : in  std_logic_vector(10 downto 0);
        pixel_y : in  std_logic_vector(10 downto 0);
        red     : out std_logic_vector(7 downto 0);
        green   : out std_logic_vector(7 downto 0);
        blue    : out std_logic_vector(7 downto 0)
    );
end image_rom;

architecture Behavioral of image_rom is

    signal addr        : std_logic_vector(18 downto 0) := (others => '0');
    signal rom_data    : std_logic_vector(7 downto 0);

    signal px          : unsigned(9 downto 0);
    signal py          : unsigned(8 downto 0);
    signal row_base    : unsigned(18 downto 0);
    signal pixel_valid : std_logic;

    signal r3          : std_logic_vector(2 downto 0);
    signal g3          : std_logic_vector(2 downto 0);
    signal b2          : std_logic_vector(1 downto 0);

begin

    pixel_valid <= '1'
                   when (unsigned(pixel_x) < to_unsigned(640, pixel_x'length)) and
                        (unsigned(pixel_y) < to_unsigned(480, pixel_y'length))
                   else '0';

    px <= unsigned(pixel_x(9 downto 0))
          when unsigned(pixel_x) < to_unsigned(640, pixel_x'length)
          else (others => '0');

    py <= unsigned(pixel_y(8 downto 0))
          when unsigned(pixel_y) < to_unsigned(480, pixel_y'length)
          else (others => '0');

    -- y * 640 = y * 512 + y * 128
    row_base <= shift_left(resize(py, 19), 9) +
                shift_left(resize(py, 19), 7);

    -- addr = y*640 + x
    addr <= std_logic_vector(row_base + resize(px, 19));

    ROM_INST : altsyncram
        generic map (
            operation_mode         => "ROM",
            width_a                => 8,
            widthad_a              => 19,
            numwords_a             => 307200,
            outdata_reg_a          => "UNREGISTERED",
            init_file              => "image.mif",
            intended_device_family => "Cyclone IV E",
            lpm_type               => "altsyncram",
            ram_block_type         => "AUTO"
        )
        port map (
            clock0    => clk,
            address_a => addr,
            q_a       => rom_data
        );

    r3 <= rom_data(7 downto 5);
    g3 <= rom_data(4 downto 2);
    b2 <= rom_data(1 downto 0);

    red   <= r3 & r3 & r3(2 downto 1) when pixel_valid = '1' else (others => '0');
    green <= g3 & g3 & g3(2 downto 1) when pixel_valid = '1' else (others => '0');
    blue  <= b2 & b2 & b2 & b2        when pixel_valid = '1' else (others => '0');

end Behavioral;