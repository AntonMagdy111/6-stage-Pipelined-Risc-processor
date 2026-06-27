--------------------------------------------------------------------------
-- alu.vhd
-- 32-bit ALU.
--   ADD:  a + b      , updates Z, N, C
--   SUB:  a - b      , updates Z, N, C
--   AND:  a AND b    , updates Z, N
--   NOT:  NOT b      , updates Z, N
--   INC:  b + 1      , updates Z, N, C
--   PASS: b          , no flag update
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity alu is
    port(
        a, b   : in  std_logic_vector(DATA_W-1 downto 0);
        op     : in  std_logic_vector(3 downto 0);
        result : out std_logic_vector(DATA_W-1 downto 0);
        z_flag : out std_logic;
        n_flag : out std_logic;
        c_flag : out std_logic
    );
end alu;

architecture rtl of alu is
    signal res    : std_logic_vector(DATA_W-1 downto 0);
    signal carry  : std_logic;
    signal a_ext, b_ext : unsigned(DATA_W downto 0);
    signal sum_ext, sub_ext, inc_ext : unsigned(DATA_W downto 0);
begin
    a_ext   <= '0' & unsigned(a);
    b_ext   <= '0' & unsigned(b);
    sum_ext <= a_ext + b_ext;
    sub_ext <= a_ext - b_ext;
    inc_ext <= b_ext + 1;

    process(all)
    begin
        carry <= '0';
        case op is
            when ALU_ADD =>
                res   <= std_logic_vector(sum_ext(DATA_W-1 downto 0));
                carry <= sum_ext(DATA_W);
            when ALU_SUB =>
                res   <= std_logic_vector(sub_ext(DATA_W-1 downto 0));
                carry <= sub_ext(DATA_W);
            when ALU_INC =>
                res   <= std_logic_vector(inc_ext(DATA_W-1 downto 0));
                carry <= inc_ext(DATA_W);
            when ALU_AND  => res <= a and b;
            when ALU_NOT  => res <= not b;
            when ALU_PASS => res <= b;
            when ALU_PASS_A => res <= a;
            when others   => res <= (others => '0');
        end case;
    end process;

    result <= res;
    z_flag <= '1' when res = (res'range => '0') else '0';
    n_flag <= res(DATA_W-1);
    c_flag <= carry;
end rtl;
