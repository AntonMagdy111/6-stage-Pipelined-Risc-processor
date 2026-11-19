--------------------------------------------------------------------------
-- decodeStage.vhd
--
-- Owns: instruction-field extraction, control-unit instantiation, and
-- the register-file read ports. Builds the bundle that feeds ID/EX1.
--
-- Encoding (instruction is 16 bits):
--   ir(15:11) = opcode
--   ir(10: 8) = Rdst
--   ir( 7: 5) = Rs1
--   ir( 4: 2) = Rs2
--
-- Register-file read-port mapping:
--   * Most ops:        rd_addr1 = Rs1, rd_addr2 = Rs2.
--   * SWAP Rdst, Rsrc: rd_addr1 = Rs2 (Rsrc -> operand A -> written to Rdst),
--                      rd_addr2 = Rdst (old Rdst -> store -> written to Rs2).
--   * rs1_o / rs2_o preserve the raw instruction fields so downstream stages
--     (SWAP secondary WB in MEM) know the target Rs2 register, while
--     rd_addr1_o / rd_addr2_o feed both the RegisterFile and Hazard Unit.
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity decodeStage is
    port(
        ir            : in  std_logic_vector(INSTR_W-1 downto 0);
        rd_addr1_o    : out std_logic_vector(REG_W-1 downto 0);
        rd_addr2_o    : out std_logic_vector(REG_W-1 downto 0);
        rd_data1      : in  std_logic_vector(DATA_W-1 downto 0);
        rd_data2      : in  std_logic_vector(DATA_W-1 downto 0);
        imm_in        : in  std_logic_vector(DATA_W-1 downto 0);
        opcode_o      : out std_logic_vector(4 downto 0);
        rdst_o        : out std_logic_vector(REG_W-1 downto 0);
        rs1_o         : out std_logic_vector(REG_W-1 downto 0);
        rs2_o         : out std_logic_vector(REG_W-1 downto 0);
        a_o           : out std_logic_vector(DATA_W-1 downto 0);
        b_o           : out std_logic_vector(DATA_W-1 downto 0);
        store_o       : out std_logic_vector(DATA_W-1 downto 0);
        ctrl_o        : out ctrl_bundle;
        cu_needs_imm  : out std_logic
    );
end decodeStage;

architecture rtl of decodeStage is
    signal opcode : std_logic_vector(4 downto 0);
    signal rdst, rs1, rs2 : std_logic_vector(REG_W-1 downto 0);
    signal cu : ctrl_bundle;
    signal needs_imm : std_logic;

    component controlUnit is
        port(
            opcode    : in  std_logic_vector(4 downto 0);
            reg_we    : out std_logic; mem_re : out std_logic; mem_we : out std_logic;
            alu_op    : out std_logic_vector(3 downto 0);
            use_imm   : out std_logic; uses_rs1 : out std_logic; uses_rs2 : out std_logic;
            is_branch : out std_logic; is_jump : out std_logic;
            wb_sel    : out std_logic_vector(1 downto 0);
            sp_op     : out std_logic_vector(1 downto 0);
            needs_imm : out std_logic;
            out_en    : out std_logic; in_en : out std_logic;
            set_c     : out std_logic; halt : out std_logic;
            upd_zn    : out std_logic; upd_c : out std_logic;
            is_swap   : out std_logic; is_push : out std_logic; is_pop : out std_logic;
            is_call   : out std_logic; is_ret : out std_logic;
            is_rti    : out std_logic; is_int : out std_logic
        );
    end component;
begin
    opcode <= ir(15 downto 11);
    rdst   <= ir(10 downto 8);
    rs1    <= ir(7 downto 5);
    rs2    <= ir(4 downto 2);

    opcode_o <= opcode;
    rdst_o   <= rdst;
    rs1_o    <= rs1;
    rs2_o    <= rs2;

    rd_addr1_o <= rs2  when opcode = OP_SWAP else rs1;
    rd_addr2_o <= rdst when opcode = OP_SWAP else rs2;

    U_CU : controlUnit
        port map(
            opcode => opcode,
            reg_we => cu.reg_we, mem_re => cu.mem_re, mem_we => cu.mem_we,
            alu_op => cu.alu_op, use_imm => cu.use_imm,
            uses_rs1 => cu.uses_rs1, uses_rs2 => cu.uses_rs2,
            is_branch => cu.is_branch, is_jump => cu.is_jump,
            wb_sel => cu.wb_sel, sp_op => cu.sp_op,
            needs_imm => needs_imm,
            out_en => cu.out_en, in_en => cu.in_en,
            set_c => cu.set_c, halt => cu.halt,
            upd_zn => cu.upd_zn, upd_c => cu.upd_c,
            is_swap => cu.is_swap, is_push => cu.is_push, is_pop => cu.is_pop,
            is_call => cu.is_call, is_ret => cu.is_ret,
            is_rti => cu.is_rti, is_int => cu.is_int
        );

    ctrl_o       <= cu;
    cu_needs_imm <= needs_imm;

    a_o     <= rd_data1;
    b_o     <= imm_in when cu.use_imm = '1' else rd_data2;
    store_o <= rd_data2;
end rtl;
