--------------------------------------------------------------------------
-- fetchStage.vhd
--
-- Owns: the Program Counter (pc.vhd), the 2-word instruction fetch FSM,
-- early unconditional JMP/CALL steering, and the 2-bit BTB branch
-- predictor lookup.
--
-- Fetch FSM:
--   1-word insn:      IF/ID gets {M[PC](15:0), imm=0}, PC <- PC+1 (or BTB)
--   2-word cycle 1:   IF/ID gets bubble; latch IR + BTB lookup; PC <- PC+1
--   2-word cycle 2:   IF/ID gets {IR_latched, imm=M[PC]};
--                     * JMP/CALL: steer PC <- M[PC] immediately (0 bubbles!)
--                     * Branch BTB hit+taken: steer PC <- pred_target_lat
--                     * Otherwise: PC <- PC+1
--   Pause (HW INTR):  finishes any in-progress 2-word fetch, then holds PC
--                     and emits bubbles so older instructions drain cleanly.
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity fetchStage is
    port(
        clk           : in  std_logic;
        rst           : in  std_logic;

        -- stalls / pauses / redirects
        stall         : in  std_logic;             -- hold PC and IF/ID (load-use or HLT)
        pause_fetch   : in  std_logic;             -- emit bubbles after current insn (HW INTR drain)
        flush         : in  std_logic;             -- branch mispredict / RET / INT / HLT
        redirect_pc   : in  std_logic_vector(DATA_W-1 downto 0);

        -- shared memory (instruction port)
        i_addr        : out std_logic_vector(ADDR_W-1 downto 0);
        i_data        : in  std_logic_vector(DATA_W-1 downto 0);

        -- reset vector (M[0]) for cold-start PC
        reset_vec     : in  std_logic_vector(DATA_W-1 downto 0);

        -- predictor update (driven from EX2 on conditional branches)
        bp_upd_en     : in  std_logic;
        bp_upd_pc     : in  std_logic_vector(DATA_W-1 downto 0);
        bp_upd_taken  : in  std_logic;
        bp_upd_tgt    : in  std_logic_vector(DATA_W-1 downto 0);

        -- IF/ID inputs
        ir_out        : out std_logic_vector(INSTR_W-1 downto 0);
        imm_out       : out std_logic_vector(DATA_W-1 downto 0);
        pcp1_out      : out std_logic_vector(DATA_W-1 downto 0);
        pred_taken_o  : out std_logic;
        pred_pc_o     : out std_logic_vector(DATA_W-1 downto 0);
        pred_target_o : out std_logic_vector(DATA_W-1 downto 0);
        valid_out     : out std_logic;
        imm_pending_o : out std_logic;
        pc_obs        : out std_logic_vector(DATA_W-1 downto 0)
    );
end fetchStage;

architecture rtl of fetchStage is
    -- PC wiring
    signal pc_v            : std_logic_vector(DATA_W-1 downto 0);
    signal pc_sel          : std_logic_vector(1 downto 0);
    signal pc_target       : std_logic_vector(DATA_W-1 downto 0);

    -- 2-word fetch FSM state
    signal imm_pending     : std_logic := '0';
    signal ir_latched      : std_logic_vector(INSTR_W-1 downto 0) := (others => '0');
    signal pc_at_fetch     : unsigned(DATA_W-1 downto 0) := (others => '0');

    -- Branch predictor wires & cycle-1 latches
    signal pred_taken, pred_hit : std_logic;
    signal pred_target          : std_logic_vector(DATA_W-1 downto 0);
    signal pred_taken_lat       : std_logic := '0';
    signal pred_hit_lat         : std_logic := '0';
    signal pred_target_lat      : std_logic_vector(DATA_W-1 downto 0) := (others => '0');

    -- Local pre-decode
    signal cur_opcode    : std_logic_vector(4 downto 0);
    signal lat_opcode    : std_logic_vector(4 downto 0);
    signal needs_imm     : std_logic;
    signal lat_is_uncond : std_logic;

    component pc is
        port(
            clk       : in  std_logic;
            rst       : in  std_logic;
            sel       : in  std_logic_vector(1 downto 0);
            target_in : in  std_logic_vector(DATA_W-1 downto 0);
            reset_vec : in  std_logic_vector(DATA_W-1 downto 0);
            pc_out    : out std_logic_vector(DATA_W-1 downto 0)
        );
    end component;

    component branchPredictor is
        generic(IDX_W : integer := 4);
        port(
            clk, rst       : in  std_logic;
            lookup_pc      : in  std_logic_vector(DATA_W-1 downto 0);
            predict_taken  : out std_logic;
            predict_target : out std_logic_vector(DATA_W-1 downto 0);
            predict_hit    : out std_logic;
            upd_en         : in  std_logic;
            upd_pc         : in  std_logic_vector(DATA_W-1 downto 0);
            upd_taken      : in  std_logic;
            upd_target     : in  std_logic_vector(DATA_W-1 downto 0)
        );
    end component;
