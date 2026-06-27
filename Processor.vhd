--------------------------------------------------------------------------
-- Processor.vhd
-- Top-level 6-stage pipelined Von Neumann processor.
--
-- Stages: IF -> ID -> EX1 -> EX2 -> MEM -> WB
-- Pipeline registers: IF_ID, ID_EX1, EX1_EX2, EX2_MEM, MEM_WB
--
-- Reset:
--   PC <- M[0] (the reset-vector word stored at address 0)
--   SP <- 4095
--   CCR <- 0
--   All pipeline registers cleared.
--
-- Interrupt (INTR):
--   Latched. Taken when fetch FSM is idle (no immediate pending). The
--   pipeline is flushed; PC <- 1 (which then loads the interrupt vector
--   from memory address 1 on the next fetch). PC+1 is pushed onto the
--   stack via the same datapath used by INT.
--
--   For a fully spec-correct INT implementation, M[index+2] would be the
--   target. Here we treat INTR as "jump to M[1]"; software-INT (the INT
--   instruction) writes a target through the standard CALL path.
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity Processor is
    generic(
        MEM_FILE : string := "program.mem"
    );
    port(
        clk      : in  std_logic;
        rst      : in  std_logic;
        intr     : in  std_logic;
        in_port  : in  std_logic_vector(DATA_W-1 downto 0);
        out_port : out std_logic_vector(DATA_W-1 downto 0);

        -- Observation outputs for the testbench wave
        pc_obs   : out std_logic_vector(DATA_W-1 downto 0);
        sp_obs   : out std_logic_vector(DATA_W-1 downto 0);
        ccr_obs  : out std_logic_vector(2 downto 0);
        r0_obs,r1_obs,r2_obs,r3_obs,
        r4_obs,r5_obs,r6_obs,r7_obs : out std_logic_vector(DATA_W-1 downto 0);
        in_en_obs : out std_logic
    );
end Processor;

