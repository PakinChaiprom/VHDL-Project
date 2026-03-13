----------------------------------------------------------------------------------
-- Module Name: state_analyzer
-- Project Name: Advanced Electronic Voting System
--
-- Description:
-- This module analyzes the Popular Vote of a single state and allocates
-- Electoral Votes (EV) according to the following rules:
--
-- 1) If Candidate 1 has more Popular Votes → C1 gets all EV
-- 2) If Candidate 2 has more Popular Votes → C2 gets all EV
--
-- 3) If Popular Votes are tied:
--      • If EV is even → split EV equally
--      • If EV is odd:
--            - split EV equally first
--            - remaining 1 EV goes to candidate with higher NATIONAL popular vote
--            - if national popular vote also tied → store that EV in pending pool
--
-- Output values are accumulated at national level.
--
-- Pending EV pool is sent to Admin Mode for final decision.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity state_analyzer is
    Port (

        ----------------------------------------------------------------
        -- CLOCK & RESET
        ----------------------------------------------------------------
        clk             : in std_logic;
        rst             : in std_logic;

        ----------------------------------------------------------------
        -- CONTROL SIGNAL
        ----------------------------------------------------------------
        start_analysis  : in std_logic;

        ----------------------------------------------------------------
        -- POPULAR VOTE (CURRENT STATE)
        ----------------------------------------------------------------
        pop_vote_c1     : in unsigned(15 downto 0);
        pop_vote_c2     : in unsigned(15 downto 0);

        ----------------------------------------------------------------
        -- NATIONAL POPULAR VOTE (ALL STATES COMBINED)
        ----------------------------------------------------------------
        national_pop_c1 : in unsigned(31 downto 0);
        national_pop_c2 : in unsigned(31 downto 0);

        ----------------------------------------------------------------
        -- ELECTORAL VOTES OF CURRENT STATE
        ----------------------------------------------------------------
        state_ev_value  : in unsigned(9 downto 0);

        ----------------------------------------------------------------
        -- OUTPUT: TOTAL ELECTORAL VOTES
        ----------------------------------------------------------------
        total_ev_c1     : out unsigned(15 downto 0);
        total_ev_c2     : out unsigned(15 downto 0);

        ----------------------------------------------------------------
        -- OUTPUT: PENDING EV POOL
        ----------------------------------------------------------------
        pending_ev_pool : out unsigned(7 downto 0);

        ----------------------------------------------------------------
        -- OUTPUT: DONE FLAG
        ----------------------------------------------------------------
        done_analysis   : out std_logic
    );
end state_analyzer;

architecture behavioral of state_analyzer is

    ----------------------------------------------------------------
    -- INTERNAL REGISTERS
    ----------------------------------------------------------------

    signal ev_acc_c1 : unsigned(15 downto 0) := (others => '0');
    signal ev_acc_c2 : unsigned(15 downto 0) := (others => '0');

    signal pending_ev : unsigned(7 downto 0) := (others => '0');

    signal processing : std_logic := '0';

begin

process(clk)

    variable half_ev : unsigned(9 downto 0);

begin

    if rising_edge(clk) then

        ----------------------------------------------------------------
        -- RESET SYSTEM
        ----------------------------------------------------------------
        if rst = '1' then

            ev_acc_c1 <= (others => '0');
            ev_acc_c2 <= (others => '0');
            pending_ev <= (others => '0');

            processing <= '0';
            done_analysis <= '0';

        ----------------------------------------------------------------
        -- START ANALYSIS
        ----------------------------------------------------------------
        elsif start_analysis = '1' and processing = '0' then

            processing <= '1';
            done_analysis <= '0';

            ------------------------------------------------------------
            -- CASE 1 : CANDIDATE 1 WINS STATE
            ------------------------------------------------------------
            if pop_vote_c1 > pop_vote_c2 then

                ev_acc_c1 <= ev_acc_c1 + state_ev_value;

            ------------------------------------------------------------
            -- CASE 2 : CANDIDATE 2 WINS STATE
            ------------------------------------------------------------
            elsif pop_vote_c2 > pop_vote_c1 then

                ev_acc_c2 <= ev_acc_c2 + state_ev_value;

            ------------------------------------------------------------
            -- CASE 3 : POPULAR VOTE TIE
            ------------------------------------------------------------
            else

                half_ev := state_ev_value / 2;

                --------------------------------------------------------
                -- EVEN EV CASE
                --------------------------------------------------------
                if (state_ev_value mod 2 = 0) then

                    ev_acc_c1 <= ev_acc_c1 + half_ev;
                    ev_acc_c2 <= ev_acc_c2 + half_ev;

                --------------------------------------------------------
                -- ODD EV CASE
                --------------------------------------------------------
                else

                    

                    ----------------------------------------------------
                    -- CHECK NATIONAL POPULAR VOTE
                    ----------------------------------------------------
                    if national_pop_c1 > national_pop_c2 then

                        ev_acc_c1 <= ev_acc_c1 + half_ev + 1; -- half + remain 1
                        ev_acc_c2 <= ev_acc_c2 + half_ev;

                    elsif national_pop_c2 > national_pop_c1 then

                        ev_acc_c2 <= ev_acc_c2 + half_ev + 1;
                        ev_acc_c1 <= ev_acc_c1 + half_ev; -- half + remain 1

                    ----------------------------------------------------
                    -- NATIONAL POP TIE → STORE IN PENDING POOL
                    ----------------------------------------------------
                    else

                        pending_ev <= pending_ev + 1;

                    end if;

                end if;

            end if;

        ----------------------------------------------------------------
        -- FINISH SIGNAL
        ----------------------------------------------------------------
        elsif start_analysis = '1' and processing = '1' then

            done_analysis <= '1';

        ----------------------------------------------------------------
        -- IDLE STATE
        ----------------------------------------------------------------
        elsif start_analysis = '0' then

            processing <= '0';
            done_analysis <= '0';

        end if;

    end if;

end process;

----------------------------------------------------------------
-- OUTPUT ASSIGNMENT
----------------------------------------------------------------

total_ev_c1 <= ev_acc_c1;
total_ev_c2 <= ev_acc_c2;

pending_ev_pool <= pending_ev;

end behavioral;
