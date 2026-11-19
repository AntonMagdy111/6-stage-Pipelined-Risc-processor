-- ==========================================================================
-- Project : 6-Stage Pipelined 32-Bit Von Neumann RISC Processor
-- Author  : Anton Magdy (@AntonMagdy111) - https://github.com/AntonMagdy111
-- Repo    : https://github.com/AntonMagdy111/6-stage-Pipelined-Risc-processor
-- License : Apache-2.0 (see LICENSE and NOTICE for mandatory attribution)
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Anton Magdy. All rights reserved.
-- ==========================================================================
--------------------------------------------------------------------------
-- execute1Stage.vhd
-- Applies unified age-ordered data forwarding for operands A, B, and Store,
-- then executes the ALU operation.
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity execute1Stage is
    port(
        a_in, b_in, store_in : in  std_logic_vector(DATA_W-1 downto 0);
        ex1_ex2_alu          : in  std_logic_vector(DATA_W-1 downto 0);
        ex2_mem_data         : in  std_logic_vector(DATA_W-1 downto 0);
        mem_wb_data          : in  std_logic_vector(DATA_W-1 downto 0);
        swap_data_e1e2       : in  std_logic_vector(DATA_W-1 downto 0);
        swap_data_mem        : in  std_logic_vector(DATA_W-1 downto 0);
        swap_data_wb         : in  std_logic_vector(DATA_W-1 downto 0);
        sel_a                : in  std_logic_vector(2 downto 0);
        sel_b                : in  std_logic_vector(2 downto 0);
        sel_store            : in  std_logic_vector(2 downto 0);
        op                   : in  std_logic_vector(3 downto 0);
        alu_res_o            : out std_logic_vector(DATA_W-1 downto 0);
        store_o              : out std_logic_vector(DATA_W-1 downto 0);
        z_o, n_o, c_o        : out std_logic
    );
end execute1Stage;

architecture rtl of execute1Stage is
    signal a_mux, b_mux : std_logic_vector(DATA_W-1 downto 0);

    component alu
        port(
            a, b   : in  std_logic_vector(DATA_W-1 downto 0);
            op     : in  std_logic_vector(3 downto 0);
            result : out std_logic_vector(DATA_W-1 downto 0);
            z_flag, n_flag, c_flag : out std_logic
        );
    end component;
begin
    with sel_a select
        a_mux <= ex1_ex2_alu    when "001",
                 swap_data_e1e2 when "010",
                 ex2_mem_data   when "011",
                 swap_data_mem  when "100",
                 mem_wb_data    when "101",
                 swap_data_wb   when "110",
                 a_in           when others;

    with sel_b select
        b_mux <= ex1_ex2_alu    when "001",
                 swap_data_e1e2 when "010",
                 ex2_mem_data   when "011",
                 swap_data_mem  when "100",
                 mem_wb_data    when "101",
                 swap_data_wb   when "110",
                 b_in           when others;

    with sel_store select
        store_o <= ex1_ex2_alu    when "001",
                   swap_data_e1e2 when "010",
                   ex2_mem_data   when "011",
                   swap_data_mem  when "100",
                   mem_wb_data    when "101",
                   swap_data_wb   when "110",
                   store_in       when others;

    U_ALU : alu
        port map(
            a => a_mux, b => b_mux, op => op,
            result => alu_res_o,
            z_flag => z_o, n_flag => n_o, c_flag => c_o
        );
end rtl;
