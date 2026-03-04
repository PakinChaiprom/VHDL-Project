entity main_fsm is
    Port (
        clk     : in std_logic;
        rst     : in std_logic;

        btn_center : in std_logic;

        state_out  : out std_logic_vector(7 downto 0)
    );
end main_fsm;

architecture behavioral of main_fsm is

    type state_type is (
        C1, C2, C3, C4, C5, C6,
        U0, U1, U2, U3, U4, U5, U6,
        A1, A2, A3, A4, A5, A6
    );

    signal current_state, next_state : state_type;

begin

    -- State register
    process(clk, rst)
    begin
        if rst = '1' then
            current_state <= C1;
        elsif rising_edge(clk) then
            current_state <= next_state;
        end if;
    end process;

    -- Next state logic (เติมภายหลัง)

end behavioral;