architecture rtl of Processor is
    ----------------------------------------------------------------------
    -- Memory wiring
    ----------------------------------------------------------------------
    signal i_addr : std_logic_vector(ADDR_W-1 downto 0);
    signal i_data : std_logic_vector(DATA_W-1 downto 0);
    signal d_addr : std_logic_vector(ADDR_W-1 downto 0);
    signal d_we, d_re : std_logic;
    signal d_in, d_out : std_logic_vector(DATA_W-1 downto 0);
    signal vec_addr : std_logic_vector(ADDR_W-1 downto 0);
    signal vec_data : std_logic_vector(DATA_W-1 downto 0);

    -- Reset vector lives at memory location 0; we read it through a
    -- dedicated combinational read port (use the data port at addr 0
    -- when not otherwise busy is unsafe; instead we read it via a
    -- snapshot held by Memory.vhd's combinational instruction port at
    -- reset). For simplicity we always provide M[0] via the i-port at
    -- reset and use it as PC's initial value.
    signal reset_vec : std_logic_vector(DATA_W-1 downto 0);

    ----------------------------------------------------------------------
    -- Register file wiring
    ----------------------------------------------------------------------
    signal rf_we      : std_logic;
    signal rf_wraddr  : std_logic_vector(REG_W-1 downto 0);
    signal rf_wrdata  : std_logic_vector(DATA_W-1 downto 0);
    signal rf_rdaddr1 : std_logic_vector(REG_W-1 downto 0);
    signal rf_rdaddr2 : std_logic_vector(REG_W-1 downto 0);
    signal rf_rddata1 : std_logic_vector(DATA_W-1 downto 0);
    signal rf_rddata2 : std_logic_vector(DATA_W-1 downto 0);

    ----------------------------------------------------------------------
    -- Architectural registers
    ----------------------------------------------------------------------
    signal pc_v   : std_logic_vector(DATA_W-1 downto 0);
    signal sp_v   : std_logic_vector(DATA_W-1 downto 0);
    signal ccr_v  : std_logic_vector(2 downto 0);

    ----------------------------------------------------------------------
    -- IF stage
    ----------------------------------------------------------------------
    signal if_ir       : std_logic_vector(INSTR_W-1 downto 0);
    signal if_imm      : std_logic_vector(DATA_W-1 downto 0);
    signal if_pcp1     : std_logic_vector(DATA_W-1 downto 0);
    signal if_valid    : std_logic;
    signal if_pred_taken : std_logic;
    signal if_pred_pc  : std_logic_vector(DATA_W-1 downto 0);

    signal flush_front : std_logic;       -- mispredict / interrupt / RET
    signal redirect_pc : std_logic_vector(DATA_W-1 downto 0);
    signal stall_front : std_logic;       -- load-use stall

    -- Hardware interrupt
    signal hw_int_pending : std_logic := '0';   -- latched intr request
    signal hw_int_active  : std_logic;           -- firing this cycle (pipeline empty)

    -- predictor update wires (driven by EX2)
    signal bp_upd_en   : std_logic;
    signal bp_upd_pc   : std_logic_vector(DATA_W-1 downto 0);
    signal bp_upd_taken: std_logic;
    signal bp_upd_tgt  : std_logic_vector(DATA_W-1 downto 0);

    ----------------------------------------------------------------------
    -- IF/ID register outputs
    ----------------------------------------------------------------------
    signal ifid_ir    : std_logic_vector(INSTR_W-1 downto 0);
    signal ifid_imm   : std_logic_vector(DATA_W-1 downto 0);
    signal ifid_pcp1  : std_logic_vector(DATA_W-1 downto 0);
    signal ifid_valid : std_logic;

    -- predictor info also flows through the pipeline (via separate small regs)
    signal ifid_pred_taken : std_logic := '0';
    signal ifid_pred_pc    : std_logic_vector(DATA_W-1 downto 0) := (others=>'0');

    ----------------------------------------------------------------------
    -- ID stage outputs
    ----------------------------------------------------------------------
    signal id_opcode : std_logic_vector(4 downto 0);
    signal id_rdst, id_rs1, id_rs2 : std_logic_vector(REG_W-1 downto 0);
    signal id_a, id_b, id_store : std_logic_vector(DATA_W-1 downto 0);
    signal id_ctrl : ctrl_bundle;
    -- HW interrupt injection muxes (override ID/EX1 when hw_int_active)
    signal id_ctrl_i  : ctrl_bundle;
    signal id_pcp1_i  : std_logic_vector(DATA_W-1 downto 0);
    signal id_valid_i : std_logic;
    signal hw_int_mem : std_logic;   -- hw_int has reached MEM stage
    signal hw_int_ex1 : std_logic := '0';
    signal hw_int_ex2 : std_logic := '0';
    signal id_needs_imm : std_logic;

    ----------------------------------------------------------------------
    -- ID/EX1 register outputs
    ----------------------------------------------------------------------
    signal idex1_a, idex1_b, idex1_store, idex1_imm, idex1_pcp1 : std_logic_vector(DATA_W-1 downto 0);
    signal idex1_rdst, idex1_rs1, idex1_rs2 : std_logic_vector(REG_W-1 downto 0);
    signal idex1_op    : std_logic_vector(4 downto 0);
    signal idex1_ctrl  : ctrl_bundle;
    signal idex1_valid : std_logic;
    signal idex1_pred_taken : std_logic := '0';
    signal idex1_pred_pc    : std_logic_vector(DATA_W-1 downto 0) := (others=>'0');

    ----------------------------------------------------------------------
    -- Forwarding wires
    ----------------------------------------------------------------------
    signal fwd_sel_a, fwd_sel_b, fwd_sel_store : std_logic_vector(1 downto 0);
    signal swap_fwd_a_sig, swap_fwd_b_sig, swap_fwd_store_sig : std_logic_vector(1 downto 0);
    signal fwd_src_a_reg, fwd_src_b_reg : std_logic_vector(REG_W-1 downto 0);

    ----------------------------------------------------------------------
    -- EX1 outputs
    ----------------------------------------------------------------------
    signal ex1_alu_res : std_logic_vector(DATA_W-1 downto 0);
    signal ex1_store   : std_logic_vector(DATA_W-1 downto 0);
    signal ex1_z, ex1_n, ex1_c : std_logic;

    ----------------------------------------------------------------------
    -- EX1/EX2 register outputs
    ----------------------------------------------------------------------
    signal ex12_alu_res, ex12_store, ex12_imm, ex12_pcp1 : std_logic_vector(DATA_W-1 downto 0);
    -- FIX: when EX1/EX2 holds a WB_IMM instruction (LDM), alu_res is garbage;
    -- forward the immediate word instead so downstream instructions get the right value.
    signal ex12_fwd : std_logic_vector(DATA_W-1 downto 0);
    signal ex12_rdst, ex12_rs2 : std_logic_vector(REG_W-1 downto 0);
    signal ex12_op : std_logic_vector(4 downto 0);
    signal ex12_z, ex12_n, ex12_c : std_logic;
    signal ex12_ctrl : ctrl_bundle;
    -- Flag forwarding: branches read from CCR register, others from pipeline
    signal ex2_z_in, ex2_n_in, ex2_c_in : std_logic;
    signal ex12_valid : std_logic;
    signal ex12_pred_taken : std_logic := '0';
    signal ex12_pred_pc    : std_logic_vector(DATA_W-1 downto 0) := (others=>'0');

    ----------------------------------------------------------------------
    -- EX2 outputs
    ----------------------------------------------------------------------
    signal ex2_mem_addr  : std_logic_vector(DATA_W-1 downto 0);
    signal ex2_mem_store : std_logic_vector(DATA_W-1 downto 0);
    signal ex2_sp_op     : std_logic_vector(1 downto 0);
    signal ex2_misp      : std_logic;
    signal ex2_redir_pc  : std_logic_vector(DATA_W-1 downto 0);
    signal ex2_ccr_upd_zn, ex2_ccr_upd_c, ex2_ccr_set_c : std_logic;
    signal ex2_ccr_z, ex2_ccr_n, ex2_ccr_c : std_logic;

    ----------------------------------------------------------------------
    -- EX2/MEM register outputs
    ----------------------------------------------------------------------
    signal e2m_mem_addr, e2m_store, e2m_alu_res, e2m_imm : std_logic_vector(DATA_W-1 downto 0);
    signal e2m_rdst : std_logic_vector(REG_W-1 downto 0);
    signal e2m_rs2  : std_logic_vector(REG_W-1 downto 0);
    signal e2m_op   : std_logic_vector(4 downto 0);
    signal e2m_ctrl : ctrl_bundle;
    signal e2m_valid: std_logic;
    signal e2m_valid_in_gated : std_logic;

    signal mem_wb_data  : std_logic_vector(DATA_W-1 downto 0);
    signal mem_wb_we    : std_logic;
    signal mem_wb_rdst  : std_logic_vector(REG_W-1 downto 0);
    signal mem_swap_we  : std_logic;
    signal mem_swap_addr: std_logic_vector(REG_W-1 downto 0);
    signal mem_swap_data: std_logic_vector(DATA_W-1 downto 0);
    signal mem_out_en   : std_logic;
    signal mem_out_dat  : std_logic_vector(DATA_W-1 downto 0);
    signal mem_ret_redirect : std_logic;
    signal mem_ret_target   : std_logic_vector(DATA_W-1 downto 0);

    signal mw_data : std_logic_vector(DATA_W-1 downto 0);
    signal mw_rdst : std_logic_vector(REG_W-1 downto 0);
    signal mw_we   : std_logic;
    signal mw_valid: std_logic;
    signal mw_swap_we  : std_logic;
    signal mw_swap_addr: std_logic_vector(REG_W-1 downto 0);
    signal mw_swap_data: std_logic_vector(DATA_W-1 downto 0);
    signal swap_data_fwd : std_logic_vector(DATA_W-1 downto 0); -- muxed swap data for EX1

    ----------------------------------------------------------------------
    -- Hazard wires
    ----------------------------------------------------------------------
    signal hz_load_use, hz_imm_stall, hz_stall : std_logic;
    signal halt_latch : std_logic := '0';  -- set when HLT reaches ID stage
    signal not_stall : std_logic;
    signal flush_or_stall : std_logic;
    signal sp_op_gated : std_logic_vector(1 downto 0);

    ----------------------------------------------------------------------
    -- Reset-vector latching
    ----------------------------------------------------------------------
    signal reset_seen   : std_logic := '1';
    signal pc_init_done : std_logic := '0';

    ----------------------------------------------------------------------
    -- Component declarations
    ----------------------------------------------------------------------
    component Memory is
        generic(MEM_FILE : string := "program.mem");
        port(
            clk, rst : in std_logic;
            i_addr : in  std_logic_vector(ADDR_W-1 downto 0);
            i_data : out std_logic_vector(DATA_W-1 downto 0);
            d_addr : in  std_logic_vector(ADDR_W-1 downto 0);
            d_we, d_re : in std_logic;
            d_in   : in  std_logic_vector(DATA_W-1 downto 0);
            d_out  : out std_logic_vector(DATA_W-1 downto 0);
            vec_addr : in  std_logic_vector(ADDR_W-1 downto 0);
            vec_data : out std_logic_vector(DATA_W-1 downto 0);
            rst_vec : out std_logic_vector(DATA_W-1 downto 0)
        );
    end component;

    component RegisterFile is
        port(
            clk, rst : in std_logic;
            we : in std_logic;
            wr_addr : in std_logic_vector(REG_W-1 downto 0);
            wr_data : in std_logic_vector(DATA_W-1 downto 0);
            we2 : in std_logic;
            wr_addr2 : in std_logic_vector(REG_W-1 downto 0);
            wr_data2 : in std_logic_vector(DATA_W-1 downto 0);
            rd_addr1, rd_addr2 : in std_logic_vector(REG_W-1 downto 0);
            rd_data1, rd_data2 : out std_logic_vector(DATA_W-1 downto 0);
            r0_o,r1_o,r2_o,r3_o,r4_o,r5_o,r6_o,r7_o : out std_logic_vector(DATA_W-1 downto 0)
        );
    end component;

    component sp is
        port(
            clk, rst : in std_logic;
            sel : in std_logic_vector(1 downto 0);
            sp_out : out std_logic_vector(DATA_W-1 downto 0)
        );
    end component;

    component CCR is
        port(
            clk, rst : in std_logic;
            upd_zn, upd_c, set_c : in std_logic;
            z_in, n_in, c_in : in std_logic;
            ccr_out : out std_logic_vector(2 downto 0)
        );
    end component;

    component fetchStage is
        port(
            clk, rst : in std_logic;
            stall, flush : in std_logic;
            redirect_pc : in std_logic_vector(DATA_W-1 downto 0);
            i_addr : out std_logic_vector(ADDR_W-1 downto 0);
            i_data : in  std_logic_vector(DATA_W-1 downto 0);
            reset_vec : in std_logic_vector(DATA_W-1 downto 0);
            bp_upd_en : in std_logic;
            bp_upd_pc : in std_logic_vector(DATA_W-1 downto 0);
            bp_upd_taken : in std_logic;
            bp_upd_tgt : in std_logic_vector(DATA_W-1 downto 0);
            ir_out : out std_logic_vector(INSTR_W-1 downto 0);
            imm_out, pcp1_out : out std_logic_vector(DATA_W-1 downto 0);
            pred_taken_o : out std_logic;
            pred_pc_o : out std_logic_vector(DATA_W-1 downto 0);
            valid_out : out std_logic;
            pc_obs : out std_logic_vector(DATA_W-1 downto 0)
        );
    end component;

    component decodeStage is
        port(
            ir : in std_logic_vector(INSTR_W-1 downto 0);
            rd_addr1_o, rd_addr2_o : out std_logic_vector(REG_W-1 downto 0);
            rd_data1, rd_data2 : in std_logic_vector(DATA_W-1 downto 0);
            imm_in : in std_logic_vector(DATA_W-1 downto 0);
            opcode_o : out std_logic_vector(4 downto 0);
            rdst_o, rs1_o, rs2_o : out std_logic_vector(REG_W-1 downto 0);
            a_o, b_o, store_o : out std_logic_vector(DATA_W-1 downto 0);
            ctrl_o : out ctrl_bundle;
            cu_needs_imm : out std_logic
        );
    end component;

    component IF_ID is
        port(
            clk, rst, en, flush : in std_logic;
            ir_in : in std_logic_vector(INSTR_W-1 downto 0);
            imm_in, pcp1_in : in std_logic_vector(DATA_W-1 downto 0);
            valid_in : in std_logic;
            ir_out : out std_logic_vector(INSTR_W-1 downto 0);
            imm_out, pcp1_out : out std_logic_vector(DATA_W-1 downto 0);
            valid_out : out std_logic
        );
    end component;

    component ID_EX1 is
        port(
            clk, rst, en, flush : in std_logic;
            a_in, b_in, store_in, imm_in, pcp1_in : in std_logic_vector(DATA_W-1 downto 0);
            rdst_in, rs1_in, rs2_in : in std_logic_vector(REG_W-1 downto 0);
            op_in : in std_logic_vector(4 downto 0);
            ctrl_in : in ctrl_bundle;
            valid_in : in std_logic;
            a_out, b_out, store_out, imm_out, pcp1_out : out std_logic_vector(DATA_W-1 downto 0);
            rdst_out, rs1_out, rs2_out : out std_logic_vector(REG_W-1 downto 0);
            op_out : out std_logic_vector(4 downto 0);
            ctrl_out : out ctrl_bundle;
            valid_out : out std_logic
        );
    end component;

    component EX1_EX2 is
        port(
            clk, rst, flush : in std_logic;
            alu_res_in, store_in, imm_in, pcp1_in : in std_logic_vector(DATA_W-1 downto 0);
            rdst_in, rs2_in : in std_logic_vector(REG_W-1 downto 0);
            op_in : in std_logic_vector(4 downto 0);
            z_in, n_in, c_in : in std_logic;
            ctrl_in : in ctrl_bundle;
            valid_in : in std_logic;
            alu_res_out, store_out, imm_out, pcp1_out : out std_logic_vector(DATA_W-1 downto 0);
            rdst_out, rs2_out : out std_logic_vector(REG_W-1 downto 0);
            op_out : out std_logic_vector(4 downto 0);
            z_out, n_out, c_out : out std_logic;
            ctrl_out : out ctrl_bundle;
            valid_out : out std_logic
        );
    end component;

    component EX2_MEM is
        port(
            clk, rst : in std_logic;
            mem_addr_in, store_in, alu_res_in, imm_in : in std_logic_vector(DATA_W-1 downto 0);
            rdst_in : in std_logic_vector(REG_W-1 downto 0);
            rs2_in  : in std_logic_vector(REG_W-1 downto 0);
            op_in : in std_logic_vector(4 downto 0);
            ctrl_in : in ctrl_bundle;
            valid_in : in std_logic;
            mem_addr_out, store_out, alu_res_out, imm_out : out std_logic_vector(DATA_W-1 downto 0);
            rdst_out : out std_logic_vector(REG_W-1 downto 0);
            rs2_out  : out std_logic_vector(REG_W-1 downto 0);
            op_out : out std_logic_vector(4 downto 0);
            ctrl_out : out ctrl_bundle;
            valid_out : out std_logic
        );
    end component;

    component MEM_WB is
        port(
            clk, rst : in std_logic;
            flush : in std_logic;
            wb_data_in : in std_logic_vector(DATA_W-1 downto 0);
            rdst_in : in std_logic_vector(REG_W-1 downto 0);
            we_in, valid_in : in std_logic;
            swap_we_in : in std_logic;
            swap_addr_in : in std_logic_vector(REG_W-1 downto 0);
            swap_data_in : in std_logic_vector(DATA_W-1 downto 0);
            wb_data_out : out std_logic_vector(DATA_W-1 downto 0);
            rdst_out : out std_logic_vector(REG_W-1 downto 0);
            we_out, valid_out : out std_logic;
            swap_we_out : out std_logic;
            swap_addr_out : out std_logic_vector(REG_W-1 downto 0);
            swap_data_out : out std_logic_vector(DATA_W-1 downto 0)
        );
    end component;

    component execute1Stage is
        port(
            a_in, b_in, store_in : in std_logic_vector(DATA_W-1 downto 0);
            ex1_ex2_alu  : in std_logic_vector(DATA_W-1 downto 0);
            ex2_mem_alu  : in std_logic_vector(DATA_W-1 downto 0);
            mem_wb_data  : in std_logic_vector(DATA_W-1 downto 0);
            swap_data_e1e2 : in std_logic_vector(DATA_W-1 downto 0);
            swap_data_mem  : in std_logic_vector(DATA_W-1 downto 0);
            swap_data_wb   : in std_logic_vector(DATA_W-1 downto 0);
            sel_a       : in std_logic_vector(1 downto 0);
            sel_b       : in std_logic_vector(1 downto 0);
            sel_store   : in std_logic_vector(1 downto 0);
            swap_fwd_a  : in std_logic_vector(1 downto 0);
            swap_fwd_b  : in std_logic_vector(1 downto 0);
            swap_fwd_store : in std_logic_vector(1 downto 0);
            is_swap_in  : in std_logic;
            op      : in std_logic_vector(3 downto 0);
            alu_res_o   : out std_logic_vector(DATA_W-1 downto 0);
            store_o     : out std_logic_vector(DATA_W-1 downto 0);
            z_o, n_o, c_o : out std_logic
        );
    end component;

    component execute2Stage is
        port(
            valid_in : in std_logic;
            op_in : in std_logic_vector(4 downto 0);
            ctrl_in : in ctrl_bundle;
            alu_res_in, store_in, imm_in, pcp1_in : in std_logic_vector(DATA_W-1 downto 0);
            z_in, n_in, c_in : in std_logic;
            sp_in : in std_logic_vector(DATA_W-1 downto 0);
            pred_taken_in : in std_logic;
            pred_pc_in : in std_logic_vector(DATA_W-1 downto 0);
            mem_addr_o, mem_store_o : out std_logic_vector(DATA_W-1 downto 0);
            sp_op_o : out std_logic_vector(1 downto 0);
            mispredict : out std_logic;
            redirect_pc : out std_logic_vector(DATA_W-1 downto 0);
            bp_upd_en : out std_logic;
            bp_upd_pc, bp_upd_tgt : out std_logic_vector(DATA_W-1 downto 0);
            bp_upd_taken : out std_logic;
            ccr_upd_zn, ccr_upd_c, ccr_set_c : out std_logic;
            ccr_z, ccr_n, ccr_c : out std_logic
        );
    end component;

    component memoryStage is
        port(
            valid_in : in std_logic;
            ctrl_in : in ctrl_bundle;
            mem_addr_in, store_in, alu_res_in, imm_in : in std_logic_vector(DATA_W-1 downto 0);
            rdst_in : in std_logic_vector(REG_W-1 downto 0);
            rs2_in  : in std_logic_vector(REG_W-1 downto 0);
            in_port : in std_logic_vector(DATA_W-1 downto 0);
            hw_int_in   : in std_logic;
            d_addr_o : out std_logic_vector(ADDR_W-1 downto 0);
            d_we_o, d_re_o : out std_logic;
            d_in_o : out std_logic_vector(DATA_W-1 downto 0);
            d_out_in : in std_logic_vector(DATA_W-1 downto 0);
            vec_addr_o : out std_logic_vector(ADDR_W-1 downto 0);
            vec_data_in : in std_logic_vector(DATA_W-1 downto 0);
            wb_data_o : out std_logic_vector(DATA_W-1 downto 0);
            wb_we_o : out std_logic;
            wb_rdst_o : out std_logic_vector(REG_W-1 downto 0);
            swap_we_o   : out std_logic;
            swap_addr_o : out std_logic_vector(REG_W-1 downto 0);
            swap_data_o : out std_logic_vector(DATA_W-1 downto 0);
            out_en_o : out std_logic;
            out_data_o : out std_logic_vector(DATA_W-1 downto 0);
            ret_redirect : out std_logic;
            ret_target : out std_logic_vector(DATA_W-1 downto 0)
        );
    end component;

    component writeBackStage is
        port(
            valid_in, we_in : in std_logic;
            rdst_in : in std_logic_vector(REG_W-1 downto 0);
            data_in : in std_logic_vector(DATA_W-1 downto 0);
            rf_we_o : out std_logic;
            rf_addr_o : out std_logic_vector(REG_W-1 downto 0);
            rf_data_o : out std_logic_vector(DATA_W-1 downto 0)
        );
    end component;

    component forwardingUnit is
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
    end component;

    component hazardDetectionUnit is
        port(
            id_rs1, id_rs2 : in std_logic_vector(REG_W-1 downto 0);
            id_use_imm : in std_logic;
            id_is_branch : in std_logic;
            id_ex1_valid : in std_logic;
            id_ex1_rdst : in std_logic_vector(REG_W-1 downto 0);
            id_ex1_wb_sel : in std_logic_vector(1 downto 0);
            id_ex1_in_en : in std_logic;
            ex1_ex2_valid  : in std_logic;
            ex1_ex2_rdst   : in std_logic_vector(REG_W-1 downto 0);
            ex1_ex2_wb_sel : in std_logic_vector(1 downto 0);
            ex1_ex2_in_en  : in std_logic;
            cu_needs_imm : in std_logic;
            imm_pending : in std_logic;
            load_use_stall, imm_stall, stall : out std_logic;
            id_ex1_is_swap   : in std_logic;
            id_ex1_rs2_addr  : in std_logic_vector(REG_W-1 downto 0);
            ex1_ex2_is_swap  : in std_logic;
            ex1_ex2_rs2_addr : in std_logic_vector(REG_W-1 downto 0)
        );
    end component;

    component outPutReg is
        port(
            clk, rst : in std_logic;
            out_en : in std_logic;
            data_in : in std_logic_vector(DATA_W-1 downto 0);
            out_port : out std_logic_vector(DATA_W-1 downto 0)
        );
    end component;

    -- Read M[0] for the reset vector. We tie the i-port to address 0
    -- before PC is initialized; combinational read returns M[0].
    signal pc_init_addr : std_logic_vector(ADDR_W-1 downto 0);
