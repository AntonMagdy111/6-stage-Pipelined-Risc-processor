// ---------------------------------------------------------------------------
// cpu_sva.sv — SystemVerilog Assertions (SVA) & Functional Covergroups
//
// Industry-standard Siemens Questa / mixed-language DV checker designed to
// bind onto the VHDL Processor top-level for formal (Questa PropCheck) and
// dynamic simulation coverage closure:
//   vlog -sv verification/cpu_sva.sv
// ---------------------------------------------------------------------------
module cpu_sva (
    input logic        clk,
    input logic        rst,
    input logic        d_we,
    input logic        d_re,
    input logic        ifid_valid,
    input logic        idex1_valid,
    input logic        ex12_valid,
    input logic        e2m_valid,
    input logic        mw_valid,
    input logic [4:0]  ex12_op,
    input logic        hz_stall,
    input logic        flush_front,
    input logic        mem_ret_redirect,
    input logic        ex2_misp_gated,
    input logic        ex2_halt,
    input logic        halt_latch,
    input logic        hw_int_active,
    input logic        pipe_empty,
    input logic        bp_upd_en_gated,
    input logic        bp_upd_taken,
    input logic [1:0]  sp_op_gated,
    input logic        rf_we,
    input logic        mw_swap_we_gated,
    input logic        mem_out_en,
    input logic [2:0]  fwd_sel_a,
    input logic [2:0]  fwd_sel_b,
    input logic [2:0]  fwd_sel_store,
    input logic [31:0] pc_obs,
    input logic [31:0] sp_obs,
    input logic [2:0]  ccr_obs
);
    default clocking cb @(posedge clk); endclocking
    default disable iff (rst);

    // -----------------------------------------------------------------------
    // 1. Concurrent SVA Safety & Liveness Properties
    // -----------------------------------------------------------------------

    // P1: Shared data memory port never reads and writes simultaneously
    property p_no_simul_mem_rw;
        !(d_we && d_re);
    endproperty
    a_no_simul_mem_rw : assert property (p_no_simul_mem_rw)
        else $error("SVA [P1]: Simultaneous d_we and d_re asserted");

    // P2: Invalid IF/ID bubbles never trigger hazard stalls
    property p_no_bubble_stall;
        hz_stall |-> ifid_valid;
    endproperty
    a_no_bubble_stall : assert property (p_no_bubble_stall)
        else $error("SVA [P2]: Spurious hz_stall on invalid IF/ID bubble");

    // P3: Wrong-path EX2 never modifies SP or BTB or commits HLT on MEM redirect
    property p_mem_redirect_gates_ex2;
        mem_ret_redirect |-> (sp_op_gated == 2'b00 && !bp_upd_en_gated && !ex2_halt);
    endproperty
    a_mem_redirect_gates_ex2 : assert property (p_mem_redirect_gates_ex2)
        else $error("SVA [P3]: Wrong-path EX2 side effect during MEM redirect");

    // P4: HLT commit permanently latches halt_latch on the next cycle and
    // keeps the front pipeline drained thereafter
    property p_halt_sticky;
        ex2_halt |=> halt_latch;
    endproperty
    a_halt_sticky : assert property (p_halt_sticky)
        else $error("SVA [P4]: halt_latch failed to assert after ex2_halt");

    property p_halt_front_empty;
        halt_latch |-> (!ifid_valid && !idex1_valid && !ex12_valid);
    endproperty
    a_halt_front_empty : assert property (p_halt_front_empty)
        else $error("SVA [P4b]: Front pipeline active after HLT");

    // P5: Hardware interrupt injection requires an empty, non-halted pipeline
    property p_hw_int_safe_inject;
        hw_int_active |-> (pipe_empty && !halt_latch && !flush_front && !hz_stall);
    endproperty
    a_hw_int_safe_inject : assert property (p_hw_int_safe_inject)
        else $error("SVA [P5]: Unsafe HW interrupt injection");

    // P6: Invalid WB/MEM stages never write architectural state
    property p_no_invalid_wb;
        !mw_valid |-> (!rf_we && !mw_swap_we_gated);
    endproperty
    a_no_invalid_wb : assert property (p_no_invalid_wb)
        else $error("SVA [P6]: Invalid WB wrote RegisterFile");

    property p_no_invalid_out;
        !e2m_valid |-> !mem_out_en;
    endproperty
    a_no_invalid_out : assert property (p_no_invalid_out)
        else $error("SVA [P6b]: Invalid MEM wrote OUT.PORT");

    // P7: Forwarding selectors never use reserved encoding 3'b111
    property p_valid_fwd_sel;
        (fwd_sel_a != 3'b111) && (fwd_sel_b != 3'b111) && (fwd_sel_store != 3'b111);
    endproperty
    a_valid_fwd_sel : assert property (p_valid_fwd_sel)
        else $error("SVA [P7]: Reserved forwarding encoding 3'b111 observed");

    // P8: No X/Z propagation on architectural PC, SP, CCR
    property p_no_x_arch_state;
        !$isunknown(pc_obs) && !$isunknown(sp_obs) && !$isunknown(ccr_obs);
    endproperty
    a_no_x_arch_state : assert property (p_no_x_arch_state)
        else $error("SVA [P8]: Unknown state on PC/SP/CCR");

    // -----------------------------------------------------------------------
    // 2. Functional Coverage (Covergroups for Verification Closure)
    // -----------------------------------------------------------------------
    covergroup cg_cpu @(posedge clk iff !rst);
        option.per_instance = 1;

        cp_opcode : coverpoint ex12_op iff (ex12_valid) {
            bins op_nop  = {5'b00000}; bins op_hlt  = {5'b00001};
            bins op_setc = {5'b00010}; bins op_not  = {5'b00011};
            bins op_inc  = {5'b00100}; bins op_mov  = {5'b00101};
            bins op_swap = {5'b00110}; bins op_add  = {5'b00111};
            bins op_sub  = {5'b01000}; bins op_and  = {5'b01001};
            bins op_iadd = {5'b01010}; bins op_out  = {5'b01011};
            bins op_in   = {5'b01100}; bins op_push = {5'b01101};
            bins op_pop  = {5'b01110}; bins op_ldm  = {5'b10000};
            bins op_ldd  = {5'b10001}; bins op_std  = {5'b10010};
            bins op_jz   = {5'b10011}; bins op_jn   = {5'b10100};
            bins op_jc   = {5'b10101}; bins op_jmp  = {5'b10110};
            bins op_call = {5'b10111}; bins op_ret  = {5'b11000};
            bins op_rti  = {5'b11001}; bins op_int  = {5'b11010};
        }

        cp_fwd_a : coverpoint fwd_sel_a iff (idex1_valid) {
            bins rf       = {3'b000};
            bins e12_pri  = {3'b001}; bins e12_swap = {3'b010};
            bins e2m_pri  = {3'b011}; bins e2m_swap = {3'b100};
            bins wb_pri   = {3'b101}; bins wb_swap  = {3'b110};
        }

        cp_fwd_b : coverpoint fwd_sel_b iff (idex1_valid) {
            bins rf       = {3'b000};
            bins e12_pri  = {3'b001}; bins e12_swap = {3'b010};
            bins e2m_pri  = {3'b011}; bins e2m_swap = {3'b100};
            bins wb_pri   = {3'b101}; bins wb_swap  = {3'b110};
        }

        cp_fwd_store : coverpoint fwd_sel_store iff (idex1_valid) {
            bins rf       = {3'b000};
            bins e12_pri  = {3'b001}; bins e12_swap = {3'b010};
            bins e2m_pri  = {3'b011}; bins e2m_swap = {3'b100};
            bins wb_pri   = {3'b101}; bins wb_swap  = {3'b110};
        }

        cp_stall     : coverpoint hz_stall;
        cp_misp      : coverpoint ex2_misp_gated;
        cp_mem_redir : coverpoint mem_ret_redirect;
        cp_hw_int    : coverpoint hw_int_active;
        cp_bp_outcome: coverpoint bp_upd_taken iff (bp_upd_en_gated);

        // Cross: conditional branch taken/not-taken x mispredict
        cx_bp : cross cp_bp_outcome, cp_misp;
    endgroup

    cg_cpu u_cg = new();
endmodule
