--------------------------------------------------------------------------
-- fetchStage.vhd
--
-- Owns: the PC, the fetch FSM (handles 2-word instructions), and the
-- branch predictor lookup. Drives the instruction-port address into
-- shared memory and presents the next IF/ID input to the rest of the
-- pipeline.
--
-- Fetch FSM:
--   Normal:           IF/ID gets {ir = M[PC](low16), imm = 0}, PC <- PC+1
--   Imm-fetch cycle1: IF/ID held invalid, latch IR, PC <- PC+1
--   Imm-fetch cycle2: IF/ID gets {IR_latched, imm = M[PC]}, PC <- PC+1
--
-- Predictor:
--   On every fetch, look up PC. If a hit predicts taken, redirect PC to
--   the predicted target on the *next* clock. (The cycle's IR still gets
--   latched into IF/ID; the corresponding ID stage will then see the
--   redirected PC.) The predicted_taken/target travel down the pipeline
--   in a small 2-bit field so EX2 can compare against the actual outcome.
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity fetchStage is
    port(
        clk          : in  std_logic;
        rst          : in  std_logic;

        -- stalls / redirects
        stall        : in  std_logic;             -- hold PC and IF/ID
        flush        : in  std_logic;             -- branch mispredict / interrupt
        redirect_pc  : in  std_logic_vector(DATA_W-1 downto 0);

        -- shared memory (instruction port)
        i_addr       : out std_logic_vector(ADDR_W-1 downto 0);
        i_data       : in  std_logic_vector(DATA_W-1 downto 0);

        -- reset vector (M[0]) for cold-start PC
        reset_vec    : in  std_logic_vector(DATA_W-1 downto 0);

        -- predictor update (driven from EX2)
        bp_upd_en    : in  std_logic;
        bp_upd_pc    : in  std_logic_vector(DATA_W-1 downto 0);
        bp_upd_taken : in  std_logic;
        bp_upd_tgt   : in  std_logic_vector(DATA_W-1 downto 0);

        -- IF/ID inputs (for the IF_ID register)
        ir_out       : out std_logic_vector(INSTR_W-1 downto 0);
        imm_out      : out std_logic_vector(DATA_W-1 downto 0);
        pcp1_out     : out std_logic_vector(DATA_W-1 downto 0);
        pred_taken_o : out std_logic;
        pred_pc_o    : out std_logic_vector(DATA_W-1 downto 0); -- PC of fetched insn
        valid_out    : out std_logic;
        pc_obs       : out std_logic_vector(DATA_W-1 downto 0)
    );
end fetchStage;

architecture rtl of fetchStage is
    -- PC register
    signal pc_r        : unsigned(DATA_W-1 downto 0) := (others => '0');
    signal pc_v        : std_logic_vector(DATA_W-1 downto 0);
    -- FSM
    signal imm_pending : std_logic := '0';
    signal ir_latched  : std_logic_vector(INSTR_W-1 downto 0) := (others=>'0');
    signal pc_at_fetch : unsigned(DATA_W-1 downto 0) := (others=>'0'); -- PC when IR was latched

    -- predictor wires
    signal pred_taken, pred_hit : std_logic;
    signal pred_target          : std_logic_vector(DATA_W-1 downto 0);
    -- Latched predictor outputs for the cycle-2 of an imm-fetch, so
    -- branch metadata travels with the branch instruction (not the
    -- bubble in cycle-1).
    signal pred_taken_lat : std_logic := '0';
    signal pred_hit_lat   : std_logic := '0';
    signal pred_target_lat : std_logic_vector(DATA_W-1 downto 0) := (others => '0');

    -- Local decode: does the just-fetched word need an immediate?
    signal cur_opcode : std_logic_vector(4 downto 0);
    signal needs_imm  : std_logic;

    component branchPredictor is
        generic(IDX_W : integer := 4);
        port(
            clk, rst : in std_logic;
            lookup_pc      : in  std_logic_vector(DATA_W-1 downto 0);
            predict_taken  : out std_logic;
            predict_target : out std_logic_vector(DATA_W-1 downto 0);
            predict_hit    : out std_logic;
            upd_en         : in std_logic;
            upd_pc         : in std_logic_vector(DATA_W-1 downto 0);
            upd_taken      : in std_logic;
            upd_target     : in std_logic_vector(DATA_W-1 downto 0)
        );
    end component;
