#!/usr/bin/env python3
# ==========================================================================
# Project : 6-Stage Pipelined 32-Bit Von Neumann RISC Processor
# Author  : Anton Magdy (@AntonMagdy111) - https://github.com/AntonMagdy111
# Repo    : https://github.com/AntonMagdy111/6-stage-Pipelined-Risc-processor
# License : Apache-2.0 (see LICENSE and NOTICE for mandatory attribution)
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 Anton Magdy. All rights reserved.
# ==========================================================================
"""
verification/cosim_fuzzer.py
Industry-style Constrained-Random RTL vs. Golden-ISS Cosimulation,
Benchmark Profiler, and Functional Coverage Closure Engine for the
6-Stage Pipelined Von Neumann RISC Processor.

Usage:
    python verification/cosim_fuzzer.py [--seeds 50]
"""
import argparse
import os
import random
import re
import shutil
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR   = os.path.abspath(os.path.join(SCRIPT_DIR, '..'))
SIM_DIR    = os.path.join(REPO_DIR, 'sim')
sys.path.insert(0, REPO_DIR)
import isa_sim

# Exact ISA table matching assembler/assembler.cpp and components/cpu_pkg.vhd
OPS = {
    'NOP': (0b00000, 0, False), 'HLT': (0b00001, 0, False), 'SETC': (0b00010, 0, False),
    'NOT': (0b00011, 1, False), 'INC': (0b00100, 1, False), 'MOV':  (0b00101, 2, False),
    'SWAP':(0b00110, 2, False), 'ADD': (0b00111, 3, False), 'SUB':  (0b01000, 3, False),
    'AND': (0b01001, 3, False), 'IADD':(0b01010, 4, True),  'OUT':  (0b01011, 8, False),
    'IN':  (0b01100, 9, False), 'PUSH':(0b01101, 8, False), 'POP':  (0b01110, 9, False),
    'LDM': (0b10000,10, True),  'LDD': (0b10001, 6, True),  'STD':  (0b10010, 7, True),
    'JZ':  (0b10011, 5, True),  'JN':  (0b10100, 5, True),  'JC':   (0b10101, 5, True),
    'JMP': (0b10110, 5, True),  'CALL':(0b10111, 5, True),  'RET':  (0b11000, 0, False),
    'RTI': (0b11001, 0, False), 'INT': (0b11010,11, False),
}
CODE_TO_NAME = {v[0]: k for k, v in OPS.items()}


