library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

------------------------------------------------------------------------
-- scan_controller: streams a full frame to the SSD1331 over SPI
-- Generic pixel interface via pixel_addr_o / pixel_data_i;
-- connect to a ROM, BRAM, or combinational pixel source as needed.
------------------------------------------------------------------------
entity scan_controller is
    port (
        clk_i        : in  std_logic;
        rst_i        : in  std_logic;
        start_i      : in  std_logic;                     -- frame start pulse
        -- pixel source interface (ROM, BRAM, or combinational logic)
        pixel_addr_o : out std_logic_vector(12 downto 0); -- 0 to 6143
        pixel_data_i : in  std_logic_vector(15 downto 0); -- RGB565 colour
        -- SPI master interface
        spi_data_o   : out std_logic_vector(7 downto 0);
        spi_start_o  : out std_logic;
        spi_busy_i   : in  std_logic;
        dc_o         : out std_logic;                     -- 0=command, 1=data
        -- status
        done_o       : out std_logic                      -- single-cycle pulse
    );
end entity scan_controller;

architecture rtl of scan_controller is

    -- Window command header: 6 bytes, DC=0
    -- Columns 0→95 then rows 0→63
    constant HDR_CNT : natural := 6;
    type t_hdr_rom is array(0 to HDR_CNT - 1) of std_logic_vector(7 downto 0);
    constant HDR_ROM : t_hdr_rom := (
        x"15", x"00", x"5F",   -- Set Column Address: 0 → 95
        x"75", x"00", x"3F"    -- Set Row Address:    0 → 63
    );

    -- 96 × 64 pixels
    constant PIX_CNT : natural := 6144;

    type t_state is (
        IDLE,
        SND_HDR, WAIT_HDR,
        SND_HI,  WAIT_HI,
        SND_LO,  WAIT_LO,
        DONE
    );

    signal current_state_s : t_state;
    signal next_state_s    : t_state;

    signal hdr_idx_s : natural range 0 to HDR_CNT - 1;
    signal pix_idx_s : natural range 0 to PIX_CNT - 1;

begin

    next_state_logic : process(current_state_s, hdr_idx_s, pix_idx_s,
                               start_i, spi_busy_i)
    begin
        next_state_s <= current_state_s;

        case current_state_s is

            when IDLE =>
                if start_i = '1' then
                    next_state_s <= SND_HDR;
                end if;

            when SND_HDR =>
                next_state_s <= WAIT_HDR;

            when WAIT_HDR =>
                if spi_busy_i = '0' then
                    if hdr_idx_s < HDR_CNT - 1 then
                        next_state_s <= SND_HDR;
                    elsif hdr_idx_s = HDR_CNT - 1 then
                        next_state_s <= SND_HI;
                    end if;
                end if;

            when SND_HI =>
                next_state_s <= WAIT_HI;

            when WAIT_HI =>
                if spi_busy_i = '0' then
                    next_state_s <= SND_LO;
                end if;

            when SND_LO =>
                next_state_s <= WAIT_LO;

            when WAIT_LO =>
                if spi_busy_i = '0' then
                    if pix_idx_s < PIX_CNT - 1 then
                        next_state_s <= SND_HI;
                    elsif pix_idx_s = PIX_CNT - 1 then
                        next_state_s <= DONE;
                    end if;
                end if;

            when DONE =>
                -- Immediately restart for continuous refresh
                next_state_s <= SND_HDR;

        end case;
    end process next_state_logic;

    current_state : process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            current_state_s <= IDLE;
            hdr_idx_s       <= 0;
            pix_idx_s       <= 0;

        elsif rising_edge(clk_i) then
            current_state_s <= next_state_s;

            case current_state_s is
                when IDLE =>
                    hdr_idx_s <= 0;
                    pix_idx_s <= 0;

                when DONE =>
                    hdr_idx_s <= 0;
                    pix_idx_s <= 0;

                when WAIT_HDR =>
                    if spi_busy_i = '0' and hdr_idx_s < HDR_CNT - 1 then
                        hdr_idx_s <= hdr_idx_s + 1;
                    end if;

                when WAIT_LO =>
                    if spi_busy_i = '0' and pix_idx_s < PIX_CNT - 1 then
                        pix_idx_s <= pix_idx_s + 1;
                    end if;

                when others =>
                    null;
            end case;

        end if;
    end process current_state;

    output_logic : process(current_state_s, hdr_idx_s, pix_idx_s, pixel_data_i)
    begin
        dc_o         <= '0';
        spi_start_o  <= '0';
        spi_data_o   <= (others => '0');
        pixel_addr_o <= (others => '0');
        done_o       <= '0';

        case current_state_s is

            when IDLE => null;

            when SND_HDR =>
                spi_start_o <= '1';
                spi_data_o  <= HDR_ROM(hdr_idx_s);

            when WAIT_HDR => null;

            when SND_HI =>
                dc_o         <= '1';
                spi_start_o  <= '1';
                spi_data_o   <= pixel_data_i(15 downto 8);
                pixel_addr_o <= std_logic_vector(TO_UNSIGNED(pix_idx_s, 13));

            when WAIT_HI =>
                dc_o         <= '1';
                pixel_addr_o <= std_logic_vector(TO_UNSIGNED(pix_idx_s, 13));

            when SND_LO =>
                dc_o         <= '1';
                spi_start_o  <= '1';
                spi_data_o   <= pixel_data_i(7 downto 0);
                pixel_addr_o <= std_logic_vector(TO_UNSIGNED(pix_idx_s, 13));

            when WAIT_LO =>
                dc_o <= '1';
                if pix_idx_s < PIX_CNT - 1 then
                    pixel_addr_o <= std_logic_vector(to_unsigned(pix_idx_s + 1, 13));
                else
                    pixel_addr_o <= (others => '0');
                end if;

            when DONE =>
                done_o <= '1';

        end case;
    end process output_logic;

end architecture rtl;
