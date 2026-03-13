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
        ev_query_index   : in  integer range 0 to 998;
        ev_result_out    : out std_logic_vector(9 downto 0);
        population_total_out : out unsigned(31 downto 0)
    );
end ev_allocator;

architecture behavioral of ev_allocator is
    
    constant MAX_STATES : integer := 999;

    type pop_array_t is array (0 to MAX_STATES-1) of unsigned(9 downto 0);
    signal population_array : pop_array_t := (others => (others => '0'));

    type ev_array_t is array (0 to MAX_STATES-1) of unsigned(9 downto 0);
    signal base_ev_array : ev_array_t := (others => (others => '0'));

    type rem_array_t is array (0 to MAX_STATES-1) of unsigned(15 downto 0);
    signal remainder_array : rem_array_t := (others => (others => '0'));

    signal population_total   : unsigned(31 downto 0) := (others => '0');
    signal total_ev_assigned  : unsigned(9 downto 0)  := (others => '0');
    signal ev_to_add          : unsigned(9 downto 0)  := (others => '0');

    signal mult_a : unsigned(15 downto 0) := (others => '0');
    signal mult_b : unsigned(15 downto 0) := (others => '0');
    signal mult_p : unsigned(31 downto 0);

    signal div_q  : unsigned(15 downto 0);
    signal div_r  : unsigned(15 downto 0);

    signal i      : integer range 0 to MAX_STATES := 0;
    signal winner : integer range 0 to MAX_STATES-1 := 0;
    signal max_rem : unsigned(15 downto 0) := (others => '0');

    type state_t is (
        IDLE,
        SUM_POP,
        CALC_BASE,
        WAIT_CALC,
        FIND_MAX_REM,
        FIND_NEXT,
        ADD_EV,
        FINISH
    );

    signal current_state : state_t := IDLE;

begin
    ev_result_out        <= std_logic_vector(base_ev_array(ev_query_index));
    population_total_out <= population_total;
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
    -- Combinational Multiplier
    -------------------------------------------------
    mult_p <= resize(mult_a, 32) * resize(mult_b, 32);

    -------------------------------------------------
    -- Combinational Divider (แก้: ใช้ population_total เต็ม 32-bit)
    -------------------------------------------------
    div_q <= resize(mult_p / population_total, 16) when population_total /= 0 else (others => '0');
    div_r <= resize(mult_p mod population_total, 16) when population_total /= 0 else (others => '0');

    -------------------------------------------------
    -- Main FSM
    -------------------------------------------------
    process(clk, rst)
 
    begin

        if rst = '1' then
            current_state    <= IDLE;
            done             <= '0';
            i                <= 0;
            population_total <= (others => '0');
            total_ev_assigned <= (others => '0');
            ev_to_add        <= (others => '0');
            winner           <= 0;
            max_rem          <= (others => '0');

        elsif rising_edge(clk) then

            case current_state is

                -------------------------------------------------
                when IDLE =>
                    done <= '0';
                    if start = '1' then
                        i                 <= 0;
                        population_total  <= (others => '0');
                        total_ev_assigned <= (others => '0');
                        current_state     <= SUM_POP;
                    end if;

                -------------------------------------------------
                -- SUM POPULATION
                -------------------------------------------------
                when SUM_POP =>
                    if i < to_integer(state_count) then
                        population_total <= population_total +
                                            resize(population_array(i), 32);
                        i <= i + 1;
                    else
                        i             <= 0;
                        current_state <= CALC_BASE;
                    end if;

                -------------------------------------------------
                -- CALCULATE BASE EV: ตั้งค่า input multiplier
                -------------------------------------------------
                when CALC_BASE =>
                    if i < to_integer(state_count) then
                        mult_a        <= resize(population_array(i), 16);
                        mult_b        <= resize(ev_total, 16);
                        current_state <= WAIT_CALC;
                    else
                        ev_to_add     <= ev_total - total_ev_assigned;
                        current_state <= FIND_MAX_REM;
                    end if;

                -------------------------------------------------
                -- WAIT_CALC: รอ 1 clock ให้ mult_p, div_q, div_r settle
                -------------------------------------------------
                when WAIT_CALC =>
                    base_ev_array(i)   <= resize(div_q, 10);
                    remainder_array(i) <= div_r;
                    total_ev_assigned  <= total_ev_assigned + resize(div_q, 10);
                    i                  <= i + 1;
                    current_state      <= CALC_BASE;

                -------------------------------------------------
                -- FIND MAX REMAINDER (แก้: ใช้ variable)
                -------------------------------------------------
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
                    if i < to_integer(state_count) then
                        if remainder_array(i) > max_rem then
                            max_rem <= remainder_array(i);
                            winner  <= i;
                        end if;
                        i <= i + 1;
                    else
                        current_state <= ADD_EV;
                    end if;

                -------------------------------------------------
                -- ADD EV
                -------------------------------------------------
                when ADD_EV =>
                    base_ev_array(winner)   <= base_ev_array(winner) + 1;
                    remainder_array(winner) <= (others => '0');
                    ev_to_add               <= ev_to_add - 1;
                    current_state           <= FIND_MAX_REM;

                -------------------------------------------------
                -- FINISH
                -------------------------------------------------
                when FINISH =>
                    done <= '1';
                    if start = '0' then
                        current_state <= IDLE;
                    end if;

                when others =>
                    current_state <= IDLE;

            end case;
        end if;
    end process;

end behavioral;
