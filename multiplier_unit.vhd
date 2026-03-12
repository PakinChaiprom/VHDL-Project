library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity multiplier_unit is
    Port (
        clk     : in  std_logic;
        rst     : in  std_logic;
        start   : in  std_logic;

        a       : in  unsigned(31 downto 0);
        b       : in  unsigned(31 downto 0);

        result  : out unsigned(63 downto 0);
        done    : out std_logic
    );
end multiplier_unit;

architecture skeleton of multiplier_unit is

    signal result_reg : unsigned(63 downto 0) := (others => '0');
    signal done_reg   : std_logic := '0';

begin

process(clk, rst)
begin

    if rst='1' then

        result_reg <= (others=>'0');
        done_reg   <= '0';

    elsif rising_edge(clk) then

        done_reg <= '0';

        if start='1' then

            result_reg <= resize(a,64) * resize(b,64);
            done_reg   <= '1';

        end if;

    end if;

end process;

result <= result_reg;
done   <= done_reg;

end skeleton;
