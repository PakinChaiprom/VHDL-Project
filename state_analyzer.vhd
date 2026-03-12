----------------------------------------------------------------------------------
-- Testbench: tb_state_analyzer
-- Test Cases:
--   TC1 : C1 wins state       → C1 gets all EV
--   TC2 : C2 wins state       → C2 gets all EV
--   TC3 : Tie + EVEN EV       → split equally
--   TC4 : Tie + ODD EV        → C1 wins national → C1 gets extra 1
--   TC5 : Tie + ODD EV        → C2 wins national → C2 gets extra 1
--   TC6 : Tie + ODD EV        → National tie     → pending +1
--   TC7 : RST mid-run         → all accumulators clear
--   TC8 : Multiple states     → accumulation across states
--
-- Expected Results:
--   TC1 : ev_c1=10  ev_c2=0   pending=0
--   TC2 : ev_c1=10  ev_c2=8   pending=0
--   TC3 : ev_c1=13  ev_c2=11  pending=0
--   TC4 : ev_c1=18  ev_c2=15  pending=0  (half=4, c1 gets +5)
--   TC5 : ev_c1=21  ev_c2=21  pending=0  (half=3, c2 gets +4)
--   TC6 : ev_c1=24  ev_c2=24  pending=1
--   TC7 : ev_c1=0   ev_c2=0   pending=0  (after RST)
--   TC8 : ev_c1=10  ev_c2=0   pending=0  (re-accumulate after RST)
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_state_analyzer is
end tb_state_analyzer;

architecture behavior of tb_state_analyzer is

    ----------------------------------------------------------------
    -- DUT SIGNALS
    ----------------------------------------------------------------
    signal clk             : std_logic := '0';
    signal rst             : std_logic := '0';
    signal start_analysis  : std_logic := '0';

    signal pop_vote_c1     : unsigned(15 downto 0) := (others => '0');
    signal pop_vote_c2     : unsigned(15 downto 0) := (others => '0');
    signal national_pop_c1 : unsigned(31 downto 0) := (others => '0');
    signal national_pop_c2 : unsigned(31 downto 0) := (others => '0');
    signal state_ev_value  : unsigned(7 downto 0)  := (others => '0');

    signal total_ev_c1     : unsigned(15 downto 0);
    signal total_ev_c2     : unsigned(15 downto 0);
    signal pending_ev_pool : unsigned(7 downto 0);
    signal done_analysis   : std_logic;

    constant CLK_PERIOD : time := 10 ns;

    ----------------------------------------------------------------
    -- HELPER: wait until done_analysis pulses then goes low
    ----------------------------------------------------------------
    -- Usage: call after setting start_analysis='1' for 1 cycle
    ----------------------------------------------------------------

