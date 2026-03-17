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
        pop_index : in integer range 0 to 998;
        pop_write : in std_logic;

        done : out std_logic;

        ev_query_index       : in  integer range 0 to 998;
        ev_result_out        : out std_logic_vector(9 downto 0);
        population_total_out : out unsigned(31 downto 0);
        pop_query_index      : in  integer range 0 to 998;
        pop_result_out       : out std_logic_vector(9 downto 0)
    );
end ev_allocator;

architecture behavioral of ev_allocator is

    constant MAX_STATES : integer := 999;

    type pop_array_t is array (0 to MAX_STATES-1) of unsigned(9 downto 0);
    signal population_array : pop_array_t := (others => (others => '0'));

    type ev_array_t is array (0 to MAX_STATES-1) of unsigned(9 downto 0);
    signal base_ev_array : ev_array_t := (others => (others => '0'));

    type rem_array_t is array (0 to MAX_STATES-1) of unsigned(31 downto 0);
    signal remainder_array : rem_array_t := (others => (others => '0'));

    signal state_count_reg : unsigned(9 downto 0) := (others => '0');
    signal ev_total_reg    : unsigned(9 downto 0)  := (others => '0');

    signal population_total   : unsigned(31 downto 0) := (others => '0');
    signal total_ev_assigned  : unsigned(9 downto 0)  := (others => '0');
    signal ev_to_add          : unsigned(9 downto 0)  := (others => '0');

    -- Divider interface
    signal div_dividend : unsigned(31 downto 0) := (others => '0');
    signal div_divisor  : unsigned(31 downto 0) := (others => '0');
    signal div_start    : std_logic := '0';
    signal div_done     : std_logic := '0';
    signal div_result_q : unsigned(31 downto 0) := (others => '0');
    signal div_result_r : unsigned(31 downto 0) := (others => '0');

    -- Divider internals
    -- acc: upper 32 = remainder accumulator, lower 32 = quotient being built
    signal div_acc     : unsigned(63 downto 0) := (others => '0');
    signal div_reg_b   : unsigned(31 downto 0) := (others => '0');
    signal div_counter : integer range 0 to 32 := 0;

    signal i       : integer range 0 to MAX_STATES := 0;
    signal winner  : integer range 0 to MAX_STATES-1 := 0;
    signal max_rem : unsigned(31 downto 0) := (others => '0');
    signal done_reg : std_logic := '0';

    type state_t is (
        IDLE, SUM_POP, CALC_BASE,
        WAIT_DIV, STORE_BASE,
        FIND_MAX_REM, FIND_NEXT, ADD_EV, FINISH
    );
    signal current_state : state_t := IDLE;

