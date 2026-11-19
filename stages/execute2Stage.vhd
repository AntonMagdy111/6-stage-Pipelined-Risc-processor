-- ==========================================================================
-- Project : 6-Stage Pipelined 32-Bit Von Neumann RISC Processor
-- Author  : Anton Magdy (@AntonMagdy111) - https://github.com/AntonMagdy111
-- Repo    : https://github.com/AntonMagdy111/6-stage-Pipelined-Risc-processor
-- License : Apache-2.0 (see LICENSE and NOTICE for mandatory attribution)
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Anton Magdy. All rights reserved.
-- ==========================================================================
--------------------------------------------------------------------------
-- execute2Stage.vhd
--
-- Owns: branch resolution against the predictor (direction AND target
-- verification), memory-address computation for STACK ops and LDD/STD,
-- pass-through of store/output data for SWAP and OUT, and driving the
-- branch-predictor & CCR updates.
--
-- Unconditional JMP/CALL are already steered with 0 bubbles in IF; only
-- conditional branches (JZ/JN/JC) allocate/update the 16-entry BTB.
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity execute2Stage is
    port(
        -- pipeline inputs (from EX1/EX2)
        valid_in       : in  std_logic;
        op_in          : in  std_logic_vector(4 downto 0);
        ctrl_in        : in  ctrl_bundle;
        alu_res_in     : in  std_logic_vector(DATA_W-1 downto 0);
        store_in       : in  std_logic_vector(DATA_W-1 downto 0);
        imm_in         : in  std_logic_vector(DATA_W-1 downto 0);
        pcp1_in        : in  std_logic_vector(DATA_W-1 downto 0);
        z_in, n_in, c_in : in std_logic;

        -- current SP (architectural, pre-update)
        sp_in          : in  std_logic_vector(DATA_W-1 downto 0);

        -- predictor info that travelled with the instruction
        pred_taken_in  : in  std_logic;
        pred_pc_in     : in  std_logic_vector(DATA_W-1 downto 0);
        pred_target_in : in  std_logic_vector(DATA_W-1 downto 0);

        -- outputs to EX2/MEM
        mem_addr_o     : out std_logic_vector(DATA_W-1 downto 0);
        mem_store_o    : out std_logic_vector(DATA_W-1 downto 0);

        -- SP control
        sp_op_o        : out std_logic_vector(1 downto 0);

        -- branch resolution / mispredict
        mispredict     : out std_logic;          -- pulse: flush IF, ID, EX1
        redirect_pc    : out std_logic_vector(DATA_W-1 downto 0);

        -- predictor update (conditional branches only)
        bp_upd_en      : out std_logic;
        bp_upd_pc      : out std_logic_vector(DATA_W-1 downto 0);
        bp_upd_taken   : out std_logic;
        bp_upd_tgt     : out std_logic_vector(DATA_W-1 downto 0);

        -- flag updates to CCR
        ccr_upd_zn     : out std_logic;
        ccr_upd_c      : out std_logic;
        ccr_set_c      : out std_logic;
        ccr_z, ccr_n, ccr_c : out std_logic
    );
end execute2Stage;

architecture rtl of execute2Stage is
    signal taken           : std_logic;
    signal target          : std_logic_vector(DATA_W-1 downto 0);
    signal is_ex2_cf       : std_logic;
    signal target_mismatch : std_logic;
