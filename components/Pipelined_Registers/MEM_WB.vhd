-- ==========================================================================
-- Project : 6-Stage Pipelined 32-Bit Von Neumann RISC Processor
-- Author  : Anton Magdy (@AntonMagdy111) - https://github.com/AntonMagdy111
-- Repo    : https://github.com/AntonMagdy111/6-stage-Pipelined-Risc-processor
-- License : Apache-2.0 (see LICENSE and NOTICE for mandatory attribution)
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Anton Magdy. All rights reserved.
-- ==========================================================================
--------------------------------------------------------------------------
-- MEM_WB.vhd
-- Pipeline register between Memory and Write-Back stages.
-- Carries the primary WB value plus an optional SWAP second write.
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity MEM_WB is
    port(
        clk   : in std_logic;
        rst   : in std_logic;
        flush : in std_logic;   -- clear on pipeline redirect

        wb_data_in  : in std_logic_vector(DATA_W-1 downto 0);
        rdst_in     : in std_logic_vector(REG_W-1 downto 0);
        we_in       : in std_logic;
        valid_in    : in std_logic;
        -- SWAP second write
        swap_we_in   : in std_logic;
        swap_addr_in : in std_logic_vector(REG_W-1 downto 0);
        swap_data_in : in std_logic_vector(DATA_W-1 downto 0);

        wb_data_out  : out std_logic_vector(DATA_W-1 downto 0);
        rdst_out     : out std_logic_vector(REG_W-1 downto 0);
        we_out       : out std_logic;
        valid_out    : out std_logic;
        swap_we_out   : out std_logic;
        swap_addr_out : out std_logic_vector(REG_W-1 downto 0);
        swap_data_out : out std_logic_vector(DATA_W-1 downto 0)
    );
end MEM_WB;

architecture rtl of MEM_WB is
    signal wb_data_r  : std_logic_vector(DATA_W-1 downto 0) := (others=>'0');
    signal rdst_r     : std_logic_vector(REG_W-1 downto 0)  := (others=>'0');
    signal we_r, valid_r : std_logic := '0';
    signal swap_we_r   : std_logic := '0';
    signal swap_addr_r : std_logic_vector(REG_W-1 downto 0) := (others=>'0');
    signal swap_data_r : std_logic_vector(DATA_W-1 downto 0) := (others=>'0');
begin
    process(clk, rst)
    begin
        if rst = '1' then
            wb_data_r  <= (others=>'0');
            rdst_r     <= (others=>'0');
            we_r       <= '0';
            valid_r    <= '0';
            swap_we_r   <= '0';
            swap_addr_r <= (others=>'0');
            swap_data_r <= (others=>'0');
        elsif rising_edge(clk) then
            if flush = '1' then
                rdst_r      <= (others => '0');
                we_r        <= '0';
                valid_r     <= '0';
                swap_we_r   <= '0';
                swap_addr_r <= (others => '0');
            else
                wb_data_r  <= wb_data_in;
                rdst_r     <= rdst_in;
                we_r       <= we_in;
                valid_r    <= valid_in;
                swap_we_r   <= swap_we_in;
                swap_addr_r <= swap_addr_in;
                swap_data_r <= swap_data_in;
            end if;
        end if;
    end process;

    wb_data_out  <= wb_data_r;
    rdst_out     <= rdst_r;
    we_out       <= we_r;
    valid_out    <= valid_r;
    swap_we_out   <= swap_we_r;
    swap_addr_out <= swap_addr_r;
    swap_data_out <= swap_data_r;
end rtl;