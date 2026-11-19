--------------------------------------------------------------------------
-- hazardDetectionUnit.vhd
-- Detects unavoidable 1-cycle load-use / pop-use / in-use RAW hazards
-- between ID and EX1.
--
-- Stall conditions (strict theoretical minimum for this 6-stage pipeline):
--   1. Not suppressed by a simultaneous front flush (flush_in = '0').
--   2. IF/ID holds a valid instruction (ifid_valid = '1').
--   3. ID/EX1 holds a valid MEM-producing instruction (LDD, POP, or IN).
--   4. The ID instruction genuinely needs that register in EX1
--      (id_uses_a / id_uses_b_ex1). Note: PUSH, OUT, and STD store-data
--      only need their data register in MEM and are resolved with 0 stalls
--      via the WB -> MEM bypass path.
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity hazardDetectionUnit is
    port(
        flush_in       : in  std_logic;
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
        if flush_in = '0'
           and ifid_valid = '1'
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
