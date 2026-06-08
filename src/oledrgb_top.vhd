library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cat_rom_pkg.all;

------------------------------------------------------------------------
-- Top-level: Basys 3 + Pmod OLEDrgb
-- Sequence:
--   1. ssd1331_init  runs from reset, drives SPI during initialisation
--   2. scan_controller starts when init_done pulses, loops continuously
-- spi_master is shared via a MUX gated by init_done_latch_s
------------------------------------------------------------------------
entity oledrgb_top is
    port (
        clk_i     : in  std_logic;  -- 100 MHz (W5 on Basys 3)
        rst_i     : in  std_logic;  -- reset button, active high

        -- Pmod OLEDrgb (connector JA or JB)
        cs_n_o    : out std_logic;
        sclk_o    : out std_logic;
        mosi_o    : out std_logic;
        dc_o      : out std_logic;
        res_n_o   : out std_logic;
        vccen_o   : out std_logic;
        pmoden_o  : out std_logic
    );
end entity oledrgb_top;

architecture rtl of oledrgb_top is

    -- SPI master signals shared between init and scan
    signal spi_start_s : std_logic;
    signal spi_data_s  : std_logic_vector(7 downto 0);
    signal spi_busy_s  : std_logic;
    signal dc_mux_s    : std_logic;

    -- ssd1331_init → SPI master
    signal init_spi_start_s : std_logic;
    signal init_spi_data_s  : std_logic_vector(7 downto 0);
    signal init_dc_s        : std_logic;
    signal init_done_s      : std_logic;  -- single-cycle pulse at end of init

    -- scan_controller → SPI master
    signal scan_spi_start_s : std_logic;
    signal scan_spi_data_s  : std_logic_vector(7 downto 0);
    signal scan_dc_s        : std_logic;
    signal scan_start_s     : std_logic;

    -- ROM ↔ scan_controller
    signal pixel_addr_s : std_logic_vector(12 downto 0);
    signal pixel_data_s : std_logic_vector(15 downto 0);

    -- Latches high on init_done_s and stays high; gates the MUX and scan start
    signal init_done_latch_s : std_logic;

begin

    -- Synchronous ROM read so Vivado infers BRAM (meets timing)
    rom_read : process(clk_i)
    begin
        if rising_edge(clk_i) then
            pixel_data_s <= IMG_ROM(to_integer(unsigned(pixel_addr_s)));
        end if;
    end process rom_read;

    latch_done : process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            init_done_latch_s <= '0';
        elsif rising_edge(clk_i) then
            if init_done_s = '1' then
                init_done_latch_s <= '1';
            end if;
        end if;
    end process latch_done;

    -- init_done_s is already a single-cycle pulse; wire it directly
    scan_start_s <= init_done_s;

    -- SPI MUX: init owns the bus until init_done_latch_s goes high
    spi_start_s <= init_spi_start_s when init_done_latch_s = '0' else scan_spi_start_s;
    spi_data_s  <= init_spi_data_s  when init_done_latch_s = '0' else scan_spi_data_s;
    dc_mux_s    <= init_dc_s        when init_done_latch_s = '0' else scan_dc_s;

    i_spi : entity work.spi_master
        port map (
            clk_i   => clk_i,
            rst_i   => rst_i,
            start_i => spi_start_s,
            data_i  => spi_data_s,
            busy_o  => spi_busy_s,
            cs_n_o  => cs_n_o,
            sclk_o  => sclk_o,
            mosi_o  => mosi_o
        );

    -- start_i tied high: init begins immediately after reset and never restarts
    i_init : entity work.ssd1331_init
        port map (
            clk_i       => clk_i,
            rst_i       => rst_i,
            start_i     => '1',
            res_n_o     => res_n_o,
            vccen_o     => vccen_o,
            pmoden_o    => pmoden_o,
            dc_o        => init_dc_s,
            spi_data_o  => init_spi_data_s,
            spi_start_o => init_spi_start_s,
            spi_busy_i  => spi_busy_s,
            done_o      => init_done_s
        );

    i_scan : entity work.scan_controller
        port map (
            clk_i        => clk_i,
            rst_i        => rst_i,
            start_i      => scan_start_s,
            pixel_addr_o => pixel_addr_s,
            pixel_data_i => pixel_data_s,
            spi_data_o   => scan_spi_data_s,
            spi_start_o  => scan_spi_start_s,
            spi_busy_i   => spi_busy_s,
            dc_o         => scan_dc_s,
            done_o       => open   -- continuous refresh; done_o unused here
        );

    dc_o <= dc_mux_s;

end architecture rtl;
