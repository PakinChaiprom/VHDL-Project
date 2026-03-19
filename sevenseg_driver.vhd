library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sevenseg_driver is
    Generic ( CLK_FREQ : integer := 100_000_000 );
    Port ( 
        clk        : in  STD_LOGIC;
        rst        : in  STD_LOGIC;
        digit_0    : in  STD_LOGIC_VECTOR(3 downto 0); -- ข้อมูลหลักหน่วย
        digit_1    : in  STD_LOGIC_VECTOR(3 downto 0); -- ข้อมูลหลักสิบ
        digit_2    : in  STD_LOGIC_VECTOR(3 downto 0); -- ข้อมูลหลักร้อย
        cursor_pos : in  STD_LOGIC_VECTOR(1 downto 0); -- ตำแหน่งไฟกระพริบ
        msg_sel    : in  STD_LOGIC_VECTOR(3 downto 0); -- โหมดหน้าจอ (สั่งจาก เจโน่/FSM)
        seg        : out STD_LOGIC_VECTOR(6 downto 0); -- สายคุมไฟ 7 ขีด (A-G)
        index_digit : in STD_LOGIC_VECTOR(9 downto 0);  -- รับ state_index จาก main
        an          : out STD_LOGIC_VECTOR(7 downto 0);
        blink_en : in std_logic := '1'  
    );
end sevenseg_driver;

architecture Behavioral of sevenseg_driver is
    -- ตัวนับความเร็วสแกนจอ (หารให้เหลือความเร็วระดับที่ตามองไม่ทัน)
    constant MUX_MAX : integer := CLK_FREQ / 4000; 
    signal mux_cnt : integer range 0 to MUX_MAX := 0;
    signal scan_idx : integer range 0 to 7 := 0;       -- วนค่า 0,1,2,3 เพื่อสแกน 4 หลัก
    
    -- ตัวนับทำไฟกระพริบ (หารให้ช้าลงเหลือวิละ 4 ครั้ง)
    constant BLINK_MAX : integer := CLK_FREQ / 4; 
    signal blink_cnt : integer range 0 to BLINK_MAX := 0;
    signal blink_state : std_logic := '0';             -- สถานะเปิด/ปิด ไฟกระพริบ

    signal char_code : integer range 0 to 31 := 0;     -- รหัสตัวอักษรที่จะส่งไปแปลงเป็นแสงไฟ
    signal hide_digit : std_logic := '0';              -- คำสั่งปิดไฟชั่วคราว (เช่น ดับไฟกระพริบ)
    signal idx_digit0 : integer range 0 to 9 := 0;
    signal idx_digit1 : integer range 0 to 9 := 0;
    signal idx_digit2 : integer range 0 to 9 := 0;
    signal raw_digit0 : integer range 0 to 9 := 0;
    signal raw_digit1 : integer range 0 to 9 := 0;
    signal raw_digit2 : integer range 0 to 9 := 0;