begin

    done                 <= done_reg;
    ev_result_out        <= std_logic_vector(base_ev_array(ev_query_index));
    population_total_out <= population_total;
    pop_result_out       <= std_logic_vector(population_array(pop_query_index));

    -------------------------------------------------
    -- Population Write Port
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
    -- Sequential Restoring Divider (32-bit / 32-bit)
    --
    -- Algorithm (standard restoring):
    --   acc = { 0[32], dividend[32] }  (64-bit)
    --   repeat 32 times:
    --     acc = shift_left(acc, 1)
    --     if acc[63:32] >= divisor then
    --         acc[63:32] -= divisor
    --         acc[0] = 1
    -- After 32 iterations:
    --   quotient  = acc[31:0]
    --   remainder = acc[63:32]
    -------------------------------------------------
    process(clk, rst)
        variable v_acc  : unsigned(63 downto 0);
        variable v_upper: unsigned(31 downto 0);
    begin
        if rst = '1' then
            div_done     <= '0';
            div_counter  <= 0;
            div_result_q <= (others => '0');
            div_result_r <= (others => '0');
            div_acc      <= (others => '0');
            div_reg_b    <= (others => '0');

        elsif rising_edge(clk) then
            div_done <= '0';

            if div_start = '1' then
                -- Load: lower 32 = dividend, upper 32 = 0
                div_acc     <= resize(div_dividend, 64);  -- upper=0, lower=dividend
                div_reg_b   <= div_divisor;
                div_counter <= 32;

            elsif div_counter > 0 then
                -- Step: shift left 1 bit
                v_acc  := shift_left(div_acc, 1);
                v_upper := v_acc(63 downto 32);

                -- Try subtract
                if v_upper >= div_reg_b then
                    v_upper := v_upper - div_reg_b;
                    v_acc(0) := '1';
                end if;

                v_acc(63 downto 32) := v_upper;
                div_acc     <= v_acc;
                div_counter <= div_counter - 1;

                if div_counter = 1 then
                    div_result_q <= v_acc(31 downto 0);
                    div_result_r <= v_upper;
                    div_done     <= '1';
                end if;
            end if;
        end if;
    end process;

    -------------------------------------------------
    -- Main FSM
    -------------------------------------------------
    process(clk, rst)
        variable safe_q : unsigned(9 downto 0);
    begin
        if rst = '1' then
            current_state     <= IDLE;
            done_reg          <= '0';
            div_start         <= '0';
            i                 <= 0;
            population_total  <= (others => '0');
            total_ev_assigned <= (others => '0');
            ev_to_add         <= (others => '0');
            winner            <= 0;
            max_rem           <= (others => '0');
            state_count_reg   <= (others => '0');
            ev_total_reg      <= (others => '0');

        elsif rising_edge(clk) then
            div_start <= '0';

            case current_state is

                when IDLE =>
                    done_reg <= '0';
                    if start = '1' then
                        state_count_reg   <= state_count;
                        ev_total_reg      <= ev_total;
                        i                 <= 0;
                        population_total  <= (others => '0');
                        total_ev_assigned <= (others => '0');
                        current_state     <= SUM_POP;
                    end if;

                when SUM_POP =>
                    if i < to_integer(state_count_reg) then
                        population_total <= population_total +
                                            resize(population_array(i), 32);
                        i <= i + 1;
                    else
                        i             <= 0;
                        current_state <= CALC_BASE;
                    end if;

                when CALC_BASE =>
                    if i < to_integer(state_count_reg) then
                        -- dividend = pop[i] * ev_total (max 1023*1023 = ~1M, fits in 32-bit)
                        
                        div_dividend  <= resize(
                    resize(population_array(i), 32) *
                    resize(ev_total_reg, 32),
                 32);
                        div_divisor   <= population_total;
                        div_start     <= '1';
                        current_state <= WAIT_DIV;
                    else
                        ev_to_add     <= ev_total_reg - total_ev_assigned;
                        current_state <= FIND_MAX_REM;
                    end if;

                when WAIT_DIV =>
                    if div_done = '1' then
                        current_state <= STORE_BASE;
                    end if;

                when STORE_BASE =>
                    if div_result_q > 1023 then
                        safe_q := (others => '1');
                    else
                        safe_q := resize(div_result_q, 10);
                    end if;
                    base_ev_array(i)   <= safe_q;
                    remainder_array(i) <= div_result_r;
                    total_ev_assigned  <= total_ev_assigned + safe_q;
                    i                  <= i + 1;
                    current_state      <= CALC_BASE;

                when FIND_MAX_REM =>
                    if ev_to_add > 0 then
                        max_rem <= (others => '0');
                        winner  <= 0;
                        i       <= 0;
                        current_state <= FIND_NEXT;
                    else
                        current_state <= FINISH;
                    end if;

                when FIND_NEXT =>
                    if i < to_integer(state_count_reg) then
                        if remainder_array(i) > max_rem then
                            max_rem <= remainder_array(i);
                            winner  <= i;
                        end if;
                        i <= i + 1;
                    else
                        current_state <= ADD_EV;
                    end if;

                when ADD_EV =>
                    if base_ev_array(winner) < 1023 then
                        base_ev_array(winner) <= base_ev_array(winner) + 1;
                    end if;
                    remainder_array(winner) <= (others => '0');
                    ev_to_add               <= ev_to_add - 1;
                    current_state           <= FIND_MAX_REM;

                when FINISH =>
                    done_reg <= '1';
                    if start = '0' then
                        current_state <= IDLE;
                    end if;

                when others =>
                    current_state <= IDLE;

            end case;
        end if;
    end process;

end behavioral;
    end process;

end behavioral;
