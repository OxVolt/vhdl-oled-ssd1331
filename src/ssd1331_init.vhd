library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

------------------------------------------------------------------------
entity ssd1331_init is
    port (
        clk_i       : in  std_logic;
        rst_i       : in  std_logic;
        start_i     : in  std_logic;
        res_n_o     : out std_logic;
        vccen_o     : out std_logic;
        pmoden_o    : out std_logic;
        dc_o        : out std_logic;
        spi_data_o  : out std_logic_vector(7 downto 0);
        spi_start_o : out std_logic;
        spi_busy_i  : in  std_logic;
        done_o      : out std_logic
    );
end entity ssd1331_init;

architecture rtl of ssd1331_init is

    -- Timing constants for 100 MHz clock (10 ns/cycle)
    constant C_PMODEN_START : natural := 2_000_000;  -- 20 ms: logic supply stabilization
    constant C_RST_LOW      : natural := 300;        --  3 µs: reset pulse width
    constant C_RST_HIGH     : natural := 300;        --  3 µs: reset recovery
    constant C_VCCEN        : natural := 2_500_000;  -- 25 ms: OLED power stabilization
    constant C_DELAY_100MS  : natural := 10_000_000; -- 100 ms: post-power-on delay

    constant CMD_CNT : natural := 38;
    type t_cmd_rom is array(0 to CMD_CNT - 1) of std_logic_vector(7 downto 0);

    constant CMD_ROM : t_cmd_rom := (
        x"FD", x"12",   -- Unlock SSD1331
        x"AE",          -- Display off
        x"A0", x"72",   -- Set remap
        x"A1", x"00",
        x"A2", x"00",
        x"A4",
        x"A8", x"3F",
        x"AD", x"8E",
        x"B0", x"0B",
        x"B1", x"31",
        x"B3", x"F0",
        x"8A", x"64",
        x"8B", x"78",
        x"8C", x"64",
        x"BB", x"3A",
        x"BE", x"3E",
        x"87", x"06",
        x"81", x"91",
        x"82", x"50",
        x"83", x"7D"
    );

    type t_state is (
        IDLE,
        PMODEN_START,
        RST_LOW, RST_HIGH,
        SND_CONF, WAIT_SPI,
        VCCEN_WAIT,
        SND_DISP, WAIT_DISP,
        DELAY_100MS,
        DONE
    );

    signal current_state_s : t_state;
    signal next_state_s    : t_state;
    signal cnt_s           : natural range 0 to C_DELAY_100MS;
    signal cmd_idx_s       : natural range 0 to CMD_CNT - 1;

begin

    next_state_logic : process(current_state_s, cnt_s, cmd_idx_s, start_i, spi_busy_i)
    begin
        next_state_s <= current_state_s;

        case current_state_s is
            when IDLE =>
                if start_i = '1' then
                    next_state_s <= PMODEN_START;
                end if;

            when PMODEN_START =>
                if cnt_s = (C_PMODEN_START - 1) then
                    next_state_s <= RST_LOW;
                end if;

            when RST_LOW =>
                if cnt_s = (C_RST_LOW - 1) then
                    next_state_s <= RST_HIGH;
                end if;

            when RST_HIGH =>
                if cnt_s = (C_RST_HIGH - 1) then
                    next_state_s <= SND_CONF;
                end if;

            when SND_CONF =>
                next_state_s <= WAIT_SPI;

            when WAIT_SPI =>
                if spi_busy_i = '0' then
                    if cmd_idx_s = (CMD_CNT - 1) then
                        next_state_s <= VCCEN_WAIT;
                    else
                        next_state_s <= SND_CONF;
                    end if;
                end if;

            when VCCEN_WAIT =>
                if cnt_s = (C_VCCEN - 1) then
                    next_state_s <= SND_DISP;
                end if;

            when SND_DISP =>
                next_state_s <= WAIT_DISP;

            when WAIT_DISP =>
                if spi_busy_i = '0' then
                    next_state_s <= DELAY_100MS;
                end if;

            when DELAY_100MS =>
                if cnt_s = (C_DELAY_100MS - 1) then
                    next_state_s <= DONE;
                end if;

            when DONE =>
                null;
        end case;
    end process next_state_logic;

    current_state : process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            current_state_s <= IDLE;
            cnt_s           <= 0;
            cmd_idx_s       <= 0;
        elsif rising_edge(clk_i) then
            current_state_s <= next_state_s;

            case current_state_s is
                when IDLE =>
                    cnt_s <= 0;
                    cmd_idx_s <= 0;

                when WAIT_SPI =>
                    if (spi_busy_i = '0') and (cmd_idx_s < CMD_CNT - 1) then
                        cmd_idx_s <= cmd_idx_s + 1;
                    end if;

                when PMODEN_START =>
                    if next_state_s = RST_LOW then
                        cnt_s <= 0;
                    else
                        cnt_s <= cnt_s + 1;
                    end if;

                when RST_LOW =>
                    if next_state_s = RST_HIGH then
                        cnt_s <= 0;
                    else
                        cnt_s <= cnt_s + 1;
                    end if;

                when RST_HIGH =>
                    cnt_s <= cnt_s + 1;

                when VCCEN_WAIT =>
                    cnt_s <= cnt_s + 1;

                when DELAY_100MS =>
                    cnt_s <= cnt_s + 1;

                when others =>
                    cnt_s <= 0;
            end case;
        end if;
    end process current_state;

    output_logic : process(current_state_s, cmd_idx_s)
    begin
        res_n_o     <= '1';
        vccen_o     <= '0';
        pmoden_o    <= '1';
        dc_o        <= '0';
        spi_start_o <= '0';
        spi_data_o  <= (others => '0');
        done_o      <= '0';

        case current_state_s is
            when IDLE =>
                pmoden_o <= '0';

            when PMODEN_START =>
                null; -- pmoden remains high; waiting for supply stabilization

            when RST_LOW =>
                res_n_o <= '0';

            when RST_HIGH =>
                null;

            when SND_CONF =>
                spi_start_o <= '1';
                spi_data_o  <= CMD_ROM(cmd_idx_s);

            when WAIT_SPI =>
                null;

            when VCCEN_WAIT =>
                vccen_o <= '1';

            when SND_DISP =>
                vccen_o     <= '1';
                spi_start_o <= '1';
                spi_data_o  <= x"AF";

            when WAIT_DISP =>
                vccen_o <= '1';

            when DELAY_100MS =>
                vccen_o <= '1';

            when DONE =>
                vccen_o <= '1';
                done_o  <= '1';
        end case;
    end process output_logic;

end architecture rtl;
