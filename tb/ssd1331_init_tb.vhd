library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ssd1331_init_tb is
end entity ssd1331_init_tb;

architecture testbench of ssd1331_init_tb is

    constant CLK_PERIOD   : time    := 10 ns;
    constant SPI_BYTE_DUR : time    := 1280 ns; -- 8 bits × 2 × 80 ns (SPI ÷16)
    constant CMD_CNT      : natural := 38;
    constant RST_DURATION : time    := 3 * CLK_PERIOD;

    signal clk_s       : std_logic := '0';
    signal rst_s       : std_logic := '0';
    signal start_s     : std_logic := '0';

    signal res_n_s     : std_logic;
    signal vccen_s     : std_logic;
    signal pmoden_s    : std_logic;
    signal dc_s        : std_logic;
    signal spi_data_s  : std_logic_vector(7 downto 0);
    signal spi_start_s : std_logic;
    signal spi_busy_s  : std_logic := '0';
    signal done_s      : std_logic;

begin

    DUT : entity work.ssd1331_init
        port map (
            clk_i       => clk_s,
            rst_i       => rst_s,
            start_i     => start_s,
            res_n_o     => res_n_s,
            vccen_o     => vccen_s,
            pmoden_o    => pmoden_s,
            dc_o        => dc_s,
            spi_data_o  => spi_data_s,
            spi_start_o => spi_start_s,
            spi_busy_i  => spi_busy_s,
            done_o      => done_s
        );

    Gen_clock : process
    begin
        clk_s <= '0'; wait for CLK_PERIOD / 2;
        clk_s <= '1'; wait for CLK_PERIOD / 2;
    end process;

    Gen_reset : process
    begin
        rst_s <= '1'; wait for RST_DURATION;
        rst_s <= '0'; wait;
    end process;

    -- Simulates spi_master: asserts busy for SPI_BYTE_DUR on each start pulse
    SPI_stub : process
    begin
        spi_busy_s <= '0';
        wait until rising_edge(spi_start_s);
        spi_busy_s <= '1';
        wait for SPI_BYTE_DUR;
        spi_busy_s <= '0';
    end process SPI_stub;

    stimulus : process
    begin
        report "OK: stimulus started" severity note;

        wait until falling_edge(rst_s);
        report "OK: reset released" severity note;

        wait for CLK_PERIOD * 5;
        start_s <= '1';
        wait until res_n_s = '0';
        start_s <= '0';

        assert res_n_s = '0'
            report "ERROR: RES# should be low (RST_LOW)"
            severity error;

        wait until rising_edge(res_n_s);
        report "OK: RES# released" severity note;

        assert res_n_s = '1'
            report "ERROR: RES# should be high (RST_HIGH)"
            severity error;

        -- First SPI byte must be 0xFD (Unlock SSD1331)
        wait until rising_edge(spi_start_s);
        report "OK: first SPI start pulse" severity note;

        assert spi_data_s = x"FD"
            report "ERROR: first byte expected 0xFD, got 0x" &
                   to_hstring(spi_data_s)
            severity error;

        assert dc_s = '0'
            report "ERROR: D/C# must remain '0' (command mode)"
            severity error;

        -- VCCEN rises after all CMD_CNT config bytes are sent
        wait until rising_edge(vccen_s);
        report "OK: VCCEN asserted" severity note;

        assert vccen_s  = '1'
            report "ERROR: VCCEN should be active"
            severity error;
        assert pmoden_s = '1'
            report "ERROR: PMODEN should be active (driven high from PMODEN_START)"
            severity error;

        -- Display ON command (0xAF)
        wait until rising_edge(spi_start_s);
        assert spi_data_s = x"AF"
            report "ERROR: expected 0xAF (Display ON), got 0x" &
                   to_hstring(spi_data_s)
            severity error;

        -- Verify final state
        wait until rising_edge(done_s);

        assert done_s   = '1'
            report "ERROR: done_o should be active"
            severity error;
        assert pmoden_s = '1'
            report "ERROR: PMODEN should be active"
            severity error;
        assert vccen_s  = '1'
            report "ERROR: VCCEN should remain active"
            severity error;

        report "OK: init sequence complete" severity note;
        std.env.finish;

    end process stimulus;

end architecture testbench;
