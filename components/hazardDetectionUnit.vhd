library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity hazardDetectionUnit is
    port(
        id_rs1         : in std_logic_vector(REG_W-1 downto 0);
        id_rs2         : in std_logic_vector(REG_W-1 downto 0);
        id_use_imm     : in std_logic;
        id_is_branch   : in std_logic;
        id_ex1_valid   : in std_logic;
        id_ex1_rdst    : in std_logic_vector(REG_W-1 downto 0);
        id_ex1_wb_sel  : in std_logic_vector(1 downto 0);
        id_ex1_in_en   : in std_logic;
        ex1_ex2_valid  : in std_logic;
        ex1_ex2_rdst   : in std_logic_vector(REG_W-1 downto 0);
        ex1_ex2_wb_sel : in std_logic_vector(1 downto 0);
        ex1_ex2_in_en  : in std_logic;
        cu_needs_imm   : in std_logic;
        imm_pending    : in std_logic;
        -- ADD THESE FOUR PORTS
        id_ex1_is_swap   : in std_logic;
        id_ex1_rs2_addr  : in std_logic_vector(REG_W-1 downto 0);
        ex1_ex2_is_swap  : in std_logic;
        ex1_ex2_rs2_addr : in std_logic_vector(REG_W-1 downto 0);

        load_use_stall : out std_logic;
        imm_stall      : out std_logic;
        stall          : out std_logic
    );
end hazardDetectionUnit;

architecture rtl of hazardDetectionUnit is
    signal lu, lu2, im : std_logic;
begin
    process(all)
    begin
        lu <= '0';
        if id_ex1_valid = '1'
           and id_is_branch = '0'
           and (id_ex1_wb_sel = WB_MEM or id_ex1_in_en = '1')
           and (id_ex1_rdst = id_rs1
                or (id_use_imm = '0' and id_ex1_rdst = id_rs2)) then
            lu <= '1';
        end if;
    end process;

    process(all)
    begin
        lu2 <= '0';
        if ex1_ex2_valid = '1'
           and id_is_branch = '0'
           and (ex1_ex2_wb_sel = WB_MEM or ex1_ex2_in_en = '1')
           and (ex1_ex2_rdst = id_rs1
                or (id_use_imm = '0' and ex1_ex2_rdst = id_rs2)) then
            lu2 <= '1';
        end if;
    end process;

    im <= cu_needs_imm and not imm_pending;
    load_use_stall <= lu or lu2;
    imm_stall      <= im;
    stall          <= lu or lu2 or im;
end rtl;