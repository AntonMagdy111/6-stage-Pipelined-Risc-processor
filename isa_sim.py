#!/usr/bin/env python3
"""
isa_sim.py - Golden-model ISA simulator for the 6-stage Von Neumann CPU.

Reads a memory file (one 32-bit binary word per line, same format as the
.mem file consumed by the VHDL Memory.vhd) and executes it sequentially
(non-pipelined). Used to validate the instruction set semantics against
the hardware model.

Memory layout:
  M[0] = reset vector (start address)
  M[1] = interrupt vector
  M[2..] = code/data
"""
import sys

MASK32 = 0xFFFFFFFF
SIGN   = 0x80000000

OPCODES = {
    0b00000:'NOP', 0b00001:'HLT', 0b00010:'SETC', 0b00011:'NOT',
    0b00100:'INC', 0b00101:'MOV', 0b00110:'SWAP', 0b00111:'ADD',
    0b01000:'SUB', 0b01001:'AND', 0b01010:'IADD', 0b01011:'OUT',
    0b01100:'IN',  0b01101:'PUSH', 0b01110:'POP',
    0b10000:'LDM', 0b10001:'LDD', 0b10010:'STD',
    0b10011:'JZ',  0b10100:'JN',  0b10101:'JC',
    0b10110:'JMP', 0b10111:'CALL',
    0b11000:'RET', 0b11001:'RTI', 0b11010:'INT',
}
NEEDS_IMM = {'IADD','LDM','LDD','STD','JZ','JN','JC','JMP','CALL'}

