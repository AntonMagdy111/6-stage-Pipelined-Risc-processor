--------------------------------------------------------------------------
-- Memory.vhd
-- 4096 x 32-bit Von Neumann memory.
-- Single storage array, dual-edge access:
--   * Instruction port reads combinationally (so fetch sees data the same
--     cycle PC is presented).
--   * Data port reads combinationally when d_re=1, writes on falling edge.
--
-- The memory file is plain text, one 32-bit binary word per line.
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use work.cpu_pkg.all;

entity Memory is
    generic(
        MEM_FILE : string := "program.mem"
    );
    port(
        clk    : in  std_logic;
        rst    : in  std_logic;
        i_addr : in  std_logic_vector(ADDR_W-1 downto 0);
        i_data : out std_logic_vector(DATA_W-1 downto 0);
        d_addr : in  std_logic_vector(ADDR_W-1 downto 0);
        d_we   : in  std_logic;
        d_re   : in  std_logic;
        d_in   : in  std_logic_vector(DATA_W-1 downto 0);
        d_out  : out std_logic_vector(DATA_W-1 downto 0);
        vec_addr : in  std_logic_vector(ADDR_W-1 downto 0);
        vec_data : out std_logic_vector(DATA_W-1 downto 0);
        -- Always reads M[0]; used for reset-vector load. This port is
        -- guaranteed not to depend on any external address bus so it is
        -- stable even when PC is unknown at time 0.
        rst_vec : out std_logic_vector(DATA_W-1 downto 0)
    );
end Memory;

architecture rtl of Memory is
    type mem_t is array (0 to 4095) of std_logic_vector(DATA_W-1 downto 0);

    impure function load_mem(file_name : string) return mem_t is
        file mem_file     : text;
        variable line_buf : line;
        variable word     : std_logic_vector(DATA_W-1 downto 0);
        variable mem_var  : mem_t := (others => (others => '0'));
        variable idx      : integer := 0;
        variable status   : file_open_status;
    begin
        file_open(status, mem_file, file_name, read_mode);
        if status /= open_ok then
            report "Could not open memory file: " & file_name severity warning;
            return mem_var;
        end if;
        while not endfile(mem_file) and idx < 4096 loop
            readline(mem_file, line_buf);
            if line_buf'length > 0 then
                read(line_buf, word);
                mem_var(idx) := word;
                idx := idx + 1;
            end if;
        end loop;
        file_close(mem_file);
        return mem_var;
    end function;

    signal mem : mem_t := load_mem(MEM_FILE);
begin
    i_data <= mem(safe_int(i_addr));
    d_out  <= mem(safe_int(d_addr)) when d_re = '1'
              else (others => '0');
    vec_data <= mem(safe_int(vec_addr));
    rst_vec <= mem(0);

    process(clk)
    begin
        if falling_edge(clk) then
            if d_we = '1' then
                mem(safe_int(d_addr)) <= d_in;
            end if;
        end if;
    end process;
end rtl;
