--------------------------------------------------------------------------
-- branchPredictor.vhd
--
-- 2-bit saturating branch predictor with a 16-entry Branch Target Buffer.
-- Both lookup and prediction happen in the FETCH stage, so a correctly
-- predicted taken branch costs zero bubbles.
--
-- Counter encoding (Smith-style 2-bit saturating counter):
--   00 = strongly not taken
--   01 = weakly   not taken
--   10 = weakly   taken
--   11 = strongly taken
--   Predict TAKEN iff the high bit is '1'.
--
-- BTB:
--   16 entries, indexed by PC[3:0]. Each entry stores:
--     valid  (1 bit)
--     tag    (the rest of PC, 28 bits, used to detect index collisions)
--     target (32 bits, branch target address)
--     ctr    (2-bit saturating counter)
--
-- Interface (combinational outputs, synchronous update):
--   Lookup port:
--     lookup_pc       -> the PC being fetched
--     predict_taken   -> '1' if predictor says take this branch
--     predict_target  -> address to redirect PC to
--     predict_hit     -> '1' if the BTB has a valid matching entry
--   Update port (driven from EX2 when a branch resolves):
--     upd_en          -> resolved a branch this cycle
--     upd_pc          -> PC of the resolved branch
--     upd_taken       -> actual outcome
--     upd_target      -> actual target (only used when taken)
--
-- On reset, all entries invalidated.
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity branchPredictor is
    generic(
        IDX_W : integer := 4         -- 2^4 = 16 entries
    );
    port(
        clk             : in  std_logic;
        rst             : in  std_logic;

        -- lookup (in FETCH)
        lookup_pc       : in  std_logic_vector(DATA_W-1 downto 0);
        predict_taken   : out std_logic;
        predict_target  : out std_logic_vector(DATA_W-1 downto 0);
        predict_hit     : out std_logic;

        -- update (from EX2 when a branch resolves)
        upd_en          : in  std_logic;
        upd_pc          : in  std_logic_vector(DATA_W-1 downto 0);
        upd_taken       : in  std_logic;
        upd_target      : in  std_logic_vector(DATA_W-1 downto 0)
    );
end branchPredictor;

architecture rtl of branchPredictor is
    constant NUM_ENT : integer := 2**IDX_W;
    constant TAG_W   : integer := DATA_W - IDX_W;

    type tag_arr_t    is array (0 to NUM_ENT-1) of std_logic_vector(TAG_W-1  downto 0);
    type target_arr_t is array (0 to NUM_ENT-1) of std_logic_vector(DATA_W-1 downto 0);
    type ctr_arr_t    is array (0 to NUM_ENT-1) of std_logic_vector(1 downto 0);
    type valid_arr_t  is array (0 to NUM_ENT-1) of std_logic;

    signal tags    : tag_arr_t    := (others => (others=>'0'));
    signal targets : target_arr_t := (others => (others=>'0'));
    signal ctrs    : ctr_arr_t    := (others => "01");   -- start weakly not-taken
    signal valids  : valid_arr_t  := (others => '0');

    -- index/tag extraction helpers
    function idx_of(pc : std_logic_vector) return integer is
    begin
        return safe_int(pc(IDX_W-1 downto 0));
    end;
    function tag_of(pc : std_logic_vector) return std_logic_vector is
    begin
        return pc(DATA_W-1 downto IDX_W);
    end;

    signal lk_idx, up_idx : integer range 0 to NUM_ENT-1;
    signal lk_tag, up_tag : std_logic_vector(TAG_W-1 downto 0);
    signal hit            : std_logic;
begin
    -- Lookup (combinational)
    lk_idx <= idx_of(lookup_pc);
    lk_tag <= tag_of(lookup_pc);
    up_idx <= idx_of(upd_pc);
    up_tag <= tag_of(upd_pc);

    hit <= '1' when (valids(lk_idx) = '1' and tags(lk_idx) = lk_tag) else '0';

    predict_hit    <= hit;
    predict_target <= targets(lk_idx);
    predict_taken  <= '1' when (hit = '1' and ctrs(lk_idx)(1) = '1') else '0';

    -- Update on resolved branches
    process(clk, rst)
        variable cur : std_logic_vector(1 downto 0);
    begin
        if rst = '1' then
            valids <= (others => '0');
            ctrs   <= (others => "01");
        elsif rising_edge(clk) then
            if upd_en = '1' then
                if valids(up_idx) = '1' and tags(up_idx) = up_tag then
                    -- Existing entry: bump the counter
                    cur := ctrs(up_idx);
                    if upd_taken = '1' then
                        if cur /= "11" then
                            ctrs(up_idx) <= std_logic_vector(unsigned(cur) + 1);
                        end if;
                        targets(up_idx) <= upd_target;     -- refresh target
                    else
                        if cur /= "00" then
                            ctrs(up_idx) <= std_logic_vector(unsigned(cur) - 1);
                        end if;
                    end if;
                else
                    -- Allocate a new entry only if taken (don't pollute on
                    -- not-taken branches we've never seen).
                    if upd_taken = '1' then
                        valids(up_idx)  <= '1';
                        tags(up_idx)    <= up_tag;
                        targets(up_idx) <= upd_target;
                        ctrs(up_idx)    <= "10";   -- weakly taken
                    end if;
                end if;
            end if;
        end if;
    end process;
end rtl;
