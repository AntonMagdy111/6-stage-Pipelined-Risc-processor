--------------------------------------------------------------------------
-- RegisterFile.vhd
-- 8 x 32-bit register file.
--   - 2 read ports (combinational)
--   - 2 write ports (falling edge): port1 = normal WB, port2 = SWAP only
--   - Write-through bypass on both ports
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity RegisterFile is
    port(
        clk      : in  std_logic;
        rst      : in  std_logic;
        -- Primary write port (normal WB)
        we       : in  std_logic;
        wr_addr  : in  std_logic_vector(REG_W-1 downto 0);
        wr_data  : in  std_logic_vector(DATA_W-1 downto 0);
        -- Secondary write port (SWAP second write)
        we2      : in  std_logic;
        wr_addr2 : in  std_logic_vector(REG_W-1 downto 0);
        wr_data2 : in  std_logic_vector(DATA_W-1 downto 0);
        -- Read ports
        rd_addr1 : in  std_logic_vector(REG_W-1 downto 0);
        rd_addr2 : in  std_logic_vector(REG_W-1 downto 0);
        rd_data1 : out std_logic_vector(DATA_W-1 downto 0);
        rd_data2 : out std_logic_vector(DATA_W-1 downto 0);
        -- Observation
        r0_o,r1_o,r2_o,r3_o,r4_o,r5_o,r6_o,r7_o : out std_logic_vector(DATA_W-1 downto 0)
    );
end RegisterFile;

architecture rtl of RegisterFile is
    type ram_t is array (0 to 7) of std_logic_vector(DATA_W-1 downto 0);
    signal regs : ram_t := (others => (others => '0'));
begin
    process(clk, rst)
    begin
        if rst = '1' then
            regs <= (others => (others => '0'));
        elsif falling_edge(clk) then
            if we = '1' then
                regs(safe_int(wr_addr)) <= wr_data;
            end if;
            if we2 = '1' then
                regs(safe_int(wr_addr2)) <= wr_data2;
            end if;
        end if;
    end process;

    -- Read with write-through bypass (port1 has priority over port2)
    rd_data1 <= wr_data  when (we  = '1' and wr_addr  = rd_addr1) else
                wr_data2 when (we2 = '1' and wr_addr2 = rd_addr1) else
                regs(safe_int(rd_addr1));
    rd_data2 <= wr_data  when (we  = '1' and wr_addr  = rd_addr2) else
                wr_data2 when (we2 = '1' and wr_addr2 = rd_addr2) else
                regs(safe_int(rd_addr2));

    r0_o <= regs(0); r1_o <= regs(1); r2_o <= regs(2); r3_o <= regs(3);
    r4_o <= regs(4); r5_o <= regs(5); r6_o <= regs(6); r7_o <= regs(7);
end rtl;
