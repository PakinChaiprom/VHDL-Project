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
        voter_id    : in unsigned(12 downto 0);
        
        -- [INPUT]: Validation trigger to check/record the ID
        -- Source: Triggered by 'main_fsm.vhd' when user confirms their vote
        vote_valid  : in std_logic;

        -- [OUTPUT]: Status flag indicating if the ID has already voted
        -- Destination: Read by 'main_fsm.vhd' to allow or deny the voting process
        -- Value: '1' if ID is a duplicate, '0' if ID is valid (first-time vote)
        voted_flag  : out std_logic
    );
end vote_memory;

architecture behavioral of vote_memory is

    ------------------------------------------------------------------------------
    -- CONSTANT DECLARATION
    ------------------------------------------------------------------------------
    -- Total number of supported voters = 2^13 = 8,192
    constant MAX_VOTERS : integer := 8192;

    ------------------------------------------------------------------------------
    -- INTERNAL MEMORY DECLARATION
    ------------------------------------------------------------------------------
    -- Define a RAM-like array type to store 1-bit status for each voter ID
    -- Index: 0 to 8191 (corresponds to voter_id value)
    -- Content: '0' = Available, '1' = Already Voted
    type voter_array is array (0 to MAX_VOTERS-1) of std_logic;

    -- Create the actual memory signal and initialize all slots to '0' (Not Voted)
    signal voter_memory : voter_array := (others => '0');

    -- Internal register to hold the flag state before sending to the output port
    signal voted_flag_reg : std_logic := '0';

begin

    ------------------------------------------------------------------------------
    -- MAIN SEQUENTIAL PROCESS
    ------------------------------------------------------------------------------
    -- Synchronous logic that reacts to the rising edge of the system clock
    process(clk)
    begin
        if rising_edge(clk) then
            
            -- [RESET HANDLER]: Clears the database
            -- Triggered when rst is high (usually from the admin or power-on)
            if rst = '1' then
                voter_memory <= (others => '0'); -- Wipe all 8,192 entries
                voted_flag_reg <= '0';           -- Clear the duplicate warning flag
                
            -- [VOTE PROCESSING]: Triggered by a pulse from the FSM
            elsif vote_valid = '1' then
                
                -- Check the memory entry at the index specified by voter_id
                -- to_integer() converts the 13-bit unsigned signal to an array index
                if voter_memory(to_integer(voter_id)) = '1' then
                    
                    ------------------------------------------------------------
                    -- CASE A: DUPLICATE VOTE DETECTED
                    -- The current ID is already marked as '1' in memory
                    ------------------------------------------------------------
                    voted_flag_reg <= '1'; -- Alert the FSM to block this vote
                    
                else
                    
                    ------------------------------------------------------------
                    -- CASE B: VALID FIRST-TIME VOTE
                    -- The current ID is marked as '0' in memory
                    ------------------------------------------------------------
                    voted_flag_reg <= '0'; -- Inform the FSM that the ID is clear
                    
                    -- Update memory: Mark this specific ID as '1' (voted)
                    -- This prevents the ID from being used again in the same cycle
                    voter_memory(to_integer(voter_id)) <= '1';
                    
                end if;
            else
                voted_flag_reg <= '0'; 
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------------
    -- OUTPUT ASSIGNMENT
    ------------------------------------------------------------------------------
    -- Drive the external output port using the value from the internal register
    voted_flag <= voted_flag_reg;

end behavioral;
