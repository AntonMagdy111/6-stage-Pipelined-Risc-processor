--------------------------------------------------------------------------
-- EX1_EX2.vhd
-- Pipeline register between Execute-1 and Execute-2.
-- Carries: ALU result (becomes effective address for LDD/STD, or value
-- for arithmetic), store-data (forwarded), immediate (branch target),
-- PC+1 (return address), Rdst, Rs2 (for SWAP), opcode, ALU flags, and
-- the control bundle.
--   en is always 1 in this design (no stall after EX1).
--   flush=1 -> bubble (used on taken branch, but EX1/EX2 itself is the
--             *resolver*, so flushing this latch is normally not done).
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity EX1_EX2 is
    port(
        clk   : in std_logic;
        rst   : in std_logic;
        flush : in std_logic;

        alu_res_in   : in std_logic_vector(DATA_W-1 downto 0);
        store_in     : in std_logic_vector(DATA_W-1 downto 0);
        imm_in       : in std_logic_vector(DATA_W-1 downto 0);
        pcp1_in      : in std_logic_vector(DATA_W-1 downto 0);
        rdst_in      : in std_logic_vector(REG_W-1 downto 0);
        rs2_in       : in std_logic_vector(REG_W-1 downto 0);
        op_in        : in std_logic_vector(4 downto 0);
        z_in, n_in, c_in : in std_logic;
        ctrl_in      : in ctrl_bundle;
        valid_in     : in std_logic;

        alu_res_out  : out std_logic_vector(DATA_W-1 downto 0);
        store_out    : out std_logic_vector(DATA_W-1 downto 0);
        imm_out      : out std_logic_vector(DATA_W-1 downto 0);
        pcp1_out     : out std_logic_vector(DATA_W-1 downto 0);
        rdst_out     : out std_logic_vector(REG_W-1 downto 0);
        rs2_out      : out std_logic_vector(REG_W-1 downto 0);
        op_out       : out std_logic_vector(4 downto 0);
        z_out, n_out, c_out : out std_logic;
        ctrl_out     : out ctrl_bundle;
        valid_out    : out std_logic
    );
end EX1_EX2;

architecture rtl of EX1_EX2 is
    signal alu_res_r, store_r, imm_r, pcp1_r : std_logic_vector(DATA_W-1 downto 0) := (others=>'0');
    signal rdst_r, rs2_r : std_logic_vector(REG_W-1 downto 0) := (others=>'0');
    signal op_r          : std_logic_vector(4 downto 0)  := (others=>'0');
    signal z_r, n_r, c_r : std_logic := '0';
    signal ctrl_r        : ctrl_bundle := CTRL_NOP;
    signal valid_r       : std_logic := '0';
begin
    process(clk, rst)
    begin
        if rst = '1' then
            alu_res_r <= (others=>'0'); store_r <= (others=>'0');
            imm_r <= (others=>'0'); pcp1_r <= (others=>'0');
            rdst_r <= (others=>'0'); rs2_r <= (others=>'0');
            op_r <= (others=>'0');
            z_r <= '0'; n_r <= '0'; c_r <= '0';
            ctrl_r <= CTRL_NOP;
            valid_r <= '0';
        elsif rising_edge(clk) then
            if flush = '1' then
                valid_r <= '0';
                ctrl_r  <= CTRL_NOP;
            else
                alu_res_r <= alu_res_in; store_r <= store_in;
                imm_r <= imm_in; pcp1_r <= pcp1_in;
                rdst_r <= rdst_in; rs2_r <= rs2_in;
                op_r <= op_in;
                z_r <= z_in; n_r <= n_in; c_r <= c_in;
                ctrl_r <= ctrl_in;
                valid_r <= valid_in;
            end if;
        end if;
    end process;

    alu_res_out <= alu_res_r; store_out <= store_r;
    imm_out <= imm_r; pcp1_out <= pcp1_r;
    rdst_out <= rdst_r; rs2_out <= rs2_r;
    op_out <= op_r;
    z_out <= z_r; n_out <= n_r; c_out <= c_r;
    ctrl_out <= ctrl_r;
    valid_out <= valid_r;
end rtl;