def assemble(src):
    labels, code_at = {}, {}
    addr, start_addr, intr_addr = 2, 2, 0
    got_start = False
    start_tok = intr_tok = None

    def parse_reg(tok):
        t = tok.strip().upper()
        assert t.startswith('R')
        r = int(t[1:])
        assert 0 <= r <= 7
        return r

    def parse_imm(tok):
        t = tok.strip()
        if t.startswith('#'):
            t = t[1:]
        if t.upper() in labels:
            return labels[t.upper()] & 0xFFFFFFFF
        return int(t, 0) & 0xFFFFFFFF

    for raw in src.splitlines():
        s = raw.split(';', 1)[0].strip()
        if not s:
            continue
        if ':' in s:
            lbl, s = s.split(':', 1)
            labels[lbl.strip().upper()] = addr
            s = s.strip()
            if not s:
                continue
        toks = [t for t in re.split(r'[,\s]+', s) if t]
        d = toks[0].upper()
        if d == '.ORG':
            addr = parse_imm(toks[1])
            if not got_start:
                start_addr = addr
                got_start = True
        elif d == '.START':
            start_tok = toks[1]
            got_start = True
        elif d == '.INTR':
            intr_tok = toks[1]
        elif d == '.WORD':
            code_at[addr] = toks
            addr += 1
        else:
            _, _, has_imm = OPS[d]
            code_at[addr] = toks
            addr += 2 if has_imm else 1

    if start_tok is not None:
        start_addr = parse_imm(start_tok)
    if intr_tok is not None:
        intr_addr = parse_imm(intr_tok)

    mem = [0] * 4096
    mem[0] = start_addr & 0xFFFFFFFF
    mem[1] = intr_addr & 0xFFFFFFFF

    for a, toks in code_at.items():
        m = toks[0].upper()
        if m == '.WORD':
            mem[a] = parse_imm(toks[1])
            continue
        op, fmt, has_imm = OPS[m]
        rdst = rs1 = rs2 = imm = 0
        if fmt == 0:
            pass
        elif fmt == 1:
            r = parse_reg(toks[1]); rdst = rs2 = r
        elif fmt == 2:
            rdst = parse_reg(toks[1]); rs2 = parse_reg(toks[2])
        elif fmt == 3:
            rdst = parse_reg(toks[1]); rs1 = parse_reg(toks[2]); rs2 = parse_reg(toks[3])
        elif fmt == 4:
            rdst = parse_reg(toks[1]); rs1 = parse_reg(toks[2]); imm = parse_imm(toks[3])
        elif fmt == 5:
            imm = parse_imm(toks[1])
        elif fmt == 6:
            rdst = parse_reg(toks[1])
            p, q = toks[2].index('('), toks[2].index(')')
            imm = parse_imm(toks[2][:p]); rs1 = parse_reg(toks[2][p+1:q])
        elif fmt == 7:
            rs2 = parse_reg(toks[1])
            p, q = toks[2].index('('), toks[2].index(')')
            imm = parse_imm(toks[2][:p]); rs1 = parse_reg(toks[2][p+1:q])
        elif fmt == 8:
            rs2 = parse_reg(toks[1])
        elif fmt == 9:
            rdst = parse_reg(toks[1])
        elif fmt == 10:
            rdst = parse_reg(toks[1]); imm = parse_imm(toks[2])
        elif fmt == 11:
            rdst = parse_imm(toks[1]) & 0x1
        mem[a] = ((op & 0x1F) << 11) | ((rdst & 7) << 8) | ((rs1 & 7) << 5) | ((rs2 & 7) << 2)
        if has_imm:
            mem[a + 1] = imm
    return mem


def write_mem(path, mem):
    with open(path, 'w') as f:
        for w in mem:
            f.write(f'{w:032b}\n')


