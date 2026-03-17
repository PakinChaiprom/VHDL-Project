library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- =============================================================
-- Testbench for ev_allocator (Fixed Version)
--
-- Test Cases:
--   TC1: Simple 3-state case (easy to verify by hand)
--   TC2: Equal population (EV should be distributed evenly)
--   TC3: Single state (all EV goes to 1 state)
--   TC4: Reset mid-operation
-- =============================================================

entity ev_allocator_tb is
end ev_allocator_tb;

architecture sim of ev_allocator_tb is

    -- -------------------------------------------------------
    -- Component Declaration
    -- -------------------------------------------------------
    component ev_allocator is
        Port (
            clk   : in std_logic;
            rst   : in std_logic;
            start : in std_logic;

            state_count : in unsigned(9 downto 0);
            ev_total    : in unsigned(9 downto 0);

            pop_data  : in unsigned(9 downto 0);
            pop_index : in integer range 0 to 998;
            pop_write : in std_logic;

            done : out std_logic;

            ev_query_index       : in  integer range 0 to 998;
            ev_result_out        : out std_logic_vector(9 downto 0);
            population_total_out : out unsigned(31 downto 0);
            pop_query_index      : in  integer range 0 to 998;
            pop_result_out       : out std_logic_vector(9 downto 0)
        );
    end component;

    -- -------------------------------------------------------
    -- Signals
    -- -------------------------------------------------------
    constant CLK_PERIOD : time := 10 ns;

    signal clk   : std_logic := '0';
    signal rst   : std_logic := '1';
    signal start : std_logic := '0';

    signal state_count : unsigned(9 downto 0) := (others => '0');
    signal ev_total    : unsigned(9 downto 0) := (others => '0');

    signal pop_data  : unsigned(9 downto 0) := (others => '0');
    signal pop_index : integer range 0 to 998 := 0;
    signal pop_write : std_logic := '0';

    signal done                  : std_logic;
    signal ev_query_index        : integer range 0 to 998 := 0;
    signal ev_result_out         : std_logic_vector(9 downto 0);
    signal population_total_out  : unsigned(31 downto 0);
    signal pop_query_index       : integer range 0 to 998 := 0;
    signal pop_result_out        : std_logic_vector(9 downto 0);

    -- -------------------------------------------------------
    -- Helper: track test pass/fail
    -- -------------------------------------------------------
    signal test_pass : boolean := true;

    -- -------------------------------------------------------
    -- Procedures
    -- -------------------------------------------------------

    -- Wait for rising edge
    procedure clk_wait(n : integer; signal clk : in std_logic) is
    begin
        for k in 1 to n loop
            wait until rising_edge(clk);
        end loop;
    end procedure;

    -- Write one population entry
    procedure write_pop(
        idx  : in integer;
        val  : in integer;
        signal pop_index : out integer range 0 to 998;
        signal pop_data  : out unsigned(9 downto 0);
        signal pop_write : out std_logic;
        signal clk       : in  std_logic
    ) is
    begin
        wait until rising_edge(clk);
        pop_index <= idx;
        pop_data  <= to_unsigned(val, 10);
        pop_write <= '1';
        wait until rising_edge(clk);
        pop_write <= '0';
    end procedure;