begin
    pc_v   <= std_logic_vector(pc_r);
    pc_obs <= pc_v;
    i_addr <= pc_v(ADDR_W-1 downto 0);

    cur_opcode <= i_data(15 downto 11);
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
            clk => clk, rst => rst,
            lookup_pc => pc_v,
            predict_taken => pred_taken,
            predict_target => pred_target,
            predict_hit => pred_hit,
            upd_en => bp_upd_en,
            upd_pc => bp_upd_pc,
            upd_taken => bp_upd_taken,
            upd_target => bp_upd_tgt
        );

    -- Drive IF/ID inputs
    process(all)
    begin
        if imm_pending = '1' then
            -- The immediate word is on the bus this cycle. The predictor
            -- output that mattered was the one captured during cycle 1
            -- (when we saw the branch opcode).
            ir_out    <= ir_latched;
            imm_out   <= i_data;
            pcp1_out  <= std_logic_vector(pc_at_fetch + 2);
            pred_pc_o <= std_logic_vector(pc_at_fetch);
            valid_out <= '1';
            pred_taken_o <= pred_taken_lat and pred_hit_lat;
        elsif needs_imm = '1' then
            -- IR is fetched but immediate isn't ready yet; emit a bubble
            -- to IF/ID this cycle. (Next cycle the imm arrives and we
            -- present the full instruction with the latched predictor.)
            ir_out    <= (others => '0');
            imm_out   <= (others => '0');
            pcp1_out  <= (others => '0');
            pred_pc_o <= pc_v;
            valid_out <= '0';
            pred_taken_o <= '0';
        else
            ir_out    <= i_data(INSTR_W-1 downto 0);
            imm_out   <= (others => '0');
            pcp1_out  <= std_logic_vector(pc_r + 1);
            pred_pc_o <= pc_v;
            valid_out <= '1';
            pred_taken_o <= pred_taken and pred_hit;
        end if;
    end process;

    -- PC update + FSM
    process(clk, rst)
    begin
        if rst = '1' then
            pc_r        <= unsigned(reset_vec);
            imm_pending <= '0';
            ir_latched  <= (others=>'0');
            pc_at_fetch <= (others=>'0');
            pred_taken_lat <= '0';
            pred_hit_lat   <= '0';
            pred_target_lat <= (others => '0');
        elsif rising_edge(clk) then
            if flush = '1' then
                pc_r        <= unsigned(redirect_pc);
                imm_pending <= '0';
                pred_taken_lat <= '0';
                pred_hit_lat   <= '0';
                pred_target_lat <= (others => '0');
            elsif stall = '1' then
                -- hold everything (load-use stall)
                null;
            elsif imm_pending = '1' then
                -- second fetch of a 2-word instruction completed.
                -- If the branch predictor predicted this immediate-based
                -- instruction as taken, steer the PC to the latched target.
                -- The old code only advanced to PC+1 here; EX2 then believed
                -- the branch had been predicted taken and would not repair the
                -- PC, which broke loops after the predictor learned them.
                imm_pending <= '0';
                if pred_taken_lat = '1' and pred_hit_lat = '1' then
                    pc_r <= unsigned(pred_target_lat);
                else
                    pc_r <= pc_r + 1;
                end if;
            elsif needs_imm = '1' then
                -- this fetch was an instruction needing an immediate.
                -- Capture the predictor outputs NOW so they travel with
                -- the instruction in cycle 2.
                ir_latched     <= i_data(INSTR_W-1 downto 0);
                pc_at_fetch    <= pc_r;
                imm_pending    <= '1';
                pred_taken_lat <= pred_taken;
                pred_hit_lat   <= pred_hit;
                pred_target_lat <= pred_target;
                pc_r <= pc_r + 1;
            elsif pred_taken = '1' and pred_hit = '1' then
                -- predictor steers fetch (1-word jumps don't exist, but
                -- this branch covers the case if any are added)
                pc_r <= unsigned(pred_target);
            else
                pc_r <= pc_r + 1;
            end if;
        end if;
    end process;
end rtl;
