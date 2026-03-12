library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity config_controller is
    Port (
        clk : in std_logic;
        rst : in std_logic;

        start : in std_logic;

        -- input data
        state_population : in unsigned(31 downto 0);
        population_total : in unsigned(31 downto 0);

        total_EV : in unsigned(31 downto 0);

        -- multiplier interface
        mul_start : out std_logic;
        mul_done  : in  std_logic;

        -- divider interface
        div_start : out std_logic;
        div_done  : in  std_logic;

        -- result
        done : out std_logic
    );
end config_controller;

architecture behavioral of config_controller is

    type state_type is (
        IDLE,
        START_MUL,
        WAIT_MUL,
        START_DIV,
        WAIT_DIV,
        FINISH
    );

    signal state_reg : state_type := IDLE;
    signal state_next : state_type;

    signal mul_start_reg : std_logic := '0';
    signal div_start_reg : std_logic := '0';
    signal done_reg      : std_logic := '0';

begin

    ------------------------------------------------
    -- STATE REGISTER
    ------------------------------------------------
    process(clk, rst)
    begin
        if rst = '1' then
            state_reg <= IDLE;

        elsif rising_edge(clk) then
            state_reg <= state_next;
        end if;
    end process;

    ------------------------------------------------
    -- NEXT STATE LOGIC
    ------------------------------------------------
    process(state_reg, start, mul_done, div_done)
    begin

        state_next <= state_reg;

        case state_reg is

            when IDLE =>
                if start = '1' then
                    state_next <= START_MUL;
                end if;

            when START_MUL =>
                state_next <= WAIT_MUL;

            when WAIT_MUL =>
                if mul_done = '1' then
                    state_next <= START_DIV;
                end if;

            when START_DIV =>
                state_next <= WAIT_DIV;

            when WAIT_DIV =>
                if div_done = '1' then
                    state_next <= FINISH;
                end if;

            when FINISH =>
                state_next <= IDLE;

            when others =>
                state_next <= IDLE;

        end case;

    end process;

    ------------------------------------------------
    -- OUTPUT LOGIC
    ------------------------------------------------
    process(state_reg)
    begin

        mul_start_reg <= '0';
        div_start_reg <= '0';
        done_reg      <= '0';

        case state_reg is

            when IDLE =>
                null;

            when START_MUL =>
                mul_start_reg <= '1';

            when WAIT_MUL =>
                null;

            when START_DIV =>
                div_start_reg <= '1';

            when WAIT_DIV =>
                null;

            when FINISH =>
                done_reg <= '1';

            when others =>
                null;

        end case;

    end process;

    mul_start <= mul_start_reg;
    div_start <= div_start_reg;
    done      <= done_reg;

end behavioral;
