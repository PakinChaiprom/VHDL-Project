library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
    Port (
        clk100MHZ     : in  std_logic;
      
        btn_u      : in std_logic;
        btn_d    : in std_logic;
        btn_l    : in std_logic;
        btn_r   : in std_logic;
        btn_c  : in std_logic;
        

        seg     : out std_logic_vector(6 downto 0);
        an  : out std_logic_vector(7 downto 0);
        LED : out std_logic_vector(9 downto 0)
        
    );
end top;

architecture structural of top is

    signal state_out : std_logic_vector(7 downto 0);
    signal val_top : std_logic_vector(9 downto 0);
    signal confirmed   : std_logic;
    signal error : std_logic;
    signal btn_vec : std_logic_vector(4 downto 0);
    signal digit0 : std_logic_vector(3 downto 0);
    signal digit1 : std_logic_vector(3 downto 0);
    signal digit2 : std_logic_vector(3 downto 0);
    signal cursor  : std_logic_vector(1 downto 0);
    signal msg_sel : std_logic_vector(3 downto 0);
    signal index_digit_top :std_logic_vector(9 downto 0);
    signal alloc_start_top : std_logic;
    signal alloc_done_top : std_logic;
    signal state_count_top : std_logic_vector(9 downto 0);
    signal ev_total_top : std_logic_vector(9 downto 0);
    signal pop_data_top : std_logic_vector(9 downto 0);
    signal pop_index_top : integer range 0 to 998;
    signal pop_write_top : std_logic;
    signal population_total_top : unsigned(31 downto 0);
    signal ev_result_top    : std_logic_vector(9 downto 0);
    signal ev_query_index_top : integer range 0 to 998;
    signal ev_digit0        : std_logic_vector(3 downto 0);
    signal ev_digit1        : std_logic_vector(3 downto 0);
    signal ev_digit2        : std_logic_vector(3 downto 0);
    signal disp_digit0      : std_logic_vector(3 downto 0);
    signal disp_digit1      : std_logic_vector(3 downto 0);
    signal disp_digit2      : std_logic_vector(3 downto 0);
    signal selected_state_top : std_logic_vector(9 downto 0);
    signal pop_query_index_top : integer range 0 to 998;
    signal pop_result_top : std_logic_vector(9 downto 0);
    signal voter_id_top : std_logic_vector(12 downto 0);
    signal voted_flag_top  : std_logic;
    signal vote_valid_top  : std_logic;
    signal selected_candidate_top : std_logic_vector(1 downto 0);
    signal btn_debounced : std_logic_vector(4 downto 0);
    type vote_array_t is array(0 to 998) of unsigned(15 downto 0);
    signal vote_c1        : vote_array_t := (others => (others => '0'));
    signal vote_c2        : vote_array_t := (others => (others => '0'));
    signal vote_count_top : unsigned(15 downto 0);
    signal state_sel_int  : integer range 0 to 998;
    signal pop_vote_c1_top : unsigned(15 downto 0);
    signal pop_vote_c2_top : unsigned(15 downto 0);
    signal start_analysis_top : std_logic;
    signal total_ev_c1_top : unsigned(15 downto 0);
    signal total_ev_c2_top : unsigned(15 downto 0);
    signal pending_ev_top  : unsigned(7 downto 0);
    signal done_analysis_top : std_logic;
    signal national_pop_c1_top : unsigned(31 downto 0) := (others => '0');
    signal national_pop_c2_top : unsigned(31 downto 0) := (others => '0');
    
