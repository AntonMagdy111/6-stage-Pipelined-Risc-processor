--------------------------------------------------------------------------
-- IF_ID.vhd
-- Pipeline register between Fetch and Decode stages.
-- Holds: instruction (16 bits), immediate (32 bits), PC+1/PC+2,
-- branch-predictor metadata (pred_taken, pred_pc, pred_target), and valid.
--   en=0    -> hold (load-use stall / HLT)
--   flush=1 -> clear to clean NOP bubble
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity IF_ID is
    port(
        clk            : in  std_logic;
        rst            : in  std_logic;
        en             : in  std_logic;
        flush          : in  std_logic;
        ir_in          : in  std_logic_vector(INSTR_W-1 downto 0);
        imm_in         : in  std_logic_vector(DATA_W-1 downto 0);
        pcp1_in        : in  std_logic_vector(DATA_W-1 downto 0);
        pred_taken_in  : in  std_logic;
        pred_pc_in     : in  std_logic_vector(DATA_W-1 downto 0);
        pred_target_in : in  std_logic_vector(DATA_W-1 downto 0);
        valid_in       : in  std_logic;

        ir_out          : out std_logic_vector(INSTR_W-1 downto 0);
        imm_out         : out std_logic_vector(DATA_W-1 downto 0);
        pcp1_out        : out std_logic_vector(DATA_W-1 downto 0);
        pred_taken_out  : out std_logic;
        pred_pc_out     : out std_logic_vector(DATA_W-1 downto 0);
        pred_target_out : out std_logic_vector(DATA_W-1 downto 0);
        valid_out       : out std_logic
    );
end IF_ID;

architecture rtl of IF_ID is
    signal ir_r          : std_logic_vector(INSTR_W-1 downto 0) := (others => '0');
    signal imm_r         : std_logic_vector(DATA_W-1 downto 0)  := (others => '0');
    signal pcp1_r        : std_logic_vector(DATA_W-1 downto 0)  := (others => '0');
    signal pred_taken_r  : std_logic := '0';
    signal pred_pc_r     : std_logic_vector(DATA_W-1 downto 0)  := (others => '0');
    signal pred_target_r : std_logic_vector(DATA_W-1 downto 0)  := (others => '0');
    signal valid_r       : std_logic := '0';
begin
    process(clk, rst)
    begin
        if rst = '1' then
            ir_r          <= (others => '0');
            imm_r         <= (others => '0');
            pcp1_r        <= (others => '0');
            pred_taken_r  <= '0';
            pred_pc_r     <= (others => '0');
            pred_target_r <= (others => '0');
            valid_r       <= '0';
        elsif rising_edge(clk) then
            if flush = '1' then
                ir_r          <= (others => '0');
                imm_r         <= (others => '0');
                pcp1_r        <= (others => '0');
                pred_taken_r  <= '0';
                pred_pc_r     <= (others => '0');
                pred_target_r <= (others => '0');
                valid_r       <= '0';
            elsif en = '1' then
                ir_r          <= ir_in;
                imm_r         <= imm_in;
                pcp1_r        <= pcp1_in;
                pred_taken_r  <= pred_taken_in;
                pred_pc_r     <= pred_pc_in;
                pred_target_r <= pred_target_in;
                valid_r       <= valid_in;
            end if;
        end if;
    end process;

    ir_out          <= ir_r;
    imm_out         <= imm_r;
    pcp1_out        <= pcp1_r;
    pred_taken_out  <= pred_taken_r;
    pred_pc_out     <= pred_pc_r;
    pred_target_out <= pred_target_r;
    valid_out       <= valid_r;
end rtl;
