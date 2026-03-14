library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity main_fsm is
    Generic (
            CLK_FREQ : integer := 100_000_000
    );
    Port (
        clk     : in std_logic;
        rst     : in std_logic;

        btn_center : in std_logic;
        btn_up      : in std_logic;
        btn_down    : in std_logic;
        btn_left    : in std_logic;
        btn_right   : in std_logic;
                       
        state_confirmed : in std_logic;
        msg_sel : out std_logic_vector(3 downto 0);
        index_digit_out : out STD_LOGIC_VECTOR(9 downto 0);
              
        state_count_out : out std_logic_vector(9 downto 0);
        ev_total_out : out std_logic_vector(9 downto 0);
        val_in : in std_logic_vector(9 downto 0);
        
        state_out  : out std_logic_vector(7 downto 0);
        LED : out std_logic_vector(9 downto 0);
        
        pop_data_out : out std_logic_vector(9 downto 0);
        pop_index_out : out integer range 0 to 998;
        pop_write_out : out std_logic;
        selected_state_out : out std_logic_vector(9 downto 0);
               
        pop_result_in : in std_logic_vector(9 downto 0);
        alloc_pop_total_in : in unsigned(31 downto 0);
        alloc_start_out : out std_logic;
        alloc_done_in  : in  std_logic;
        voter_id_out : out std_logic_vector(12 downto 0);       
        voted_flag_in  : in  std_logic;   
        vote_valid_out : out std_logic;
        selected_candidate_out : out std_logic_vector(1 downto 0);
        vote_count_in : in unsigned(15 downto 0);
        start_analysis_out : out std_logic;
        done_analysis_in   : in  std_logic; 
        admin_login_ok : in std_logic
           
    );
end main_fsm;

architecture behavioral of main_fsm is

    type state_type is (
        C1, C2, C3, C4, C5, 
        U0, U1, U2, U3, U4, U5, U6,
        A1, A2, A3, A4, A5, A6
    );

    signal current_state, next_state : state_type;
    signal val_int : integer;
    signal state_index     : integer range 0 to 999 := 0;
    signal state_count_reg : integer range 0 to 999 := 0;
    signal alloc_start_reg  : std_logic := '0';
    signal alloc_started    : std_logic := '0';
    signal selected_state : integer range 0 to 999 := 0;
    signal voter_id_reg : integer range 0 to 999 := 0;
    signal attempt_count : integer range 0 to 3 := 0;
    signal lock_count    : integer range 0 to 1100000000 := 0;
    signal locked        : std_logic := '0'; 
    signal vote_valid_reg : std_logic;
    signal selected_candidate : integer range 1 to 2 := 1;
    signal analysis_started : std_logic := '0';
    signal analysis_start_reg : std_logic := '0';

