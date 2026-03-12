----------------------------------------------------------------------------------
-- Module Name:   admin_controller
-- Project Name:  Advanced Electronic Voting System (Nexys A7)
--
-- Description:
--   Handles all logic for ADMIN MODE stages A1 through A6.
--   This module does NOT have its own FSM state machine.
--   It receives state_out from main_fsm and executes logic
--   based on the current stage encoding.
--
-- State Encoding (from main_fsm):
--   A1 = "00100001"  ADMIN LOGIN
--   A2 = "00100010"  ADMIN HOME
--   A3 = "00100011"  VIEW STATE POPULAR VOTE
--   A4 = "00100100"  VIEW ELECTORAL TOTAL
--   A5 = "00100101"  DECLARE WINNER
--   A6 = "00100110"  RESET SYSTEM
--
-- Signal Sources:
--   state_in        ← main_fsm.vhd       state_out(7 downto 0)
--   digit_value     ← digit_input.vhd    val_out(9 downto 0)
--   digit_confirmed ← digit_input.vhd    confirmed
--   btn_*           ← button_controller.vhd (debounced + edge detected)
--   total_ev_c1/c2  ← state_analyzer.vhd total_ev_c1 / total_ev_c2
--   pending_ev      ← state_analyzer.vhd pending_ev_pool
--   national_pop_*  ← top.vhd accumulated national popular vote counters
--   ev_total        ← main_fsm.vhd ev_total_out(9 downto 0)
--   state_count     ← main_fsm.vhd state_count_out(9 downto 0)
--   pop_c1/c2_s0..7 ← top.vhd per-state vote counters (flat port)
--
-- Signal Destinations:
--   disp_digit_0/1/2 → sevenseg_driver.vhd digit_0/1/2
--   disp_msg_sel     → sevenseg_driver.vhd msg_sel
--   disp_index       → sevenseg_driver.vhd index_digit
--   rst_out          → top.vhd global reset trigger after A6 confirm
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity admin_controller is
    Generic (
        CLK_FREQ : integer := 100_000_000  -- 100 MHz Nexys A7
    );
    Port (
        ----------------------------------------------------------------
        -- CLOCK & RESET
        ----------------------------------------------------------------
        clk             : in  std_logic;
        rst             : in  std_logic;

        ----------------------------------------------------------------
        -- FSM STATE INPUT
        -- state_in : current stage from main_fsm.vhd state_out(7 downto 0)
        ----------------------------------------------------------------
        state_in        : in  std_logic_vector(7 downto 0);

        ----------------------------------------------------------------
        -- DIGIT INPUT
        -- digit_value     : 10-bit (0-999) from digit_input.vhd val_out
        -- digit_confirmed : 1-cycle pulse from digit_input.vhd confirmed
        ----------------------------------------------------------------
        digit_value     : in  unsigned(9 downto 0);
        digit_confirmed : in  std_logic;

        ----------------------------------------------------------------
        -- BUTTON INPUTS
        -- Source: button_controller.vhd btn_out (debounced + edge detected)
        ----------------------------------------------------------------
        btn_left        : in  std_logic;
        btn_right       : in  std_logic;
        btn_up          : in  std_logic;
        btn_down        : in  std_logic;
        btn_center      : in  std_logic;

        ----------------------------------------------------------------
        -- ELECTORAL VOTE TOTALS
        -- Source: state_analyzer.vhd
        ----------------------------------------------------------------
        total_ev_c1     : in  unsigned(15 downto 0);
        total_ev_c2     : in  unsigned(15 downto 0);
        pending_ev      : in  unsigned(7 downto 0);

        ----------------------------------------------------------------
        -- NATIONAL POPULAR VOTE
        -- Source: accumulated counters in top.vhd
        ----------------------------------------------------------------
        national_pop_c1 : in  unsigned(31 downto 0);
        national_pop_c2 : in  unsigned(31 downto 0);

        ----------------------------------------------------------------
        -- CONFIGURATION VALUES
        -- Source: main_fsm.vhd output ports
        -- ev_total    : from ev_total_out(9 downto 0)
        -- state_count : from state_count_out(9 downto 0)
        ----------------------------------------------------------------
        ev_total        : in  unsigned(9 downto 0);
        state_count     : in  unsigned(9 downto 0);

        ----------------------------------------------------------------
        -- POPULAR VOTE PER STATE (FLAT PORT, MAX 8 STATES)
        -- Source: vote counters in top.vhd updated during U5
        -- Used in A3 to display per-state popular vote
        ----------------------------------------------------------------
        pop_c1_s0 : in unsigned(15 downto 0);
        pop_c1_s1 : in unsigned(15 downto 0);
        pop_c1_s2 : in unsigned(15 downto 0);
        pop_c1_s3 : in unsigned(15 downto 0);
        pop_c1_s4 : in unsigned(15 downto 0);
        pop_c1_s5 : in unsigned(15 downto 0);
        pop_c1_s6 : in unsigned(15 downto 0);
        pop_c1_s7 : in unsigned(15 downto 0);

        pop_c2_s0 : in unsigned(15 downto 0);
        pop_c2_s1 : in unsigned(15 downto 0);
        pop_c2_s2 : in unsigned(15 downto 0);
        pop_c2_s3 : in unsigned(15 downto 0);
        pop_c2_s4 : in unsigned(15 downto 0);
        pop_c2_s5 : in unsigned(15 downto 0);
        pop_c2_s6 : in unsigned(15 downto 0);
        pop_c2_s7 : in unsigned(15 downto 0);

        ----------------------------------------------------------------
        -- DISPLAY OUTPUTS → sevenseg_driver.vhd
        ----------------------------------------------------------------
        disp_digit_0    : out std_logic_vector(3 downto 0);
        disp_digit_1    : out std_logic_vector(3 downto 0);
        disp_digit_2    : out std_logic_vector(3 downto 0);
        disp_msg_sel    : out std_logic_vector(3 downto 0);
        disp_index      : out std_logic_vector(9 downto 0);

        ----------------------------------------------------------------
        -- RESET OUTPUT → top.vhd
        -- Pulses '1' for one cycle after A6 double confirmation
        ----------------------------------------------------------------
        rst_out         : out std_logic
    );