begin

    process(index_digit)
    begin
        raw_digit0 <= to_integer(unsigned(index_digit)) mod 10;
        raw_digit1 <= (to_integer(unsigned(index_digit)) / 10) mod 10;
        raw_digit2 <= (to_integer(unsigned(index_digit)) / 100) mod 10;
    
        idx_digit0 <= (to_integer(unsigned(index_digit)) + 1) mod 10;
        idx_digit1 <= ((to_integer(unsigned(index_digit)) + 1) / 10) mod 10;
        idx_digit2 <= ((to_integer(unsigned(index_digit)) + 1) / 100) mod 10;
    end process;
    -- โพรเซสที่ 1: นาฬิกานับจังหวะ สแกนจอ และ ไฟกระพริบ
    process(clk, rst)
    begin
        if rst = '1' then
            mux_cnt <= 0; scan_idx <= 0;
            blink_cnt <= 0; blink_state <= '0';
        elsif rising_edge(clk) then
            -- ระบบ Multiplex (สแกนจอ)
            if mux_cnt < MUX_MAX then
                mux_cnt <= mux_cnt + 1;
            else
                mux_cnt <= 0;
                if scan_idx < 7 then scan_idx <= scan_idx + 1; -- สลับหลักถัดไป
                else scan_idx <= 0; end if;
            end if;
            
            -- ระบบไฟกระพริบ
            if blink_cnt < BLINK_MAX then
                blink_cnt <= blink_cnt + 1;
            else
                blink_cnt <= 0;
                blink_state <= not blink_state; -- สลับสถานะ ติด-ดับ
            end if;
        end if;
    end process;

    -- โพรเซสที่ 2: เลือกว่าจะโชว์ตัวเลขปกติ หรือข้อความ
    process(scan_idx, msg_sel, digit_0, digit_1, digit_2, cursor_pos, blink_state, index_digit, idx_digit0, idx_digit1, idx_digit2, raw_digit0, blink_en)
    begin
        hide_digit <= '0';       -- เริ่มต้นให้ไฟติดปกติ
        an <= (others => '1');            -- ปิดจอทุกหลัก (Active Low = 1 คือปิด)
        char_code <= 24;         -- รหัสเผื่อไว้ (ไฟดับ)
        
        if msg_sel = "0000" then -- ถ้า FSM สั่งให้เป็นโหมดป้อนตัวเลข
            case scan_idx is
                when 0 => -- เปิดหลักหน่วย (ขวาสุด)
                    char_code <= to_integer(unsigned(digit_0)); an <= "11111110"; -- ดึงค่าหลักหน่วยมาโชว์
                    if cursor_pos = "00" and blink_state = '1' and blink_en = '1' then hide_digit <= '1'; end if; -- ถ้าเคอร์เซอร์อยู่ตรงนี้ ให้กระพริบ
                when 1 => -- เปิดหลักสิบ
                    char_code <= to_integer(unsigned(digit_1)); an <= "11111101";
                    if cursor_pos = "01" and blink_state = '1' and blink_en = '1' then hide_digit <= '1'; end if;
                when 2 => -- เปิดหลักร้อย
                    char_code <= to_integer(unsigned(digit_2)); an <= "11111011";
                    if cursor_pos = "10" and blink_state = '1' and blink_en = '1' then hide_digit <= '1'; end if;
                when 3 => -- หลักพัน (ไม่ได้ใช้)
                    char_code <= 24; an <= "11110111"; 
                    hide_digit <= '1'; -- สั่งปิดหลักนี้ไปเลย
                when 4 | 5 | 6 | 7 => hide_digit <= '1'; an <= (others => '1');
                when others => null;
            end case;
        else -- ถ้า FSM สั่งเป็นโหมดข้อความพิเศษ
            an <= (others => '1');
            an(scan_idx) <= '0'; -- เปิดจอตามจังหวะสแกนปกติ
            case msg_sel is
                when "0001" =>   -- โหมดโชว์คำว่า READY (r E A d)
                if scan_idx >= 4 then
                    hide_digit <= '1';
                else
                    if scan_idx=3 then char_code <= 16;      -- r
                    elsif scan_idx=2 then char_code <= 14;   -- E
                    elsif scan_idx=1 then char_code <= 10;   -- A
                    else char_code <= 13; end if;  
                end if;          -- d
                when "0010" =>   -- โหมด ERROR (E r r)
                if scan_idx >= 4 then
                    hide_digit <= '1';
                else
                    if scan_idx=3 then char_code <= 14;      -- E
                    elsif scan_idx=2 or scan_idx=1 then char_code <= 16; -- r
                    else hide_digit <= '1'; end if;
                 end if;
                -- (ส่วนข้อความอื่นๆ ใช้หลักการเดียวกัน ยัดรหัสลงไปตามหลักที่กำลังสแกน)
                when "0011" =>   -- S ตามด้วยเลข (เช่น S 1)
                if scan_idx >= 4 then
                    hide_digit <= '1';
                else
                    if scan_idx=2 then char_code <= 5;       -- ตัว S (ใช้หน้าตาเดียวกับเลข 5)
                    elsif scan_idx=0 then char_code <= to_integer(unsigned(digit_0));
                    else hide_digit <= '1'; end if;
                end if;
                when "0100" =>   --show toP
                if scan_idx >= 4 then
                    hide_digit <= '1';
                else
                    if scan_idx=2 then char_code <= 18;      -- t
                    elsif scan_idx=1 then char_code <= 19;   -- o
                    elsif scan_idx=0 then char_code <= 20;   -- P
                    else hide_digit <= '1'; end if;
                end if;
                when "0110" =>   -- โชว์คำว่า tIE (เสมอ)
                if scan_idx >= 4 then
                    hide_digit <= '1';
                else
                    if scan_idx=2 then char_code <= 18;      -- t
                    elsif scan_idx=1 then char_code <= 1;    -- I (ใช้หน้าตาเดียวกับเลข 1)
                    elsif scan_idx=0 then char_code <= 14;   -- E
                    else hide_digit <= '1'; end if;
                end if;
                when "0111" =>   -- โชว์คำว่า no (ไม่มีคนชนะ)
                    if scan_idx >= 4 then
                        hide_digit <= '1';
                    else
                        if scan_idx=2 then char_code <= 22;      -- n
                        elsif scan_idx=1 then char_code <= 23;   -- o
                        else hide_digit <= '1'; end if;
                    end if;
                
                when "1001" =>   -- โหมดโชว์คำว่า Load
                    if scan_idx >= 4 then
                        hide_digit <= '1';
                    else
                        if scan_idx = 3 then char_code <= 21;      -- L
                        elsif scan_idx = 2 then char_code <= 23;   -- o
                        elsif scan_idx = 1 then char_code <= 10;   -- A (ใช้แทน a)
                        else char_code <= 13; end if;              -- d
                    end if;
    
                   when "1000" =>             
                    case scan_idx is
                        when 7 => char_code <= 5;          -- S
                        when 6 =>                          -- ร้อย index
                            if idx_digit2 = 0 then 
                                hide_digit <= '1';
                            else 
                                char_code <= idx_digit2;
                            end if;
                        when 5 =>                          -- สิบ index
                            if idx_digit2 = 0 and idx_digit1 = 0 then
                                hide_digit <= '1';
                            else 
                                char_code <= idx_digit1;
                            end if;
                        when 4 =>                          -- หน่วย index
                            char_code <= idx_digit0;
                            if cursor_pos = "11" and blink_state = '1' and blink_en = '1' then hide_digit <= '1'; end if;
                        when 3 => hide_digit <= '1';       -- ดับ
                        when 2 =>                          -- ร้อย EV
                            char_code <= to_integer(unsigned(digit_2));
                            if cursor_pos = "10" and blink_state = '1' and blink_en = '1' then hide_digit <= '1'; end if;
                        when 1 =>                          -- สิบ EV
                            char_code <= to_integer(unsigned(digit_1));
                            if cursor_pos = "01" and blink_state = '1' and blink_en = '1' then hide_digit <= '1'; end if;
                        when 0 =>                          -- หน่วย EV
                            char_code <= to_integer(unsigned(digit_0));
                            if cursor_pos = "00" and blink_state = '1' and blink_en = '1' then hide_digit <= '1'; end if;
                        when others => hide_digit <= '1';
                    end case;
                
                when "0101" =>   -- โชว์ C ตามด้วย index
                case scan_idx is
                    when 7 => char_code <= 12;   -- C
                    when 6 => hide_digit <= '1';
                    when 5 => hide_digit <= '1';
                    when 4 => hide_digit <= '1';
                    when 3 => hide_digit <= '1';
                    when 2 => hide_digit <= '1';
                    when 1 => hide_digit <= '1';
                    when 0 => char_code <= raw_digit0;  -- 1 หรือ 2
                    when others => hide_digit <= '1';
                end case;
                
                  when "1010" =>   -- แสดงแค่ S[index] ฝั่งซ้าย ไม่มีตัวเลขขวา
                    case scan_idx is
                        when 7 => char_code <= 5;          -- S
                        when 6 =>                          -- ร้อย index
                            if idx_digit2 = 0 then 
                                hide_digit <= '1';
                            else 
                                char_code <= idx_digit2;
                            end if;
                        when 5 =>                          -- สิบ index
                            if idx_digit2 = 0 and idx_digit1 = 0 then
                                hide_digit <= '1';
                            else 
                                char_code <= idx_digit1;
                            end if;
                        when 4 =>                          -- หน่วย index
                            char_code <= idx_digit0;
                            if cursor_pos = "11" and blink_state = '1' and blink_en = '1' then 
                                hide_digit <= '1'; 
                            end if;
                        when 3 | 2 | 1 | 0 => hide_digit <= '1';  -- ← ดับหมดฝั่งขวา
                        when others => hide_digit <= '1';
                    end case;
                    
                    when "1011" =>   -- โหมดโชว์คำว่า PASS
                    if scan_idx >= 4 then
                        hide_digit <= '1';
                    else
                        if scan_idx=3 then char_code <= 20;      -- P
                        elsif scan_idx=2 then char_code <= 10;   -- A
                        elsif scan_idx=1 then char_code <= 5;    -- S
                        else char_code <= 5; end if;             -- S
                    end if;
                
            when others => hide_digit <= '1';
            end case;
        end if;
    end process;

    -- โพรเซสที่ 3: Decoder แปลงรหัสตัวเลข/ตัวอักษร เป็นแพทเทิร์นแสงไฟ A-G
    -- 0 คือไฟติด, 1 คือไฟดับ (เพราะบอร์ด Nexys A7 เป็นแบบ Common Anode)
    process(char_code, hide_digit)
    begin
        if hide_digit = '1' then
            seg <= "1111111"; -- ถ้าโดนสั่งซ่อน ให้ดับไฟทุกดวง
        else
            case char_code is
                when 0 => seg <= "1000000"; -- โชว์เลข 0
                when 1 => seg <= "1111001"; -- โชว์เลข 1
                when 2 => seg <= "0100100"; -- โชว์เลข 2
                -- [บรรทัด 3-9 ข้ามเพื่อความกระชับ เป็นแพทเทิร์นเลขปกติ]
                when 3 => seg <= "0110000"; 
                when 4 => seg <= "0011001"; 
                when 5 => seg <= "0010010"; 
                when 6 => seg <= "0000010"; 
                when 7 => seg <= "1111000"; 
                when 8 => seg <= "0000000"; 
                when 9 => seg <= "0010000"; 
                
                -- โซนข้อความพิเศษที่ออกแบบไว้
                when 10 => seg <= "0001000"; -- โชว์ตัว A
                when 12 => seg <= "1000110"; -- โชว์ตัว C
                when 13 => seg <= "0100001"; -- โชว์ตัว d
                when 14 => seg <= "0000110"; -- โชว์ตัว E
                when 16 => seg <= "0101111"; -- โชว์ตัว r
                when 18 => seg <= "0000111"; -- โชว์ตัว t
                when 19 => seg <= "1000000"; -- โชว์ตัว o (หน้าตาเหมือน 0)
                when 20 => seg <= "0001100"; -- โชว์ตัว P
                when 21 => seg <= "1000111"; -- โชว์ตัว L
                when 22 => seg <= "0101011"; -- โชว์ตัว n
                when 23 => seg <= "0100011"; -- โชว์ตัว o (ตัวเล็ก)
                when others => seg <= "1111111"; -- ถ้าไม่อยู่ในเงื่อนไข ให้ดับไฟ
            end case;
        end if;
    end process;
end Behavioral;
