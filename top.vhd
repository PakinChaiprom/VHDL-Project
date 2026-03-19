library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
    Generic (
        CLK_FREQ : integer := 100_000_000  
    );
    Port (
        clk100MHZ     : in  std_logic;      
        btn_u      : in std_logic;
        btn_d    : in std_logic;
        btn_l    : in std_logic;
        btn_r   : in std_logic;
        btn_c  : in std_logic;
        btn_res : in std_logic;       
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
    signal btn_vec : std_logic_vector(5 downto 0);
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
    signal voter_id_top : std_logic_vector(9 downto 0);
    signal voted_flag_top  : std_logic;
    signal vote_valid_top  : std_logic;
    signal selected_candidate_top : std_logic_vector(1 downto 0);
    signal btn_debounced : std_logic_vector(5 downto 0);
    type vote_array_t is array(0 to 49) of unsigned(15 downto 0);
    signal vote_c1        : vote_array_t := (others => (others => '0'));
    signal vote_c2        : vote_array_t := (others => (others => '0'));
    signal vote_count_top : unsigned(15 downto 0);
    signal state_sel_int  : integer range 0 to 49;
    signal start_analysis_top : std_logic;
    signal total_ev_c1_top : unsigned(15 downto 0);
    signal total_ev_c2_top : unsigned(15 downto 0);
    signal pending_ev_top  : unsigned(7 downto 0);
    signal done_analysis_top : std_logic;
    signal national_pop_c1_top : unsigned(31 downto 0) := (others => '0');
    signal national_pop_c2_top : unsigned(31 downto 0) := (others => '0');
    signal admin_disp_digit0  : std_logic_vector(3 downto 0);
    signal admin_disp_digit1  : std_logic_vector(3 downto 0);
    signal admin_disp_digit2  : std_logic_vector(3 downto 0);
    signal admin_msg_sel      : std_logic_vector(3 downto 0);
    signal admin_index        : std_logic_vector(9 downto 0);
    signal rst_from_admin     : std_logic;
    signal global_rst         : std_logic;
    signal msg_sel_final      : std_logic_vector(3 downto 0);
    signal index_digit_final  : std_logic_vector(9 downto 0);
    signal admin_pop_query    : integer range 0 to 998;
    signal admin_pop_c1       : unsigned(15 downto 0);
    signal admin_pop_c2       : unsigned(15 downto 0);
    signal admin_login_ok_top : std_logic;
    signal digit_clear_top : std_logic;
    signal digit_max_d1 : integer range 0 to 9 := 9;
    signal digit_max_d0 : integer range 0 to 9 := 9;
    signal digit_allow_d2 : std_logic := '0';
    signal blink_en_top : std_logic;
    signal ana_query_index  : integer range 0 to 49;
    signal ana_pop_c1       : unsigned(15 downto 0);
    signal ana_pop_c2       : unsigned(15 downto 0);
    signal ana_ev_value     : unsigned(9 downto 0);
    signal analysis_active : std_logic;
           
begin 
    btn_vec(0) <= btn_r;
    btn_vec(1) <= btn_l;
    btn_vec(2) <= btn_d;
    btn_vec(3) <= btn_u;
    btn_vec(4) <= btn_c;
    btn_vec(5) <= btn_res;
    
    ev_digit0 <= std_logic_vector(
        to_unsigned(to_integer(unsigned(ev_result_top)) mod 10, 4));
    ev_digit1 <= std_logic_vector(
        to_unsigned((to_integer(unsigned(ev_result_top)) / 10) mod 10, 4));
    ev_digit2 <= std_logic_vector(
        to_unsigned((to_integer(unsigned(ev_result_top)) / 100) mod 10, 4));
    admin_pop_c1 <= vote_c1(admin_pop_query);
    admin_pop_c2 <= vote_c2(admin_pop_query);
    
    -- MUX for C5 and admin
    disp_digit0 <= admin_disp_digit0 when state_out(7 downto 5) = "001"
                   else ev_digit0    when state_out = "00000101"
                   else digit0;
    disp_digit1 <= admin_disp_digit1 when state_out(7 downto 5) = "001"
                   else ev_digit1    when state_out = "00000101"
                   else digit1;
    disp_digit2 <= admin_disp_digit2 when state_out(7 downto 5) = "001"
                   else ev_digit2    when state_out = "00000101"
                   else digit2;
    msg_sel_final     <= admin_msg_sel when state_out(7 downto 5) = "001"
                         else msg_sel;
    index_digit_final <= admin_index   when state_out(7 downto 5) = "001"
                         else index_digit_top;
    
    pop_query_index_top <= to_integer(unsigned(selected_state_top));

    state_sel_int <= to_integer(unsigned(selected_state_top))
                 when to_integer(unsigned(selected_state_top)) <= 49
                 else 49;
    vote_count_top <= vote_c1(state_sel_int) + vote_c2(state_sel_int);
       
    global_rst <= rst_from_admin;
   
    digit_allow_d2 <= '1' when state_out = "00100001"  -- A1
             else '1' when state_out = "00000011"  -- C3
             else '0';
             
    blink_en_top <= '0' when state_out = "00000101"   -- C5: view EV result
           else '0' when state_out = "00100010"   -- A2: admin home
           else '0' when state_out = "00100011"   -- A3: view state results
           else '0' when state_out = "00100100"   -- A4: view EV total
           else '0' when state_out = "00100101"   -- A5: declare winner
           else '0' when state_out = "00100110"   -- A6: reset system
           else '1';
     
    ana_pop_c1   <= vote_c1(ana_query_index);
    ana_pop_c2   <= vote_c2(ana_query_index);
    ev_query_index_top <= ana_query_index
                          when analysis_active = '1'
                          else to_integer(unsigned(index_digit_top));
    ana_ev_value <= unsigned(ev_result_top);
     
    process(clk100MHZ, global_rst)
    begin
        if global_rst = '1' then
            analysis_active <= '0';
        elsif rising_edge(clk100MHZ) then
            if start_analysis_top = '1' then
                analysis_active <= '1';
            elsif done_analysis_top = '1' then
                analysis_active <= '0';
            end if;
        end if;
    end process;
    
    -- 2D array
    process(clk100MHZ, global_rst)
    begin
        if global_rst = '1' then
            vote_c1             <= (others => (others => '0'));
            vote_c2             <= (others => (others => '0'));
            national_pop_c1_top <= (others => '0');
            national_pop_c2_top <= (others => '0');
        elsif rising_edge(clk100MHZ) then
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

    process(state_out, digit1, digit2)
    begin
        if state_out = "00000001" then  -- C1
            digit_max_d1 <= 5;
            if to_integer(unsigned(digit1)) >= 5 then
                digit_max_d0 <= 0;  -- d1=5 → d0 ได้แค่ 0
            else
                digit_max_d0 <= 9;  -- d1<5 → d0 ได้ 0-9
            end if;
         elsif state_out = "00000011" then  -- C3: max population=100
            digit_max_d1 <= 9;
            digit_max_d0 <= 9;
            -- ถ้า d2=1 จำกัด d1 ให้ได้แค่ 0 และ d0 ให้ได้แค่ 0
            if to_integer(unsigned(digit2)) >= 1 then
                digit_max_d1 <= 0;  -- d2=1 → d1 ได้แค่ 0
                digit_max_d0 <= 0;  -- d2=1,d1=0 → d0 ได้แค่ 0
            end if;
        else
            digit_max_d1 <= 9;
            digit_max_d0 <= 9;
        end if;
    end process;
    
    main : entity work.main_fsm
    generic map(CLK_FREQ => CLK_FREQ)
    port map(
        clk => clk100MHZ,
        rst => global_rst,       
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
        done_analysis_in   => done_analysis_top,
        digit_clear_out => digit_clear_top,
        admin_login_ok => admin_login_ok_top,
        skip_in        => btn_debounced(5)       
         
    );

    digit_in : entity work.digit_input
    port map(

        clk => clk100MHZ,
        rst => global_rst,
        btn_pulse => btn_debounced,
        val_out => val_top,

        digit_0 => digit0,
        digit_1 => digit1,
        digit_2 => digit2,

        cursor_pos => cursor,

        confirmed => confirmed,
        clear => digit_clear_top,
        error => error,
        allow_d2 => digit_allow_d2,
        max_d1 => digit_max_d1,
        max_d0 => digit_max_d0
    );
    
    seven_seg : entity work.sevenseg_driver
    generic map(CLK_FREQ => CLK_FREQ)
    port map(
        clk => clk100MHZ,
        rst => global_rst,

        digit_0 => disp_digit0,
        digit_1 => disp_digit1,
        digit_2 => disp_digit2,
        index_digit => index_digit_final,

        cursor_pos => cursor,

        msg_sel => msg_sel_final,

        seg => seg,
        an => an,
        blink_en => blink_en_top
   );
   
   ev_allocator : entity work.ev_allocator
   port map(
        clk => clk100MHZ,
        rst => global_rst,
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
        rst        => global_rst,
        voter_id   => unsigned(voter_id_top),
        vote_valid => vote_valid_top,
        voted_flag => voted_flag_top,
        state_id   => state_sel_int
   );
   
   btn_ctrl : entity work.button_controller
    generic map(CLK_FREQ => CLK_FREQ)
    port map(
        clk     => clk100MHZ,
        rst     => global_rst,
        btn_in  => btn_vec,         
        btn_out => btn_debounced     
   );
    
    state_ana : entity work.state_analyzer
    port map(
        clk             => clk100MHZ,
        rst             => global_rst,
        start_analysis  => start_analysis_top,
        state_count     => unsigned(state_count_top),   
        query_index     => ana_query_index,              
        pop_c1_in       => ana_pop_c1,                 
        pop_c2_in       => ana_pop_c2,               
        ev_value_in     => ana_ev_value,               
        national_pop_c1 => national_pop_c1_top,
        national_pop_c2 => national_pop_c2_top,
        total_ev_c1     => total_ev_c1_top,
        total_ev_c2     => total_ev_c2_top,
        pending_ev_pool => pending_ev_top,
        done_analysis   => done_analysis_top
    );
    
    admin_ctrl : entity work.admin_controller
    generic map(CLK_FREQ => CLK_FREQ)
    port map(
        clk             => clk100MHZ,
        rst             => global_rst,
        state_in        => state_out,
        digit_value     => unsigned(val_top),
        digit_confirmed => confirmed,
        btn_left        => btn_debounced(1),
        btn_right       => btn_debounced(0),
        btn_up          => btn_debounced(3),
        btn_down        => btn_debounced(2),
        btn_center      => btn_debounced(4),
        total_ev_c1     => total_ev_c1_top,
        total_ev_c2     => total_ev_c2_top,
        pending_ev      => pending_ev_top,
        national_pop_c1 => national_pop_c1_top,
        national_pop_c2 => national_pop_c2_top,
        ev_total        => unsigned(ev_total_top),
        state_count     => unsigned(state_count_top),
        pop_query_index => admin_pop_query,
        pop_c1_result   => admin_pop_c1,
        pop_c2_result   => admin_pop_c2,
        disp_digit_0    => admin_disp_digit0,
        disp_digit_1    => admin_disp_digit1,
        disp_digit_2    => admin_disp_digit2,
        disp_msg_sel    => admin_msg_sel,
        disp_index      => admin_index,
        rst_out         => rst_from_admin,
        admin_login_ok => admin_login_ok_top
    );
end structural;
