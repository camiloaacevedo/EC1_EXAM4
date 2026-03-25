-- =============================================================================
-- lcd_controller.vhd
-- Controlador HD44780 en modo 4 bits para DE2-115
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity lcd_controller is
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
end lcd_controller;

architecture Behavioral of lcd_controller is

    constant T_15MS    : integer := 750000;
    constant T_5MS     : integer := 250000;
    constant T_2MS     : integer := 100000;
    constant T_200US   : integer := 10000;
    constant T_50US    : integer := 2500;
    constant T_REFRESH : integer := 250000;
    constant T_EN      : integer := 25;

    subtype byte_t is std_logic_vector(7 downto 0);

    type state_t is (
        ST_PWRUP,

        ST_INIT1_SEND, ST_INIT1_WAIT, ST_INIT1_DELAY,
        ST_INIT2_SEND, ST_INIT2_WAIT, ST_INIT2_DELAY,
        ST_INIT3_SEND, ST_INIT3_WAIT, ST_INIT3_DELAY,
        ST_INIT4_SEND, ST_INIT4_WAIT, ST_INIT4_DELAY,

        ST_CMD_SEND, ST_CMD_WAIT, ST_CMD_DELAY,

        ST_SET_LINE1_SEND, ST_SET_LINE1_WAIT, ST_SET_LINE1_DELAY,
        ST_WRITE_LINE1_SEND, ST_WRITE_LINE1_WAIT, ST_WRITE_LINE1_DELAY,

        ST_SET_LINE2_SEND, ST_SET_LINE2_WAIT, ST_SET_LINE2_DELAY,
        ST_WRITE_LINE2_SEND, ST_WRITE_LINE2_WAIT, ST_WRITE_LINE2_DELAY,

        ST_REFRESH_DELAY
    );

    type nibble_state_t is (
        NB_IDLE,
        NB_HI_SETUP, NB_HI_EN, NB_HI_HOLD,
        NB_LO_SETUP, NB_LO_EN, NB_LO_HOLD,
        NB_FINISH
    );

    signal state      : state_t := ST_PWRUP;
    signal nb_state   : nibble_state_t := NB_IDLE;

    signal timer      : integer range 0 to T_15MS := 0;
    signal init_idx   : integer range 0 to 3 := 0;
    signal char_idx   : integer range 0 to 15 := 0;

    signal nb_rs      : std_logic := '0';
    signal nb_hi      : std_logic_vector(3 downto 0) := (others => '0');
    signal nb_lo      : std_logic_vector(3 downto 0) := (others => '0');
    signal nb_single  : std_logic := '0';
    signal nb_start   : std_logic := '0';
    signal nb_done    : std_logic := '0';
    signal nb_cnt     : integer range 0 to 63 := 0;

