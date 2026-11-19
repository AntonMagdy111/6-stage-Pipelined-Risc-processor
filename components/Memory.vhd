-- ==========================================================================
-- Project : 6-Stage Pipelined 32-Bit Von Neumann RISC Processor
-- Author  : Anton Magdy (@AntonMagdy111) - https://github.com/AntonMagdy111
-- Repo    : https://github.com/AntonMagdy111/6-stage-Pipelined-Risc-processor
-- License : Apache-2.0 (see LICENSE and NOTICE for mandatory attribution)
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Anton Magdy. All rights reserved.
-- ==========================================================================
--------------------------------------------------------------------------
-- Memory.vhd
-- 4096 x 32-bit Von Neumann memory (single-edge rising-clock write).
--   * Instruction port reads combinationally (fetch sees data same cycle).
--   * Data port reads combinationally when d_re=1, writes on rising edge
--     (guarded by rst='0'), eliminating half-cycle falling-edge timing paths.
--   * Vector port reads interrupt vectors M[1] / M[2+idx] combinationally.
--   * Reset-vector port continuously exposes M[0].
--   * Simulation file initialization is guarded by synthesis pragmas so
--     synthesis tools (Precision RTL / Quartus / Vivado / DC) cleanly infer
--     memory storage without choking on std.textio file I/O.
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- synthesis translate_off
use std.textio.all;
use ieee.std_logic_textio.all;
-- synthesis translate_on
use work.cpu_pkg.all;

entity Memory is
    generic(
        MEM_FILE : string  := "program.mem";
        SIM_INIT : boolean := true
    );
    port(
        clk      : in  std_logic;
        rst      : in  std_logic;
        i_addr   : in  std_logic_vector(ADDR_W-1 downto 0);
        i_data   : out std_logic_vector(DATA_W-1 downto 0);
        d_addr   : in  std_logic_vector(ADDR_W-1 downto 0);
        d_we     : in  std_logic;
        d_re     : in  std_logic;
        d_in     : in  std_logic_vector(DATA_W-1 downto 0);
        d_out    : out std_logic_vector(DATA_W-1 downto 0);
        vec_addr : in  std_logic_vector(ADDR_W-1 downto 0);
        vec_data : out std_logic_vector(DATA_W-1 downto 0);
        rst_vec  : out std_logic_vector(DATA_W-1 downto 0)
    );
end Memory;

architecture rtl of Memory is
    type mem_t is array (0 to 4095) of std_logic_vector(DATA_W-1 downto 0);

    impure function load_mem(file_name : string) return mem_t is
        variable mem_var  : mem_t := (others => (others => '0'));
        -- synthesis translate_off
        file mem_file     : text;
        variable line_buf : line;
        variable word     : std_logic_vector(DATA_W-1 downto 0);
        variable idx      : integer := 0;
        variable status   : file_open_status;
        -- synthesis translate_on
    begin
        -- synthesis translate_off
        if SIM_INIT then
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
        end if;
        -- synthesis translate_on
        return mem_var;
    end function;

    signal mem : mem_t := load_mem(MEM_FILE);
begin
    i_data   <= mem(safe_int(i_addr));
    d_out    <= mem(safe_int(d_addr)) when d_re = '1' else (others => '0');
    vec_data <= mem(safe_int(vec_addr));
    rst_vec  <= mem(0);

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '0' and d_we = '1' then
                mem(safe_int(d_addr)) <= d_in;
            end if;
        end if;
    end process;
end rtl;
