--------------------------------------------------------------------------
-- sp.vhd
-- Stack Pointer. Initial value 4095. Operations: hold / inc / dec.
--   sel = "00" hold, "01" inc, "10" dec
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity sp is
    port(
        clk    : in  std_logic;
        rst    : in  std_logic;
        sel    : in  std_logic_vector(1 downto 0);
        sp_out : out std_logic_vector(DATA_W-1 downto 0)
    );
end sp;

architecture rtl of sp is
    signal sp_r : unsigned(DATA_W-1 downto 0) := to_unsigned(4095, DATA_W);
begin
    process(clk, rst)
    begin
        if rst = '1' then
            sp_r <= to_unsigned(4095, DATA_W);
        elsif rising_edge(clk) then
            case sel is
                when "01"   => sp_r <= sp_r + 1;
                when "10"   => sp_r <= sp_r - 1;
                when others => sp_r <= sp_r;
            end case;
        end if;
    end process;
    sp_out <= std_logic_vector(sp_r);
end rtl;
