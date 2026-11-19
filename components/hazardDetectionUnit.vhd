--------------------------------------------------------------------------
-- hazardDetectionUnit.vhd
-- Detects load-use / pop-use / in-use RAW hazards between ID and EX1.
--
-- Because MEM-stage data (LDD/POP/IN) is forwarded combinationally from
-- EX2/MEM (mem_wb_data) directly into EX1, a dependent instruction only
-- requires a 1-cycle stall when the producer (LDD/POP/IN) is in ID/EX1.
--
-- Crucial gating rules:
--   1. Only active when IF/ID holds a valid instruction (ifid_valid = '1'),
--      preventing bubbles from stalling the pipeline.
--   2. Source register matches are gated by id_uses_a and id_uses_b,
--      eliminating spurious stalls on R0 (encoding "000") for instructions
--      that do not read rs1 or rs2, while properly catching STD store-data
--      (rs2) and SWAP Rdst dependencies.
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity hazardDetectionUnit is
    port(
        ifid_valid     : in  std_logic;
        id_src_a       : in  std_logic_vector(REG_W-1 downto 0);
        id_src_b       : in  std_logic_vector(REG_W-1 downto 0);
        id_uses_a      : in  std_logic;
        id_uses_b      : in  std_logic;

        id_ex1_valid   : in  std_logic;
        id_ex1_rdst    : in  std_logic_vector(REG_W-1 downto 0);
        id_ex1_wb_sel  : in  std_logic_vector(1 downto 0);
        id_ex1_in_en   : in  std_logic;

        load_use_stall : out std_logic;
        stall          : out std_logic
    );
end hazardDetectionUnit;

architecture rtl of hazardDetectionUnit is
    signal lu : std_logic;
begin
    process(all)
    begin
        lu <= '0';
        if ifid_valid = '1'
           and id_ex1_valid = '1'
           and (id_ex1_wb_sel = WB_MEM or id_ex1_in_en = '1')
           and ((id_uses_a = '1' and id_ex1_rdst = id_src_a)
                or (id_uses_b = '1' and id_ex1_rdst = id_src_b)) then
            lu <= '1';
        end if;
    end process;

    load_use_stall <= lu;
    stall          <= lu;
end rtl;
