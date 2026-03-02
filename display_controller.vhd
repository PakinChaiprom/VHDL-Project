library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity display_controller is
    Port (
        clk               : in  std_logic;
        current_state     : in  std_logic_vector(3 downto 0);
        vote_count_array  : in  std_logic_vector(31 downto 0);
        tie_flag          : in  std_logic;
        early_winner_flag : in  std_logic;

        led               : out std_logic_vector(10 downto 0);
        seg               : out std_logic_vector(6 downto 0);
        an                : out std_logic_vector(3 downto 0)
    );
end display_controller;

architecture behavioral of display_controller is
begin

    led <= (others => '0');
    seg <= (others => '1');
    an  <= "1110";

end behavioral;