end admin_controller;

architecture behavioral of admin_controller is

    ----------------------------------------------------------------
    -- CONSTANTS
    ----------------------------------------------------------------
    constant ADMIN_PASSWORD : unsigned(9 downto 0) := to_unsigned(123, 10);
    constant LOCK_MAX       : integer := CLK_FREQ * 10;  -- 10 seconds
    constant ERROR_MAX      : integer := CLK_FREQ;       -- 1 second

    ----------------------------------------------------------------
    -- A1 LOGIN SIGNALS
    -- fail_count   : wrong attempts counter (max 3 before lock)
    -- lock_counter : dual-purpose timer for error display and lock
    -- locked       : '1' while system is locked
    -- show_error   : '1' while showing ERR after wrong password
    ----------------------------------------------------------------
    signal fail_count   : integer range 0 to 3       := 0;
    signal lock_counter : integer range 0 to LOCK_MAX := 0;
    signal locked       : std_logic := '0';
    signal show_error   : std_logic := '0';

    ----------------------------------------------------------------
    -- BROWSE INDEX
    -- view_index : current browse position in A3 (states) or A4 (candidates)
    -- Resets to 0 whenever FSM enters a new stage
    ----------------------------------------------------------------
    signal view_index   : integer range 0 to 7 := 0;

    ----------------------------------------------------------------
    -- A6 RESET CONFIRMATION FLAG
    -- reset_confirm : '1' after first btn_down in A6
    --                 requires second btn_down to execute reset
    ----------------------------------------------------------------
    signal reset_confirm : std_logic := '0';

    ----------------------------------------------------------------
    -- DISPLAY VALUE REGISTER
    -- Holds the value to be split into BCD digits for sevenseg_driver
    ----------------------------------------------------------------
    signal display_val  : unsigned(15 downto 0) := (others => '0');

    ----------------------------------------------------------------
    -- PREVIOUS STATE REGISTER
    -- Used to detect FSM stage transitions so flags can be reset
    -- on entry to each new stage
    ----------------------------------------------------------------
    signal prev_state   : std_logic_vector(7 downto 0) := (others => '0');

