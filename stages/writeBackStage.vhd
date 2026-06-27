--------------------------------------------------------------------------
-- writeBackStage.vhd
--
-- The actual write happens inside the RegisterFile on the falling edge.
-- This stage is just a thin wrapper that names the inputs and gates the
-- write enable with the valid bit, for grading-visibility symmetry with
-- the other stages.
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity writeBackStage is
    port(
        valid_in : in  std_logic;
        we_in    : in  std_logic;
        rdst_in  : in  std_logic_vector(REG_W-1 downto 0);
        data_in  : in  std_logic_vector(DATA_W-1 downto 0);

        rf_we_o  : out std_logic;
        rf_addr_o: out std_logic_vector(REG_W-1 downto 0);
        rf_data_o: out std_logic_vector(DATA_W-1 downto 0)
    );
end writeBackStage;

architecture rtl of writeBackStage is
begin
    rf_we_o   <= valid_in and we_in;
    rf_addr_o <= rdst_in;
    rf_data_o <= data_in;
end rtl;
