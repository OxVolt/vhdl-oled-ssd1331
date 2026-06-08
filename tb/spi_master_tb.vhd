library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity spi_master_tb is
end entity spi_master_tb;

architecture behavioral of spi_master_tb is

    constant CLK_PERIOD   : time := 10 ns;
    constant RST_DURATION : time := 3 * CLK_PERIOD;

    signal clk_s   : std_logic := '0';
    signal rst_s   : std_logic := '0';
    signal start_s : std_logic := '0';
    signal data_s  : std_logic_vector(7 downto 0) := (others => '0');
    signal sclk_s  : std_logic;
    signal mosi_s  : std_logic;
    signal cs_n_s  : std_logic;
    signal busy_s  : std_logic;
    signal done_s  : std_logic;

    component spi_master is
        port (
            clk_i   : in  std_logic;
            rst_i   : in  std_logic;
            start_i : in  std_logic;
            data_i  : in  std_logic_vector(7 downto 0);
            sclk_o  : out std_logic;
            mosi_o  : out std_logic;
            cs_n_o  : out std_logic;
            busy_o  : out std_logic;
            done_o  : out std_logic
        );
    end component;

begin

    DUT : spi_master
        port map (
            clk_i   => clk_s,
            rst_i   => rst_s,
            start_i => start_s,
            data_i  => data_s,
            sclk_o  => sclk_s,
            mosi_o  => mosi_s,
            cs_n_o  => cs_n_s,
            busy_o  => busy_s,
            done_o  => done_s
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

    stimulus : process
    begin
        wait for RST_DURATION + CLK_PERIOD;

        assert cs_n_s = '1'
            report "ERROR: CS# should be inactive after reset"
            severity error;

        assert busy_s = '0'
            report "ERROR: busy should be low after reset"
            severity error;

        -- Transmit 0xA5
        data_s  <= x"A5";
        start_s <= '1';
        wait for CLK_PERIOD;
        start_s <= '0';

        wait until done_s = '1';
        wait for CLK_PERIOD;

        assert cs_n_s = '1'
            report "ERROR: CS# should be inactive after transfer"
            severity error;

        assert busy_s = '0'
            report "ERROR: busy should be low after transfer"
            severity error;

        -- Transmit 0x00
        data_s  <= x"00";
        start_s <= '1';
        wait for CLK_PERIOD;
        start_s <= '0';

        wait until done_s = '1';
        wait for CLK_PERIOD;

        -- Transmit 0xFF
        data_s  <= x"FF";
        start_s <= '1';
        wait for CLK_PERIOD;
        start_s <= '0';

        wait until done_s = '1';
        wait for CLK_PERIOD;

        report "Simulation complete" severity note;
        std.env.finish;
    end process;

end architecture behavioral;
