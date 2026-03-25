-- =============================================================================
-- image_rom.vhd
-- Image ROM – carga la foto del equipo desde image.mif
-- Resolucion: 640x480 pixeles, 24 bits RGB
-- Fecha: Marzo, 2026
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

    signal addr     : std_logic_vector(18 downto 0);
    signal rom_data : std_logic_vector(23 downto 0);
    signal px       : unsigned(9 downto 0);
    signal py       : unsigned(8 downto 0);

begin

    px <= unsigned(pixel_x(9 downto 0)) when unsigned(pixel_x) < 640
          else (others => '0');
    py <= unsigned(pixel_y(8 downto 0)) when unsigned(pixel_y) < 480
          else (others => '0');

    addr <= std_logic_vector(resize(py * 640, 19) + resize(px, 19));

    ROM_INST : altsyncram
        generic map (
            operation_mode         => "ROM",
            width_a                => 24,
            widthad_a              => 19,
            numwords_a             => 307200,
            outdata_reg_a          => "CLOCK0",
            init_file              => "image.mif",
            intended_device_family => "Cyclone IV E",
            lpm_type               => "altsyncram",
            ram_block_type         => "M9K"
        )
        port map (
            clock0    => clk,
            address_a => addr,
            q_a       => rom_data
        );

    red   <= rom_data(23 downto 16);
    green <= rom_data(15 downto 8);
    blue  <= rom_data(7  downto 0);

end Behavioral;
