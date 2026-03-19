----------------------------------------------------------------------------------
-- Module Name: vote_memory - Behavioral
-- Project Name: Advanced Electronic Voting System (Nexys A7)
-- Description: This module handles voter registration and prevents double-voting.
--              Updated to 13-bit Voter ID, supporting up to 8,192 unique voters.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL; -- Necessary for unsigned to integer conversion

entity vote_memory is
    Port (
        -- [INPUT]: System clock signal (Driven by top.vhd)
        clk         : in std_logic;
        
        -- [INPUT]: Global reset signal (Driven by top.vhd or admin command)
        -- Effect: Clears the entire voter database to start a new election cycle
        rst         : in std_logic;

        -- [INPUT]: 13-bit Voter ID (Supports values 0 to 8191)
        -- Source: Received from 'digit_input.vhd' module
        voter_id    : in unsigned(9 downto 0);
        
        -- [INPUT]: Validation trigger to check/record the ID
        -- Source: Triggered by 'main_fsm.vhd' when user confirms their vote
        vote_valid  : in std_logic;

        -- [OUTPUT]: Status flag indicating if the ID has already voted
        -- Destination: Read by 'main_fsm.vhd' to allow or deny the voting process
        -- Value: '1' if ID is a duplicate, '0' if ID is valid (first-time vote)
        voted_flag  : out std_logic;
        state_id    : in integer range 0 to 998
    );
end vote_memory;

architecture behavioral of vote_memory is
    constant MAX_VOTERS : integer := 100;
    constant MAX_STATES : integer := 50;

    type voter_array is array (0 to MAX_STATES-1, 0 to MAX_VOTERS-1) of std_logic;
    signal voter_memory : voter_array := (others => (others => '0'));
begin
    voted_flag <= voter_memory(state_id, to_integer(voter_id));

    process(clk, rst)
    begin
        if rst = '1' then
            voter_memory <= (others => (others => '0'));
        elsif rising_edge(clk) then
            if vote_valid = '1' then
                voter_memory(state_id, to_integer(voter_id)) <= '1';
            end if;
        end if;
    end process;
end behavioral;
