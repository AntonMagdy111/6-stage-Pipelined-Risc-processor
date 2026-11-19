-- ==========================================================================
-- Project : 6-Stage Pipelined 32-Bit Von Neumann RISC Processor
-- Author  : Anton Magdy (@AntonMagdy111) - https://github.com/AntonMagdy111
-- Repo    : https://github.com/AntonMagdy111/6-stage-Pipelined-Risc-processor
-- License : Apache-2.0 (see LICENSE and NOTICE for mandatory attribution)
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Anton Magdy. All rights reserved.
-- ==========================================================================
--------------------------------------------------------------------------
-- cpu_pkg.vhd
-- Shared constants for the 6-stage pipelined Von Neumann processor.
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package cpu_pkg is
    -- Design & authorship metadata (compile-time constants; zero synthesis area)
    constant CPU_DESIGN_NAME : string := "6-Stage Pipelined 32-Bit Von Neumann RISC Processor";
    constant CPU_AUTHOR      : string := "Anton Magdy (@AntonMagdy111)";
    constant CPU_REPO_URL    : string := "https://github.com/AntonMagdy111/6-stage-Pipelined-Risc-processor";
    constant CPU_LICENSE     : string := "Apache-2.0";

    constant DATA_W  : integer := 32;
    constant ADDR_W  : integer := 12;             -- 4096 words
    constant INSTR_W : integer := 16;             -- 16-bit instruction
    constant REG_W   : integer := 3;              -- 8 GP registers

    -- 5-bit opcodes
    constant OP_NOP  : std_logic_vector(4 downto 0) := "00000";
    constant OP_HLT  : std_logic_vector(4 downto 0) := "00001";
    constant OP_SETC : std_logic_vector(4 downto 0) := "00010";
    constant OP_NOT  : std_logic_vector(4 downto 0) := "00011";
    constant OP_INC  : std_logic_vector(4 downto 0) := "00100";
    constant OP_MOV  : std_logic_vector(4 downto 0) := "00101";
    constant OP_SWAP : std_logic_vector(4 downto 0) := "00110";
    constant OP_ADD  : std_logic_vector(4 downto 0) := "00111";
    constant OP_SUB  : std_logic_vector(4 downto 0) := "01000";
    constant OP_AND  : std_logic_vector(4 downto 0) := "01001";
    constant OP_IADD : std_logic_vector(4 downto 0) := "01010";
    constant OP_OUT  : std_logic_vector(4 downto 0) := "01011";
    constant OP_IN   : std_logic_vector(4 downto 0) := "01100";
    constant OP_PUSH : std_logic_vector(4 downto 0) := "01101";
    constant OP_POP  : std_logic_vector(4 downto 0) := "01110";
    constant OP_LDM  : std_logic_vector(4 downto 0) := "10000";
    constant OP_LDD  : std_logic_vector(4 downto 0) := "10001";
    constant OP_STD  : std_logic_vector(4 downto 0) := "10010";
    constant OP_JZ   : std_logic_vector(4 downto 0) := "10011";
    constant OP_JN   : std_logic_vector(4 downto 0) := "10100";
    constant OP_JC   : std_logic_vector(4 downto 0) := "10101";
    constant OP_JMP  : std_logic_vector(4 downto 0) := "10110";
    constant OP_CALL : std_logic_vector(4 downto 0) := "10111";
    constant OP_RET  : std_logic_vector(4 downto 0) := "11000";
    constant OP_RTI  : std_logic_vector(4 downto 0) := "11001";
    constant OP_INT  : std_logic_vector(4 downto 0) := "11010";

    -- 4-bit ALU operations
    constant ALU_ADD  : std_logic_vector(3 downto 0) := "0000";
    constant ALU_SUB  : std_logic_vector(3 downto 0) := "0001";
    constant ALU_AND  : std_logic_vector(3 downto 0) := "0010";
    constant ALU_NOT  : std_logic_vector(3 downto 0) := "0011";
    constant ALU_INC  : std_logic_vector(3 downto 0) := "0100";
    constant ALU_PASS : std_logic_vector(3 downto 0) := "0101";
    constant ALU_PASS_A : std_logic_vector(3 downto 0) := "0110";

    -- WB source select
    constant WB_ALU : std_logic_vector(1 downto 0) := "00";
    constant WB_MEM : std_logic_vector(1 downto 0) := "01";
    constant WB_IN  : std_logic_vector(1 downto 0) := "10";
    constant WB_IMM : std_logic_vector(1 downto 0) := "11";

    -- Control bundle that flows down the pipeline. Using a record keeps
    -- the pipeline-register entity ports manageable.
    type ctrl_bundle is record
        reg_we    : std_logic;
        mem_re    : std_logic;
        mem_we    : std_logic;
        alu_op    : std_logic_vector(3 downto 0);
        use_imm   : std_logic;
        uses_rs1  : std_logic;
        uses_rs2  : std_logic;
        is_branch : std_logic;
        is_jump   : std_logic;
        wb_sel    : std_logic_vector(1 downto 0);
        sp_op     : std_logic_vector(1 downto 0);
        out_en    : std_logic;
        in_en     : std_logic;
        set_c     : std_logic;
        halt      : std_logic;
        upd_zn    : std_logic;
        upd_c     : std_logic;
        is_swap   : std_logic;
        is_push   : std_logic;
        is_pop    : std_logic;
        is_call   : std_logic;
        is_ret    : std_logic;
        is_rti    : std_logic;
        is_int    : std_logic;
    end record;

    constant CTRL_NOP : ctrl_bundle := (
        reg_we=>'0', mem_re=>'0', mem_we=>'0', alu_op=>ALU_PASS, use_imm=>'0',
        uses_rs1=>'0', uses_rs2=>'0',
        is_branch=>'0', is_jump=>'0', wb_sel=>WB_ALU, sp_op=>"00",
        out_en=>'0', in_en=>'0', set_c=>'0', halt=>'0',
        upd_zn=>'0', upd_c=>'0', is_swap=>'0', is_push=>'0', is_pop=>'0',
        is_call=>'0', is_ret=>'0', is_rti=>'0', is_int=>'0');

    -- Safe conversion: returns 0 if any bit is metavalue ('U','X','Z',etc).
    -- Use this everywhere we index an array with a std_logic_vector to
    -- avoid the to_integer(unsigned(...)) warning storm during reset.
    function safe_int(v : std_logic_vector) return integer;
end package;

package body cpu_pkg is
    function safe_int(v : std_logic_vector) return integer is
        variable clean : std_logic_vector(v'range);
    begin
        for i in v'range loop
            if v(i) = '1' then
                clean(i) := '1';
            else
                clean(i) := '0';   -- maps U/X/Z/W/L/H/- to 0
            end if;
        end loop;
        return to_integer(unsigned(clean));
    end function;
end package body cpu_pkg;