begin
    U_PC : pc
        port map(
            clk       => clk,
            rst       => rst,
            sel       => pc_sel,
            target_in => pc_target,
            reset_vec => reset_vec,
            pc_out    => pc_v
        );

    pc_obs        <= pc_v;
    i_addr        <= pc_v(ADDR_W-1 downto 0);
    imm_pending_o <= imm_pending;

    cur_opcode    <= i_data(15 downto 11);
    lat_opcode    <= ir_latched(15 downto 11);
    lat_is_uncond <= '1' when (lat_opcode = OP_JMP or lat_opcode = OP_CALL) else '0';

    process(all)
    begin
        case cur_opcode is
            when OP_IADD | OP_LDM  | OP_LDD  | OP_STD
               | OP_JZ   | OP_JN   | OP_JC   | OP_JMP | OP_CALL =>
                needs_imm <= '1';
            when others =>
                needs_imm <= '0';
        end case;
    end process;

    U_BP : branchPredictor
        port map(
            clk            => clk,
            rst            => rst,
            lookup_pc      => pc_v,
            predict_taken  => pred_taken,
            predict_target => pred_target,
            predict_hit    => pred_hit,
            upd_en         => bp_upd_en,
            upd_pc         => bp_upd_pc,
            upd_taken      => bp_upd_taken,
            upd_target     => bp_upd_tgt
        );

    -- Drive IF/ID bundle
    process(all)
    begin
        if imm_pending = '1' then
            ir_out    <= ir_latched;
            imm_out   <= i_data;
            pcp1_out  <= std_logic_vector(pc_at_fetch + 2);
            pred_pc_o <= std_logic_vector(pc_at_fetch);
            valid_out <= '1';
            if lat_is_uncond = '1' then
                -- JMP / CALL: immediate on i_data is the exact target!
                pred_taken_o  <= '1';
                pred_target_o <= i_data;
            elsif pred_taken_lat = '1' and pred_hit_lat = '1' then
                pred_taken_o  <= '1';
                pred_target_o <= pred_target_lat;
            else
                pred_taken_o  <= '0';
                pred_target_o <= (others => '0');
            end if;
        elsif pause_fetch = '1' then
            ir_out        <= (others => '0');
            imm_out       <= (others => '0');
            pcp1_out      <= (others => '0');
            pred_pc_o     <= pc_v;
            pred_taken_o  <= '0';
            pred_target_o <= (others => '0');
            valid_out     <= '0';
        elsif needs_imm = '1' then
            ir_out        <= (others => '0');
            imm_out       <= (others => '0');
            pcp1_out      <= (others => '0');
            pred_pc_o     <= pc_v;
            pred_taken_o  <= '0';
            pred_target_o <= (others => '0');
            valid_out     <= '0';
        else
            ir_out    <= i_data(INSTR_W-1 downto 0);
            imm_out   <= (others => '0');
            pcp1_out  <= std_logic_vector(unsigned(pc_v) + 1);
            pred_pc_o <= pc_v;
            valid_out <= '1';
            if pred_taken = '1' and pred_hit = '1' then
                pred_taken_o  <= '1';
                pred_target_o <= pred_target;
            else
                pred_taken_o  <= '0';
                pred_target_o <= (others => '0');
            end if;
        end if;
    end process;

    -- Combinational PC next-state steering for U_PC
    process(all)
    begin
        pc_sel    <= "01";
        pc_target <= redirect_pc;

        if flush = '1' then
            pc_sel    <= "11";
            pc_target <= redirect_pc;
        elsif stall = '1' then
            pc_sel    <= "00";
        elsif imm_pending = '1' then
            if lat_is_uncond = '1' then
                pc_sel    <= "11";
                pc_target <= i_data;
            elsif pred_taken_lat = '1' and pred_hit_lat = '1' then
                pc_sel    <= "11";
                pc_target <= pred_target_lat;
            else
                pc_sel    <= "01";
            end if;
        elsif pause_fetch = '1' then
            pc_sel <= "00";
        elsif needs_imm = '1' then
            pc_sel <= "01";
        elsif pred_taken = '1' and pred_hit = '1' then
            pc_sel    <= "11";
            pc_target <= pred_target;
        else
            pc_sel <= "01";
        end if;
    end process;

    -- Fetch FSM state registers (synchronous reset aligned with U_PC)
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                imm_pending     <= '0';
                ir_latched      <= (others => '0');
                pc_at_fetch     <= (others => '0');
                pred_taken_lat  <= '0';
                pred_hit_lat    <= '0';
                pred_target_lat <= (others => '0');
            elsif flush = '1' then
                imm_pending     <= '0';
                pred_taken_lat  <= '0';
                pred_hit_lat    <= '0';
                pred_target_lat <= (others => '0');
            elsif stall = '1' then
                null;
            elsif imm_pending = '1' then
                imm_pending <= '0';
            elsif pause_fetch = '1' then
                null;
            elsif needs_imm = '1' then
                ir_latched      <= i_data(INSTR_W-1 downto 0);
                pc_at_fetch     <= unsigned(pc_v);
                imm_pending     <= '1';
                pred_taken_lat  <= pred_taken;
                pred_hit_lat    <= pred_hit;
                pred_target_lat <= pred_target;
            end if;
        end if;
    end process;
end rtl;
