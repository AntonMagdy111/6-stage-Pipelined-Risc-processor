--------------------------------------------------------------------------
-- execute1Stage.vhd
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity execute1Stage is
    port(
        a_in, b_in, store_in : in std_logic_vector(DATA_W-1 downto 0);
        ex1_ex2_alu    : in std_logic_vector(DATA_W-1 downto 0);
        ex2_mem_alu    : in std_logic_vector(DATA_W-1 downto 0);
        mem_wb_data    : in std_logic_vector(DATA_W-1 downto 0);
        swap_data_e1e2 : in std_logic_vector(DATA_W-1 downto 0);
        swap_data_mem  : in std_logic_vector(DATA_W-1 downto 0);
        swap_data_wb   : in std_logic_vector(DATA_W-1 downto 0);
        sel_a          : in std_logic_vector(1 downto 0);
        sel_b          : in std_logic_vector(1 downto 0);
        sel_store      : in std_logic_vector(1 downto 0);
        swap_fwd_a     : in std_logic_vector(1 downto 0);
        swap_fwd_b     : in std_logic_vector(1 downto 0);
        swap_fwd_store : in std_logic_vector(1 downto 0);
        is_swap_in     : in std_logic;
        op             : in std_logic_vector(3 downto 0);
        alu_res_o      : out std_logic_vector(DATA_W-1 downto 0);
        store_o        : out std_logic_vector(DATA_W-1 downto 0);
        z_o, n_o, c_o  : out std_logic
    );
end execute1Stage;

architecture rtl of execute1Stage is
    signal a_mux_raw, b_mux_raw, store_raw : std_logic_vector(DATA_W-1 downto 0);
    signal a_mux, b_mux : std_logic_vector(DATA_W-1 downto 0);
    signal a_swap_val, b_swap_val, store_swap_val : std_logic_vector(DATA_W-1 downto 0);

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
        a_mux_raw <= ex1_ex2_alu  when "01",
                     ex2_mem_alu  when "10",
                     mem_wb_data  when "11",
                     a_in         when others;

    with sel_b select
        b_mux_raw <= ex1_ex2_alu  when "01",
                     ex2_mem_alu  when "10",
                     mem_wb_data  when "11",
                     b_in         when others;

    with sel_store select
        store_raw <= ex1_ex2_alu  when "01",
                     ex2_mem_alu  when "10",
                     mem_wb_data  when "11",
                     store_in     when others;

    with swap_fwd_a select
        a_swap_val <= swap_data_e1e2 when "01",
                      swap_data_mem  when "10",
                      swap_data_wb   when "11",
                      (others => '0') when others;

    a_mux <= a_swap_val when swap_fwd_a /= "00" else a_mux_raw;

    with swap_fwd_b select
        b_swap_val <= swap_data_e1e2 when "01",
                      swap_data_mem  when "10",
                      swap_data_wb   when "11",
                      (others => '0') when others;

    b_mux <= b_swap_val when swap_fwd_b /= "00" else b_mux_raw;

    with swap_fwd_store select
        store_swap_val <= swap_data_e1e2 when "01",
                          swap_data_mem  when "10",
                          swap_data_wb   when "11",
                          (others => '0') when others;

    store_o <= store_swap_val when (swap_fwd_store /= "00") else store_raw;

    U_ALU : alu
        port map(
            a => a_mux, b => b_mux, op => op,
            result => alu_res_o,
            z_flag => z_o, n_flag => n_o, c_flag => c_o
        );
end rtl;