begin
    -- Control-flow instructions resolved in EX2 (branches + JMP + CALL)
    is_ex2_cf <= ctrl_in.is_branch
                 or (ctrl_in.is_jump and not (ctrl_in.is_ret or ctrl_in.is_rti or ctrl_in.is_int));

    -- Resolve branch outcome
    process(all)
    begin
        taken  <= '0';
        target <= imm_in;
        if valid_in = '1' then
            if ctrl_in.is_branch = '1' then
                case op_in is
                    when OP_JZ => taken <= z_in;
                    when OP_JN => taken <= n_in;
                    when OP_JC => taken <= c_in;
                    when others => null;
                end case;
            elsif ctrl_in.is_jump = '1' then
                if ctrl_in.is_ret = '1' or ctrl_in.is_rti = '1'
                   or ctrl_in.is_int = '1' then
                    taken <= '0';   -- target comes from MEM stage
                else
                    taken <= '1';   -- JMP / CALL
                end if;
            end if;
        end if;
    end process;

    -- Verify BOTH predicted direction AND predicted target address
    target_mismatch <= '1' when (taken = '1' and pred_taken_in = '1'
                                 and pred_target_in /= target) else '0';
    mispredict      <= valid_in and is_ex2_cf
                       and ((taken xor pred_taken_in) or target_mismatch);
    redirect_pc     <= target when taken = '1' else pcp1_in;

    -- Reserve all 16 BTB entries exclusively for conditional branches
    -- (JMP and CALL are already steered with zero penalty directly in IF).
    bp_upd_en    <= valid_in and ctrl_in.is_branch;
    bp_upd_pc    <= pred_pc_in;
    bp_upd_taken <= taken;
    bp_upd_tgt   <= target;

    -- Memory address & store / output data routing
    process(all)
    begin
        if valid_in = '1' and (ctrl_in.is_call = '1' or ctrl_in.is_int = '1'
                                or ctrl_in.is_push = '1') then
            mem_addr_o <= sp_in;
            if ctrl_in.is_push = '1' then
                mem_store_o <= store_in;     -- value of Rsrc (rs2-read)
            else
                mem_store_o <= pcp1_in;      -- return address
            end if;
        elsif valid_in = '1' and (ctrl_in.is_ret = '1' or ctrl_in.is_rti = '1'
                                   or ctrl_in.is_pop = '1') then
            mem_addr_o  <= std_logic_vector(unsigned(sp_in) + 1);
            mem_store_o <= (others => '0');
        elsif valid_in = '1' and op_in = OP_STD then
            mem_addr_o  <= alu_res_in;       -- Rsrc + offset
            mem_store_o <= store_in;         -- forwarded data register value
        elsif valid_in = '1' and op_in = OP_LDD then
            mem_addr_o  <= alu_res_in;
            mem_store_o <= (others => '0');
        elsif valid_in = '1' and (ctrl_in.is_swap = '1' or ctrl_in.out_en = '1') then
            -- SWAP: carry old Rdst value to secondary WB in MEM.
            -- OUT:  carry forwarded Rsrc value to outPutReg in MEM.
            mem_addr_o  <= (others => '0');
            mem_store_o <= store_in;
        else
            mem_addr_o  <= (others => '0');
            mem_store_o <= (others => '0');
        end if;
    end process;

    sp_op_o <= ctrl_in.sp_op when valid_in = '1' else "00";

    -- Flag updates: arithmetic/logical ops + ISA: JZ/JN/JC clear tested flag when taken
    process(all)
        variable b_jz, b_jn, b_jc : std_logic;
    begin
        b_jz := '0'; b_jn := '0'; b_jc := '0';
        if valid_in = '1' and ctrl_in.is_branch = '1' and taken = '1' then
            if    op_in = OP_JZ then b_jz := '1';
            elsif op_in = OP_JN then b_jn := '1';
            elsif op_in = OP_JC then b_jc := '1';
            end if;
        end if;
        ccr_upd_zn <= (ctrl_in.upd_zn and valid_in) or b_jz or b_jn;
        ccr_upd_c  <= (ctrl_in.upd_c  and valid_in) or b_jc;
        ccr_set_c  <= ctrl_in.set_c and valid_in;
        if    b_jz = '1' then ccr_z <= '0'; else ccr_z <= z_in; end if;
        if    b_jn = '1' then ccr_n <= '0'; else ccr_n <= n_in; end if;
        if    b_jc = '1' then ccr_c <= '0'; else ccr_c <= c_in; end if;
    end process;
end rtl;
