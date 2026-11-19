-- ==========================================================================
-- Project : 6-Stage Pipelined 32-Bit Von Neumann RISC Processor
-- Author  : Anton Magdy (@AntonMagdy111) - https://github.com/AntonMagdy111
-- Repo    : https://github.com/AntonMagdy111/6-stage-Pipelined-Risc-processor
-- License : Apache-2.0 (see LICENSE and NOTICE for mandatory attribution)
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Anton Magdy. All rights reserved.
-- ==========================================================================
--------------------------------------------------------------------------
-- controlUnit.vhd
-- Pure combinational decoder. Opcode -> all pipeline control signals.
--
-- Output meanings:
--   reg_we    : write-back updates the register file
--   mem_re    : data memory read in MEM stage
--   mem_we    : data memory write in MEM stage
--   alu_op    : 4-bit ALU opcode
--   use_imm   : ALU operand B = immediate (not rd_data2)
--   uses_rs1  : instruction genuinely reads RF read port 1 (src_a)
--   uses_rs2  : instruction genuinely reads RF read port 2 (src_b / store)
--   is_branch : conditional branch (JZ/JN/JC)
--   is_jump   : unconditional control transfer (JMP/CALL/RET/RTI/INT)
--   wb_sel    : selects WB source (00=ALU,01=MEM,10=IN,11=IMM)
--   sp_op     : 00 hold, 01 inc, 10 dec
--   needs_imm : instruction has a 2nd memory word
--   out_en    : drive OUT.PORT
--   in_en     : capture IN.PORT
--   set_c     : SETC
--   halt      : HLT
--   upd_zn    : update Z and N flags
--   upd_c     : update C flag
--   is_swap, is_push, is_pop, is_call, is_ret, is_rti, is_int : tags used
--   by the EX2/MEM stages for routing.
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity controlUnit is
    port(
        opcode    : in  std_logic_vector(4 downto 0);
        reg_we    : out std_logic;
        mem_re    : out std_logic;
        mem_we    : out std_logic;
        alu_op    : out std_logic_vector(3 downto 0);
        use_imm   : out std_logic;
        uses_rs1  : out std_logic;
        uses_rs2  : out std_logic;
        is_branch : out std_logic;
        is_jump   : out std_logic;
        wb_sel    : out std_logic_vector(1 downto 0);
        sp_op     : out std_logic_vector(1 downto 0);
        needs_imm : out std_logic;
        out_en    : out std_logic;
        in_en     : out std_logic;
        set_c     : out std_logic;
        halt      : out std_logic;
        upd_zn    : out std_logic;
        upd_c     : out std_logic;
        is_swap   : out std_logic;
        is_push   : out std_logic;
        is_pop    : out std_logic;
        is_call   : out std_logic;
        is_ret    : out std_logic;
        is_rti    : out std_logic;
        is_int    : out std_logic
    );
end controlUnit;

architecture rtl of controlUnit is
begin
    process(all)
    begin
        reg_we    <= '0';
        mem_re    <= '0';
        mem_we    <= '0';
        alu_op    <= ALU_PASS;
        use_imm   <= '0';
        uses_rs1  <= '0';
        uses_rs2  <= '0';
        is_branch <= '0';
        is_jump   <= '0';
        wb_sel    <= WB_ALU;
        sp_op     <= "00";
        needs_imm <= '0';
        out_en    <= '0';
        in_en     <= '0';
        set_c     <= '0';
        halt      <= '0';
        upd_zn    <= '0';
        upd_c     <= '0';
        is_swap   <= '0';
        is_push   <= '0';
        is_pop    <= '0';
        is_call   <= '0';
        is_ret    <= '0';
        is_rti    <= '0';
        is_int    <= '0';

        case opcode is
            when OP_NOP  => null;
            when OP_HLT  =>
                -- HLT is handled explicitly in EX2 (freezes PC at HLT+1 and
                -- flushes younger instructions without polluting the BTB).
                halt <= '1';
            when OP_SETC => set_c <= '1';
            when OP_NOT  =>
                reg_we <= '1'; uses_rs2 <= '1';
                alu_op <= ALU_NOT; upd_zn <= '1';
            when OP_INC  =>
                reg_we <= '1'; uses_rs2 <= '1';
                alu_op <= ALU_INC; upd_zn <= '1'; upd_c <= '1';
            when OP_MOV  =>
                reg_we <= '1'; uses_rs2 <= '1';
                alu_op <= ALU_PASS;
            when OP_SWAP =>
                -- Port 1 reads Rs2 (Rsrc), Port 2 reads Rdst.
                reg_we <= '1'; uses_rs1 <= '1'; uses_rs2 <= '1';
                alu_op <= ALU_PASS_A;
                is_swap <= '1';
            when OP_ADD  =>
                reg_we <= '1'; uses_rs1 <= '1'; uses_rs2 <= '1';
                alu_op <= ALU_ADD; upd_zn <= '1'; upd_c <= '1';
            when OP_SUB  =>
                reg_we <= '1'; uses_rs1 <= '1'; uses_rs2 <= '1';
                alu_op <= ALU_SUB; upd_zn <= '1'; upd_c <= '1';
            when OP_AND  =>
                reg_we <= '1'; uses_rs1 <= '1'; uses_rs2 <= '1';
                alu_op <= ALU_AND; upd_zn <= '1';
            when OP_IADD =>
                reg_we <= '1'; uses_rs1 <= '1';
                alu_op <= ALU_ADD; use_imm <= '1';
                upd_zn <= '1'; upd_c <= '1'; needs_imm <= '1';
            when OP_OUT  =>
                out_en <= '1'; uses_rs2 <= '1';
            when OP_IN   =>
                reg_we <= '1';
                in_en <= '1'; wb_sel <= WB_IN;
            when OP_PUSH =>
                mem_we <= '1'; uses_rs2 <= '1';
                sp_op <= "10"; is_push <= '1';
            when OP_POP  =>
                reg_we <= '1';
                mem_re <= '1'; sp_op <= "01";
                wb_sel <= WB_MEM; is_pop <= '1';
            when OP_LDM  =>
                reg_we <= '1';
                alu_op <= ALU_PASS; use_imm <= '1';
                wb_sel <= WB_IMM; needs_imm <= '1';
            when OP_LDD  =>
                reg_we <= '1'; uses_rs1 <= '1';
                mem_re <= '1'; alu_op <= ALU_ADD;
                use_imm <= '1'; wb_sel <= WB_MEM; needs_imm <= '1';
            when OP_STD  =>
                -- Reads base (rs1) for effective address AND data (rs2) for store.
                mem_we <= '1'; uses_rs1 <= '1'; uses_rs2 <= '1';
                alu_op <= ALU_ADD; use_imm <= '1';
                needs_imm <= '1';
            when OP_JZ | OP_JN | OP_JC =>
                is_branch <= '1';
                needs_imm <= '1';
            when OP_JMP  =>
                is_jump <= '1';
                needs_imm <= '1';
            when OP_CALL =>
                is_jump <= '1';
                is_call <= '1'; mem_we <= '1';
                sp_op <= "10"; needs_imm <= '1';
            when OP_RET  =>
                is_jump <= '1';
                is_ret <= '1'; mem_re <= '1'; sp_op <= "01";
            when OP_RTI  =>
                is_jump <= '1';
                is_rti <= '1'; mem_re <= '1'; sp_op <= "01";
            when OP_INT  =>
                is_jump <= '1';
                is_int <= '1'; mem_we <= '1'; sp_op <= "10";
            when others => null;
        end case;
    end process;
end rtl;
