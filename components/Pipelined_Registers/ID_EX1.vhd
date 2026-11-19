--------------------------------------------------------------------------
-- ID_EX1.vhd
-- Pipeline register between Decode and Execute-1.
--   en=0    -> hold
--   flush=1 -> clear to clean NOP bubble
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity ID_EX1 is
    port(
        clk   : in std_logic;
        rst   : in std_logic;
        en    : in std_logic;
        flush : in std_logic;

        a_in, b_in, store_in, imm_in, pcp1_in : in std_logic_vector(DATA_W-1 downto 0);
        rdst_in, rs1_in, rs2_in : in std_logic_vector(REG_W-1 downto 0);
        op_in          : in std_logic_vector(4 downto 0);
        pred_taken_in  : in std_logic;
        pred_pc_in     : in std_logic_vector(DATA_W-1 downto 0);
        pred_target_in : in std_logic_vector(DATA_W-1 downto 0);
        ctrl_in        : in ctrl_bundle;
        valid_in       : in std_logic;

        a_out, b_out, store_out, imm_out, pcp1_out : out std_logic_vector(DATA_W-1 downto 0);
        rdst_out, rs1_out, rs2_out : out std_logic_vector(REG_W-1 downto 0);
        op_out          : out std_logic_vector(4 downto 0);
        pred_taken_out  : out std_logic;
        pred_pc_out     : out std_logic_vector(DATA_W-1 downto 0);
        pred_target_out : out std_logic_vector(DATA_W-1 downto 0);
        ctrl_out        : out ctrl_bundle;
        valid_out       : out std_logic
    );
end ID_EX1;

architecture rtl of ID_EX1 is
    signal a_r, b_r, store_r, imm_r, pcp1_r : std_logic_vector(DATA_W-1 downto 0) := (others => '0');
    signal rdst_r, rs1_r, rs2_r : std_logic_vector(REG_W-1 downto 0) := (others => '0');
    signal op_r          : std_logic_vector(4 downto 0) := (others => '0');
    signal pred_taken_r  : std_logic := '0';
    signal pred_pc_r     : std_logic_vector(DATA_W-1 downto 0) := (others => '0');
    signal pred_target_r : std_logic_vector(DATA_W-1 downto 0) := (others => '0');
    signal ctrl_r        : ctrl_bundle := CTRL_NOP;
    signal valid_r       : std_logic := '0';
begin
    process(clk, rst)
    begin
        if rst = '1' then
            a_r <= (others => '0'); b_r <= (others => '0');
            store_r <= (others => '0'); imm_r <= (others => '0');
            pcp1_r <= (others => '0');
            rdst_r <= (others => '0'); rs1_r <= (others => '0'); rs2_r <= (others => '0');
            op_r <= (others => '0');
            pred_taken_r <= '0'; pred_pc_r <= (others => '0'); pred_target_r <= (others => '0');
            ctrl_r <= CTRL_NOP;
            valid_r <= '0';
        elsif rising_edge(clk) then
            if flush = '1' then
                rdst_r <= (others => '0'); rs1_r <= (others => '0'); rs2_r <= (others => '0');
                op_r <= (others => '0');
                pred_taken_r <= '0'; pred_pc_r <= (others => '0'); pred_target_r <= (others => '0');
                ctrl_r <= CTRL_NOP;
                valid_r <= '0';
            elsif en = '1' then
                a_r <= a_in; b_r <= b_in; store_r <= store_in;
                imm_r <= imm_in; pcp1_r <= pcp1_in;
                rdst_r <= rdst_in; rs1_r <= rs1_in; rs2_r <= rs2_in;
                op_r <= op_in;
                pred_taken_r <= pred_taken_in;
                pred_pc_r <= pred_pc_in;
                pred_target_r <= pred_target_in;
                ctrl_r <= ctrl_in;
                valid_r <= valid_in;
            end if;
        end if;
    end process;

    a_out <= a_r; b_out <= b_r; store_out <= store_r;
    imm_out <= imm_r; pcp1_out <= pcp1_r;
    rdst_out <= rdst_r; rs1_out <= rs1_r; rs2_out <= rs2_r;
    op_out <= op_r;
    pred_taken_out <= pred_taken_r;
    pred_pc_out <= pred_pc_r;
    pred_target_out <= pred_target_r;
    ctrl_out <= ctrl_r;
    valid_out <= valid_r;
end rtl;