begin

    ----------------------------------------------------------------
    -- DUT INSTANTIATION
    ----------------------------------------------------------------
    DUT : entity work.state_analyzer
        port map (
            clk             => clk,
            rst             => rst,
            start_analysis  => start_analysis,
            pop_vote_c1     => pop_vote_c1,
            pop_vote_c2     => pop_vote_c2,
            national_pop_c1 => national_pop_c1,
            national_pop_c2 => national_pop_c2,
            state_ev_value  => state_ev_value,
            total_ev_c1     => total_ev_c1,
            total_ev_c2     => total_ev_c2,
            pending_ev_pool => pending_ev_pool,
            done_analysis   => done_analysis
        );

    ----------------------------------------------------------------
    -- CLOCK GENERATION : 100 MHz
    ----------------------------------------------------------------
    clk_process : process
    begin
        clk <= '0'; wait for CLK_PERIOD / 2;
        clk <= '1'; wait for CLK_PERIOD / 2;
    end process;

    ----------------------------------------------------------------
    -- STIMULUS PROCESS
    ----------------------------------------------------------------
    stimulus : process
    begin

        ------------------------------------------------------------
        -- INITIAL RESET
        ------------------------------------------------------------
        rst <= '1';
        wait for 3 * CLK_PERIOD;   -- hold reset 3 cycles
        rst <= '0';
        wait for CLK_PERIOD;

        ------------------------------------------------------------
        -- TC1 : C1 WINS STATE
        -- pop_c1=1200 > pop_c2=800  →  C1 gets all 10 EV
        -- Expected after TC1: ev_c1=10  ev_c2=0  pending=0
        ------------------------------------------------------------
        pop_vote_c1     <= to_unsigned(1200, 16);
        pop_vote_c2     <= to_unsigned(800,  16);
        national_pop_c1 <= to_unsigned(5000, 32);
        national_pop_c2 <= to_unsigned(4500, 32);
        state_ev_value  <= to_unsigned(10, 8);

        start_analysis <= '1';
        wait for CLK_PERIOD;        -- cycle 1: latch inputs, processing='1'
        start_analysis <= '0';
        wait for CLK_PERIOD;        -- cycle 2: done_analysis='1'
        wait for CLK_PERIOD;        -- cycle 3: done clears, observe outputs
        -- >> Observe: total_ev_c1=10, total_ev_c2=0, pending=0

        ------------------------------------------------------------
        -- TC2 : C2 WINS STATE
        -- pop_c1=500 < pop_c2=900  →  C2 gets all 8 EV
        -- Expected after TC2: ev_c1=10  ev_c2=8  pending=0
        ------------------------------------------------------------
        pop_vote_c1    <= to_unsigned(500, 16);
        pop_vote_c2    <= to_unsigned(900, 16);
        state_ev_value <= to_unsigned(8, 8);

        start_analysis <= '1';
        wait for CLK_PERIOD;
        start_analysis <= '0';
        wait for 2 * CLK_PERIOD;
        -- >> Observe: total_ev_c1=10, total_ev_c2=8, pending=0

        ------------------------------------------------------------
        -- TC3 : TIE + EVEN EV (6 EV)
        -- pop_c1=pop_c2=1000  EV=6 (even) → each gets 3
        -- Expected after TC3: ev_c1=13  ev_c2=11  pending=0
        ------------------------------------------------------------
        pop_vote_c1    <= to_unsigned(1000, 16);
        pop_vote_c2    <= to_unsigned(1000, 16);
        state_ev_value <= to_unsigned(6, 8);

        start_analysis <= '1';
        wait for CLK_PERIOD;
        start_analysis <= '0';
        wait for 2 * CLK_PERIOD;
        -- >> Observe: total_ev_c1=13, total_ev_c2=11, pending=0

        ------------------------------------------------------------
        -- TC4 : TIE + ODD EV (9 EV)  →  C1 leads nationally
        -- half = 4, remain 1 → C1 gets 5, C2 gets 4
        -- Expected after TC4: ev_c1=18  ev_c2=15  pending=0
        ------------------------------------------------------------
        pop_vote_c1     <= to_unsigned(1000, 16);
        pop_vote_c2     <= to_unsigned(1000, 16);
        national_pop_c1 <= to_unsigned(7000, 32);  -- C1 leads nationally
        national_pop_c2 <= to_unsigned(6500, 32);
        state_ev_value  <= to_unsigned(9, 8);

        start_analysis <= '1';
        wait for CLK_PERIOD;
        start_analysis <= '0';
        wait for 2 * CLK_PERIOD;
        -- >> Observe: total_ev_c1=18, total_ev_c2=15, pending=0

        ------------------------------------------------------------
        -- TC5 : TIE + ODD EV (7 EV)  →  C2 leads nationally
        -- half = 3, remain 1 → C1 gets 3, C2 gets 4
        -- Expected after TC5: ev_c1=21  ev_c2=19  pending=0
        ------------------------------------------------------------
        pop_vote_c1     <= to_unsigned(1000, 16);
        pop_vote_c2     <= to_unsigned(1000, 16);
        national_pop_c1 <= to_unsigned(6000, 32);
        national_pop_c2 <= to_unsigned(6800, 32);  -- C2 leads nationally
        state_ev_value  <= to_unsigned(7, 8);

        start_analysis <= '1';
        wait for CLK_PERIOD;
        start_analysis <= '0';
        wait for 2 * CLK_PERIOD;
        -- >> Observe: total_ev_c1=21, total_ev_c2=19, pending=0

        ------------------------------------------------------------
        -- TC6 : TIE + ODD EV (5 EV)  →  NATIONAL TIE → pending +1
        -- half = 2, remain 1 → each gets 2, pending pool +1
        -- Expected after TC6: ev_c1=23  ev_c2=21  pending=1
        ------------------------------------------------------------
        pop_vote_c1     <= to_unsigned(1000, 16);
        pop_vote_c2     <= to_unsigned(1000, 16);
        national_pop_c1 <= to_unsigned(6000, 32);  -- national tie
        national_pop_c2 <= to_unsigned(6000, 32);
        state_ev_value  <= to_unsigned(5, 8);

        start_analysis <= '1';
        wait for CLK_PERIOD;
        start_analysis <= '0';
        wait for 2 * CLK_PERIOD;
        -- >> Observe: total_ev_c1=23, total_ev_c2=21, pending=1

        ------------------------------------------------------------
        -- TC7 : RESET MID-RUN
        -- After reset all accumulators must clear to 0
        -- Expected after TC7: ev_c1=0  ev_c2=0  pending=0
        ------------------------------------------------------------
        rst <= '1';
        wait for 2 * CLK_PERIOD;
        rst <= '0';
        wait for CLK_PERIOD;
        -- >> Observe: total_ev_c1=0, total_ev_c2=0, pending=0

        ------------------------------------------------------------
        -- TC8 : ACCUMULATE AFTER RESET  (verify accumulators restart)
        -- C1 wins 10 EV again
        -- Expected after TC8: ev_c1=10  ev_c2=0  pending=0
        ------------------------------------------------------------
        pop_vote_c1    <= to_unsigned(1200, 16);
        pop_vote_c2    <= to_unsigned(800,  16);
        state_ev_value <= to_unsigned(10, 8);

        start_analysis <= '1';
        wait for CLK_PERIOD;
        start_analysis <= '0';
        wait for 2 * CLK_PERIOD;
        -- >> Observe: total_ev_c1=10, total_ev_c2=0, pending=0

        wait; -- end simulation
    end process;

end behavior;