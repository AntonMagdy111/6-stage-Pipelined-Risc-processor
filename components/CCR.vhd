--------------------------------------------------------------------------
-- CCR.vhd
-- Condition Code Register. 3 bits: Z=bit0, N=bit1, C=bit2.
--   upd_zn  : if 1, latch z_in/n_in
--   upd_c   : if 1, latch c_in
--   set_c   : if 1, force C <- 1 (SETC instruction)
-- The (upd_zn, upd_c) signals come from the EX2 stage along with the
-- ALU's flags.
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity CCR is
    port(
        clk     : in  std_logic;
        rst     : in  std_logic;
        upd_zn  : in  std_logic;
        upd_c   : in  std_logic;
        set_c   : in  std_logic;
        z_in    : in  std_logic;
        n_in    : in  std_logic;
        c_in    : in  std_logic;
        ccr_out : out std_logic_vector(2 downto 0)
    );
end CCR;

architecture rtl of CCR is
    signal ccr_r : std_logic_vector(2 downto 0) := (others => '0');
begin
    process(clk, rst)
    begin
        if rst = '1' then
            ccr_r <= (others => '0');
        elsif rising_edge(clk) then
            if upd_zn = '1' then
                ccr_r(0) <= z_in;
                ccr_r(1) <= n_in;
            end if;
            if upd_c = '1' then
                ccr_r(2) <= c_in;
            end if;
            if set_c = '1' then
                ccr_r(2) <= '1';
            end if;
        end if;
    end process;
    ccr_out <= ccr_r;
end rtl;