begin

    lcd_rw <= '0';

    process(clk, reset)
    begin
        if reset = '1' then
            nb_state <= NB_IDLE;
            nb_done  <= '0';
            nb_cnt   <= 0;
            lcd_en   <= '0';
            lcd_rs   <= '0';
            lcd_data <= (others => '0');
        elsif rising_edge(clk) then
            nb_done <= '0';

            case nb_state is
                when NB_IDLE =>
                    lcd_en <= '0';
                    if nb_start = '1' then
                        nb_cnt   <= 0;
                        nb_state <= NB_HI_SETUP;
                    end if;

                when NB_HI_SETUP =>
                    lcd_rs   <= nb_rs;
                    lcd_data <= nb_hi;
                    lcd_en   <= '0';
                    if nb_cnt >= 2 then
                        nb_cnt   <= 0;
                        nb_state <= NB_HI_EN;
                    else
                        nb_cnt <= nb_cnt + 1;
                    end if;

                when NB_HI_EN =>
                    lcd_rs   <= nb_rs;
                    lcd_data <= nb_hi;
                    lcd_en   <= '1';
                    if nb_cnt >= T_EN then
                        nb_cnt   <= 0;
                        nb_state <= NB_HI_HOLD;
                    else
                        nb_cnt <= nb_cnt + 1;
                    end if;

                when NB_HI_HOLD =>
                    lcd_rs   <= nb_rs;
                    lcd_data <= nb_hi;
                    lcd_en   <= '0';
                    if nb_cnt >= 2 then
                        nb_cnt <= 0;
                        if nb_single = '1' then
                            nb_state <= NB_FINISH;
                        else
                            nb_state <= NB_LO_SETUP;
                        end if;
                    else
                        nb_cnt <= nb_cnt + 1;
                    end if;

                when NB_LO_SETUP =>
                    lcd_rs   <= nb_rs;
                    lcd_data <= nb_lo;
                    lcd_en   <= '0';
                    if nb_cnt >= 2 then
                        nb_cnt   <= 0;
                        nb_state <= NB_LO_EN;
                    else
                        nb_cnt <= nb_cnt + 1;
                    end if;

                when NB_LO_EN =>
                    lcd_rs   <= nb_rs;
                    lcd_data <= nb_lo;
                    lcd_en   <= '1';
                    if nb_cnt >= T_EN then
                        nb_cnt   <= 0;
                        nb_state <= NB_LO_HOLD;
                    else
                        nb_cnt <= nb_cnt + 1;
                    end if;

                when NB_LO_HOLD =>
                    lcd_rs   <= nb_rs;
                    lcd_data <= nb_lo;
                    lcd_en   <= '0';
                    if nb_cnt >= 2 then
                        nb_cnt   <= 0;
                        nb_state <= NB_FINISH;
                    else
                        nb_cnt <= nb_cnt + 1;
                    end if;

                when NB_FINISH =>
                    lcd_en   <= '0';
                    nb_done  <= '1';
                    nb_state <= NB_IDLE;
            end case;
        end if;
    end process;

    process(clk, reset)
        variable ch : byte_t;
    begin
        if reset = '1' then
            state     <= ST_PWRUP;
            timer     <= 0;
            init_idx  <= 0;
            char_idx  <= 0;
            nb_rs     <= '0';
            nb_hi     <= (others => '0');
            nb_lo     <= (others => '0');
            nb_single <= '0';
            nb_start  <= '0';
        elsif rising_edge(clk) then
            nb_start <= '0';

            case state is
                when ST_PWRUP =>
                    if timer >= T_15MS then
                        timer <= 0;
                        state <= ST_INIT1_SEND;
                    else
                        timer <= timer + 1;
                    end if;

                when ST_INIT1_SEND =>
                    nb_rs     <= '0';
                    nb_hi     <= "0011";
                    nb_lo     <= "0000";
                    nb_single <= '1';
                    nb_start  <= '1';
                    state     <= ST_INIT1_WAIT;

                when ST_INIT1_WAIT =>
                    if nb_done = '1' then
                        timer <= 0;
                        state <= ST_INIT1_DELAY;
                    end if;

                when ST_INIT1_DELAY =>
                    if timer >= T_5MS then
                        timer <= 0;
                        state <= ST_INIT2_SEND;
                    else
                        timer <= timer + 1;
                    end if;

                when ST_INIT2_SEND =>
                    nb_rs     <= '0';
                    nb_hi     <= "0011";
                    nb_lo     <= "0000";
                    nb_single <= '1';
                    nb_start  <= '1';
                    state     <= ST_INIT2_WAIT;

                when ST_INIT2_WAIT =>
                    if nb_done = '1' then
                        timer <= 0;
                        state <= ST_INIT2_DELAY;
                    end if;

                when ST_INIT2_DELAY =>
                    if timer >= T_200US then
                        timer <= 0;
                        state <= ST_INIT3_SEND;
                    else
                        timer <= timer + 1;
                    end if;

                when ST_INIT3_SEND =>
                    nb_rs     <= '0';
                    nb_hi     <= "0011";
                    nb_lo     <= "0000";
                    nb_single <= '1';
                    nb_start  <= '1';
                    state     <= ST_INIT3_WAIT;

                when ST_INIT3_WAIT =>
                    if nb_done = '1' then
                        timer <= 0;
                        state <= ST_INIT3_DELAY;
                    end if;

                when ST_INIT3_DELAY =>
                    if timer >= T_50US then
                        timer <= 0;
                        state <= ST_INIT4_SEND;
                    else
                        timer <= timer + 1;
                    end if;

                when ST_INIT4_SEND =>
                    nb_rs     <= '0';
                    nb_hi     <= "0010";
                    nb_lo     <= "0000";
                    nb_single <= '1';
                    nb_start  <= '1';
                    state     <= ST_INIT4_WAIT;

                when ST_INIT4_WAIT =>
                    if nb_done = '1' then
                        timer    <= 0;
                        init_idx <= 0;
                        state    <= ST_INIT4_DELAY;
                    end if;

                when ST_INIT4_DELAY =>
                    if timer >= T_50US then
                        timer <= 0;
                        state <= ST_CMD_SEND;
                    else
                        timer <= timer + 1;
                    end if;

                when ST_CMD_SEND =>
                    nb_rs     <= '0';
                    nb_single <= '0';

                    case init_idx is
                        when 0 =>
                            nb_hi <= "0010";  -- 0x28
                            nb_lo <= "1000";
                        when 1 =>
                            nb_hi <= "0000";  -- 0x0C
                            nb_lo <= "1100";
                        when 2 =>
                            nb_hi <= "0000";  -- 0x06
                            nb_lo <= "0110";
                        when others =>
                            nb_hi <= "0000";  -- 0x01
                            nb_lo <= "0001";
                    end case;

                    nb_start <= '1';
                    state    <= ST_CMD_WAIT;

                when ST_CMD_WAIT =>
                    if nb_done = '1' then
                        timer <= 0;
                        state <= ST_CMD_DELAY;
                    end if;

                when ST_CMD_DELAY =>
                    if init_idx = 3 then
                        if timer >= T_2MS then
                            timer <= 0;
                            state <= ST_SET_LINE1_SEND;
                        else
                            timer <= timer + 1;
                        end if;
                    else
                        if timer >= T_50US then
                            timer    <= 0;
                            init_idx <= init_idx + 1;
                            state    <= ST_CMD_SEND;
                        else
                            timer <= timer + 1;
                        end if;
                    end if;

                when ST_SET_LINE1_SEND =>
                    nb_rs     <= '0';
                    nb_hi     <= "1000";
                    nb_lo     <= "0000";
                    nb_single <= '0';
                    nb_start  <= '1';
                    state     <= ST_SET_LINE1_WAIT;

                when ST_SET_LINE1_WAIT =>
                    if nb_done = '1' then
                        timer <= 0;
                        state <= ST_SET_LINE1_DELAY;
                    end if;

                when ST_SET_LINE1_DELAY =>
                    if timer >= T_50US then
                        timer    <= 0;
                        char_idx <= 0;
                        state    <= ST_WRITE_LINE1_SEND;
                    else
                        timer <= timer + 1;
                    end if;

                when ST_WRITE_LINE1_SEND =>
                    ch := line1((15 - char_idx) * 8 + 7 downto (15 - char_idx) * 8);
                    nb_rs     <= '1';
                    nb_hi     <= ch(7 downto 4);
                    nb_lo     <= ch(3 downto 0);
                    nb_single <= '0';
                    nb_start  <= '1';
                    state     <= ST_WRITE_LINE1_WAIT;

                when ST_WRITE_LINE1_WAIT =>
                    if nb_done = '1' then
                        timer <= 0;
                        state <= ST_WRITE_LINE1_DELAY;
                    end if;

                when ST_WRITE_LINE1_DELAY =>
                    if timer >= T_50US then
                        timer <= 0;
                        if char_idx = 15 then
                            state <= ST_SET_LINE2_SEND;
                        else
                            char_idx <= char_idx + 1;
                            state    <= ST_WRITE_LINE1_SEND;
                        end if;
                    else
                        timer <= timer + 1;
                    end if;

                when ST_SET_LINE2_SEND =>
                    nb_rs     <= '0';
                    nb_hi     <= "1100";
                    nb_lo     <= "0000";
                    nb_single <= '0';
                    nb_start  <= '1';
                    state     <= ST_SET_LINE2_WAIT;

                when ST_SET_LINE2_WAIT =>
                    if nb_done = '1' then
                        timer <= 0;
                        state <= ST_SET_LINE2_DELAY;
                    end if;

                when ST_SET_LINE2_DELAY =>
                    if timer >= T_50US then
                        timer    <= 0;
                        char_idx <= 0;
                        state    <= ST_WRITE_LINE2_SEND;
                    else
                        timer <= timer + 1;
                    end if;

                when ST_WRITE_LINE2_SEND =>
                    ch := line2((15 - char_idx) * 8 + 7 downto (15 - char_idx) * 8);
                    nb_rs     <= '1';
                    nb_hi     <= ch(7 downto 4);
                    nb_lo     <= ch(3 downto 0);
                    nb_single <= '0';
                    nb_start  <= '1';
                    state     <= ST_WRITE_LINE2_WAIT;

                when ST_WRITE_LINE2_WAIT =>
                    if nb_done = '1' then
                        timer <= 0;
                        state <= ST_WRITE_LINE2_DELAY;
                    end if;

                when ST_WRITE_LINE2_DELAY =>
                    if timer >= T_50US then
                        timer <= 0;
                        if char_idx = 15 then
                            state <= ST_REFRESH_DELAY;
                        else
                            char_idx <= char_idx + 1;
                            state    <= ST_WRITE_LINE2_SEND;
                        end if;
                    else
                        timer <= timer + 1;
                    end if;

                when ST_REFRESH_DELAY =>
                    if timer >= T_REFRESH then
                        timer <= 0;
                        state <= ST_SET_LINE1_SEND;
                    else
                        timer <= timer + 1;
                    end if;
            end case;
        end if;
    end process;

end Behavioral;