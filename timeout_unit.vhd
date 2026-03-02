library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity timeout_unit is
    Port (
        clk          : in  std_logic;
        enable       : in  std_logic;
        timeout_flag : out std_logic
    );
end timeout_unit;

architecture behavioral of timeout_unit is
begin

    timeout_flag <= '0';

end behavioral;