begin 
    btn_vec(0) <= btn_r;
    btn_vec(1) <= btn_l;
    btn_vec(2) <= btn_d;
    btn_vec(3) <= btn_u;
    btn_vec(4) <= btn_c;
    
    ev_query_index_top <= to_integer(unsigned(index_digit_top));
    ev_digit0 <= std_logic_vector(
        to_unsigned(to_integer(unsigned(ev_result_top)) mod 10, 4));
    ev_digit1 <= std_logic_vector(
        to_unsigned((to_integer(unsigned(ev_result_top)) / 10) mod 10, 4));
    ev_digit2 <= std_logic_vector(
        to_unsigned((to_integer(unsigned(ev_result_top)) / 100) mod 10, 4));
    -- MUX for C5   
    disp_digit0 <= ev_digit0 when state_out = "00000101" else digit0;
    disp_digit1 <= ev_digit1 when state_out = "00000101" else digit1;
    disp_digit2 <= ev_digit2 when state_out = "00000101" else digit2;
    
    pop_query_index_top <= to_integer(unsigned(selected_state_top));

    state_sel_int  <= to_integer(unsigned(selected_state_top));
    vote_count_top <= vote_c1(state_sel_int) + vote_c2(state_sel_int);
    
    pop_vote_c1_top <= vote_c1(state_sel_int);
    pop_vote_c2_top <= vote_c2(state_sel_int);
        
    -- 2D array
    process(clk100MHZ)
    begin
        if rising_edge(clk100MHZ) then
            if vote_valid_top = '1' then
                if selected_candidate_top = "01" then
                    vote_c1(state_sel_int)  <= vote_c1(state_sel_int) + 1;
                    national_pop_c1_top     <= national_pop_c1_top + 1; 
                else
                    vote_c2(state_sel_int)  <= vote_c2(state_sel_int) + 1;
                    national_pop_c2_top     <= national_pop_c2_top + 1;  
                end if;
            end if;
        end if;
    end process;

    main : entity work.main_fsm
    port map(
        clk => clk100MHZ,
        rst => '0',       
        btn_down   => btn_debounced(2),  
        btn_up     => btn_debounced(3),
        btn_left   => btn_debounced(1),
        btn_right  => btn_debounced(0),
        btn_center => btn_debounced(4),     
        state_confirmed => confirmed,
        state_out => state_out,
        msg_sel => msg_sel,
        LED => LED,
        val_in => val_top,
        index_digit_out => index_digit_top,
        alloc_start_out => alloc_start_top,
        alloc_done_in => alloc_done_top,
        state_count_out => state_count_top,
        ev_total_out => ev_total_top,
        pop_data_out => pop_data_top,
        pop_index_out => pop_index_top,
        pop_write_out => pop_write_top,
        alloc_pop_total_in => population_total_top,
        pop_result_in => pop_result_top,
        selected_state_out => selected_state_top,
        voter_id_out => voter_id_top,        
        voted_flag_in => voted_flag_top, 
        vote_valid_out => vote_valid_top,
        selected_candidate_out => selected_candidate_top,
        vote_count_in => vote_count_top,
        start_analysis_out => start_analysis_top,
        done_analysis_in   => done_analysis_top 
    );

    digit_in : entity work.digit_input
    port map(

        clk => clk100MHZ,
        rst => '0',
        btn_pulse => btn_debounced,
        val_out => val_top,

        digit_0 => digit0,
        digit_1 => digit1,
        digit_2 => digit2,

        cursor_pos => cursor,

        confirmed => confirmed,
        error => error
    );
    
    seven_seg : entity work.sevenseg_driver
    generic map(CLK_FREQ => 100000000)
    port map(
        clk => clk100MHZ,
        rst => '0',

        digit_0 => disp_digit0,
        digit_1 => disp_digit1,
        digit_2 => disp_digit2,
        index_digit => index_digit_top,

        cursor_pos => cursor,

        msg_sel => msg_sel,

        seg => seg,
        an => an
   );
   
   ev_allocator : entity work.ev_allocator
   port map(
        clk => clk100MHZ,
        rst => '0',
        start => alloc_start_top,
        state_count => unsigned(state_count_top),
        ev_total => unsigned(ev_total_top),
        pop_data => unsigned(pop_data_top),
        pop_index => pop_index_top,
        pop_write => pop_write_top,
        ev_query_index => ev_query_index_top,
        ev_result_out => ev_result_top,
        done => alloc_done_top,
        population_total_out => population_total_top,
        pop_query_index => pop_query_index_top,
        pop_result_out => pop_result_top
   );
   
   vote_memory : entity work.vote_memory
   port map(
        clk        => clk100MHZ,
        rst        => '0',
        voter_id   => unsigned(voter_id_top),
        vote_valid => vote_valid_top,
        voted_flag => voted_flag_top
   );
   
   btn_ctrl : entity work.button_controller
    generic map(CLK_FREQ => 100_000_000)
    port map(
        clk     => clk100MHZ,
        rst     => '0',
        btn_in  => btn_vec,         
        btn_out => btn_debounced     
    );
    
    state_ana : entity work.state_analyzer
    port map(
        clk             => clk100MHZ,
        rst             => '0',
        start_analysis  => start_analysis_top,
        pop_vote_c1     => pop_vote_c1_top,
        pop_vote_c2     => pop_vote_c2_top,
        national_pop_c1 => national_pop_c1_top,
        national_pop_c2 => national_pop_c2_top,
        state_ev_value  => unsigned(ev_result_top(7 downto 0)),
        total_ev_c1     => total_ev_c1_top,
        total_ev_c2     => total_ev_c2_top,
        pending_ev_pool => pending_ev_top,
        done_analysis   => done_analysis_top
    );
    
end structural;
