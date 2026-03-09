library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity divider_unit is
    Port (
        clk     : in  std_logic;
        rst     : in  std_logic;

        start   : in  std_logic;

        numerator   : in  unsigned(63 downto 0); -- raw_value
        denominator : in  unsigned(31 downto 0); -- population_total

        quotient    : out unsigned(31 downto 0); -- base_EV
        remainder   : out unsigned(31 downto 0);

        done    : out std_logic
    );
end divider_unit;

architecture skeleton of divider_unit is

    signal quotient_reg  : unsigned(31 downto 0) := (others => '0');
    signal remainder_reg : unsigned(31 downto 0) := (others => '0');
    signal done_reg      : std_logic := '0';

begin

    process(clk, rst)
        variable q : unsigned(63 downto 0);
        variable r : unsigned(63 downto 0);
    begin

        if rst = '1' then

            quotient_reg  <= (others => '0');
            remainder_reg <= (others => '0');
            done_reg      <= '0';

        elsif rising_edge(clk) then

            if start = '1' then

                if denominator /= 0 then

                    q := numerator / resize(denominator,64);
                    r := numerator mod resize(denominator,64);

                    quotient_reg  <= q(31 downto 0);
                    remainder_reg <= r(31 downto 0);

                else

                    quotient_reg  <= (others => '0');
                    remainder_reg <= (others => '0');

                end if;

                done_reg <= '1';

            else

                done_reg <= '0';

            end if;

        end if;

    end process;

    quotient  <= quotient_reg;
    remainder <= remainder_reg;
    done      <= done_reg;

end skeleton;