begin
    val_int <= to_integer(unsigned(val_in));
    selected_state_out <= std_logic_vector(to_unsigned(selected_state, 10));
    voter_id_out       <= std_logic_vector(to_unsigned(voter_id_reg, 13));
    selected_candidate_out <= std_logic_vector(to_unsigned(selected_candidate, 2));

    -- State register
    process(clk, rst)
    begin
        if rst = '1' then
            current_state <= C1;
        elsif rising_edge(clk) then
            current_state <= next_state;
        end if;
    end process;
    
    --registered process
    process(clk, rst)
    begin
        if rst = '1' then
            state_index     <= 0;
            state_count_reg <= 0;
            selected_state  <= 0;
            voter_id_reg    <= 0;
            selected_candidate <= 1;
        elsif rising_edge(clk) then
            --C1 register state_count
            if current_state = C1 and state_confirmed = '1' and val_int >= 2 and val_int <= 999 then
                state_count_reg <= val_int;
            end if;
            --C3 next state index
            if current_state = C3 and state_confirmed = '1' and val_int > 0 then
                if state_index + 1 < state_count_reg then
                    state_index <= state_index + 1;
                else
                    state_index <= 0;
                end if;
            end if;
            --C5 Left/Right view EV each state
            if current_state = C5 then
                if btn_right = '1' then
                    if state_index + 1 < state_count_reg then
                        state_index <= state_index + 1;
                    end if;
                elsif btn_left = '1' then
                    if state_index > 0 then
                        state_index <= state_index - 1;
                    end if;
                end if;
            end if;        
            if current_state = C5 and btn_center = '1' then
                state_index <= 0;
            end if;         
            -- U1 Left/Right view state and confirm selected
            if current_state = U1 then
                  if btn_center = '1' then
                        if state_index < state_count_reg then
                            selected_state <= state_index;  
                        end if;
                        state_index <= 0;  
                    elsif btn_right = '1' then
                        if state_index + 1 < state_count_reg then
                            state_index <= state_index + 1;
                        end if;
                    elsif btn_left = '1' then
                        if state_index > 0 then
                            state_index <= state_index - 1;
                        end if;
                  end if;
            end if;
              -- U2 register voter id
            if current_state = U2 and state_confirmed = '1' then           
                voter_id_reg <= val_int;
            end if;  
            
            -- U4: veiw candidate and confirm select
            if current_state = U4 then
                if btn_right = '1' then
                    selected_candidate <= 2;
                elsif btn_left = '1' then
                    selected_candidate <= 1;
                end if;
            end if;
                        
        end if;
    end process;
    
    -- U3: attempt and lock
    process(clk, rst)
    begin
        if rst = '1' then
            attempt_count <= 0;
            lock_count    <= 0;
            locked        <= '0';
        elsif rising_edge(clk) then
            if current_state = U3 then
                if locked = '1' then
                    if lock_count > 0 then
                        lock_count <= lock_count - 1;
                    else
                        locked        <= '0';
                        attempt_count <= 0;
                    end if;
                elsif btn_center = '1' then
                    if voter_id_reg > 0
                       and voter_id_reg <= to_integer(unsigned(pop_result_in)) then
                        attempt_count <= 0;
                    else
                        if attempt_count + 1 >= 3 then
                            locked        <= '1';
                            lock_count    <= CLK_FREQ * 10;  
                            attempt_count <= 0;
                        else
                            attempt_count <= attempt_count + 1;
                        end if;
                    end if;
                end if;
            end if;
            if current_state = U0 then
                attempt_count <= 0;
                locked        <= '0';
                lock_count    <= 0;
            end if;
        end if;
    end process;
    
    -- U3 vote_valid 
    process(clk, rst)
    begin
        if rst = '1' then
            vote_valid_reg <= '0';
        elsif rising_edge(clk) then
            vote_valid_reg <= '0';  
            if current_state = U3 
               and btn_center = '1'
               and locked = '0'
               and voter_id_reg > 0
               and voter_id_reg <= to_integer(unsigned(pop_result_in))
               and voted_flag_in = '0' then
                vote_valid_reg <= '1';  
            end if;
        end if;
    end process;
    vote_valid_out <= vote_valid_reg;
    
    --alloc_start one-shot pulse
    process(clk, rst)
    begin
        if rst = '1' then
            alloc_start_reg <= '0';
            alloc_started   <= '0';
        elsif rising_edge(clk) then
            if current_state = C4 then
                if alloc_started = '0' then
                    alloc_start_reg <= '1';  
                    alloc_started   <= '1';  
                else
                    alloc_start_reg <= '0';  
                end if;
            else
                alloc_start_reg <= '0';
                alloc_started   <= '0';  
            end if;
        end if;
    end process;
    alloc_start_out <= alloc_start_reg;
    
    --analysis_start one-shot pulse
    process(clk, rst)
    begin
        if rst = '1' then
            analysis_start_reg <= '0';
            analysis_started   <= '0';
        elsif rising_edge(clk) then
            if current_state = U6 then
                if analysis_started = '0' then
                    analysis_start_reg <= '1';
                    analysis_started   <= '1';
                else
                    analysis_start_reg <= '0';
                end if;
            else
                analysis_start_reg <= '0';
                analysis_started   <= '0';
            end if;
        end if;
    end process;
    start_analysis_out <= analysis_start_reg;
    
    -- stage table
    process(current_state)
    begin   
        case current_state is
            when C1 => state_out <= "00000001";
            when C2 => state_out <= "00000010";
            when C3 => state_out <= "00000011";
            when C4 => state_out <= "00000100";
            when C5 => state_out <= "00000101";
            when U0 => state_out <= "00010000";
            when U1 => state_out <= "00010001";
            when U2 => state_out <= "00010010";
            when U3 => state_out <= "00010011";
            when U4 => state_out <= "00010100";
            when U5 => state_out <= "00010101";
            when U6 => state_out <= "00010110";
            when A1 => state_out <= "00100001";
            when A2 => state_out <= "00100010";
            when A3 => state_out <= "00100011";
            when A4 => state_out <= "00100100";
            when A5 => state_out <= "00100101";
            when A6 => state_out <= "00100110";
            when others => state_out <= "00000000";   
       end case;  
    end process;

    -- Next state 
    process(
            current_state, 
            btn_center,
            btn_up,      
            btn_down,    
            btn_left,    
            btn_right,  
            state_confirmed,
            val_in,
            val_int,
            state_index,
            state_count_reg,
            alloc_pop_total_in,
            alloc_done_in,
            pop_result_in,
            locked,
            voter_id_reg,
            voted_flag_in,
            vote_count_in,
            done_analysis_in,
            admin_login_ok                 
            )
    begin
    
    next_state    <= current_state;
    msg_sel       <= "0000";
    index_digit_out <= (others => '0');
    state_count_out <= (others => '0');
    ev_total_out    <= (others => '0');
    pop_data_out    <= (others => '0');
    pop_index_out   <= 0;
    pop_write_out   <= '0'; 
    
        case current_state is                          
            when C1 => --set state count 
                msg_sel <= "0000";
                if state_confirmed = '1' then
                    if val_int >= 2 and val_int <=999 then
                        state_count_out <= val_in;
                        next_state <= C2;
                    else
                        msg_sel <= "0010";
                        next_state <= C1;   
                    end if;
                end if;   
          
            when C2 => --set total EV
                msg_sel <= "0000";
                if  state_confirmed = '1' then
                    if val_int > 0 then
                        ev_total_out <= val_in;
                        next_state <= C3;
                    else
                        msg_sel <= "0010";
                        next_state <= C2;                    
                    end if;
                end if;
            
            when C3 => --set each state population
                msg_sel <= "1000";
                index_digit_out <= std_logic_vector(to_unsigned(state_index, 10));            
                if  state_confirmed = '1' then
                    if val_int > 0 then
                        pop_data_out <= val_in;
                        pop_index_out <= state_index;
                        pop_write_out <= '1';
                        if state_index + 1 < state_count_reg then                         
                            next_state <= C3;
                        else
                            next_state <= C4;
                        end if;
                    else
                        msg_sel <= "0010";
                        next_state <= C3;
                    end if;
                end if;
            
            when C4 =>  --calculate total population & EV per state               
                if alloc_done_in = '1' then
                    if alloc_pop_total_in = 0 then
                        msg_sel    <= "0010";  
                        next_state <= C3;    
                    else
                        next_state <= C5;
                    end if;
                else
                    msg_sel    <= "1001";  
                    next_state <= C4;
                end if;
                                       
            when C5 =>  -- show EV result
                msg_sel         <= "1000";  
                index_digit_out <= std_logic_vector(to_unsigned(state_index, 10));
                if btn_center = '1' then
                    next_state <= U0;
                else
                    next_state <= C5;
                end if; 
                
            when U0 =>  --Idle(ready)
                msg_sel <= "0001";
                if btn_center = '1' then 
                    next_state <= U1;
                else                  
                    next_state <= U0;
                end if;
                
            when U1 =>  -- select state
                msg_sel         <= "1000";   
                index_digit_out <= std_logic_vector(to_unsigned(state_index, 10));
                
                if btn_center = '1' then
                    if state_index < state_count_reg then  
                        next_state <= U2;
                    else
                        msg_sel <= "0010";   
                    end if;
                else
                    next_state <= U1;
                end if;
                
            when U2 =>  -- insert voter ID
                msg_sel <= "0000";  
                if state_confirmed = '1' then
                    next_state <= U3;   
                else
                    next_state <= U2;
                end if;
                
            when U3 =>                
                if locked = '1' then
                    msg_sel    <= "0010";
                    next_state <= U3;
                elsif btn_center = '1' then
                    if voter_id_reg = 0
                       or voter_id_reg > to_integer(unsigned(pop_result_in)) then
                        msg_sel    <= "0010";
                        next_state <= U2;   
                    elsif voted_flag_in = '1' then
                        msg_sel    <= "0010";
                        next_state <= U0;   
                    else
                        next_state     <= U4;
                    end if;
                else
                    next_state <= U3;
                end if;
                
            when U4 =>  -- select candidate
                msg_sel         <= "0100"; 
                index_digit_out <= std_logic_vector(to_unsigned(selected_candidate, 10));       
                if btn_center = '1' then
                    next_state <= U5;
                else
                    next_state <= U4;
                end if;
                
           when U5 =>  -- register vote
                msg_sel <= "1001";
                if vote_count_in >= resize(unsigned(pop_result_in), 16) then
                    next_state <= U6;
                else
                    next_state <= U0;
                end if;
                        
             when U6 =>  --state analysis           
                if done_analysis_in = '1' then
                    next_state <= A1;
                else
                    msg_sel    <= "1001";  
                    next_state <= U6;
                end if;
                
             when A1 =>           --admin login           
                if btn_center = '1' and admin_login_ok = '1' then 
                    next_state <= A2;
                else 
                    next_state <= A1;
                end if;
                
             when A2 =>           --admin homepage          
                if btn_left = '1' then 
                    next_state <= A3;
                elsif btn_right = '1' then
                    next_state <= A4;
                elsif btn_up = '1' then 
                    next_state <= A5;
                elsif btn_down = '1' then          
                    next_state <= A6;           
                else 
                    next_state <= A2;
                end if;
                
              when A3 =>           --view state result          
                if btn_center = '1' then 
                    next_state <= A2;
                else 
                    next_state <= A3;
                end if;
                
              when A4 =>           --view electoral total          
                if btn_center = '1' then 
                    next_state <= A2;
                else 
                    next_state <= A4;
                end if;
                
              when A5 =>           --declare winner           
                if btn_center = '1' then           
                    next_state <= A2;
                else 
                    next_state <= A5;
                end if;
                
              when A6 =>           --reset system        
                if btn_center = '1' then
                    next_state <= A2;  -- cancel
                end if;
                
              when others =>
                    next_state <= C1;
                    
        end case;
    end process;
    
    -- LED display
   process(current_state)
    begin
        LED <= (others => '0');       
        case current_state is   
            when C1 => LED(0) <= '1'; LED(7) <= '1';
            when C2 => LED(1) <= '1'; LED(7) <= '1';
            when C3 => LED(2) <= '1'; LED(7) <= '1';             
            when C5 => LED(3) <= '1'; LED(7) <= '1';
            when U0 => LED(0) <= '1'; LED(7) <= '1'; LED(8) <= '1';
            when U1 => LED(1) <= '1'; LED(7) <= '1'; LED(8) <= '1';
            when U2 => LED(2) <= '1'; LED(7) <= '1'; LED(8) <= '1';
            when U3 => LED(3) <= '1'; LED(7) <= '1'; LED(8) <= '1';
            when U4 => LED(4) <= '1'; LED(7) <= '1'; LED(8) <= '1';
            when U5 => LED(5) <= '1'; LED(7) <= '1'; LED(8) <= '1';
            when U6 => LED(6) <= '1'; LED(7) <= '1'; LED(8) <= '1';
            when A1 => LED(0) <= '1'; LED(7) <= '1'; LED(8) <= '1'; LED(9) <= '1';
            when A2 => LED(1) <= '1'; LED(7) <= '1'; LED(8) <= '1'; LED(9) <= '1'; 
            when A3 => LED(2) <= '1'; LED(7) <= '1'; LED(8) <= '1'; LED(9) <= '1';
            when A4 => LED(3) <= '1'; LED(7) <= '1'; LED(8) <= '1'; LED(9) <= '1';          
            when A5 => LED(4) <= '1'; LED(7) <= '1'; LED(8) <= '1'; LED(9) <= '1';
            when A6 => LED(5) <= '1'; LED(7) <= '1'; LED(8) <= '1'; LED(9) <= '1';                   
            when others => null;
        end case;
    end process; 
   
end behavioral;
