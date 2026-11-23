-- ==========================================================================
-- Project : 6-Stage Pipelined 32-Bit Von Neumann RISC Processor
-- Author  : Anton Magdy (@AntonMagdy111) - https://github.com/AntonMagdy111
-- Repo    : https://github.com/AntonMagdy111/6-stage-Pipelined-Risc-processor
-- License : Apache-2.0 (see LICENSE and NOTICE for mandatory attribution)
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Anton Magdy. All rights reserved.
-- ==========================================================================
--------------------------------------------------------------------------
-- writeBackStage.vhd
--
-- The actual write happens inside RegisterFile on the rising clock edge
-- (with same-cycle write-through bypass to ID). This stage is a clean
-- wrapper that gates the write enable with valid_in for stage symmetry.
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity writeBackStage is
    port(
        valid_in : in  std_logic;
        we_in    : in  std_logic;
        rdst_in  : in  std_logic_vector(REG_W-1 downto 0);
        data_in  : in  std_logic_vector(DATA_W-1 downto 0);

        rf_we_o  : out std_logic;
        rf_addr_o: out std_logic_vector(REG_W-1 downto 0);
        rf_data_o: out std_logic_vector(DATA_W-1 downto 0)
    );
end writeBackStage;

architecture rtl of writeBackStage is
begin
    rf_we_o   <= valid_in and we_in;
    rf_addr_o <= rdst_in;
    rf_data_o <= data_in;
end rtl;