def generate_random_program(seed, n_ops=55):
    """
    Generate a constrained-random valid assembly program exercising all 26 ISA
    opcodes, dense RAW/load-use/SWAP/STD hazards, balanced stack ops,
    conditional forward branches, short loops, CALL/RET, and INT 0/1 -> RTI.
    """
    rng = random.Random(seed)
    lines = [
        '.org 0x2',
        '    .word ISR0',
        '    .word ISR1',
        '.org 0x10',
    ]
    edge_vals = [0, 1, 2, 0x10, 0xFF, 0x1234, 0x7FFFFFFF, 0x80000000, 0xFFFFFFFF]
    # Keep R7 as safe scratch base pointer (0x500), initialize R0..R6 randomly
    lines.append('    LDM R7, #0x500')
    for r in range(7):
        v = rng.choice(edge_vals) if rng.random() < 0.4 else rng.randint(0, 0xFFFF)
        lines.append(f'    LDM R{r}, #0x{v:X}')
    # Seed scratch RAM slots [0x500..0x507] so LDD always sees deterministic data
    for off in range(8):
        lines.append(f'    STD R{off % 7}, {off}(R7)')

    in_vals = [rng.randint(0, 0xFFFFFF) for _ in range(8)]
    in_used = 0
    stack_depth = 0
    lbl_id = 0
    # Use a hot-register pool to force heavy back-to-back RAW & forwarding chains!
    hot_regs = [0, 1, 2, 3, 4, 5, 6]

    def pick_reg(allow_r7=False):
        return rng.choice(hot_regs if not allow_r7 else hot_regs + [7])

    for _ in range(n_ops):
        kind = rng.choices(
            ['alu3', 'iadd', 'alu1', 'mov', 'swap', 'swap_ovw', 'ldm',
             'ldd', 'std', 'push', 'pop', 'in', 'out', 'setc', 'nop',
             'fwd_branch', 'call', 'soft_int'],
            weights=[14, 8, 8, 6, 8, 5, 6, 9, 8, 5, 5, 4, 5, 3, 3, 6, 4, 4]
        )[0]

        rd = pick_reg()
        r1 = pick_reg()
        r2 = pick_reg()

        if kind == 'alu3':
            op = rng.choice(['ADD', 'SUB', 'AND'])
            lines.append(f'    {op} R{rd}, R{r1}, R{r2}')
        elif kind == 'iadd':
            imm = rng.choice([-3, -1, 0, 1, 5, 0x100])
            lines.append(f'    IADD R{rd}, R{r1}, #{imm}')
        elif kind == 'alu1':
            op = rng.choice(['NOT', 'INC'])
            lines.append(f'    {op} R{rd}')
        elif kind == 'mov':
            lines.append(f'    MOV R{rd}, R{r2}')
        elif kind == 'swap':
            lines.append(f'    SWAP R{rd}, R{r2}')
        elif kind == 'swap_ovw':
            # Stress SWAP secondary write immediately overwritten by newer write!
            lines.append(f'    SWAP R{rd}, R{r2}')
            if rng.random() < 0.5:
                lines.append(f'    LDM R{r2}, #0x{rng.randint(1, 0xFFF):X}')
            else:
                lines.append(f'    ADD R{r2}, R{r1}, R{rd}')
            lines.append(f'    ADD R{r1}, R{r2}, R{rd}')
        elif kind == 'ldm':
            lines.append(f'    LDM R{rd}, #0x{rng.randint(0, 0xFFFF):X}')
        elif kind == 'ldd':
            off = rng.randint(0, 7)
            lines.append(f'    LDD R{rd}, {off}(R7)')
            # Often follow immediately with a dependent consumer (STD / SWAP / OUT / ADD)!
            fup = rng.choice(['none', 'add', 'std', 'swap', 'out'])
            if fup == 'add':
                lines.append(f'    ADD R{r1}, R{rd}, R{r2}')
            elif fup == 'std':
                lines.append(f'    STD R{rd}, {rng.randint(0, 7)}(R7)')
            elif fup == 'swap':
                lines.append(f'    SWAP R{rd}, R{r2}')
            elif fup == 'out':
                lines.append(f'    OUT R{rd}')
        elif kind == 'std':
            off = rng.randint(0, 7)
            lines.append(f'    STD R{r2}, {off}(R7)')
        elif kind == 'push':
            if stack_depth < 6:
                lines.append(f'    PUSH R{r2}')
                stack_depth += 1
        elif kind == 'pop':
            if stack_depth > 0:
                lines.append(f'    POP R{rd}')
                stack_depth -= 1
        elif kind == 'in':
            if in_used < len(in_vals):
                lines.append(f'    IN R{rd}')
                in_used += 1
        elif kind == 'out':
            lines.append(f'    OUT R{r2}')
        elif kind == 'setc':
            lines.append('    SETC')
        elif kind == 'nop':
            lines.append('    NOP')
        elif kind == 'fwd_branch':
            lbl = f'L_SKIP_{lbl_id}'; lbl_id += 1
            br = rng.choice(['JZ', 'JN', 'JC', 'JMP'])
            lines.append(f'    {br} {lbl}')
            lines.append(f'    ADD R{rd}, R{r1}, R{r2}')
            lines.append(f'    IADD R{r1}, R{r1}, #1')
            lines.append(f'{lbl}:')
        elif kind == 'call':
            lines.append('    CALL SUB_HELPER')
        elif kind == 'soft_int':
            idx = rng.choice([0, 1])
            lines.append(f'    INT {idx}')

    # Drain any remaining pushed stack slots so SP returns to 0x0FFF cleanly
    while stack_depth > 0:
        lines.append(f'    POP R{pick_reg()}')
        stack_depth -= 1

    # Add a short bounded loop (4 iterations) to exercise BTB saturating counters
    lines += [
        '    LDM R5, #0',
        '    LDM R6, #4',
        'RAND_LOOP:',
        '    IADD R5, R5, #1',
        '    ADD  R0, R0, R5',
        '    SUB  R4, R5, R6',
        '    JN   RAND_LOOP',
        '    OUT  R0',
        '    HLT',
        '    INC  R0',             # post-HLT decoy (must never execute)
        'SUB_HELPER:',
        '    IADD R1, R1, #7',
        '    SWAP R1, R2',
        '    RET',
        '    LDM  R0, #0xDEAD',    # post-RET decoy (must never execute)
        '.org 0x380',
        'ISR0:',
        '    INC  R3',
        '    AND  R4, R3, R2',     # modifies CCR inside ISR -> RTI must restore!
        '    RTI',
        '    LDM  R0, #0xBAD0',
        '.org 0x3A0',
        'ISR1:',
        '    SETC',
        '    NOT  R4',
        '    RTI',
        '    LDM  R0, #0xBAD1',
    ]
    return '\n'.join(lines), in_vals[:in_used]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--seeds', type=int, default=50, help='Number of random cosim seeds')
    args = ap.parse_args()

    tmp_dir = os.path.join(SIM_DIR, '_dv_tmp')
    os.makedirs(tmp_dir, exist_ok=True)

    # 1. Core + Professor + Benchmarks + Constrained-Random Programs
    jobs = []  # (name, mem_path, in_list, is_benchmark)

    core_and_prof = [
        ('test_arithmetic',  '../test/test_arithmetic.mem',  []),
        ('test_memory',      '../test/test_memory.mem',      []),
        ('test_branches',    '../test/test_branches.mem',    []),
        ('test_io',          '../test/test_io.mem',          [0x1234]),
        ('test_interrupts',  '../test/test_interrupts.mem',  []),
        ('test_hazards',     '../test/test_hazards.mem',     []),
        ('test_edgecases',   '../test/test_edgecases.mem',   []),
        ('prof_test1',       '../test/prof_test1.mem',       [0xFFFFFFFF]),
        ('prof_test2',       '../test/prof_test2.mem',       [0x50, 0x30, 0x300, 0x100, 0x55, 0x75, 0x700]),
        ('prof_oneoperand',  '../test/prof_oneoperand.mem',  [0x5, 0x10]),
        ('prof_twooperand',  '../test/prof_twooperand.mem',  [0x5, 0x19, 0xFFFFFFFF, 0xFFFFF320]),
        ('prof_memory',      '../test/prof_memory.mem',      [0x19, 0xFFFFFFFF, 0xFFFFF320, 0x10, 0x10, 0x19]),
        ('prof_branch',      '../test/prof_branch.mem',      [0x50, 0x30, 0x300, 0x100, 0x55, 0x75, 0x700]),
    ]
    for name, rel, ins in core_and_prof:
        jobs.append((name, rel, ins, False))

    benchmarks = [
        ('bench_fibonacci',     '../test/benchmarks/bench_fibonacci.mem',     []),
        ('bench_array_sum',     '../test/benchmarks/bench_array_sum.mem',     []),
        ('bench_recursive_sum', '../test/benchmarks/bench_recursive_sum.mem', []),
        ('bench_bubble_sort',   '../test/benchmarks/bench_bubble_sort.mem',   []),
    ]
    for name, rel, ins in benchmarks:
        jobs.append((name, rel, ins, True))

    for seed in range(1, args.seeds + 1):
        src, ins = generate_random_program(seed)
        mem = assemble(src)
        mp = os.path.join(tmp_dir, f'rand_{seed:03d}.mem')
        write_mem(mp, mem)
        jobs.append((f'rand_seed_{seed:03d}', f'_dv_tmp/rand_{seed:03d}.mem', ins, False))

    # Run Golden Reference Model on every job
    golden = {}
    for name, rel, ins, _ in jobs:
        abs_mem = os.path.normpath(os.path.join(SIM_DIR, rel))
        mem = isa_sim.load_mem(abs_mem)
        cpu = isa_sim.CPU(mem)
        cpu.in_queue = list(ins)
        cpu.run(max_steps=5000)
        assert cpu.halted, f'Golden model failed to halt on {name}!'
        golden[name] = (cpu.regs, cpu.sp, cpu.pc, f'{cpu.c}{cpu.n}{cpu.z}', cpu.out_log, cpu.steps)

    # Build ModelSim Tcl runner collecting exact state + functional coverage + CPI metrics
    tcl = [
        'if {[file isdirectory work]} { vdel -lib work -all }',
        'vlib work',
        'vmap work work',
        'vcom -2008 ../components/cpu_pkg.vhd',
        'vcom -2008 ../components/alu.vhd',
        'vcom -2008 ../components/RegisterFile.vhd',
        'vcom -2008 ../components/Memory.vhd',
        'vcom -2008 ../components/controlUnit.vhd',
        'vcom -2008 ../components/pc.vhd',
        'vcom -2008 ../components/sp.vhd',
        'vcom -2008 ../components/CCR.vhd',
        'vcom -2008 ../components/forwardingUnit.vhd',
        'vcom -2008 ../components/hazardDetectionUnit.vhd',
        'vcom -2008 ../components/outPutReg.vhd',
        'vcom -2008 ../components/branchPredictor.vhd',
        'vcom -2008 ../components/Pipelined_Registers/IF_ID.vhd',
        'vcom -2008 ../components/Pipelined_Registers/ID_EX1.vhd',
        'vcom -2008 ../components/Pipelined_Registers/EX1_EX2.vhd',
        'vcom -2008 ../components/Pipelined_Registers/EX2_MEM.vhd',
        'vcom -2008 ../components/Pipelined_Registers/MEM_WB.vhd',
        'vcom -2008 ../stages/fetchStage.vhd',
        'vcom -2008 ../stages/decodeStage.vhd',
        'vcom -2008 ../stages/execute1Stage.vhd',
        'vcom -2008 ../stages/execute2Stage.vhd',
        'vcom -2008 ../stages/memoryStage.vhd',
        'vcom -2008 ../stages/writeBackStage.vhd',
        'vcom -2008 ../Processor.vhd',
        'vcom -2008 ../tb_Processor.vhd',
        'array set cov_op {}',
        'array set cov_fa {}',
        'array set cov_fb {}',
        'array set cov_fs {}',
        'set total_cycles_all 0',
        'set total_stalls_all 0',
        'set total_misps_all  0',
        'set total_br_all     0',
        'set total_redir_all  0',
        'proc run_dv {name mempath in_list max_cyc} {',
        '    global cov_op cov_fa cov_fb cov_fs total_cycles_all total_stalls_all total_misps_all total_br_all total_redir_all',
        '    file copy -force $mempath "program.mem"',
        '    set n [llength $in_list]',
        '    set gargs ""',
        '    if {$n > 0} {',
        '        append gargs " -gIN_COUNT=$n"',
        '        for {set i 0} {$i < $n && $i < 8} {incr i} {',
        '            append gargs " -gIN_VAL$i=16#[lindex $in_list $i]"',
        '        }',
        '    }',
        '    eval "vsim -t 1ns work.tb_Processor -gCHECK_AT=9999999ns $gargs"',
        '    run 30ns',
        '    set cyc 0; set stalls 0; set misps 0; set brs 0; set out_log {}',
        '    for {set c 0} {$c < $max_cyc} {incr c} {',
        '        run 10ns',
        '        incr cyc',
        '        incr total_cycles_all',
        '        if {[examine /tb_Processor/U_DUT/hz_stall] eq "1"} { incr stalls; incr total_stalls_all }',
        '        if {[examine /tb_Processor/U_DUT/ex2_misp_gated] eq "1"} { incr misps; incr total_misps_all }',
        '        if {[examine /tb_Processor/U_DUT/bp_upd_en_gated] eq "1"} { incr brs; incr total_br_all }',
        '        if {[examine /tb_Processor/U_DUT/mem_ret_redirect] eq "1"} { incr total_redir_all }',
        '        if {[examine /tb_Processor/U_DUT/ex12_valid] eq "1"} {',
        '            set op [examine -unsigned /tb_Processor/U_DUT/ex12_op]',
        '            set cov_op($op) 1',
        '        }',
        '        if {[examine /tb_Processor/U_DUT/idex1_valid] eq "1"} {',
        '            set cov_fa([examine -bin /tb_Processor/U_DUT/fwd_sel_a]) 1',
        '            set cov_fb([examine -bin /tb_Processor/U_DUT/fwd_sel_b]) 1',
        '            set cov_fs([examine -bin /tb_Processor/U_DUT/fwd_sel_store]) 1',
        '        }',
        '        if {[examine /tb_Processor/U_DUT/mem_out_en] eq "1"} {',
        '            lappend out_log [examine -hex /tb_Processor/U_DUT/mem_out_dat]',
        '        }',
        '        if {[examine /tb_Processor/U_DUT/halt_latch] eq "1" && $c > 5} {',
        '            run 60ns',
        '            break',
        '        }',
        '    }',
        '    set regs {}',
        '    foreach r {r0 r1 r2 r3 r4 r5 r6 r7} { lappend regs [examine -hex /tb_Processor/$r] }',
        '    set sp   [examine -hex /tb_Processor/sp]',
        '    set pc   [examine -hex /tb_Processor/pc]',
        '    set ccr  [examine -bin /tb_Processor/ccr]',
        '    set outp [examine -hex /tb_Processor/out_port]',
        '    puts "DV|$name|[join $regs ,]|$sp|$pc|$ccr|$outp|[join $out_log ,]|$cyc|$stalls|$misps|$brs"',
        '    quit -sim',
        '}',
    ]

    for name, rel, ins, is_bench in jobs:
        in_tcl = ' '.join(f'{v:08X}' for v in ins)
        max_cyc = 1500 if is_bench else 1000
        tcl.append(f'run_dv "{name}" "{rel}" {{{in_tcl}}} {max_cyc}')

    tcl += [
        'puts "COV|OP|[join [lsort -integer [array names cov_op]] ,]"',
        'puts "COV|FA|[join [lsort [array names cov_fa]] ,]"',
        'puts "COV|FB|[join [lsort [array names cov_fb]] ,]"',
        'puts "COV|FS|[join [lsort [array names cov_fs]] ,]"',
        'puts "COV|STATS|$total_cycles_all|$total_stalls_all|$total_misps_all|$total_br_all|$total_redir_all"',
        'quit -f',
    ]

    do_path = os.path.join(SIM_DIR, '_cosim_dv.do')
    with open(do_path, 'w') as f:
        f.write('\n'.join(tcl) + '\n')

    res = subprocess.run(['vsim', '-c', '-do', '_cosim_dv.do'], cwd=SIM_DIR, capture_output=True, text=True)

    # Check for ANY assertion failures
    assert_fails = [l for l in res.stdout.splitlines() if 'ASSERT FAIL' in l or '** Failure:' in l]

    passed = failed = 0
    bench_rows = []
    cov = {}

    for line in res.stdout.splitlines():
        clean = line.lstrip('# ').strip()
        if clean.startswith('COV|'):
            parts = clean.split('|')
            cov[parts[1]] = parts[2:]
            continue
        if not clean.startswith('DV|'):
            continue
        _, name, regs_s, sp_s, pc_s, ccr_s, outp_s, olog_s, cyc_s, st_s, misp_s, br_s = clean.split('|')
        got_regs = [int(x, 16) for x in regs_s.split(',')]
        got_sp   = int(sp_s, 16)
        got_pc   = int(pc_s, 16)
        got_outp = int(outp_s, 16)
        got_olog = [int(x, 16) for x in olog_s.split(',') if x]
        cyc, st, misp, br = int(cyc_s), int(st_s), int(misp_s), int(br_s)

        exp_regs, exp_sp, exp_pc, exp_ccr, exp_olog, exp_steps = golden[name]
        exp_outp = exp_olog[-1] if exp_olog else 0

        errs = []
        for i in range(8):
            if got_regs[i] != exp_regs[i]:
                errs.append(f'R{i}={got_regs[i]:08X}!=exp {exp_regs[i]:08X}')
        if got_sp != exp_sp:     errs.append(f'SP={got_sp:08X}!=exp {exp_sp:08X}')
        if got_pc != exp_pc:     errs.append(f'PC={got_pc:08X}!=exp {exp_pc:08X}')
        if ccr_s != exp_ccr:     errs.append(f'CCR={ccr_s}!=exp {exp_ccr}')
        if got_outp != exp_outp: errs.append(f'OUT={got_outp:08X}!=exp {exp_outp:08X}')
        if got_olog != exp_olog: errs.append(f'OUT_LOG mismatch ({len(got_olog)} vs {len(exp_olog)})')

        if not errs:
            passed += 1
            if name.startswith('bench_'):
                cpi = cyc / exp_steps
                ipc = exp_steps / cyc
                bp_acc = ((br - misp) / br * 100.0) if br > 0 else 100.0
                bench_rows.append((name, exp_steps, cyc, cpi, ipc, st, br, misp, bp_acc))
        else:
            failed += 1
            print(f'  FAIL  {name}: ' + '; '.join(errs))

    print('=' * 78)
    print('6-STAGE PIPELINED RISC PROCESSOR — DV COSIMULATION & COVERAGE ENGINE')
    print('Designed by Anton Magdy (@AntonMagdy111) | Apache-2.0 License')
    print('-' * 78)
    print(f'COSIMULATION SUMMARY: {passed} PASSED, {failed} FAILED (out of {len(jobs)} programs)')
    print(f'ASSERTION FAILURES  : {len(assert_fails)}')
    if assert_fails:
        for af in assert_fails[:10]:
            print('  ', af)

    print('\nBENCHMARK PERFORMANCE PROFILE (Measured in ModelSim RTL):')
    print(f'  {"Benchmark":22s} | {"Instr":>5s} | {"Cyc":>5s} | {"CPI":>5s} | {"IPC":>5s} | {"Stalls":>6s} | {"CondBr":>6s} | {"Misp":>4s} | {"BTB Acc":>7s}')
    print('  ' + '-' * 84)
    for b, ins_c, cyc, cpi, ipc, st, br, misp, acc in bench_rows:
        print(f'  {b:22s} | {ins_c:5d} | {cyc:5d} | {cpi:5.2f} | {ipc:5.2f} | {st:6d} | {br:6d} | {misp:4d} | {acc:6.1f}%')

    ops_hit = [int(x) for x in cov.get('OP', [''])[0].split(',') if x]
    missing_ops = sorted(set(CODE_TO_NAME.keys()) - set(ops_hit))
    fa_hit = [x for x in cov.get('FA', [''])[0].split(',') if x]
    fb_hit = [x for x in cov.get('FB', [''])[0].split(',') if x]
    fs_hit = [x for x in cov.get('FS', [''])[0].split(',') if x]
    stats  = cov.get('STATS', ['0', '0', '0', '0', '0'])

    print('\nFUNCTIONAL COVERAGE CLOSURE:')
    print(f'  ISA Opcode Coverage        : {len(ops_hit):2d} / 26 ({len(ops_hit)/26*100:5.1f}%)' +
          (f'  missing={[CODE_TO_NAME[m] for m in missing_ops]}' if missing_ops else '  [100% CLOSED]'))
    print(f'  Forwarding sel_a paths     : {len(fa_hit):2d} / 7  {fa_hit}')
    print(f'  Forwarding sel_b paths     : {len(fb_hit):2d} / 7  {fb_hit}')
    print(f'  Forwarding sel_store paths : {len(fs_hit):2d} / 7  {fs_hit}')
    print(f'  Aggregate RTL Cycles       : {stats[0]} cycles | stalls={stats[1]} | cond_br={stats[3]} | misp={stats[2]} | mem_redir={stats[4]}')
    print('=' * 78)

    # Cleanup temp files and restore default program.mem
    os.remove(do_path)
    shutil.rmtree(tmp_dir, ignore_errors=True)
    shutil.copyfile(os.path.join(REPO_DIR, 'test', 'test_arithmetic.mem'),
                    os.path.join(SIM_DIR, 'program.mem'))

    sys.exit(0 if (failed == 0 and len(assert_fails) == 0 and passed == len(jobs)) else 1)


if __name__ == '__main__':
    main()
