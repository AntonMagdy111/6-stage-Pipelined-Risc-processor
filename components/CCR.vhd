-- ==========================================================================
-- Project : 6-Stage Pipelined 32-Bit Von Neumann RISC Processor
-- Author  : Anton Magdy (@AntonMagdy111) - https://github.com/AntonMagdy111
-- Repo    : https://github.com/AntonMagdy111/6-stage-Pipelined-Risc-processor
-- License : Apache-2.0 (see LICENSE and NOTICE for mandatory attribution)
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Anton Magdy. All rights reserved.
-- ==========================================================================
--------------------------------------------------------------------------
-- CCR.vhd
-- Condition Code Register. 3 bits: Z=bit0, N=bit1, C=bit2.
--   upd_zn      : if 1, latch z_in/n_in
--   upd_c       : if 1, latch c_in
--   set_c       : if 1, force C <- 1 (SETC instruction)
--   save_ccr    : push current CCR onto internal shadow stack (INT / INTR)
--   restore_ccr : pop saved CCR from internal shadow stack (RTI)
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity CCR is
    port(
        clk         : in  std_logic;
        rst         : in  std_logic;
        upd_zn      : in  std_logic;
        upd_c       : in  std_logic;
        set_c       : in  std_logic;
        save_ccr    : in  std_logic;
        restore_ccr : in  std_logic;
        z_in        : in  std_logic;
        n_in        : in  std_logic;
        c_in        : in  std_logic;
        ccr_out     : out std_logic_vector(2 downto 0)
    );
end CCR;

architecture rtl of CCR is
    type ccr_stk_t is array (0 to 7) of std_logic_vector(2 downto 0);
    signal ccr_r   : std_logic_vector(2 downto 0) := (others => '0');
    signal ccr_stk : ccr_stk_t := (others => (others => '0'));
    signal stk_ptr : integer range 0 to 8 := 0;
begin
    process(clk, rst)
    begin
        if rst = '1' then
            ccr_r   <= (others => '0');
            ccr_stk <= (others => (others => '0'));
            stk_ptr <= 0;
        elsif rising_edge(clk) then
            if save_ccr = '1' then
                if stk_ptr < 8 then
                    ccr_stk(stk_ptr) <= ccr_r;
                    stk_ptr          <= stk_ptr + 1;
                end if;
            elsif restore_ccr = '1' then
                if stk_ptr > 0 then
                    ccr_r   <= ccr_stk(stk_ptr - 1);
                    stk_ptr <= stk_ptr - 1;
                end if;
            else
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
        end if;
    end process;
    ccr_out <= ccr_r;
end rtl;
