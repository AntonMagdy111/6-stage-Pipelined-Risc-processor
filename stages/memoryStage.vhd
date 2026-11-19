-- ==========================================================================
-- Project : 6-Stage Pipelined 32-Bit Von Neumann RISC Processor
-- Author  : Anton Magdy (@AntonMagdy111) - https://github.com/AntonMagdy111
-- Repo    : https://github.com/AntonMagdy111/6-stage-Pipelined-Risc-processor
-- License : Apache-2.0 (see LICENSE and NOTICE for mandatory attribution)
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Anton Magdy. All rights reserved.
-- ==========================================================================
--------------------------------------------------------------------------
-- memoryStage.vhd
-- Drives the data memory port, computes WB data, handles SWAP second
-- write, drives OUT port, and signals RET/RTI redirect.
--------------------------------------------------------------------------
--------------------------------------------------------------------------
-- memoryStage.vhd
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity memoryStage is
    port(
        valid_in    : in std_logic;
        ctrl_in     : in ctrl_bundle;
        mem_addr_in : in std_logic_vector(DATA_W-1 downto 0);
        store_in    : in std_logic_vector(DATA_W-1 downto 0);
        alu_res_in  : in std_logic_vector(DATA_W-1 downto 0);
        imm_in      : in std_logic_vector(DATA_W-1 downto 0);
        rdst_in     : in std_logic_vector(REG_W-1 downto 0);
        rs2_in      : in std_logic_vector(REG_W-1 downto 0);
        in_port     : in std_logic_vector(DATA_W-1 downto 0);

        d_addr_o    : out std_logic_vector(ADDR_W-1 downto 0);
        d_we_o      : out std_logic;
        d_re_o      : out std_logic;
        d_in_o      : out std_logic_vector(DATA_W-1 downto 0);
        d_out_in    : in  std_logic_vector(DATA_W-1 downto 0);
        hw_int_in   : in  std_logic;
        vec_addr_o  : out std_logic_vector(ADDR_W-1 downto 0);
        vec_data_in : in  std_logic_vector(DATA_W-1 downto 0);

        wb_data_o   : out std_logic_vector(DATA_W-1 downto 0);
        wb_we_o     : out std_logic;
        wb_rdst_o   : out std_logic_vector(REG_W-1 downto 0);

        swap_we_o   : out std_logic;
        swap_addr_o : out std_logic_vector(REG_W-1 downto 0);
        swap_data_o : out std_logic_vector(DATA_W-1 downto 0);

        out_en_o    : out std_logic;
        out_data_o  : out std_logic_vector(DATA_W-1 downto 0);

        ret_redirect : out std_logic;
        ret_target   : out std_logic_vector(DATA_W-1 downto 0)
    );
end memoryStage;

architecture rtl of memoryStage is
begin
    d_addr_o <= mem_addr_in(ADDR_W-1 downto 0);
    d_we_o   <= ctrl_in.mem_we and valid_in;
    d_re_o   <= ctrl_in.mem_re and valid_in;
    d_in_o   <= store_in;

    vec_addr_o <= std_logic_vector(to_unsigned(1, ADDR_W)) when hw_int_in = '1'
             else std_logic_vector(to_unsigned(2, ADDR_W) + resize(unsigned(rdst_in), ADDR_W));

    process(all)
    begin
        case ctrl_in.wb_sel is
            when WB_ALU => wb_data_o <= alu_res_in;
            when WB_MEM => wb_data_o <= d_out_in;
            when WB_IN  => wb_data_o <= in_port;
            when WB_IMM => wb_data_o <= imm_in;
            when others => wb_data_o <= alu_res_in;
        end case;
    end process;

    wb_we_o   <= ctrl_in.reg_we and valid_in;
    wb_rdst_o <= rdst_in;

    swap_we_o   <= ctrl_in.is_swap and valid_in;
    swap_addr_o <= rs2_in;
    swap_data_o <= store_in;

    out_en_o   <= ctrl_in.out_en and valid_in;
    out_data_o <= store_in;

    ret_redirect <= valid_in and (ctrl_in.is_ret or ctrl_in.is_rti or ctrl_in.is_int);
    ret_target   <= vec_data_in when ctrl_in.is_int = '1' else d_out_in;
end rtl;