begin

    process(clk, rst)

        variable v_ev_c1    : unsigned(15 downto 0);
        variable v_ev_c2    : unsigned(15 downto 0);
        variable v_majority : unsigned(15 downto 0);

    begin
        if rst = '1' then
            fail_count    <= 0;
            lock_counter  <= 0;
            locked        <= '0';
            show_error    <= '0';
            view_index    <= 0;
            reset_confirm <= '0';
            display_val   <= (others => '0');
            prev_state    <= (others => '0');
            rst_out       <= '0';
            disp_msg_sel  <= "0000";
            disp_index    <= (others => '0');

        elsif rising_edge(clk) then

            rst_out <= '0'; -- default: no reset pulse

            -- Reset view_index and reset_confirm on every stage transition
            if state_in /= prev_state then
                view_index    <= 0;
                reset_confirm <= '0';
            end if;
            prev_state <= state_in;

            case state_in is

                ----------------------------------------------------
                -- A1 : ADMIN LOGIN
                -- Display : "0000" numeric input (wait for password)
                --           "0010" ERROR (wrong password or locked)
                --
                -- If locked:
                --   Count down lock_counter until 0, then unlock
                --
                -- If show_error (wrong password, not yet locked):
                --   Count down lock_counter (ERROR_MAX = 1 second)
                --   Then return to normal input
                --
                -- If normal:
                --   Wait for digit_confirmed pulse
                --   Match digit_value against ADMIN_PASSWORD
                --   Correct → clear fail_count (FSM moves to A2 via btn_center)
                --   Wrong   → increment fail_count
                --             3rd failure → lock (LOCK_MAX = 10 seconds)
                --             else        → show error for 1 second
                ----------------------------------------------------
                when "00100001" =>

                    if locked = '1' then
                        disp_msg_sel <= "0010";
                        if lock_counter > 0 then
                            lock_counter <= lock_counter - 1;
                        else
                            locked       <= '0';
                            fail_count   <= 0;
                            disp_msg_sel <= "0000";
                        end if;

                    elsif show_error = '1' then
                        disp_msg_sel <= "0010";
                        if lock_counter > 0 then
                            lock_counter <= lock_counter - 1;
                        else
                            show_error   <= '0';
                            disp_msg_sel <= "0000";
                        end if;

                    else
                        disp_msg_sel <= "0000";

                        if digit_confirmed = '1' then
                            if digit_value = ADMIN_PASSWORD then
                                -- Correct: FSM handles transition to A2
                                fail_count <= 0;
                            else
                                -- Wrong password
                                if fail_count + 1 >= 3 then
                                    locked       <= '1';
                                    lock_counter <= LOCK_MAX;
                                else
                                    fail_count   <= fail_count + 1;
                                    show_error   <= '1';
                                    lock_counter <= ERROR_MAX;
                                end if;
                            end if;
                        end if;
                    end if;

                ----------------------------------------------------
                -- A2 : ADMIN HOME
                -- Display: "0001" (READY pattern used as home label)
                -- Navigation to A3/A4/A5/A6 handled entirely by main_fsm
                ----------------------------------------------------
                when "00100010" =>
                    disp_msg_sel <= "0001";
                    display_val  <= (others => '0');

                ----------------------------------------------------
                -- A3 : VIEW STATE POPULAR VOTE
                -- Display: "1000" = S[index] [value]
                -- disp_index = view_index (state number shown on left)
                -- display_val = C1 popular vote of selected state
                --
                -- btn_right : view_index + 1 (up to state_count - 1)
                -- btn_left  : view_index - 1 (down to 0)
                -- btn_center: back to A2 (handled by main_fsm)
                --
                -- Flat port to array lookup:
                --   view_index 0 → pop_c1_s0 ... view_index 7 → pop_c1_s7
                ----------------------------------------------------
                when "00100011" =>
                    disp_msg_sel <= "1000";
                    disp_index   <= std_logic_vector(to_unsigned(view_index, 10));

                    case view_index is
                        when 0 => display_val <= pop_c1_s0;
                        when 1 => display_val <= pop_c1_s1;
                        when 2 => display_val <= pop_c1_s2;
                        when 3 => display_val <= pop_c1_s3;
                        when 4 => display_val <= pop_c1_s4;
                        when 5 => display_val <= pop_c1_s5;
                        when 6 => display_val <= pop_c1_s6;
                        when 7 => display_val <= pop_c1_s7;
                        when others => display_val <= (others => '0');
                    end case;

                    if btn_right = '1' then
                        if view_index < to_integer(state_count) - 1 then
                            view_index <= view_index + 1;
                        end if;
                    elsif btn_left = '1' then
                        if view_index > 0 then
                            view_index <= view_index - 1;
                        end if;
                    end if;

                ----------------------------------------------------
                -- A4 : VIEW ELECTORAL VOTE TOTAL
                -- Display: "1000" = C[1 or 2] [EV total]
                -- view_index = 0 → Candidate 1 (disp_index = 1)
                -- view_index = 1 → Candidate 2 (disp_index = 2)
                -- Source: total_ev_c1 / total_ev_c2 from state_analyzer.vhd
                --
                -- btn_right : switch to C2
                -- btn_left  : switch back to C1
                -- btn_center: back to A2 (handled by main_fsm)
                ----------------------------------------------------
                when "00100100" =>
                    disp_msg_sel <= "1000";

                    if view_index = 0 then
                        disp_index  <= std_logic_vector(to_unsigned(1, 10));
                        display_val <= total_ev_c1;
                    else
                        disp_index  <= std_logic_vector(to_unsigned(2, 10));
                        display_val <= total_ev_c2;
                    end if;

                    if btn_right = '1' and view_index = 0 then
                        view_index <= 1;
                    elsif btn_left = '1' and view_index = 1 then
                        view_index <= 0;
                    end if;

                ----------------------------------------------------
                -- A5 : DECLARE WINNER
                -- Step 1: Resolve pending_ev using national popular vote
                --   pending_ev source : state_analyzer.vhd pending_ev_pool
                --   national_pop source: top.vhd running accumulators
                --
                -- Step 2: Compute majority = (ev_total / 2) + 1
                --   ev_total source: main_fsm.vhd ev_total_out
                --
                -- Step 3: Set display based on result
                --   C1 wins  → "0100" toP, disp_index = 1
                --   C2 wins  → "0100" toP, disp_index = 2
                --   Tie      → "0110" tIE
                --   No maj   → "0111" no
                --
                -- btn_center: back to A2 (handled by main_fsm)
                ----------------------------------------------------
                when "00100101" =>

                    v_ev_c1 := total_ev_c1;
                    v_ev_c2 := total_ev_c2;

                    -- Resolve pending EV pool
                    if pending_ev > 0 then
                        if national_pop_c1 > national_pop_c2 then
                            v_ev_c1 := v_ev_c1 + pending_ev;
                        elsif national_pop_c2 > national_pop_c1 then
                            v_ev_c2 := v_ev_c2 + pending_ev;
                        else
                            -- National tie: split evenly, discard odd remainder
                            v_ev_c1 := v_ev_c1 + (pending_ev srl 1);
                            v_ev_c2 := v_ev_c2 + (pending_ev srl 1);
                        end if;
                    end if;

                    -- Compute majority threshold
                    v_majority := resize(ev_total, 16) / 2 + 1;

                    -- Determine and display result
                    if v_ev_c1 = v_ev_c2 then
                        disp_msg_sel <= "0110"; -- tIE
                        disp_index   <= (others => '0');
                        display_val  <= v_ev_c1;

                    elsif v_ev_c1 >= v_majority then
                        disp_msg_sel <= "0100"; -- toP C1 wins
                        disp_index   <= std_logic_vector(to_unsigned(1, 10));
                        display_val  <= v_ev_c1;

                    elsif v_ev_c2 >= v_majority then
                        disp_msg_sel <= "0100"; -- toP C2 wins
                        disp_index   <= std_logic_vector(to_unsigned(2, 10));
                        display_val  <= v_ev_c2;

                    else
                        disp_msg_sel <= "0111"; -- no majority
                        disp_index   <= (others => '0');
                        display_val  <= (others => '0');
                    end if;

                ----------------------------------------------------
                -- A6 : RESET SYSTEM (two-step confirmation)
                -- Display: "0010" ERROR/warning pattern throughout
                --
                -- reset_confirm = '0' (first press pending):
                --   btn_down → set reset_confirm = '1'
                --
                -- reset_confirm = '1' (waiting for second press):
                --   btn_down   → pulse rst_out = '1' for one cycle
                --                top.vhd drives global rst from this signal
                --   btn_center → cancel, clear reset_confirm
                --                FSM returns to A2
                ----------------------------------------------------
                when "00100110" =>
                    disp_msg_sel <= "0010";

                    if reset_confirm = '0' then
                        if btn_down = '1' then
                            reset_confirm <= '1';
                        end if;
                    else
                        if btn_down = '1' then
                            rst_out       <= '1'; -- pulse global reset
                            reset_confirm <= '0';
                        elsif btn_center = '1' then
                            reset_confirm <= '0'; -- cancel
                        end if;
                    end if;

                ----------------------------------------------------
                -- OTHER STAGES (C or U modes)
                -- Clear admin-specific flags when not in admin mode
                ----------------------------------------------------
                when others =>
                    disp_msg_sel  <= "0000";
                    reset_confirm <= '0';
                    show_error    <= '0';

            end case;

        end if;
    end process;

    ----------------------------------------------------------------
    -- COMBINATIONAL: Split display_val into 3 BCD digits
    -- disp_digit_0 : ones     → sevenseg_driver digit_0
    -- disp_digit_1 : tens     → sevenseg_driver digit_1
    -- disp_digit_2 : hundreds → sevenseg_driver digit_2
    -- Max displayable range: 0-999
    ----------------------------------------------------------------
    disp_digit_0 <= std_logic_vector(
                        to_unsigned(to_integer(display_val) mod 10, 4));
    disp_digit_1 <= std_logic_vector(
                        to_unsigned((to_integer(display_val) / 10) mod 10, 4));
    disp_digit_2 <= std_logic_vector(
                        to_unsigned((to_integer(display_val) / 100) mod 10, 4));

end behavioral;