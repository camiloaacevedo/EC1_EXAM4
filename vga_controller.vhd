-- =============================================================================
-- vga_controller.vhd
-- VGA Sync Signal Generator
-- Supports: 640x480@60Hz, 800x600@60Hz, 1024x768@60Hz
-- DE2-115 Clock: 50 MHz (requires PLL for pixel clocks)
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_controller is
    Port (
        clk_pixel   : in  std_logic;  -- Pixel clock (25/40/65 MHz depending on mode)
        reset       : in  std_logic;
        mode        : in  std_logic_vector(1 downto 0);
        -- 00 = 640x480@60Hz
        -- 01 = 800x600@60Hz
        -- 10 = 1024x768@60Hz

        hsync       : out std_logic;
        vsync       : out std_logic;
        h_active    : out std_logic;   -- High when in visible area (H)
        v_active    : out std_logic;   -- High when in visible area (V)
        pixel_x     : out std_logic_vector(10 downto 0);
        pixel_y     : out std_logic_vector(10 downto 0)
    );
end vga_controller;

architecture Behavioral of vga_controller is

    -- -------------------------------------------------------------------------
    -- Timing parameters for each resolution
    -- Format: H_ACTIVE, H_FP, H_SYNC, H_BP, V_ACTIVE, V_FP, V_SYNC, V_BP
    -- -------------------------------------------------------------------------

    -- 640x480 @ 60 Hz  (pixel clock = 25.175 MHz ~ 25 MHz)
    constant H_ACTIVE_640  : integer := 640;
    constant H_FP_640      : integer := 16;
    constant H_SYNC_640    : integer := 96;
    constant H_BP_640      : integer := 48;
    constant H_TOTAL_640   : integer := 800;   -- 640+16+96+48

    constant V_ACTIVE_640  : integer := 480;
    constant V_FP_640      : integer := 10;
    constant V_SYNC_640    : integer := 2;
    constant V_BP_640      : integer := 33;
    constant V_TOTAL_640   : integer := 525;   -- 480+10+2+33

    -- 800x600 @ 60 Hz  (pixel clock = 40 MHz)
    constant H_ACTIVE_800  : integer := 800;
    constant H_FP_800      : integer := 40;
    constant H_SYNC_800    : integer := 128;
    constant H_BP_800      : integer := 88;
    constant H_TOTAL_800   : integer := 1056;  -- 800+40+128+88

    constant V_ACTIVE_800  : integer := 600;
    constant V_FP_800      : integer := 1;
    constant V_SYNC_800    : integer := 4;
    constant V_BP_800      : integer := 23;
    constant V_TOTAL_800   : integer := 628;   -- 600+1+4+23

    -- 1024x768 @ 60 Hz (pixel clock = 65 MHz)
    constant H_ACTIVE_1024 : integer := 1024;
    constant H_FP_1024     : integer := 24;
    constant H_SYNC_1024   : integer := 136;
    constant H_BP_1024     : integer := 160;
    constant H_TOTAL_1024  : integer := 1344;  -- 1024+24+136+160

    constant V_ACTIVE_1024 : integer := 768;
    constant V_FP_1024     : integer := 3;
    constant V_SYNC_1024   : integer := 6;
    constant V_BP_1024     : integer := 29;
    constant V_TOTAL_1024  : integer := 806;   -- 768+3+6+29

    -- Internal counters
    signal h_count : integer range 0 to 1344 := 0;
    signal v_count : integer range 0 to 806  := 0;

    -- Active timing values (set by mode)
    signal h_active_end  : integer range 0 to 1344;
    signal h_fp_end      : integer range 0 to 1344;
    signal h_sync_end    : integer range 0 to 1344;
    signal h_total       : integer range 0 to 1344;

    signal v_active_end  : integer range 0 to 806;
    signal v_fp_end      : integer range 0 to 806;
    signal v_sync_end    : integer range 0 to 806;
    signal v_total       : integer range 0 to 806;

    -- Sync polarity (negative for 640x480, positive for 800x600 and 1024x768)
    signal h_sync_pol    : std_logic;
    signal v_sync_pol    : std_logic;

    signal h_sync_int    : std_logic;
    signal v_sync_int    : std_logic;
    signal h_active_int  : std_logic;
    signal v_active_int  : std_logic;

