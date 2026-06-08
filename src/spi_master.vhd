library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_master is
    port (
        clk_i    : in  std_logic;
        rst_i    : in  std_logic;
        start_i  : in  std_logic;
        data_i   : in  std_logic_vector(7 downto 0);
        sclk_o   : out std_logic;
        mosi_o   : out std_logic;
        cs_n_o   : out std_logic;
        busy_o   : out std_logic;
        done_o   : out std_logic
    );
end entity;

architecture rtl of spi_master is

    type state_t is (IDLE, TRANSFER, FINISH);

    signal current_state_s : state_t;
    signal next_state_s    : state_t;

    signal bit_cnt_s : integer range 0 to 7;
    signal shift_s   : std_logic_vector(7 downto 0);
    signal sclk_s    : std_logic;

begin

    next_state_logic : process(current_state_s, bit_cnt_s, start_i, sclk_s)
    begin
        next_state_s <= current_state_s;

        case current_state_s is
            when IDLE =>
                if start_i = '1' then
                    next_state_s <= TRANSFER;
                end if;

            when TRANSFER =>
                if bit_cnt_s = 7 and sclk_s = '0' then
                    next_state_s <= FINISH;
                end if;

            when FINISH =>
                next_state_s <= IDLE;
        end case;
    end process;

    current_state : process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            current_state_s <= IDLE;
            bit_cnt_s       <= 0;
            shift_s         <= (others => '0');
            sclk_s          <= '1';

        elsif rising_edge(clk_i) then
            current_state_s <= next_state_s;

            case current_state_s is
                when IDLE =>
                    shift_s <= data_i;

                when TRANSFER =>
                    sclk_s <= not sclk_s;
                    if sclk_s = '0' and bit_cnt_s < 7 then
                        bit_cnt_s <= bit_cnt_s + 1;
                        shift_s   <= (shift_s(6 downto 0) & '0');
                    end if;

                when FINISH =>
                    bit_cnt_s <= 0;

            end case;
        end if;
    end process;

    output_logic : process(current_state_s, shift_s, sclk_s)
    begin
        cs_n_o <= '1';
        busy_o <= '0';
        done_o <= '0';
        mosi_o <= '0';

        case current_state_s is
            when IDLE     => null;
            when TRANSFER =>
                cs_n_o <= '0';
                busy_o <= '1';
                mosi_o <= shift_s(7);
            when FINISH =>
                done_o <= '1';
        end case;
    end process;

    sclk_o <= sclk_s;

end architecture;
