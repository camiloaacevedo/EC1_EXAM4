-- =============================================================================
-- seg7_decoder.vhd
-- Hexadecimal to 7-Segment Display Decoder
-- Used to show PS/2 scan codes on the DE2-115 7-segment displays.
-- DE2-115 has eight 7-segment displays (HEX7..HEX0), active-LOW segments.
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity seg7_decoder is
    Port (
        hex_in  : in  std_logic_vector(3 downto 0);  -- 4-bit hex digit
        seg_out : out std_logic_vector(6 downto 0)   -- segments a-g, active LOW
    );
end seg7_decoder;

architecture Behavioral of seg7_decoder is
begin
    -- Segment encoding (active LOW): gfedcba
    --  aaa
    -- f   b
    -- f   b
    --  ggg
    -- e   c
    -- e   c
    --  ddd
    process(hex_in)
    begin
        case hex_in is
            when "0000" => seg_out <= "1000000"; -- 0
            when "0001" => seg_out <= "1111001"; -- 1
            when "0010" => seg_out <= "0100100"; -- 2
            when "0011" => seg_out <= "0110000"; -- 3
            when "0100" => seg_out <= "0011001"; -- 4
            when "0101" => seg_out <= "0010010"; -- 5
            when "0110" => seg_out <= "0000010"; -- 6
            when "0111" => seg_out <= "1111000"; -- 7
            when "1000" => seg_out <= "0000000"; -- 8
            when "1001" => seg_out <= "0010000"; -- 9
            when "1010" => seg_out <= "0001000"; -- A
            when "1011" => seg_out <= "0000011"; -- b
            when "1100" => seg_out <= "1000110"; -- C
            when "1101" => seg_out <= "0100001"; -- d
            when "1110" => seg_out <= "0000110"; -- E
            when "1111" => seg_out <= "0001110"; -- F
            when others => seg_out <= "1111111"; -- blank
        end case;
    end process;
end Behavioral;