begin

    -- -------------------------------------------------------------------------
    -- Select timing parameters based on mode input
    -- -------------------------------------------------------------------------
    process(mode)
    begin
        case mode is
            when "10" =>  -- 1024x768 @ 60 Hz
                h_active_end <= H_ACTIVE_1024;
                h_fp_end     <= H_ACTIVE_1024 + H_FP_1024;
                h_sync_end   <= H_ACTIVE_1024 + H_FP_1024 + H_SYNC_1024;
                h_total      <= H_TOTAL_1024;
                v_active_end <= V_ACTIVE_1024;
                v_fp_end     <= V_ACTIVE_1024 + V_FP_1024;
                v_sync_end   <= V_ACTIVE_1024 + V_FP_1024 + V_SYNC_1024;
                v_total      <= V_TOTAL_1024;
                h_sync_pol   <= '0';  -- Negative sync
                v_sync_pol   <= '0';

            when "01" =>  -- 800x600 @ 60 Hz
                h_active_end <= H_ACTIVE_800;
                h_fp_end     <= H_ACTIVE_800 + H_FP_800;
                h_sync_end   <= H_ACTIVE_800 + H_FP_800 + H_SYNC_800;
                h_total      <= H_TOTAL_800;
                v_active_end <= V_ACTIVE_800;
                v_fp_end     <= V_ACTIVE_800 + V_FP_800;
                v_sync_end   <= V_ACTIVE_800 + V_FP_800 + V_SYNC_800;
                v_total      <= V_TOTAL_800;
                h_sync_pol   <= '1';  -- Positive sync
                v_sync_pol   <= '1';

            when others =>  -- 00 => 640x480 @ 60 Hz (default)
                h_active_end <= H_ACTIVE_640;
                h_fp_end     <= H_ACTIVE_640 + H_FP_640;
                h_sync_end   <= H_ACTIVE_640 + H_FP_640 + H_SYNC_640;
                h_total      <= H_TOTAL_640;
                v_active_end <= V_ACTIVE_640;
                v_fp_end     <= V_ACTIVE_640 + V_FP_640;
                v_sync_end   <= V_ACTIVE_640 + V_FP_640 + V_SYNC_640;
                v_total      <= V_TOTAL_640;
                h_sync_pol   <= '0';  -- Negative sync
                v_sync_pol   <= '0';
        end case;
    end process;

    -- -------------------------------------------------------------------------
    -- Horizontal counter
    -- -------------------------------------------------------------------------
    process(clk_pixel, reset)
    begin
        if reset = '1' then
            h_count <= 0;
        elsif rising_edge(clk_pixel) then
            if h_count = h_total - 1 then
                h_count <= 0;
            else
                h_count <= h_count + 1;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- Vertical counter (increments at end of each line)
    -- -------------------------------------------------------------------------
    process(clk_pixel, reset)
    begin
        if reset = '1' then
            v_count <= 0;
        elsif rising_edge(clk_pixel) then
            if h_count = h_total - 1 then
                if v_count = v_total - 1 then
                    v_count <= 0;
                else
                    v_count <= v_count + 1;
                end if;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- Generate sync signals
    -- Sync pulse is active during [fp_end .. sync_end)
    -- -------------------------------------------------------------------------
    h_sync_int <= h_sync_pol when (h_count >= h_fp_end and h_count < h_sync_end)
                  else not h_sync_pol;

    v_sync_int <= v_sync_pol when (v_count >= v_fp_end and v_count < v_sync_end)
                  else not v_sync_pol;

    -- -------------------------------------------------------------------------
    -- Active video region
    -- -------------------------------------------------------------------------
    h_active_int <= '1' when (h_count < h_active_end) else '0';
    v_active_int <= '1' when (v_count < v_active_end) else '0';

    -- -------------------------------------------------------------------------
    -- Outputs
    -- -------------------------------------------------------------------------
    hsync    <= h_sync_int;
    vsync    <= v_sync_int;
    h_active <= h_active_int;
    v_active <= v_active_int;

    pixel_x  <= std_logic_vector(to_unsigned(h_count, 11));
    pixel_y  <= std_logic_vector(to_unsigned(v_count, 11));

end Behavioral;
