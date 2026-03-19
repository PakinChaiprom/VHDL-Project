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

-- state_analyzer.vhd (แก้ใหม่ทั้งหมด)
entity state_analyzer is
    Port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        start_analysis  : in  std_logic;

        -- ใหม่: รับ state_count เพื่อรู้ว่าต้องวนกี่รอบ
        state_count     : in  unsigned(9 downto 0);

        -- ใหม่: query interface ดึงข้อมูลทีละ state
        query_index     : out integer range 0 to 49;   -- บอก top.vhd ว่าต้องการ state ไหน
        pop_c1_in       : in  unsigned(15 downto 0);   -- top.vhd ส่ง vote_c1(query_index) มา
        pop_c2_in       : in  unsigned(15 downto 0);
        ev_value_in     : in  unsigned(9 downto 0);    -- top.vhd ส่ง ev_result(query_index) มา

        national_pop_c1 : in  unsigned(31 downto 0);
        national_pop_c2 : in  unsigned(31 downto 0);

        total_ev_c1     : out unsigned(15 downto 0);
        total_ev_c2     : out unsigned(15 downto 0);
        pending_ev_pool : out unsigned(7 downto 0);
        done_analysis   : out std_logic
    );
end state_analyzer;

architecture behavioral of state_analyzer is

    type fsm_t is (IDLE, PROCESS_STATE, NEXT_STATE, DONE_ST);
    signal state     : fsm_t := IDLE;
    signal cur_idx   : integer range 0 to 49 := 0;
    signal ev_acc_c1 : unsigned(15 downto 0) := (others => '0');
    signal ev_acc_c2 : unsigned(15 downto 0) := (others => '0');
    signal pending_ev : unsigned(7 downto 0) := (others => '0');

begin
    query_index     <= cur_idx;
    total_ev_c1     <= ev_acc_c1;
    total_ev_c2     <= ev_acc_c2;
    pending_ev_pool <= pending_ev;

    process(clk)
        variable half_ev : unsigned(9 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state      <= IDLE;
                cur_idx    <= 0;
                ev_acc_c1  <= (others => '0');
                ev_acc_c2  <= (others => '0');
                pending_ev <= (others => '0');
                done_analysis <= '0';

            else
                case state is

                    when IDLE =>
                        done_analysis <= '0';
                        if start_analysis = '1' then
                            cur_idx   <= 0;
                            ev_acc_c1 <= (others => '0');
                            ev_acc_c2 <= (others => '0');
                            pending_ev <= (others => '0');
                            state     <= PROCESS_STATE;
                        end if;

                    when PROCESS_STATE =>
                        -- รอ 1 cycle ให้ top.vhd ส่งข้อมูลของ cur_idx มาถึง
                        state <= NEXT_STATE;

                    when NEXT_STATE =>
                        -- ตอนนี้ pop_c1_in / pop_c2_in / ev_value_in
                        -- มีค่าของ state cur_idx แล้ว
                        half_ev := ev_value_in / 2;

                        if pop_c1_in > pop_c2_in then
                            ev_acc_c1 <= ev_acc_c1 + ev_value_in;

                        elsif pop_c2_in > pop_c1_in then
                            ev_acc_c2 <= ev_acc_c2 + ev_value_in;

                        else  -- tie
                            if ev_value_in mod 2 = 0 then
                                ev_acc_c1 <= ev_acc_c1 + half_ev;
                                ev_acc_c2 <= ev_acc_c2 + half_ev;
                            else
                                if national_pop_c1 > national_pop_c2 then
                                    ev_acc_c1 <= ev_acc_c1 + half_ev + 1;
                                    ev_acc_c2 <= ev_acc_c2 + half_ev;
                                elsif national_pop_c2 > national_pop_c1 then
                                    ev_acc_c2 <= ev_acc_c2 + half_ev + 1;
                                    ev_acc_c1 <= ev_acc_c1 + half_ev;
                                else
                                    ev_acc_c1 <= ev_acc_c1 + half_ev;
                                    ev_acc_c2 <= ev_acc_c2 + half_ev;
                                    pending_ev <= pending_ev + 1;
                                end if;
                            end if;
                        end if;

                        -- ไป state ถัดไป หรือจบ
                        if cur_idx + 1 < to_integer(state_count) then
                            cur_idx <= cur_idx + 1;
                            state   <= PROCESS_STATE;
                        else
                            state <= DONE_ST;
                        end if;

                    when DONE_ST =>
                        done_analysis <= '1';
                        state <= IDLE;                       
                end case;
            end if;
        end if;
    end process;
end behavioral;
