library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity digit_input is
    Port ( 
        clk        : in  STD_LOGIC;
        rst        : in  STD_LOGIC;
        btn_pulse  : in  STD_LOGIC_VECTOR(5 downto 0); 
        val_out    : out STD_LOGIC_VECTOR(9 downto 0); 
        digit_0    : out STD_LOGIC_VECTOR(3 downto 0); 
        digit_1    : out STD_LOGIC_VECTOR(3 downto 0); 
        digit_2    : out STD_LOGIC_VECTOR(3 downto 0); 
        cursor_pos : out STD_LOGIC_VECTOR(1 downto 0); 
        confirmed  : out STD_LOGIC;    
        error      : out STD_LOGIC;       
        clear      : in  std_logic;
        max_d1 : in integer range 0 to 9 := 9;  
        max_d0 : in integer range 0 to 9 := 9;
        allow_d2 : in std_logic := '0'                           
    );
end digit_input;

architecture Behavioral of digit_input is
    signal d0, d1, d2 : integer range 0 to 9 := 0;    
    signal cursor : integer range 0 to 2 := 0;        
    signal reg_10bit : STD_LOGIC_VECTOR(9 downto 0) := (others => '0');
    signal btn_c_prev  : std_logic := '0'; 
begin
   
    digit_0 <= std_logic_vector(to_unsigned(d0, 4));
    digit_1 <= std_logic_vector(to_unsigned(d1, 4));
    digit_2 <= std_logic_vector(to_unsigned(d2, 4));
    cursor_pos <= std_logic_vector(to_unsigned(cursor, 2));
    val_out <= reg_10bit;
      
    process(clk, rst)
        variable calc_val : integer;                 
    begin
        if rst = '1' then                             
            d0 <= 0; d1 <= 0; d2 <= 0;
            cursor <= 0;
            reg_10bit <= (others => '0');
            confirmed <= '0';
            btn_c_prev <= '0';
        elsif rising_edge(clk) then
            btn_c_prev <= btn_pulse(4);  -- จำ pulse cycle ที่แล้ว
            confirmed  <= '0';
            if clear = '1' then
                d0 <= 0; d1 <= 0; d2 <= 0;
                cursor <= 0;
                reg_10bit <= (others => '0');
                btn_c_prev <= '0';              
            else              
                if btn_pulse(1) = '1' then 
                    if cursor < 2 then cursor <= cursor + 1; end if; 
                elsif btn_pulse(0) = '1' then
                    if cursor > 0 then cursor <= cursor - 1; end if; 
                end if;
        
                if btn_pulse(3) = '1' then
                    case cursor is
                        when 1 =>
                            if d1 < max_d1 then
                                d1 <= d1 + 1;
                            else
                                d1 <= 0;
                            end if;
                            -- clamp d0 ถ้า d1 ใหม่ = max_d1
                            if d1 + 1 = max_d1 and d0 > max_d0 then
                                d0 <= max_d0;  -- ← clamp d0 ทันที
                            end if;
                        when 0 =>
                            if d0 < max_d0 then d0 <= d0 + 1;
                            else d0 <= 0; end if;                     
                        when 2 => 
                            if allow_d2 = '1' then  -- ← เพิ่ม condition
                                if d2 < 1 then d2 <= d2 + 1;
                                else d2 <= 0; end if;
                            end if;
                        when others => null;
                    end case;
                end if;
        
                if btn_pulse(2) = '1' then
                    case cursor is
                        when 1 =>
                            if d1 > 0 then
                                d1 <= d1 - 1;
                            else
                                d1 <= max_d1;
                                -- clamp d0 ถ้า wrap ไปที่ max_d1
                                if d0 > max_d0 then
                                    d0 <= max_d0;
                                end if;
                            end if;
                        when 0 =>
                            if d0 > 0 then d0 <= d0 - 1;
                            else d0 <= max_d0; end if;                    
                        when 2 => 
                             if allow_d2 = '1' then  -- ← เพิ่ม condition
                                if d2 > 0 then d2 <= d2 - 1;
                                else d2 <= 1; end if;
                            end if;
                        when others => null;
                    end case;
                end if;
        
               if btn_pulse(4) = '1' then
                    calc_val  := (d2 * 100) + (d1 * 10) + d0;
                    reg_10bit <= std_logic_vector(to_unsigned(calc_val, 10));
                end if;

                -- cycle 2: reg_10bit มีค่าใหม่แล้ว → ส่ง confirmed
                if btn_c_prev = '1' then
                    confirmed <= '1';
                end if;
            end if;  
        end if;
    end process;
end Behavioral;
