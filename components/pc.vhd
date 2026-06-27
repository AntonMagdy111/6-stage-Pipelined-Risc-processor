--------------------------------------------------------------------------
-- pc.vhd
-- Program Counter. Loaded with M[0] on reset. Otherwise either +1, +2,
-- or loaded with a target.
--   sel = "00" -> hold
--   sel = "01" -> pc + 1
--   sel = "10" -> pc + 2     (used after immediate-fetch)
--   sel = "11" -> load target_in
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity pc is
    port(
        clk        : in  std_logic;
        rst        : in  std_logic;
        sel        : in  std_logic_vector(1 downto 0);
        target_in  : in  std_logic_vector(DATA_W-1 downto 0);
        reset_vec  : in  std_logic_vector(DATA_W-1 downto 0); -- M[0]
        pc_out     : out std_logic_vector(DATA_W-1 downto 0)
    );
end pc;

architecture rtl of pc is
    signal pc_r : unsigned(DATA_W-1 downto 0) := (others => '0');
begin
    process(clk, rst)
    begin
        if rst = '1' then
            pc_r <= unsigned(reset_vec);
        elsif rising_edge(clk) then
            case sel is
                when "00" => pc_r <= pc_r;
                when "01" => pc_r <= pc_r + 1;
                when "10" => pc_r <= pc_r + 2;
                when "11" => pc_r <= unsigned(target_in);
                when others => pc_r <= pc_r;
            end case;
        end if;
    end process;
    pc_out <= std_logic_vector(pc_r);
end rtl;