begin

    -- -------------------------------------------------------
    -- DUT Instantiation
    -- -------------------------------------------------------
    DUT : ev_allocator
        port map (
            clk                  => clk,
            rst                  => rst,
            start                => start,
            state_count          => state_count,
            ev_total             => ev_total,
            pop_data             => pop_data,
            pop_index            => pop_index,
            pop_write            => pop_write,
            done                 => done,
            ev_query_index       => ev_query_index,
            ev_result_out        => ev_result_out,
            population_total_out => population_total_out,
            pop_query_index      => pop_query_index,
            pop_result_out       => pop_result_out
        );

    -- -------------------------------------------------------
    -- Clock Generation
    -- -------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2;

    -- -------------------------------------------------------
    -- Stimulus Process
    -- -------------------------------------------------------
    process
        variable ev0, ev1, ev2 : integer;
        variable ev_sum        : integer;
    begin

        -- ==================================================
        -- RESET
        -- ==================================================
        rst   <= '1';
        start <= '0';
        clk_wait(5, clk);
        rst <= '0';
        clk_wait(2, clk);

        -- ==================================================
        -- TC1: 3 States, pop = {100, 200, 300}, ev_total = 10
        -- Expected (Hamilton method):
        --   quota[0] = 100*10/600 = 1.667 -> base=1, rem=0.667
        --   quota[1] = 200*10/600 = 3.333 -> base=3, rem=0.333
        --   quota[2] = 300*10/600 = 5.000 -> base=5, rem=0.000
        --   sum base = 9, ev_to_add = 1
        --   largest remainder = state[0] -> state[0] gets +1
        --   Final: ev[0]=2, ev[1]=3, ev[2]=5
        -- ==================================================
        report "=== TC1: Basic 3-state test ===" severity note;

        write_pop(0, 100, pop_index, pop_data, pop_write, clk);
        write_pop(1, 200, pop_index, pop_data, pop_write, clk);
        write_pop(2, 300, pop_index, pop_data, pop_write, clk);

        state_count <= to_unsigned(3, 10);
        ev_total    <= to_unsigned(10, 10);

        -- Pulse start
        wait until rising_edge(clk);
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';

        -- Wait for done
        wait until done = '1';
        clk_wait(2, clk);

        -- Read results
        ev_query_index <= 0; clk_wait(1, clk);
        ev0 := to_integer(unsigned(ev_result_out));

        ev_query_index <= 1; clk_wait(1, clk);
        ev1 := to_integer(unsigned(ev_result_out));

        ev_query_index <= 2; clk_wait(1, clk);
        ev2 := to_integer(unsigned(ev_result_out));

        ev_sum := ev0 + ev1 + ev2;

        report "TC1 Results: ev[0]=" & integer'image(ev0) &
               " ev[1]=" & integer'image(ev1) &
               " ev[2]=" & integer'image(ev2) &
               " sum=" & integer'image(ev_sum) severity note;

        -- Check sum equals ev_total
        assert ev_sum = 10
            report "TC1 FAIL: EV sum=" & integer'image(ev_sum) & " expected 10"
            severity error;

        -- Check individual values
        assert ev0 = 2
            report "TC1 FAIL: ev[0]=" & integer'image(ev0) & " expected 2"
            severity error;
        assert ev1 = 3
            report "TC1 FAIL: ev[1]=" & integer'image(ev1) & " expected 3"
            severity error;
        assert ev2 = 5
            report "TC1 FAIL: ev[2]=" & integer'image(ev2) & " expected 5"
            severity error;

        if ev_sum = 10 and ev0 = 2 and ev1 = 3 and ev2 = 5 then
            report "TC1 PASS" severity note;
        end if;

        -- Deassert start to return to IDLE
        start <= '0';
        clk_wait(3, clk);

        -- ==================================================
        -- TC2: Equal population — EV should be even
        --   pop = {100, 100, 100, 100}, ev_total = 8
        --   Expected: ev[0..3] = 2 each
        -- ==================================================
        report "=== TC2: Equal population ===" severity note;

        rst <= '1'; clk_wait(3, clk); rst <= '0'; clk_wait(2, clk);

        write_pop(0, 100, pop_index, pop_data, pop_write, clk);
        write_pop(1, 100, pop_index, pop_data, pop_write, clk);
        write_pop(2, 100, pop_index, pop_data, pop_write, clk);
        write_pop(3, 100, pop_index, pop_data, pop_write, clk);

        state_count <= to_unsigned(4, 10);
        ev_total    <= to_unsigned(8, 10);

        wait until rising_edge(clk);
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';

        wait until done = '1';
        clk_wait(2, clk);

        ev_sum := 0;
        for idx in 0 to 3 loop
            ev_query_index <= idx;
            clk_wait(1, clk);
            ev_sum := ev_sum + to_integer(unsigned(ev_result_out));
        end loop;

        report "TC2 Total EV assigned: " & integer'image(ev_sum) severity note;

        assert ev_sum = 8
            report "TC2 FAIL: sum=" & integer'image(ev_sum) & " expected 8"
            severity error;

        if ev_sum = 8 then
            report "TC2 PASS" severity note;
        end if;

        start <= '0';
        clk_wait(3, clk);

        -- ==================================================
        -- TC3: Single state — all EV goes to state[0]
        --   pop = {500}, ev_total = 15
        --   Expected: ev[0] = 15
        -- ==================================================
        report "=== TC3: Single state ===" severity note;

        rst <= '1'; clk_wait(3, clk); rst <= '0'; clk_wait(2, clk);

        write_pop(0, 500, pop_index, pop_data, pop_write, clk);

        state_count <= to_unsigned(1, 10);
        ev_total    <= to_unsigned(15, 10);

        wait until rising_edge(clk);
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';

        wait until done = '1';
        clk_wait(2, clk);

        ev_query_index <= 0;
        clk_wait(1, clk);
        ev0 := to_integer(unsigned(ev_result_out));

        report "TC3 ev[0]=" & integer'image(ev0) severity note;

        assert ev0 = 15
            report "TC3 FAIL: ev[0]=" & integer'image(ev0) & " expected 15"
            severity error;

        if ev0 = 15 then
            report "TC3 PASS" severity note;
        end if;

        start <= '0';
        clk_wait(3, clk);

        -- ==================================================
        -- TC4: Reset mid-operation
        --   Start computation, then reset partway through
        --   After reset, run a clean TC1 again — should work correctly
        -- ==================================================
        report "=== TC4: Reset mid-operation ===" severity note;

        rst <= '1'; clk_wait(3, clk); rst <= '0'; clk_wait(2, clk);

        write_pop(0, 100, pop_index, pop_data, pop_write, clk);
        write_pop(1, 200, pop_index, pop_data, pop_write, clk);
        write_pop(2, 300, pop_index, pop_data, pop_write, clk);

        state_count <= to_unsigned(3, 10);
        ev_total    <= to_unsigned(10, 10);

        wait until rising_edge(clk);
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';

        -- Wait only 20 clocks then reset (mid-computation)
        clk_wait(20, clk);
        rst <= '1';
        clk_wait(3, clk);
        rst <= '0';
        clk_wait(2, clk);

        report "TC4: Reset applied mid-run. Re-running clean computation..." severity note;

        -- Re-write population (array survives reset by design — rewrite to be safe)
        write_pop(0, 100, pop_index, pop_data, pop_write, clk);
        write_pop(1, 200, pop_index, pop_data, pop_write, clk);
        write_pop(2, 300, pop_index, pop_data, pop_write, clk);

        state_count <= to_unsigned(3, 10);
        ev_total    <= to_unsigned(10, 10);

        wait until rising_edge(clk);
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';

        wait until done = '1';
        clk_wait(2, clk);

        ev_query_index <= 0; clk_wait(1, clk); ev0 := to_integer(unsigned(ev_result_out));
        ev_query_index <= 1; clk_wait(1, clk); ev1 := to_integer(unsigned(ev_result_out));
        ev_query_index <= 2; clk_wait(1, clk); ev2 := to_integer(unsigned(ev_result_out));
        ev_sum := ev0 + ev1 + ev2;

        report "TC4 After reset: ev[0]=" & integer'image(ev0) &
               " ev[1]=" & integer'image(ev1) &
               " ev[2]=" & integer'image(ev2) &
               " sum=" & integer'image(ev_sum) severity note;

        assert ev_sum = 10
            report "TC4 FAIL: sum after reset=" & integer'image(ev_sum) & " expected 10"
            severity error;

        if ev_sum = 10 then
            report "TC4 PASS" severity note;
        end if;

        -- ==================================================
        -- END
        -- ==================================================
        report "=== All test cases complete ===" severity note;
        wait;

    end process;
end sim;
