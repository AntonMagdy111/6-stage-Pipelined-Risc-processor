--------------------------------------------------------------------------
-- execute2Stage.vhd
--
-- Owns: branch resolution against the predictor, memory-address compu-
-- tation for STACK ops (PUSH/POP/CALL/RET/INT/RTI) and LDD/STD, and
-- driving the branch-predictor update.
--
-- For LDD/STD: address is just ex1_ex2_alu (Rsrc + offset), already
--              computed by EX1.
-- For PUSH/CALL/INT: address = SP, store data = b/pcp1; SP decrements.
-- For POP/RET/RTI:   address = SP+1, no data store; SP increments.
--   (The actual SP register increment/decrement is driven by sp_op
--    which goes to the sp.vhd entity at top level. This stage just
--    computes the address using the *pre-update* SP value passed in.)
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity execute2Stage is
    port(
        -- pipeline inputs (from EX1/EX2)
        valid_in    : in std_logic;
        op_in       : in std_logic_vector(4 downto 0);
        ctrl_in     : in ctrl_bundle;
        alu_res_in  : in std_logic_vector(DATA_W-1 downto 0);
        store_in    : in std_logic_vector(DATA_W-1 downto 0);
        imm_in      : in std_logic_vector(DATA_W-1 downto 0);
        pcp1_in     : in std_logic_vector(DATA_W-1 downto 0);
        z_in, n_in, c_in : in std_logic;

        -- current SP (architectural, pre-update)
        sp_in       : in std_logic_vector(DATA_W-1 downto 0);

        -- predictor info that travelled with the instruction
        pred_taken_in : in std_logic;
        pred_pc_in    : in std_logic_vector(DATA_W-1 downto 0);

        -- outputs to EX2/MEM
        mem_addr_o  : out std_logic_vector(DATA_W-1 downto 0);
        mem_store_o : out std_logic_vector(DATA_W-1 downto 0);

        -- SP control
        sp_op_o     : out std_logic_vector(1 downto 0);

        -- branch resolution / mispredict
        mispredict   : out std_logic;          -- pulse: flush IF, ID, EX1
        redirect_pc  : out std_logic_vector(DATA_W-1 downto 0);

        -- predictor update
        bp_upd_en    : out std_logic;
        bp_upd_pc    : out std_logic_vector(DATA_W-1 downto 0);
        bp_upd_taken : out std_logic;
        bp_upd_tgt   : out std_logic_vector(DATA_W-1 downto 0);

        -- flag updates to CCR
        ccr_upd_zn   : out std_logic;
        ccr_upd_c    : out std_logic;
        ccr_set_c    : out std_logic;
        ccr_z, ccr_n, ccr_c : out std_logic
    );
end execute2Stage;

architecture rtl of execute2Stage is
    signal taken : std_logic;
    signal target : std_logic_vector(DATA_W-1 downto 0);
begin
    -- Resolve branch outcome
    process(all)
    begin
        taken  <= '0';
        target <= imm_in;
        if valid_in = '1' then
            if ctrl_in.is_branch = '1' then
                case op_in is
                    when OP_JZ => taken <= z_in;
                    when OP_JN => taken <= n_in;
                    when OP_JC => taken <= c_in;
                    when others => null;
                end case;
            elsif ctrl_in.is_jump = '1' then
                if ctrl_in.is_ret = '1' or ctrl_in.is_rti = '1'
                   or ctrl_in.is_int = '1' then
                    taken <= '0';   -- target comes from MEM stage
                else
                    taken <= '1';   -- JMP / CALL
                end if;
            end if;
        end if;
    end process;

    -- Mispredict if actual outcome's taken-bit differs from predictor's.
    -- (Target mismatches on hit are negligible because the BTB wouldn't
    --  retarget between fetch and EX2 in this design.)
    mispredict  <= valid_in and (ctrl_in.is_branch or ctrl_in.is_jump)
                   and (taken xor pred_taken_in);
    redirect_pc <= target when taken = '1' else pcp1_in;

    -- Predictor update on every resolved branch (cond or uncond)
    bp_upd_en    <= valid_in and (ctrl_in.is_branch or
                    (ctrl_in.is_jump and not (ctrl_in.is_ret or ctrl_in.is_rti)));
    bp_upd_pc    <= pred_pc_in;
    bp_upd_taken <= taken;
    bp_upd_tgt   <= target;

    -- Memory address & store data
    process(all)
    begin
        if valid_in = '1' and (ctrl_in.is_call = '1' or ctrl_in.is_int = '1'
                                or ctrl_in.is_push = '1') then
            mem_addr_o  <= sp_in;
            if ctrl_in.is_push = '1' then
                mem_store_o <= store_in;     -- value of Rsrc (rs2-read)
            else
                mem_store_o <= pcp1_in;      -- return address
            end if;
        elsif valid_in = '1' and (ctrl_in.is_ret = '1' or ctrl_in.is_rti = '1'
                                   or ctrl_in.is_pop = '1') then
            -- POP/RET/RTI: read M[SP+1] (after SP increment, addr = new SP)
            mem_addr_o  <= std_logic_vector(unsigned(sp_in) + 1);
            mem_store_o <= (others => '0');
        elsif valid_in = '1' and op_in = OP_STD then
            mem_addr_o  <= alu_res_in;       -- Rsrc + offset
            mem_store_o <= store_in;         -- forwarded Rsrc1 value
        elsif valid_in = '1' and op_in = OP_LDD then
            mem_addr_o  <= alu_res_in;
            mem_store_o <= (others => '0');
        elsif valid_in = '1' and ctrl_in.is_swap = '1' then
            -- SWAP: store_in carries Rdst's old value; route it through
            -- so the secondary WB at MEM stage can write it to Rs2.
            mem_addr_o  <= (others => '0');
            mem_store_o <= store_in;
        else
            mem_addr_o  <= (others => '0');
            mem_store_o <= (others => '0');
        end if;
    end process;

    sp_op_o <= ctrl_in.sp_op when valid_in = '1' else "00";

    -- Flag updates: arithmetic/logical ops + ISA: JZ/JN/JC clear flag when taken
    process(all)
        variable b_jz, b_jn, b_jc : std_logic;
    begin
        b_jz := '0'; b_jn := '0'; b_jc := '0';
        if valid_in = '1' and ctrl_in.is_branch = '1' and taken = '1' then
            if    op_in = OP_JZ then b_jz := '1';
            elsif op_in = OP_JN then b_jn := '1';
            elsif op_in = OP_JC then b_jc := '1';
            end if;
        end if;
        ccr_upd_zn <= (ctrl_in.upd_zn and valid_in) or b_jz or b_jn;
        ccr_upd_c  <= (ctrl_in.upd_c  and valid_in) or b_jc;
        ccr_set_c  <= ctrl_in.set_c and valid_in;
        if    b_jz = '1' then ccr_z <= '0'; else ccr_z <= z_in; end if;
        if    b_jn = '1' then ccr_n <= '0'; else ccr_n <= n_in; end if;
        if    b_jc = '1' then ccr_c <= '0'; else ccr_c <= c_in; end if;
    end process;
end rtl;