class CPU:
    def __init__(self, mem):
        self.mem  = mem[:]              # list of 32-bit ints
        self.regs = [0]*8
        self.pc   = mem[0] & MASK32
        self.sp   = 4095
        self.z = self.n = self.c = 0
        self.ccr_stack = []
        self.halted = False
        self.out_log = []
        self.in_queue = []              # queued IN port values
        self.steps = 0

    def fetch(self):
        ir = self.mem[self.pc] & 0xFFFF
        self.pc = (self.pc + 1) & MASK32
        op = (ir >> 11) & 0x1F
        m  = OPCODES.get(op, '???')
        imm = 0
        if m in NEEDS_IMM:
            imm = self.mem[self.pc] & MASK32
            self.pc = (self.pc + 1) & MASK32
        rdst = (ir >> 8) & 0x7
        rs1  = (ir >> 5) & 0x7
        rs2  = (ir >> 2) & 0x7
        return m, rdst, rs1, rs2, imm

    def upd_zn(self, v):
        v &= MASK32
        self.z = 1 if v == 0 else 0
        self.n = 1 if (v & SIGN) else 0

    def upd_c_add(self, a, b):
        self.c = 1 if (a + b) > MASK32 else 0

    def upd_c_sub(self, a, b):
        self.c = 1 if a < b else 0    # borrow as carry

    def step(self):
        if self.halted: return
        m, rdst, rs1, rs2, imm = self.fetch()
        self.steps += 1

        if m == 'NOP': pass
        elif m == 'HLT': self.halted = True
        elif m == 'SETC': self.c = 1
        elif m == 'NOT':
            v = (~self.regs[rs2]) & MASK32  # NOT operates on Rdst (encoded in rs2 by assembler)
            self.regs[rdst] = v
            self.upd_zn(v)
        elif m == 'INC':
            a = self.regs[rs2]
            v = (a + 1) & MASK32
            self.regs[rdst] = v
            self.upd_zn(v)
            self.upd_c_add(a, 1)
        elif m == 'MOV':
            self.regs[rdst] = self.regs[rs2]
        elif m == 'SWAP':
            # SWAP Rdst, Rsrc: exchange registers
            self.regs[rdst], self.regs[rs2] = self.regs[rs2], self.regs[rdst]
        elif m == 'ADD':
            a, b = self.regs[rs1], self.regs[rs2]
            v = (a + b) & MASK32
            self.regs[rdst] = v; self.upd_zn(v); self.upd_c_add(a, b)
        elif m == 'SUB':
            a, b = self.regs[rs1], self.regs[rs2]
            v = (a - b) & MASK32
            self.regs[rdst] = v; self.upd_zn(v); self.upd_c_sub(a, b)
        elif m == 'AND':
            v = self.regs[rs1] & self.regs[rs2]
            self.regs[rdst] = v; self.upd_zn(v)
        elif m == 'IADD':
            a = self.regs[rs1]
            v = (a + imm) & MASK32
            self.regs[rdst] = v; self.upd_zn(v); self.upd_c_add(a, imm)
        elif m == 'OUT':
            self.out_log.append(self.regs[rs2])
        elif m == 'IN':
            v = self.in_queue.pop(0) if self.in_queue else 0
            self.regs[rdst] = v
        elif m == 'PUSH':
            self.mem[self.sp] = self.regs[rs2] & MASK32
            self.sp = (self.sp - 1) & MASK32
        elif m == 'POP':
            self.sp = (self.sp + 1) & MASK32
            self.regs[rdst] = self.mem[self.sp] & MASK32
        elif m == 'LDM':
            self.regs[rdst] = imm & MASK32
        elif m == 'LDD':
            addr = (self.regs[rs1] + imm) & 0xFFF
            self.regs[rdst] = self.mem[addr] & MASK32
        elif m == 'STD':
            addr = (self.regs[rs1] + imm) & 0xFFF
            self.mem[addr] = self.regs[rs2] & MASK32
        elif m == 'JZ':
            if self.z:
                self.pc = imm & MASK32
                self.z = 0
        elif m == 'JN':
            if self.n:
                self.pc = imm & MASK32
                self.n = 0
        elif m == 'JC':
            if self.c:
                self.pc = imm & MASK32
                self.c = 0
        elif m == 'JMP':
            self.pc = imm & MASK32
        elif m == 'CALL':
            self.mem[self.sp] = self.pc & MASK32
            self.sp = (self.sp - 1) & MASK32
            self.pc = imm & MASK32
        elif m == 'RET':
            self.sp = (self.sp + 1) & MASK32
            self.pc = self.mem[self.sp] & MASK32
        elif m == 'RTI':
            self.sp = (self.sp + 1) & MASK32
            self.pc = self.mem[self.sp] & MASK32
            if self.ccr_stack:
                self.z, self.n, self.c = self.ccr_stack.pop()
        elif m == 'INT':
            self.ccr_stack.append((self.z, self.n, self.c))
            self.mem[self.sp] = self.pc & MASK32
            self.sp = (self.sp - 1) & MASK32
            # spec says PC <- M[index+2]; index from rdst encoding
            self.pc = self.mem[(rdst + 2) & 0xFFF] & MASK32
        else:
            raise RuntimeError(f"Bad opcode {m} at pc={self.pc-1:04x}")

    def run(self, max_steps=10000):
        while not self.halted and self.steps < max_steps:
            self.step()


def load_mem(path):
    mem = [0]*4096
    idx = 0
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            if idx >= 4096: break
            mem[idx] = int(line, 2)
            idx += 1
    return mem


def main():
    if len(sys.argv) < 2:
        print("Usage: isa_sim.py program.mem [in1 in2 ...]"); sys.exit(1)
    mem = load_mem(sys.argv[1])
    cpu = CPU(mem)
    for v in sys.argv[2:]:
        cpu.in_queue.append(int(v, 0))
    cpu.run()
    print(f"Halted after {cpu.steps} steps. PC=0x{cpu.pc:08x} SP=0x{cpu.sp:08x}")
    print(f"Flags: Z={cpu.z} N={cpu.n} C={cpu.c}")
    for i, v in enumerate(cpu.regs):
        print(f"  R{i} = 0x{v:08x} = {v}")
    if cpu.out_log:
        print("OUT.PORT history:")
        for v in cpu.out_log:
            print(f"  0x{v:08x}")

if __name__ == '__main__':
    main()
