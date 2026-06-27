--------------------------------------------------------------------------
-- tb_Processor_100.vhd
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use work.cpu_pkg.all;

entity tb_Processor_100 is
    generic(
        TEST_NAME : string := "unnamed_test";
        EXP_R0 : std_logic_vector(31 downto 0) := x"00000000";
        EXP_R1 : std_logic_vector(31 downto 0) := x"00000000";
        EXP_R2 : std_logic_vector(31 downto 0) := x"00000000";
        EXP_R3 : std_logic_vector(31 downto 0) := x"00000000";
        EXP_R4 : std_logic_vector(31 downto 0) := x"00000000";
        EXP_R5 : std_logic_vector(31 downto 0) := x"00000000";
        EXP_R6 : std_logic_vector(31 downto 0) := x"00000000";
        EXP_R7 : std_logic_vector(31 downto 0) := x"00000000";
        EXP_SP : std_logic_vector(31 downto 0) := x"00000FFF";
        CHECK_AT : time := 20000 ns;
        IN_COUNT : integer := 0;
        IN_VAL0  : std_logic_vector(31 downto 0) := x"00001234";
        IN_VAL1  : std_logic_vector(31 downto 0) := x"00001234";
        IN_VAL2  : std_logic_vector(31 downto 0) := x"00001234";
        IN_VAL3  : std_logic_vector(31 downto 0) := x"00001234";
        IN_VAL4  : std_logic_vector(31 downto 0) := x"00001234";
        IN_VAL5  : std_logic_vector(31 downto 0) := x"00001234";
        IN_VAL6  : std_logic_vector(31 downto 0) := x"00001234";
        IN_VAL7  : std_logic_vector(31 downto 0) := x"00001234"
    );
end tb_Processor_100;

architecture sim of tb_Processor_100 is
    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal intr     : std_logic := '0';
    signal in_port  : std_logic_vector(DATA_W-1 downto 0) := x"00001234";
    signal out_port : std_logic_vector(DATA_W-1 downto 0);
    signal pc, sp   : std_logic_vector(DATA_W-1 downto 0);
    signal ccr      : std_logic_vector(2 downto 0);
    signal r0,r1,r2,r3,r4,r5,r6,r7 : std_logic_vector(DATA_W-1 downto 0);
    signal in_en_obs : std_logic;
    constant CLK_PERIOD : time := 10 ns;

    component Processor is
        generic(MEM_FILE : string := "program.mem");
        port(
            clk, rst, intr : in std_logic;
            in_port  : in  std_logic_vector(DATA_W-1 downto 0);
            out_port : out std_logic_vector(DATA_W-1 downto 0);
            pc_obs   : out std_logic_vector(DATA_W-1 downto 0);
            sp_obs   : out std_logic_vector(DATA_W-1 downto 0);
            ccr_obs  : out std_logic_vector(2 downto 0);
            r0_obs,r1_obs,r2_obs,r3_obs,
            r4_obs,r5_obs,r6_obs,r7_obs : out std_logic_vector(DATA_W-1 downto 0);
            in_en_obs : out std_logic
        );
    end component;

    procedure check(name : string; actual, expected : std_logic_vector; fail_count : inout integer) is
        variable l : line;
    begin
        if actual = expected then
            write(l, string'("  PASS ")); write(l, name);
            write(l, string'(" = 0x")); hwrite(l, actual);
        else
            write(l, string'("  FAIL ")); write(l, name);
            write(l, string'(" = 0x")); hwrite(l, actual);
            write(l, string'("  expected 0x")); hwrite(l, expected);
            fail_count := fail_count + 1;
        end if;
        writeline(output, l);
    end procedure;

begin
    U_DUT : Processor
        generic map(MEM_FILE => "program.mem")
        port map(clk=>clk, rst=>rst, intr=>intr, in_port=>in_port, out_port=>out_port,
                 pc_obs=>pc, sp_obs=>sp, ccr_obs=>ccr,
                 r0_obs=>r0, r1_obs=>r1, r2_obs=>r2, r3_obs=>r3,
                 r4_obs=>r4, r5_obs=>r5, r6_obs=>r6, r7_obs=>r7,
                 in_en_obs=>in_en_obs);

    clk_proc : process
    begin
        clk <= '0'; wait for CLK_PERIOD/2;
        clk <= '1'; wait for CLK_PERIOD/2;
    end process;

    in_seq_proc : process
        type in_array is array(0 to 7) of std_logic_vector(31 downto 0);
        variable seq : in_array;
        variable idx : integer := 0;
    begin
        seq(0):=IN_VAL0; seq(1):=IN_VAL1; seq(2):=IN_VAL2; seq(3):=IN_VAL3;
        seq(4):=IN_VAL4; seq(5):=IN_VAL5; seq(6):=IN_VAL6; seq(7):=IN_VAL7;
        if IN_COUNT > 0 then
            in_port <= seq(0); idx := 1;
            loop
                wait until rising_edge(clk);
                if in_en_obs = '1' and idx < IN_COUNT then
                    in_port <= seq(idx); idx := idx + 1;
                end if;
                exit when idx >= IN_COUNT;
            end loop;
        end if;
        wait;
    end process;

    main : process
        variable fails : integer := 0;
        variable l : line;
    begin
        rst <= '1'; wait for CLK_PERIOD * 3; rst <= '0';
        wait for CHECK_AT;
        write(l, string'("==== Self-check ")); write(l, TEST_NAME);
        write(l, string'(" at ")); write(l, now); write(l, string'(" ===="));
        writeline(output, l);
        check("R0", r0, EXP_R0, fails); check("R1", r1, EXP_R1, fails);
        check("R2", r2, EXP_R2, fails); check("R3", r3, EXP_R3, fails);
        check("R4", r4, EXP_R4, fails); check("R5", r5, EXP_R5, fails);
        check("R6", r6, EXP_R6, fails); check("R7", r7, EXP_R7, fails);
        check("SP", sp, EXP_SP, fails);
        if fails = 0 then
            report "AUTO-RESULT: PASS " & TEST_NAME severity note;
        else
            report "AUTO-RESULT: FAIL " & TEST_NAME severity note;
        end if;
        wait;
    end process;
end sim;
