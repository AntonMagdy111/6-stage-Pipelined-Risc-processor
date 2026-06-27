--------------------------------------------------------------------------
-- EX2_MEM.vhd
-- Pipeline register between Execute-2 and Memory stages.
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity EX2_MEM is
    port(
        clk   : in std_logic;
        rst   : in std_logic;

        mem_addr_in : in std_logic_vector(DATA_W-1 downto 0);
        store_in    : in std_logic_vector(DATA_W-1 downto 0);
        alu_res_in  : in std_logic_vector(DATA_W-1 downto 0);
        imm_in      : in std_logic_vector(DATA_W-1 downto 0);
        rdst_in     : in std_logic_vector(REG_W-1 downto 0);
        rs2_in      : in std_logic_vector(REG_W-1 downto 0);
        op_in       : in std_logic_vector(4 downto 0);
        ctrl_in     : in ctrl_bundle;
        valid_in    : in std_logic;

        mem_addr_out : out std_logic_vector(DATA_W-1 downto 0);
        store_out    : out std_logic_vector(DATA_W-1 downto 0);
        alu_res_out  : out std_logic_vector(DATA_W-1 downto 0);
        imm_out      : out std_logic_vector(DATA_W-1 downto 0);
        rdst_out     : out std_logic_vector(REG_W-1 downto 0);
        rs2_out      : out std_logic_vector(REG_W-1 downto 0);
        op_out       : out std_logic_vector(4 downto 0);
        ctrl_out     : out ctrl_bundle;
        valid_out    : out std_logic
    );
end EX2_MEM;

architecture rtl of EX2_MEM is
    signal mem_addr_r, store_r, alu_res_r, imm_r : std_logic_vector(DATA_W-1 downto 0) := (others=>'0');
    signal rdst_r, rs2_r : std_logic_vector(REG_W-1 downto 0) := (others=>'0');
    signal op_r    : std_logic_vector(4 downto 0) := (others=>'0');
    signal ctrl_r  : ctrl_bundle := CTRL_NOP;
    signal valid_r : std_logic := '0';
begin
    process(clk, rst)
    begin
        if rst = '1' then
            mem_addr_r <= (others=>'0'); store_r <= (others=>'0');
            alu_res_r <= (others=>'0'); imm_r <= (others=>'0');
            rdst_r <= (others=>'0'); rs2_r <= (others=>'0');
            op_r <= (others=>'0');
            ctrl_r <= CTRL_NOP;
            valid_r <= '0';
        elsif rising_edge(clk) then
            mem_addr_r <= mem_addr_in; store_r <= store_in;
            alu_res_r <= alu_res_in; imm_r <= imm_in;
            rdst_r <= rdst_in; rs2_r <= rs2_in;
            op_r <= op_in;
            ctrl_r <= ctrl_in;
            valid_r <= valid_in;
        end if;
    end process;

    mem_addr_out <= mem_addr_r; store_out <= store_r;
    alu_res_out <= alu_res_r; imm_out <= imm_r;
    rdst_out <= rdst_r; rs2_out <= rs2_r;
    op_out <= op_r;
    ctrl_out <= ctrl_r;
    valid_out <= valid_r;
end rtl;
