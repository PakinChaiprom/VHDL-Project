library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ev_allocator is
    Port (
        clk   : in std_logic;
        rst   : in std_logic;
        start : in std_logic;

        state_count : in unsigned(9 downto 0);
        ev_total    : in unsigned(9 downto 0);

        pop_data  : in unsigned(9 downto 0);
        pop_index : in integer range 0 to 49;
        pop_write : in std_logic;

        done : out std_logic
    );
end ev_allocator;

architecture behavioral of ev_allocator is

    constant MAX_STATES : integer := 50;

    -------------------------------------------------
    -- Population Storage
    -------------------------------------------------

    type pop_array_t is array (0 to MAX_STATES-1) of unsigned(9 downto 0);
    signal population_array : pop_array_t := (others => (others => '0'));

    -------------------------------------------------
    -- EV Results
    -------------------------------------------------

    type ev_array_t is array (0 to MAX_STATES-1) of unsigned(9 downto 0);
    signal base_ev_array : ev_array_t := (others => (others => '0'));

    -------------------------------------------------
    -- Remainders
    -------------------------------------------------

    type rem_array_t is array (0 to MAX_STATES-1) of unsigned(15 downto 0);
    signal remainder_array : rem_array_t := (others => (others => '0'));

    -------------------------------------------------
    -- Signals
    -------------------------------------------------

    signal population_total : unsigned(31 downto 0) := (others => '0')

    ;

    signal total_ev_assigned : unsigned(9 downto 0) := (others => '0');
    signal ev_to_add         : unsigned(9 downto 0) := (others => '0');

    signal mult_a : unsigned(15 downto 0) := (others=>'0');
    signal mult_b : unsigned(15 downto 0) := (others=>'0');
    signal mult_p : unsigned(31 downto 0);

    signal div_q : unsigned(15 downto 0);
    signal div_r : unsigned(15 downto 0);

    signal i : integer range 0 to MAX_STATES := 0;

    signal max_rem : unsigned(15 downto 0) := (others=>'0');
    signal winner  : integer range 0 to MAX_STATES-1 := 0;

    -------------------------------------------------
    -- FSM
    -------------------------------------------------

    type state_t is (
        IDLE,
        SUM_POP,
        CALC_BASE,
        FIND_MAX_REM,
        ADD_EV,
        FINISH
    );

    signal current_state : state_t := IDLE;

begin

-------------------------------------------------
-- Store population
-------------------------------------------------

process(clk)
begin
    if rising_edge(clk) then
        if pop_write = '1' then
            population_array(pop_index) <= pop_data;
        end if;
    end if;
end process;

-------------------------------------------------
-- Multiplier
-------------------------------------------------

mult_p <= resize(mult_a,32) * resize(mult_b,32);

-------------------------------------------------
-- Divider
-------------------------------------------------

div_q <= mult_p / population_total(15 downto 0) when population_total /= 0 else (others=>'0');

div_r <= mult_p mod population_total(15 downto 0) when population_total /= 0 else (others=>'0');

-------------------------------------------------
-- Main FSM
-------------------------------------------------

process(clk, rst)
begin

    if rst='1' then

        current_state <= IDLE;
        done <= '0';

        i <= 0;
        population_total <= (others=>'0');

        total_ev_assigned <= (others=>'0');
        ev_to_add <= (others=>'0');

        max_rem <= (others=>'0');
        winner <= 0;

    elsif rising_edge(clk) then

        case current_state is

        -------------------------------------------------
        when IDLE =>

            done <= '0';

            if start='1' then

                i <= 0;
                population_total <= (others=>'0');
                total_ev_assigned <= (others=>'0');

                current_state <= SUM_POP;

            end if;

        -------------------------------------------------
        -- SUM POPULATION
        -------------------------------------------------

        when SUM_POP =>

            if i < to_integer(state_count) then

                population_total <= population_total +
                    resize(population_array(i),32);

                i <= i + 1;

            else

                i <= 0;
                current_state <= CALC_BASE;

            end if;

        -------------------------------------------------
        -- CALCULATE BASE EV
        -------------------------------------------------

        when CALC_BASE =>

            if i < to_integer(state_count) then

                mult_a <= resize(population_array(i),16);
                mult_b <= resize(ev_total,16);

                base_ev_array(i) <= resize(div_q,10);
                remainder_array(i) <= div_r;

                total_ev_assigned <= total_ev_assigned +
                    resize(div_q,10);

                i <= i + 1;

            else

                ev_to_add <= ev_total - total_ev_assigned;

                current_state <= FIND_MAX_REM;

            end if;

        -------------------------------------------------
        -- FIND MAX REMAINDER
        -------------------------------------------------

        when FIND_MAX_REM =>

            if ev_to_add > 0 then

                max_rem <= (others=>'0');

                for k in 0 to MAX_STATES-1 loop

                    if k < to_integer(state_count) then

                        if remainder_array(k) > max_rem then
                            max_rem <= remainder_array(k);
                            winner <= k;
                        end if;

                    end if;

                end loop;

                current_state <= ADD_EV;

            else

                current_state <= FINISH;

            end if;

        -------------------------------------------------
        -- ADD EV
        -------------------------------------------------

        when ADD_EV =>

            base_ev_array(winner) <= base_ev_array(winner) + 1;

            remainder_array(winner) <= (others=>'0');

            ev_to_add <= ev_to_add - 1;

            current_state <= FIND_MAX_REM;

        -------------------------------------------------
        -- FINISH
        -------------------------------------------------

        when FINISH =>

            done <= '1';

            if start='0' then
                current_state <= IDLE;
            end if;

        when others =>
            current_state <= IDLE;

        end case;

    end if;

end process;

end behavioral;
