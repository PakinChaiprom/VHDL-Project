library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity digit_input is
    Port ( 
        clk        : in  STD_LOGIC;
        rst        : in  STD_LOGIC;
        btn_pulse  : in  STD_LOGIC_VECTOR(4 downto 0); -- รับสัญญาณปุ่มที่กรองแล้ว
        val_out    : out STD_LOGIC_VECTOR(9 downto 0); -- ส่งออกเลข 10 บิต (0-1023)
        digit_0    : out STD_LOGIC_VECTOR(3 downto 0); -- ส่งออกหลักหน่วยไปจอ 7-Seg
        digit_1    : out STD_LOGIC_VECTOR(3 downto 0); -- ส่งออกหลักสิบไปจอ 7-Seg
        digit_2    : out STD_LOGIC_VECTOR(3 downto 0); -- ส่งออกหลักร้อยไปจอ 7-Seg
        cursor_pos : out STD_LOGIC_VECTOR(1 downto 0); -- บอกว่ากำลังแก้หลักไหนอยู่
        confirmed  : out STD_LOGIC                     -- ส่งสัญญาณว่ากด "ยืนยัน" แล้ว
    );
end digit_input;

architecture Behavioral of digit_input is
    signal d0, d1, d2 : integer range 0 to 9 := 0;     -- ตัวแปรเก็บเลขแต่ละหลัก (ห้ามเกิน 9)
    signal cursor : integer range 0 to 2 := 0;         -- 0=หน่วย, 1=สิบ, 2=ร้อย
    signal reg_10bit : STD_LOGIC_VECTOR(9 downto 0) := (others => '0'); -- Flip-flop 10 ตัว
begin
    -- ต่อสายตัวแปรภายใน ส่งออกไปให้ 7-Seg ตลอดเวลา
    digit_0 <= std_logic_vector(to_unsigned(d0, 4));
    digit_1 <= std_logic_vector(to_unsigned(d1, 4));
    digit_2 <= std_logic_vector(to_unsigned(d2, 4));
    cursor_pos <= std_logic_vector(to_unsigned(cursor, 2));
    val_out <= reg_10bit;

    process(clk, rst)
        variable calc_val : integer;                   -- ตัวแปรกระดาษทด สำหรับคำนวณผลรวม
    begin
        if rst = '1' then                              -- ถ้า Reset ให้ทุกอย่างกลับเป็น 0
            d0 <= 0; d1 <= 0; d2 <= 0;
            cursor <= 0;
            reg_10bit <= (others => '0');
            confirmed <= '0';
        elsif rising_edge(clk) then
            confirmed <= '0';                          -- ดับสัญญาณยืนยันไว้เสมอ
            
            -- กดปุ่มเลื่อน ซ้าย(1) / ขวา(0)
            if btn_pulse(1) = '1' then 
                if cursor < 2 then cursor <= cursor + 1; end if; -- ขยับไปทางซ้าย (ร้อย)
            elsif btn_pulse(0) = '1' then
                if cursor > 0 then cursor <= cursor - 1; end if; -- ขยับไปทางขวา (หน่วย)
            end if;

            -- กดปุ่ม บน(3) = เพิ่มค่า
            if btn_pulse(3) = '1' then
                case cursor is
                    when 0 => if d0 < 9 then d0 <= d0 + 1; else d0 <= 0; end if; -- ถ้าเกิน 9 ให้วนกลับไป 0
                    when 1 => if d1 < 9 then d1 <= d1 + 1; else d1 <= 0; end if;
                    when 2 => if d2 < 9 then d2 <= d2 + 1; else d2 <= 0; end if;
                    when others => null;
                end case;
            end if;

            -- กดปุ่ม ลง(2) = ลดค่า
            if btn_pulse(2) = '1' then
                case cursor is
                    when 0 => if d0 > 0 then d0 <= d0 - 1; else d0 <= 9; end if; -- ถ้าต่ำกว่า 0 ให้วนไป 9
                    when 1 => if d1 > 0 then d1 <= d1 - 1; else d1 <= 9; end if;
                    when 2 => if d2 > 0 then d2 <= d2 - 1; else d2 <= 9; end if;
                    when others => null;
                end case;
            end if;

            -- กดปุ่ม กลาง(4) = ยืนยัน
            if btn_pulse(4) = '1' then
                calc_val := (d2 * 100) + (d1 * 10) + d0;                    -- รวมร่างเป็นเลขหลักร้อย
                reg_10bit <= std_logic_vector(to_unsigned(calc_val, 10));   -- แปลงเป็น 10-bit ยัดลง Flip-flop
                confirmed <= '1';                                           -- ส่งสัญญาณว่า "โหวตแล้ว/ตั้งค่าแล้ว!"
            end if;
        end if;
    end process;
end Behavioral;
