library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity forwardingUnit is
    port(
        id_ex1_rs1     : in std_logic_vector(REG_W-1 downto 0);
        id_ex1_rs2     : in std_logic_vector(REG_W-1 downto 0);
        id_ex1_use_imm : in std_logic;
        ex1_ex2_valid  : in std_logic;
        ex1_ex2_we     : in std_logic;
        ex1_ex2_rdst   : in std_logic_vector(REG_W-1 downto 0);
        ex1_ex2_is_swap  : in std_logic;
        ex1_ex2_swap_rs2 : in std_logic_vector(REG_W-1 downto 0);
        ex2_mem_valid  : in std_logic;
        ex2_mem_we     : in std_logic;
        ex2_mem_rdst   : in std_logic_vector(REG_W-1 downto 0);
        mem_wb_valid   : in std_logic;
        mem_wb_we      : in std_logic;
        mem_wb_rdst    : in std_logic_vector(REG_W-1 downto 0);
        swap_we        : in std_logic;
        swap_addr      : in std_logic_vector(REG_W-1 downto 0);
        mw_swap_we     : in std_logic;
        mw_swap_addr   : in std_logic_vector(REG_W-1 downto 0);
        sel_a          : out std_logic_vector(1 downto 0);
        sel_b          : out std_logic_vector(1 downto 0);
        sel_store      : out std_logic_vector(1 downto 0);
        swap_fwd_a     : out std_logic_vector(1 downto 0);
        swap_fwd_b     : out std_logic_vector(1 downto 0);
        swap_fwd_store : out std_logic_vector(1 downto 0)
    );
end forwardingUnit;

architecture rtl of forwardingUnit is
begin
    process(all)
    begin
        if    ex1_ex2_valid='1' and ex1_ex2_we='1'
              and ex1_ex2_rdst = id_ex1_rs1 then sel_a <= "01";
        elsif ex1_ex2_valid='1' and ex1_ex2_is_swap='1'
              and ex1_ex2_swap_rs2 = id_ex1_rs1 then sel_a <= "01";
        elsif ex2_mem_valid='1' and ex2_mem_we='1'
              and ex2_mem_rdst = id_ex1_rs1 then sel_a <= "10";
        elsif mem_wb_valid ='1' and mem_wb_we ='1'
              and mem_wb_rdst  = id_ex1_rs1 then sel_a <= "11";
        elsif swap_we = '1' and swap_addr = id_ex1_rs1 then
                                                 sel_a <= "10";
        elsif mw_swap_we = '1' and mw_swap_addr = id_ex1_rs1 then
                                                 sel_a <= "11";
        else                                     sel_a <= "00";
        end if;
    end process;

    process(all)
    begin
        if id_ex1_use_imm = '1' then sel_b <= "00";
        elsif ex1_ex2_valid='1' and ex1_ex2_we='1'
              and ex1_ex2_rdst = id_ex1_rs2 then sel_b <= "01";
        elsif ex1_ex2_valid='1' and ex1_ex2_is_swap='1'
              and ex1_ex2_swap_rs2 = id_ex1_rs2 then sel_b <= "01";
        elsif ex2_mem_valid='1' and ex2_mem_we='1'
              and ex2_mem_rdst = id_ex1_rs2 then sel_b <= "10";
        elsif mem_wb_valid ='1' and mem_wb_we ='1'
              and mem_wb_rdst  = id_ex1_rs2 then sel_b <= "11";
        elsif swap_we = '1' and swap_addr = id_ex1_rs2 then
                                                 sel_b <= "10";
        elsif mw_swap_we = '1' and mw_swap_addr = id_ex1_rs2
              and id_ex1_use_imm = '0' then      sel_b <= "11";
        else                                     sel_b <= "00";
        end if;
    end process;

    process(all)
    begin
        if    ex1_ex2_valid='1' and ex1_ex2_we='1'
              and ex1_ex2_rdst = id_ex1_rs2 then sel_store <= "01";
        elsif ex1_ex2_valid='1' and ex1_ex2_is_swap='1'
              and ex1_ex2_swap_rs2 = id_ex1_rs2 then sel_store <= "01";
        elsif ex2_mem_valid='1' and ex2_mem_we='1'
              and ex2_mem_rdst = id_ex1_rs2 then sel_store <= "10";
        elsif mem_wb_valid ='1' and mem_wb_we ='1'
              and mem_wb_rdst  = id_ex1_rs2 then sel_store <= "11";
        elsif swap_we = '1' and swap_addr = id_ex1_rs2 then
                                                 sel_store <= "10";
        elsif mw_swap_we = '1' and mw_swap_addr = id_ex1_rs2 then
                                                 sel_store <= "11";
        else                                     sel_store <= "00";
        end if;
    end process;

    process(all)
    begin
        if ex1_ex2_valid='1' and ex1_ex2_is_swap='1' and ex1_ex2_swap_rs2 = id_ex1_rs1 then
            swap_fwd_a <= "01";
        elsif swap_we='1' and swap_addr = id_ex1_rs1 then
            swap_fwd_a <= "10";
        elsif mw_swap_we='1' and mw_swap_addr = id_ex1_rs1 then
            swap_fwd_a <= "11";
        else
            swap_fwd_a <= "00";
        end if;
    end process;

    process(all)
    begin
        if ex1_ex2_valid='1' and ex1_ex2_is_swap='1' and ex1_ex2_swap_rs2 = id_ex1_rs2 and id_ex1_use_imm='0' then
            swap_fwd_b <= "01";
        elsif swap_we='1' and swap_addr = id_ex1_rs2 and id_ex1_use_imm='0' then
            swap_fwd_b <= "10";
        elsif mw_swap_we='1' and mw_swap_addr = id_ex1_rs2 and id_ex1_use_imm='0' then
            swap_fwd_b <= "11";
        else
            swap_fwd_b <= "00";
        end if;
    end process;

    process(all)
    begin
        if ex1_ex2_valid='1' and ex1_ex2_is_swap='1' and ex1_ex2_swap_rs2 = id_ex1_rs2 then
            swap_fwd_store <= "01";
        elsif swap_we='1' and swap_addr = id_ex1_rs2 then
            swap_fwd_store <= "10";
        elsif mw_swap_we='1' and mw_swap_addr = id_ex1_rs2 then
            swap_fwd_store <= "11";
        else
            swap_fwd_store <= "00";
        end if;
    end process;
end rtl;