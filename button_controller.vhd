library IEEE;                               -- เรียกใช้คลังเก็บข้อมูลมาตรฐาน
use IEEE.STD_LOGIC_1164.ALL;                -- ให้รู้จักตัวแปรประเภท 0, 1 (STD_LOGIC)
use IEEE.NUMERIC_STD.ALL;                   -- ให้สามารถบวกเลขคณิตศาสตร์ได้

entity button_controller is
    Generic ( CLK_FREQ : integer := 100_000_000 ); -- ตั้งค่าความเร็วบอร์ด Nexys A7 ที่ 100 MHz
    Port ( 
        clk     : in  STD_LOGIC;                    -- ขารับสัญญาณนาฬิกา
        rst     : in  STD_LOGIC;                    -- ขารับปุ่ม Reset
        btn_in  : in  STD_LOGIC_VECTOR(4 downto 0); -- ขารับสัญญาณปุ่มกด 5 ปุ่ม (ดิบๆ)
        btn_out : out STD_LOGIC_VECTOR(4 downto 0)  -- ขาส่งสัญญาณปุ่มที่กรองแล้วออกไป
    );
end button_controller;

architecture Behavioral of button_controller is
    -- คำนวณหาค่าสูงสุดของการหน่วงเวลา (เอา 100ล้าน หาร 50 = รอ 20 มิลลิวินาที)
    constant DEBOUNCE_MAX : integer := CLK_FREQ / 50; 
    signal counter : integer range 0 to DEBOUNCE_MAX := 0; -- ตัวนับเวลา
    
    -- ชุดตัวแปร D Flip-flop สำหรับพักข้อมูล ป้องกันจังหวะสัญญาณชนกัน (Metastability)
    signal btn_sync1, btn_sync2 : STD_LOGIC_VECTOR(4 downto 0) := (others => '0');
    signal btn_state : STD_LOGIC_VECTOR(4 downto 0) := (others => '0'); -- สถานะปุ่มปัจจุบันที่นิ่งแล้ว
    signal btn_prev  : STD_LOGIC_VECTOR(4 downto 0) := (others => '0'); -- สถานะปุ่มในอดีต (เสี้ยววิที่แล้ว)
begin
    process(clk, rst) -- เริ่มการทำงานทุกครั้งที่ Clock ขยับ หรือโดน Reset
    begin
        if rst = '1' then                     -- ถ้ายกสวิตช์ Reset
            counter <= 0;                     -- ล้างค่าตัวนับ
            btn_sync1 <= (others => '0');     -- ล้างค่าตัวพักสัญญาณชั้น 1
            btn_sync2 <= (others => '0');     -- ล้างค่าตัวพักสัญญาณชั้น 2
            btn_state <= (others => '0');     -- ล้างสถานะปุ่ม
            btn_prev  <= (others => '0');     -- ล้างสถานะอดีต
            btn_out   <= (others => '0');     -- ดับสัญญาณส่งออก
        elsif rising_edge(clk) then           -- ถ้า Clock ตีขึ้น (ทำงาน 100 ล้านครั้งต่อวิ)
            -- 1. Synchronize: ดึงสัญญาณดิบมาพัก 2 จังหวะ
            btn_sync1 <= btn_in;
            btn_sync2 <= btn_sync1;
            
            -- 2. Debounce: กรองการแกว่งของปุ่ม
            if btn_sync2 /= btn_state then        -- ถ้าปุ่มที่รับมา ต่างจากสถานะเดิม
                if counter < DEBOUNCE_MAX then    -- ให้นับเวลาเพิ่มขึ้นเรื่อยๆ
                    counter <= counter + 1;
                else                              -- ถ้านับจนครบ 20ms แล้ว (ปุ่มนิ่งแล้ว)
                    btn_state <= btn_sync2;       -- ให้จำค่าปุ่มนั้นเป็นสถานะปัจจุบัน
                    counter <= 0;                 -- รีเซ็ตตัวนับ
                end if;
            else                                  -- แต่ถ้าสัญญาณแกว่งกลับมาเหมือนเดิม
                counter <= 0;                     -- ให้เริ่มนับใหม่
            end if;
            
            -- 3. Edge Detection: ปล่อยสัญญาณพัลส์แค่ 1 Clock
            btn_prev <= btn_state;                -- เอาสถานะปัจจุบันไปเก็บเป็น "อดีต"
            for i in 0 to 4 loop                  -- ไล่เช็คทีละปุ่มตั้งแต่ 0 ถึง 4
                if btn_state(i) = '1' and btn_prev(i) = '0' then -- ถ้าปัจจุบันกด(1) แต่อดีตปล่อย(0)
                    btn_out(i) <= '1';            -- ส่งสัญญาณ "เพิ่งกด" ออกไป
                else
                    btn_out(i) <= '0';            -- นอกนั้นให้ดับให้หมด (แก้ปัญหากดปุ่มค้าง)
                end if;
            end loop;
        end if;
    end process;
end Behavioral;
