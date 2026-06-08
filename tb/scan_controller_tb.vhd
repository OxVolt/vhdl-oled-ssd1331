library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

entity scan_controller_tb is
end entity scan_controller_tb;

architecture testbench of scan_controller_tb is

    constant CLK_PERIOD   : time    := 10 ns;
    constant SPI_BYTE_DUR : time    := 1285 ns;  -- intentionally non-aligned with CLK_PERIOD
    constant HDR_CNT      : natural := 6;
    constant PIX_CNT      : natural := 6144;
    constant RST_DURATION : time    := 3 * CLK_PERIOD;

    signal clk_s        : std_logic := '0';
    signal rst_s        : std_logic := '0';
    signal start_s      : std_logic := '0';

    signal pixel_addr_s : std_logic_vector(12 downto 0);
    signal pixel_data_s : std_logic_vector(15 downto 0);

    signal spi_data_s   : std_logic_vector(7 downto 0);
    signal spi_start_s  : std_logic;
    signal spi_busy_s   : std_logic := '0';
    signal dc_s         : std_logic;
    signal done_s       : std_logic;

    signal byte_cnt_s   : natural := 0;  -- global byte counter for debug

begin

    DUT : entity work.scan_controller
        port map (
            clk_i        => clk_s,
            rst_i        => rst_s,
            start_i      => start_s,
            pixel_addr_o => pixel_addr_s,
            pixel_data_i => pixel_data_s,
            spi_data_o   => spi_data_s,
            spi_start_o  => spi_start_s,
            spi_busy_i   => spi_busy_s,
            dc_o         => dc_s,
            done_o       => done_s
        );

    -- Simulated pixel source: even addr = red (0xF800), odd addr = blue (0x001F)
    pixel_data_s <= x"F800" when (to_integer(unsigned(pixel_addr_s)) mod 2 = 0)
                    else x"001F";

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

    count_bytes : process
    begin
        wait until rising_edge(spi_start_s);
        byte_cnt_s <= byte_cnt_s + 1;
    end process;

    SPI_stub : process
    begin
        spi_busy_s <= '0';
        wait until rising_edge(spi_start_s);
        spi_busy_s <= '1';
        wait for SPI_BYTE_DUR;
        spi_busy_s <= '0';
    end process SPI_stub;

    stimulus : process

        procedure wait_byte(expected  : std_logic_vector(7 downto 0);
                            msg       : string;
                            check_dc  : std_logic := '-') is
        begin
            wait until rising_edge(spi_start_s);
            report "BYTE #" & integer'image(byte_cnt_s) &
                   " [" & msg & "]" &
                   "  data=0x" & to_hstring(spi_data_s) &
                   "  dc=" & std_logic'image(dc_s) &
                   "  addr=" & integer'image(to_integer(unsigned(pixel_addr_s)))
                   severity note;
            assert spi_data_s = expected
                report "ERROR [" & msg & "]: expected 0x" &
                       to_hstring(expected) & " received 0x" & to_hstring(spi_data_s)
                severity error;
            if check_dc /= '-' then
                assert dc_s = check_dc
                    report "ERROR [" & msg & "]: dc expected " &
                           std_logic'image(check_dc) & " received " & std_logic'image(dc_s)
                    severity error;
            end if;
        end procedure;

    begin
        wait until falling_edge(rst_s);
        report "--- reset released ---" severity note;

        -- Assert start then capture the first SPI edge before releasing
        start_s <= '1';
        wait until rising_edge(spi_start_s);
        start_s <= '0';

        -- Verify byte 0 directly (we are already on this edge)
        report "BYTE #0 [hdr 0x15]" &
               "  data=0x" & to_hstring(spi_data_s) &
               "  dc=" & std_logic'image(dc_s) severity note;
        assert spi_data_s = x"15"
            report "ERROR hdr 0x15: received 0x" & to_hstring(spi_data_s) severity error;
        assert dc_s = '0'
            report "ERROR hdr 0x15: dc should be '0'" severity error;

        -- Header bytes 1 → 5
        wait_byte(x"00", "hdr 0x00 col_start", '0');
        wait_byte(x"5F", "hdr 0x5F col_end",   '0');
        wait_byte(x"75", "hdr 0x75 row_cmd",   '0');
        wait_byte(x"00", "hdr 0x00 row_start",  '0');
        wait_byte(x"3F", "hdr 0x3F row_end",    '0');

        -- Pixel 0: red (0xF800), addr=0
        wait_byte(x"F8", "px0_hi 0xF8", '1');
        assert pixel_addr_s = std_logic_vector(to_unsigned(0, 13))
            report "ERROR px0: addr=" &
                   integer'image(to_integer(unsigned(pixel_addr_s))) &
                   " expected 0" severity error;

        wait_byte(x"00", "px0_lo 0x00", '1');

        -- Pixel 1: blue (0x001F), addr=1
        wait_byte(x"00", "px1_hi 0x00", '1');
        assert pixel_addr_s = std_logic_vector(to_unsigned(1, 13))
            report "ERROR px1: addr=" &
                   integer'image(to_integer(unsigned(pixel_addr_s))) &
                   " expected 1" severity error;

        wait_byte(x"1F", "px1_lo 0x1F", '1');

        -- Wait for done_o after the last pixel
        report "--- waiting for done_o (6144 pixels x 2 bytes)... ---" severity note;
        wait until done_s = '1';
        report "--- done_o received ---" severity note;
        assert done_s = '1'
            report "ERROR: done_o should be '1'" severity error;

        -- Continuous refresh: verify first byte of the next frame
        wait_byte(x"15", "refresh hdr 0x15", '0');
        report "--- frame 2 refresh confirmed ---" severity note;

        report "OK: scan_controller validated" severity note;
        std.env.finish;
    end process stimulus;

end architecture testbench;
