-- ==========================================================================
-- Project : 6-Stage Pipelined 32-Bit Von Neumann RISC Processor
-- Author  : Anton Magdy (@AntonMagdy111) - https://github.com/AntonMagdy111
-- Repo    : https://github.com/AntonMagdy111/6-stage-Pipelined-Risc-processor
-- License : Apache-2.0 (see LICENSE and NOTICE for mandatory attribution)
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Anton Magdy. All rights reserved.
-- ==========================================================================
--------------------------------------------------------------------------
-- forwardingUnit.vhd
-- Strictly age-ordered data forwarding for EX1 operands A, B, and Store.
--
-- Unified 3-bit selector encoding (newest to oldest):
--   "000" : ID/EX1 register file value (no forwarding)
--   "001" : EX1/EX2 primary result (ALU or LDM immediate)
--   "010" : EX1/EX2 SWAP secondary value (old Rdst -> Rs2)
--   "011" : EX2/MEM primary result (ALU / LDM imm / LDD&POP mem / IN port)
--   "100" : EX2/MEM SWAP secondary value
--   "101" : MEM/WB  primary result
--   "110" : MEM/WB  SWAP secondary value
--
-- Using a single age-ordered selector prevents stale SWAP secondary writes
-- in MEM/WB from overriding newer writes to the same register in EX1/EX2
-- or EX2/MEM.
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity forwardingUnit is
    port(
        id_ex1_rs1       : in  std_logic_vector(REG_W-1 downto 0);
        id_ex1_rs2       : in  std_logic_vector(REG_W-1 downto 0);
        id_ex1_use_imm   : in  std_logic;

        ex1_ex2_valid    : in  std_logic;
        ex1_ex2_we       : in  std_logic;
        ex1_ex2_rdst     : in  std_logic_vector(REG_W-1 downto 0);
        ex1_ex2_is_swap  : in  std_logic;
        ex1_ex2_swap_rs2 : in  std_logic_vector(REG_W-1 downto 0);

        ex2_mem_valid    : in  std_logic;
        ex2_mem_we       : in  std_logic;
        ex2_mem_rdst     : in  std_logic_vector(REG_W-1 downto 0);
        swap_we          : in  std_logic;
        swap_addr        : in  std_logic_vector(REG_W-1 downto 0);

        mem_wb_valid     : in  std_logic;
        mem_wb_we        : in  std_logic;
        mem_wb_rdst      : in  std_logic_vector(REG_W-1 downto 0);
        mw_swap_we       : in  std_logic;
        mw_swap_addr     : in  std_logic_vector(REG_W-1 downto 0);

        sel_a            : out std_logic_vector(2 downto 0);
        sel_b            : out std_logic_vector(2 downto 0);
        sel_store        : out std_logic_vector(2 downto 0)
    );
end forwardingUnit;

architecture rtl of forwardingUnit is
    function resolve_fwd(
        src              : std_logic_vector(REG_W-1 downto 0);
        e12_v, e12_we    : std_logic;
        e12_rd           : std_logic_vector(REG_W-1 downto 0);
        e12_sw           : std_logic;
        e12_sw_r         : std_logic_vector(REG_W-1 downto 0);
        e2m_v, e2m_we    : std_logic;
        e2m_rd           : std_logic_vector(REG_W-1 downto 0);
        m_sw_we          : std_logic;
        m_sw_r           : std_logic_vector(REG_W-1 downto 0);
        mw_v, mw_we      : std_logic;
        mw_rd            : std_logic_vector(REG_W-1 downto 0);
        wb_sw_we         : std_logic;
        wb_sw_r          : std_logic_vector(REG_W-1 downto 0)
    ) return std_logic_vector is
    begin
        -- Age 1 (youngest): EX1/EX2
        if e12_v = '1' and e12_we = '1' and e12_rd = src then
            return "001";
        elsif e12_v = '1' and e12_sw = '1' and e12_sw_r = src then
            return "010";
        -- Age 2: EX2/MEM (MEM stage)
        elsif e2m_v = '1' and e2m_we = '1' and e2m_rd = src then
            return "011";
        elsif m_sw_we = '1' and m_sw_r = src then
            return "100";
        -- Age 3 (oldest): MEM/WB (WB stage)
        elsif mw_v = '1' and mw_we = '1' and mw_rd = src then
            return "101";
        elsif mw_v = '1' and wb_sw_we = '1' and wb_sw_r = src then
            return "110";
        else
            return "000";
        end if;
    end function;
begin
    sel_a <= resolve_fwd(
        id_ex1_rs1,
        ex1_ex2_valid, ex1_ex2_we, ex1_ex2_rdst, ex1_ex2_is_swap, ex1_ex2_swap_rs2,
        ex2_mem_valid, ex2_mem_we, ex2_mem_rdst, swap_we, swap_addr,
        mem_wb_valid,  mem_wb_we,  mem_wb_rdst,  mw_swap_we, mw_swap_addr
    );

    sel_b <= "000" when id_ex1_use_imm = '1' else resolve_fwd(
        id_ex1_rs2,
        ex1_ex2_valid, ex1_ex2_we, ex1_ex2_rdst, ex1_ex2_is_swap, ex1_ex2_swap_rs2,
        ex2_mem_valid, ex2_mem_we, ex2_mem_rdst, swap_we, swap_addr,
        mem_wb_valid,  mem_wb_we,  mem_wb_rdst,  mw_swap_we, mw_swap_addr
    );

    -- Store path always reads id_ex1_rs2 (even when use_imm = '1', e.g., STD)
    sel_store <= resolve_fwd(
        id_ex1_rs2,
        ex1_ex2_valid, ex1_ex2_we, ex1_ex2_rdst, ex1_ex2_is_swap, ex1_ex2_swap_rs2,
        ex2_mem_valid, ex2_mem_we, ex2_mem_rdst, swap_we, swap_addr,
        mem_wb_valid,  mem_wb_we,  mem_wb_rdst,  mw_swap_we, mw_swap_addr
    );
end rtl;