begin
    -- Reset vector now comes from a dedicated Memory port that always
    -- reads M[0]. This removes the old circular dependency where
    -- reset_vec came from i_data, which depends on PC, which is set
    -- from reset_vec.

    ----------------------------------------------------------------------
    -- Memory
    ----------------------------------------------------------------------
    U_MEM : Memory
        generic map(MEM_FILE => MEM_FILE)
        port map(clk => clk, rst => rst,
                 i_addr => i_addr, i_data => i_data,
                 d_addr => d_addr, d_we => d_we, d_re => d_re,
                 d_in => d_in, d_out => d_out,
                 vec_addr => vec_addr, vec_data => vec_data,
                 rst_vec => reset_vec);

    ----------------------------------------------------------------------
    -- Register file
    ----------------------------------------------------------------------
    U_RF : RegisterFile
        port map(clk => clk, rst => rst,
                 we => rf_we, wr_addr => rf_wraddr, wr_data => rf_wrdata,
                 we2 => mw_swap_we, wr_addr2 => mw_swap_addr, wr_data2 => mw_swap_data,
                 rd_addr1 => rf_rdaddr1, rd_addr2 => rf_rdaddr2,
                 rd_data1 => rf_rddata1, rd_data2 => rf_rddata2,
                 r0_o => r0_obs, r1_o => r1_obs, r2_o => r2_obs, r3_o => r3_obs,
                 r4_o => r4_obs, r5_o => r5_obs, r6_o => r6_obs, r7_o => r7_obs);

    ----------------------------------------------------------------------
    -- SP and CCR
    ----------------------------------------------------------------------
    U_SP : sp
        port map(clk => clk, rst => rst, sel => sp_op_gated, sp_out => sp_v);

    U_CCR : CCR
        port map(clk => clk, rst => rst,
                 upd_zn => ex2_ccr_upd_zn, upd_c => ex2_ccr_upd_c,
                 set_c => ex2_ccr_set_c,
                 z_in => ex2_ccr_z, n_in => ex2_ccr_n, c_in => ex2_ccr_c,
                 ccr_out => ccr_v);

    ----------------------------------------------------------------------
    -- Fetch
    ----------------------------------------------------------------------
    -- Hardware interrupt: fire when pipeline front is clear (no stall/flush in progress)
    hw_int_active <= hw_int_pending and not ex2_misp and not mem_ret_redirect
                     and not hz_stall and not halt_latch;

    flush_front <= ex2_misp or mem_ret_redirect or hw_int_active;
    redirect_pc <= mem_ret_target when mem_ret_redirect = '1' else ex2_redir_pc;
    stall_front <= hz_stall or halt_latch;
    not_stall   <= not (hz_stall or halt_latch);
    flush_or_stall <= flush_front or hz_stall or halt_latch;
    -- If an older RET/RTI/INT redirects from MEM, the instruction currently
    -- in EX2 is on the wrong path and must not update SP.
    sp_op_gated <= "00" when mem_ret_redirect = '1' else ex2_sp_op;

    -- HLT latch: once HLT reaches ID/EX1, freeze pipeline forever
    halt_proc : process(clk, rst)
    begin
        if rst = '1' then
            halt_latch <= '0';
        elsif rising_edge(clk) then
            -- Do not latch a wrong-path HLT in the same cycle an older
            -- CALL/branch/RET/INT flushes the front of the pipeline.
            if flush_front = '0' and idex1_valid = '1' and idex1_ctrl.halt = '1' then
                halt_latch <= '1';
            end if;
        end if;
    end process;

    -- HW interrupt latch: capture intr edge, clear when we fire it
    hw_int_proc : process(clk, rst)
    begin
        if rst = '1' then
            hw_int_pending <= '0';
        elsif rising_edge(clk) then
            if intr = '1' then
                hw_int_pending <= '1';
            end if;
            if hw_int_active = '1' then
                hw_int_pending <= '0';
            end if;
        end if;
    end process;

    -- Propagate hw_int flag through pipeline stages (ID→EX1→EX2→MEM)
    hw_int_shift : process(clk, rst)
    begin
        if rst = '1' then
            hw_int_ex1 <= '0'; hw_int_ex2 <= '0';
        elsif rising_edge(clk) then
            hw_int_ex1 <= hw_int_active;
            hw_int_ex2 <= hw_int_ex1;
        end if;
    end process;
    hw_int_mem <= hw_int_ex2;

    -- Flag forwarding: branches read from CCR register directly
    -- Other instructions read flags they computed themselves in EX1
    ex2_z_in <= ccr_v(0) when ex12_ctrl.is_branch = '1' else ex12_z;
    ex2_n_in <= ccr_v(1) when ex12_ctrl.is_branch = '1' else ex12_n;
    ex2_c_in <= ccr_v(2) when ex12_ctrl.is_branch = '1' else ex12_c;

    U_FETCH : fetchStage
        port map(clk => clk, rst => rst,
                 stall => stall_front, flush => flush_front,
                 redirect_pc => redirect_pc,
                 i_addr => i_addr, i_data => i_data,
                 reset_vec => reset_vec,
                 bp_upd_en => bp_upd_en, bp_upd_pc => bp_upd_pc,
                 bp_upd_taken => bp_upd_taken, bp_upd_tgt => bp_upd_tgt,
                 ir_out => if_ir, imm_out => if_imm, pcp1_out => if_pcp1,
                 pred_taken_o => if_pred_taken, pred_pc_o => if_pred_pc,
                 valid_out => if_valid, pc_obs => pc_obs);

    ----------------------------------------------------------------------
    -- IF/ID register
    ----------------------------------------------------------------------
    U_IFID : IF_ID
        port map(clk => clk, rst => rst,
                 en => not_stall,
                 flush => flush_front,
                 ir_in => if_ir, imm_in => if_imm, pcp1_in => if_pcp1,
                 valid_in => if_valid,
                 ir_out => ifid_ir, imm_out => ifid_imm, pcp1_out => ifid_pcp1,
                 valid_out => ifid_valid);

    -- Tiny side-band registers for predictor info travelling through pipe
    process(clk, rst)
    begin
        if rst = '1' then
            ifid_pred_taken <= '0';
            ifid_pred_pc    <= (others=>'0');
        elsif rising_edge(clk) then
            if flush_front = '1' then
                ifid_pred_taken <= '0';
                ifid_pred_pc    <= (others=>'0');
            elsif stall_front = '0' then
                ifid_pred_taken <= if_pred_taken;
                ifid_pred_pc    <= if_pred_pc;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------
    -- Decode
    ----------------------------------------------------------------------
    U_DEC : decodeStage
        port map(ir => ifid_ir,
                 rd_addr1_o => rf_rdaddr1, rd_addr2_o => rf_rdaddr2,
                 rd_data1 => rf_rddata1, rd_data2 => rf_rddata2,
                 imm_in => ifid_imm,
                 opcode_o => id_opcode,
                 rdst_o => id_rdst, rs1_o => id_rs1, rs2_o => id_rs2,
                 a_o => id_a, b_o => id_b, store_o => id_store,
                 ctrl_o => id_ctrl, cu_needs_imm => id_needs_imm);

    ----------------------------------------------------------------------
    -- Hazard detection
    ----------------------------------------------------------------------
    U_HZ : hazardDetectionUnit
        port map(id_rs1 => id_rs1, id_rs2 => id_rs2,
                 id_use_imm => id_ctrl.use_imm,
                 id_is_branch => id_ctrl.is_branch,
                 id_ex1_valid => idex1_valid,
                 id_ex1_rdst => idex1_rdst,
                 id_ex1_wb_sel => idex1_ctrl.wb_sel,
                 id_ex1_in_en => idex1_ctrl.in_en,
                 ex1_ex2_valid  => ex12_valid,
                 ex1_ex2_rdst   => ex12_rdst,
                 ex1_ex2_wb_sel => ex12_ctrl.wb_sel,
                 ex1_ex2_in_en  => ex12_ctrl.in_en,
                 cu_needs_imm => '0',  -- imm-fetch handled inside fetchStage
                 imm_pending  => '0',
                 load_use_stall => hz_load_use,
                 imm_stall => hz_imm_stall,
                 stall => hz_stall,
                 id_ex1_is_swap   => idex1_ctrl.is_swap,
                 id_ex1_rs2_addr  => idex1_rs2,
                 ex1_ex2_is_swap  => ex12_ctrl.is_swap,
                 ex1_ex2_rs2_addr => ex12_rs2);

    -- HW interrupt injection: when hw_int_active, override ID/EX1 inputs
    -- with a fake INT ctrl bundle so MEM stage pushes PC and redirects to M[1]
    id_ctrl_i  <= (is_int=>'1', sp_op=>"10", is_branch=>'0', is_jump=>'1',
                   wb_sel=>WB_ALU, reg_we=>'0', mem_we=>'0', mem_re=>'0',
                   alu_op=>ALU_PASS, upd_zn=>'0', upd_c=>'0', set_c=>'0', halt=>'0',
                   out_en=>'0', in_en=>'0', use_imm=>'0',
                   is_swap=>'0', is_push=>'0', is_pop=>'0',
                   is_call=>'0', is_ret=>'0', is_rti=>'0') when hw_int_active = '1'
              else id_ctrl;
    id_pcp1_i  <= ifid_pcp1 when hw_int_active = '0' else pc_obs;
    id_valid_i <= ifid_valid when hw_int_active = '0' else '1';

    ----------------------------------------------------------------------
    -- ID/EX1 register
    ----------------------------------------------------------------------
    U_IDEX1 : ID_EX1
        port map(clk => clk, rst => rst,
                 en => '1',
                 flush => flush_or_stall,
                 a_in => id_a, b_in => id_b, store_in => id_store,
                 imm_in => ifid_imm, pcp1_in => id_pcp1_i,
                 rdst_in => id_rdst, rs1_in => id_rs1, rs2_in => id_rs2,
                 op_in => id_opcode,
                 ctrl_in => id_ctrl_i,
                 valid_in => id_valid_i,
                 a_out => idex1_a, b_out => idex1_b, store_out => idex1_store,
                 imm_out => idex1_imm, pcp1_out => idex1_pcp1,
                 rdst_out => idex1_rdst, rs1_out => idex1_rs1, rs2_out => idex1_rs2,
                 op_out => idex1_op,
                 ctrl_out => idex1_ctrl,
                 valid_out => idex1_valid);

    -- predictor info side-band
    process(clk, rst)
    begin
        if rst = '1' then
            idex1_pred_taken <= '0';
            idex1_pred_pc    <= (others=>'0');
        elsif rising_edge(clk) then
            if flush_front = '1' or hz_stall = '1' then
                idex1_pred_taken <= '0';
                idex1_pred_pc    <= (others=>'0');
            else
                idex1_pred_taken <= ifid_pred_taken;
                idex1_pred_pc    <= ifid_pred_pc;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------
    -- Forwarding
    ----------------------------------------------------------------------
    -- For SWAP Rdst,Rsrc, operand A actually carries Rsrc (rs2 field),
    -- while store_o carries Rdst's old value. The original code forwarded
    -- as if A used rs1 and store used rs2, so SWAP after recent writes used
    -- stale zeros. These aliases give the forwarding unit the real register
    -- tags for the values entering EX1.
    fwd_src_a_reg <= idex1_rs2 when idex1_ctrl.is_swap = '1' else idex1_rs1;
    fwd_src_b_reg <= idex1_rdst when idex1_ctrl.is_swap = '1' else idex1_rs2;

    U_FWD : forwardingUnit
        port map(id_ex1_rs1 => fwd_src_a_reg, id_ex1_rs2 => fwd_src_b_reg,
                 id_ex1_use_imm => idex1_ctrl.use_imm,
                 ex1_ex2_valid => ex12_valid, ex1_ex2_we => ex12_ctrl.reg_we,
                 ex1_ex2_rdst => ex12_rdst,
                 -- NEW: tell the forwarding unit about SWAP's pending secondary
                 -- write while SWAP is still in EX1/EX2, so it can beat any
                 -- stale e2m match on the same register (fixes 028_swap_then_add).
                 ex1_ex2_is_swap  => ex12_ctrl.is_swap,
                 ex1_ex2_swap_rs2 => ex12_rs2,   -- raw rs2 field = SWAP secondary target
                 ex2_mem_valid => e2m_valid, ex2_mem_we => e2m_ctrl.reg_we,
                 ex2_mem_rdst => e2m_rdst,
                 mem_wb_valid => mw_valid, mem_wb_we => mw_we,
                 mem_wb_rdst => mw_rdst,
                 swap_we => mem_swap_we, swap_addr => mem_swap_addr,
                 mw_swap_we => mw_swap_we, mw_swap_addr => mw_swap_addr,
                 sel_a => fwd_sel_a, sel_b => fwd_sel_b, sel_store => fwd_sel_store,
                 swap_fwd_a => swap_fwd_a_sig, swap_fwd_b => swap_fwd_b_sig,
                 swap_fwd_store => swap_fwd_store_sig);

    -- SWAP data forwarding: use MEM/WB data when SWAP is in WB stage,
    -- else use MEM stage data.
    swap_data_fwd <= mw_swap_data when mem_swap_we = '0' and mw_swap_we = '1'
                     else mem_swap_data;

    -- FIX: choose correct EX1/EX2 forward data.
    -- LDM (wb_sel=WB_IMM) computes a junk alu_res; the real result is the immediate.
    ex12_fwd <= ex12_imm when ex12_ctrl.wb_sel = WB_IMM else ex12_alu_res;

    ----------------------------------------------------------------------
    -- Execute-1
    ----------------------------------------------------------------------
    U_EX1 : execute1Stage
        port map(a_in => idex1_a, b_in => idex1_b, store_in => idex1_store,
                 op => idex1_ctrl.alu_op,
                 is_swap_in => idex1_ctrl.is_swap,
                 ex1_ex2_alu => ex12_fwd,
                 ex2_mem_alu => e2m_alu_res,
                 mem_wb_data => mw_data,
                 sel_a => fwd_sel_a, sel_b => fwd_sel_b, sel_store => fwd_sel_store,
                 swap_data_e1e2 => ex12_store, swap_data_mem  => mem_swap_data,
                 swap_data_wb   => mw_swap_data,
                 swap_fwd_a => swap_fwd_a_sig, swap_fwd_b => swap_fwd_b_sig,
                 swap_fwd_store => swap_fwd_store_sig,
                 alu_res_o => ex1_alu_res, store_o => ex1_store,
                 z_o => ex1_z, n_o => ex1_n, c_o => ex1_c);

    ----------------------------------------------------------------------
    -- EX1/EX2 register
    ----------------------------------------------------------------------
    U_EX12 : EX1_EX2
        port map(clk => clk, rst => rst,
                 flush => flush_front,
                 alu_res_in => ex1_alu_res, store_in => ex1_store,
                 imm_in => idex1_imm, pcp1_in => idex1_pcp1,
                 rdst_in => idex1_rdst, rs2_in => idex1_rs2,
                 op_in => idex1_op,
                 z_in => ex1_z, n_in => ex1_n, c_in => ex1_c,
                 ctrl_in => idex1_ctrl, valid_in => idex1_valid,
                 alu_res_out => ex12_alu_res, store_out => ex12_store,
                 imm_out => ex12_imm, pcp1_out => ex12_pcp1,
                 rdst_out => ex12_rdst, rs2_out => ex12_rs2,
                 op_out => ex12_op,
                 z_out => ex12_z, n_out => ex12_n, c_out => ex12_c,
                 ctrl_out => ex12_ctrl, valid_out => ex12_valid);

    -- predictor info
    process(clk, rst)
    begin
        if rst = '1' then
            ex12_pred_taken <= '0';
            ex12_pred_pc    <= (others=>'0');
        elsif rising_edge(clk) then
            if flush_front = '1' then
                ex12_pred_taken <= '0';
                ex12_pred_pc    <= (others=>'0');
            else
                ex12_pred_taken <= idex1_pred_taken;
                ex12_pred_pc    <= idex1_pred_pc;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------
    -- Execute-2
    ----------------------------------------------------------------------
    U_EX2 : execute2Stage
        port map(valid_in => ex12_valid,
                 op_in => ex12_op, ctrl_in => ex12_ctrl,
                 alu_res_in => ex12_alu_res, store_in => ex12_store,
                 imm_in => ex12_imm, pcp1_in => ex12_pcp1,
                 z_in => ex2_z_in, n_in => ex2_n_in, c_in => ex2_c_in,
                 sp_in => sp_v,
                 pred_taken_in => ex12_pred_taken,
                 pred_pc_in => ex12_pred_pc,
                 mem_addr_o => ex2_mem_addr, mem_store_o => ex2_mem_store,
                 sp_op_o => ex2_sp_op,
                 mispredict => ex2_misp, redirect_pc => ex2_redir_pc,
                 bp_upd_en => bp_upd_en,
                 bp_upd_pc => bp_upd_pc, bp_upd_tgt => bp_upd_tgt,
                 bp_upd_taken => bp_upd_taken,
                 ccr_upd_zn => ex2_ccr_upd_zn, ccr_upd_c => ex2_ccr_upd_c,
                 ccr_set_c => ex2_ccr_set_c,
                 ccr_z => ex2_ccr_z, ccr_n => ex2_ccr_n, ccr_c => ex2_ccr_c);

    ----------------------------------------------------------------------
    -- EX2/MEM register
    ----------------------------------------------------------------------
    e2m_valid_in_gated <= ex12_valid and not mem_ret_redirect;

    U_E2M : EX2_MEM
        port map(clk => clk, rst => rst,
                 mem_addr_in => ex2_mem_addr, store_in => ex2_mem_store,
                 alu_res_in => ex12_alu_res, imm_in => ex12_imm,
                 rdst_in => ex12_rdst, rs2_in => ex12_rs2,
                 op_in => ex12_op, ctrl_in => ex12_ctrl,
                 valid_in => e2m_valid_in_gated,
                 mem_addr_out => e2m_mem_addr, store_out => e2m_store,
                 alu_res_out => e2m_alu_res, imm_out => e2m_imm,
                 rdst_out => e2m_rdst, rs2_out => e2m_rs2,
                 op_out => e2m_op, ctrl_out => e2m_ctrl,
                 valid_out => e2m_valid);

    U_MEMS : memoryStage
        port map(valid_in => e2m_valid, ctrl_in => e2m_ctrl,
                 mem_addr_in => e2m_mem_addr, store_in => e2m_store,
                 alu_res_in => e2m_alu_res, imm_in => e2m_imm,
                 rdst_in => e2m_rdst, rs2_in => e2m_rs2,
                 in_port => in_port,
                 hw_int_in => hw_int_mem,
                 d_addr_o => d_addr, d_we_o => d_we, d_re_o => d_re,
                 d_in_o => d_in, d_out_in => d_out,
                 vec_addr_o => vec_addr, vec_data_in => vec_data,
                 wb_data_o => mem_wb_data, wb_we_o => mem_wb_we,
                 wb_rdst_o => mem_wb_rdst,
                 swap_we_o => mem_swap_we, swap_addr_o => mem_swap_addr,
                 swap_data_o => mem_swap_data,
                 out_en_o => mem_out_en, out_data_o => mem_out_dat,
                 ret_redirect => mem_ret_redirect, ret_target => mem_ret_target);

    U_OUTREG : outPutReg
        port map(clk => clk, rst => rst,
                 out_en => mem_out_en, data_in => mem_out_dat,
                 out_port => out_port);

    U_MW : MEM_WB
        port map(clk => clk, rst => rst,
                 flush => mem_ret_redirect,
                 wb_data_in => mem_wb_data, rdst_in => mem_wb_rdst,
                 we_in => mem_wb_we, valid_in => e2m_valid,
                 swap_we_in => mem_swap_we, swap_addr_in => mem_swap_addr,
                 swap_data_in => mem_swap_data,
                 wb_data_out => mw_data, rdst_out => mw_rdst,
                 we_out => mw_we, valid_out => mw_valid,
                 swap_we_out => mw_swap_we, swap_addr_out => mw_swap_addr,
                 swap_data_out => mw_swap_data);

    ----------------------------------------------------------------------
    -- Write-back
    ----------------------------------------------------------------------
    U_WB : writeBackStage
        port map(valid_in => mw_valid, we_in => mw_we,
                 rdst_in => mw_rdst, data_in => mw_data,
                 rf_we_o => rf_we, rf_addr_o => rf_wraddr, rf_data_o => rf_wrdata);

    ----------------------------------------------------------------------
    -- Observation outputs
    ----------------------------------------------------------------------
    sp_obs  <= sp_v;
    in_en_obs <= e2m_ctrl.in_en and e2m_valid;
    ccr_obs <= ccr_v;

end rtl;