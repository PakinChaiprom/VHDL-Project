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
    
    main : entity work.main_fsm
    port map(
        clk => clk100MHZ,
        rst => '0',
        
        btn_down => btn_d,       
        btn_center => btn_c,
        btn_up => btn_u,
        btn_left => btn_l,
        btn_right => btn_r,      
        state_confirmed => confirmed,
        state_out => state_out,
        msg_sel => msg_sel,
        LED => LED,
        val_in => val_top,
        index_digit_out => index_digit_top,
        alloc_start => alloc_start_top,
        alloc_done => alloc_done_top,
        state_count_out => state_count_top,
        ev_total_out => ev_total_top,
        pop_data_out => pop_data_top,
        pop_index_out => pop_index_top,
        pop_write_out => pop_write_top,
        alloc_pop_total_in => population_total_top
    );

    digit_in : entity work.digit_input
    port map(

        clk => clk100MHZ,
        rst => '0',
        btn_pulse => btn_vec,
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
        population_total_out => population_total_top
   );
end structural;
