library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity memory_unit is
    Port (
        clk               : in  std_logic;
        reset_system      : in  std_logic;
        voter_id          : in  std_logic_vector(7 downto 0);
        candidate_select  : in  std_logic_vector(1 downto 0);
        write_enable      : in  std_logic;

        id_valid          : out std_logic;
        already_voted     : out std_logic;
        vote_count_array  : out std_logic_vector(31 downto 0);
        remaining_votes   : out std_logic_vector(7 downto 0)
    );
end memory_unit;

architecture behavioral of memory_unit is
begin

    id_valid         <= '1';
    already_voted    <= '0';
    vote_count_array <= (others => '0');
    remaining_votes  <= (others => '0');

end behavioral;
