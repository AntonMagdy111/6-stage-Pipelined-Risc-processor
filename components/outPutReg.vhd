--------------------------------------------------------------------------
-- outPutReg.vhd
-- Latches the OUT.PORT value when an OUT instruction is in MEM.
-- Without latching, the bus would drop back to 0 after one cycle, which
-- is hard to read on the wave.
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity outPutReg is
    port(
        clk      : in  std_logic;
        rst      : in  std_logic;
        out_en   : in  std_logic;
        data_in  : in  std_logic_vector(DATA_W-1 downto 0);
        out_port : out std_logic_vector(DATA_W-1 downto 0)
    );
end outPutReg;

architecture rtl of outPutReg is
    signal q : std_logic_vector(DATA_W-1 downto 0) := (others=>'0');
begin
    process(clk, rst)
    begin
        if rst = '1' then
            q <= (others => '0');
        elsif rising_edge(clk) then
            if out_en = '1' then
                q <= data_in;
            end if;
        end if;
    end process;
    out_port <= q;
end rtl;
