// ==========================================================================
// Project : 6-Stage Pipelined 32-Bit Von Neumann RISC Processor
// Author  : Anton Magdy (@AntonMagdy111) - https://github.com/AntonMagdy111
// Repo    : https://github.com/AntonMagdy111/6-stage-Pipelined-Risc-processor
// License : Apache-2.0 (see LICENSE and NOTICE for mandatory attribution)
// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Anton Magdy. All rights reserved.
// ==========================================================================
//---------------------------------------------------------------------
// assembler.cpp
// Two-pass assembler for the 6-stage pipelined Von Neumann processor.
//
// Usage:   ./assembler input.asm output.mem
//
// Output: one 32-bit binary word per line. The instruction occupies the
// low 16 bits; the upper 16 bits are zero. Instructions with an
// immediate take a second word holding the 32-bit immediate.
//
// Memory layout the assembler creates:
//   M[0] = start address (program entry)
//   M[1] = interrupt-vector entry address
//   M[2..] = code/data
//
// Encoding conventions (see also cpu_pkg.vhd):
//   ir(15:11) opcode
//   ir(10: 8) rdst
//   ir( 7: 5) rs1
//   ir( 4: 2) rs2
//
// Some instructions need their operand register routed to a specific
// position because the hardware uses a fixed datapath. The assembler
// hides these:
//   * NOT/INC Rdst        -> rdst=Rdst, rs2=Rdst (so ALU sees Rdst on B)
//   * MOV  Rdst, Rsrc     -> rdst=Rdst, rs2=Rsrc (B path -> PASS)
//   * SWAP Rdst, Rsrc     -> rdst=Rdst, rs2=Rsrc
//   * OUT  Rsrc           -> rs2=Rsrc
//   * PUSH Rsrc           -> rs2=Rsrc
//   * IN   Rdst           -> rdst=Rdst
//   * POP  Rdst           -> rdst=Rdst
//   * LDM  Rdst, #imm     -> rdst=Rdst, imm
//   * LDD  Rdst, off(Rs)  -> rdst=Rdst, rs1=Rs, imm=off
//   * STD  Rsrc1, off(Rs) -> rs2=Rsrc1 (data), rs1=Rs (base), imm=off
//---------------------------------------------------------------------
#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <map>
#include <bitset>
#include <cstdint>
#include <algorithm>
#include <cctype>
#include <stdexcept>

using namespace std;

struct OpInfo {
    string mnemonic;
    uint8_t opcode;
    int     format;
    bool    has_imm;
};

// formats:
//   0 NOP/HLT/SETC/RET/RTI         (no operands)
//   1 INC/NOT Rdst                 (single reg, becomes both rdst & rs2)
//   2 MOV/SWAP Rdst, Rsrc          (rs2 = Rsrc)
//   3 ADD/SUB/AND Rdst, Rs1, Rs2
//   4 IADD Rdst, Rsrc, #imm
//   5 jumps + CALL: imm
//   6 LDD Rdst, off(Rs)
//   7 STD Rsrc1, off(Rs2)
//   8 OUT Rsrc / PUSH Rsrc         (rs2 = Rsrc)
//   9 IN Rdst / POP Rdst           (rdst = Rdst)
//  10 LDM Rdst, #imm
//  11 INT index
static const vector<OpInfo> OPS = {
    {"NOP" , 0b00000, 0, false},
    {"HLT" , 0b00001, 0, false},
    {"SETC", 0b00010, 0, false},
    {"NOT" , 0b00011, 1, false},
    {"INC" , 0b00100, 1, false},
    {"MOV" , 0b00101, 2, false},
    {"SWAP", 0b00110, 2, false},
    {"ADD" , 0b00111, 3, false},
    {"SUB" , 0b01000, 3, false},
    {"AND" , 0b01001, 3, false},
    {"IADD", 0b01010, 4, true},
    {"OUT" , 0b01011, 8, false},
    {"IN"  , 0b01100, 9, false},
    {"PUSH", 0b01101, 8, false},
    {"POP" , 0b01110, 9, false},
    {"LDM" , 0b10000,10, true},
    {"LDD" , 0b10001, 6, true},
    {"STD" , 0b10010, 7, true},
    {"JZ"  , 0b10011, 5, true},
    {"JN"  , 0b10100, 5, true},
    {"JC"  , 0b10101, 5, true},
    {"JMP" , 0b10110, 5, true},
    {"CALL", 0b10111, 5, true},
    {"RET" , 0b11000, 0, false},
    {"RTI" , 0b11001, 0, false},
    {"INT" , 0b11010,11, false}
};

static string upper(string s) {
    transform(s.begin(), s.end(), s.begin(),
              [](unsigned char c){ return toupper(c); });
    return s;
}
static string trim(const string& s) {
    auto a = s.find_first_not_of(" \t\r\n");
    if (a == string::npos) return "";
    auto b = s.find_last_not_of(" \t\r\n");
    return s.substr(a, b - a + 1);
}
static vector<string> split(const string& s, const string& delims = " ,\t") {
    vector<string> out; string cur;
    for (char c : s) {
        if (delims.find(c) != string::npos) {
            if (!cur.empty()) { out.push_back(cur); cur.clear(); }
        } else cur += c;
    }
    if (!cur.empty()) out.push_back(cur);
    return out;
}
static int parse_reg(const string& tok) {
    string t = upper(trim(tok));
    if (t.size() != 2 || t[0] != 'R' || t[1] < '0' || t[1] > '7')
        throw runtime_error("expected register R0..R7, got: " + tok);
    return t[1] - '0';
}
static uint32_t parse_imm(const string& tok, const map<string,int>& labels) {
    string t = trim(tok);
    if (t.empty()) throw runtime_error("empty immediate");
    if (t[0] == '#') t = trim(t.substr(1));
    if (t.empty()) throw runtime_error("empty immediate after '#'");

    auto it = labels.find(upper(t));
    if (it != labels.end()) return static_cast<uint32_t>(it->second);

    bool neg = false;
    string num = t;
    if (num[0] == '-' || num[0] == '+') {
        neg = (num[0] == '-');
        num = num.substr(1);
    }
    if (num.empty() || !isalnum(static_cast<unsigned char>(num[0])))
        throw runtime_error("invalid immediate: " + tok);

    int base = 10;
    if (num.size() > 2 && num[0] == '0' && (num[1] == 'x' || num[1] == 'X')) {
        base = 16;
        num = num.substr(2);
    } else if (num.size() > 2 && num[0] == '0' && (num[1] == 'b' || num[1] == 'B')) {
        base = 2;
        num = num.substr(2);
    }
    if (num.empty() || num[0] == '+' || num[0] == '-')
        throw runtime_error("invalid immediate: " + tok);

    size_t pos = 0;
    unsigned long long val = 0;
    try {
        val = stoull(num, &pos, base);
    } catch (...) {
        throw runtime_error("invalid immediate: " + tok);
    }
    if (pos != num.size() || val > 0xFFFFFFFFULL)
        throw runtime_error("immediate out of range or malformed: " + tok);

    if (neg) return static_cast<uint32_t>((0ULL - val) & 0xFFFFFFFFULL);
    return static_cast<uint32_t>(val & 0xFFFFFFFFULL);
}
static const OpInfo* find_op(const string& m) {
    string M = upper(m);
    for (auto& op : OPS) if (op.mnemonic == M) return &op;
    return nullptr;
}
static uint16_t encode(uint8_t op, int rdst, int rs1, int rs2) {
    return (uint16_t(op & 0x1F) << 11)
         | (uint16_t(rdst & 0x7) << 8)
         | (uint16_t(rs1  & 0x7) << 5)
         | (uint16_t(rs2  & 0x7) << 2);
}
static string bin32(uint32_t v) { return bitset<32>(v).to_string(); }

int main(int argc, char** argv) {
    if (argc < 3) {
        cerr << "Usage: " << argv[0] << " input.asm output.mem\n";
        return 1;
    }
    ifstream fin(argv[1]);
    if (!fin) { cerr << "Cannot open " << argv[1] << "\n"; return 1; }

    vector<string> lines;
    string ln;
    while (getline(fin, ln)) lines.push_back(ln);

    // Pass 1: addresses + labels
    map<string,int> labels;
    map<int,string> code_at;
    int addr = 2;                  // M[0] reset, M[1] intr
    int start_addr = 2;
    int intr_addr  = 0;
    string start_tok, intr_tok;
    bool got_start = false;
    bool got_start_tok = false;
    bool got_intr_tok  = false;

    for (auto& raw : lines) {
        string s = raw;
        auto sc = s.find(';');
        if (sc != string::npos) s = s.substr(0, sc);
        s = trim(s);
        if (s.empty()) continue;

        auto cp = s.find(':');
        if (cp != string::npos) {
            string lbl = upper(trim(s.substr(0, cp)));
            if (lbl.empty()) { cerr << "Empty label at address " << addr << "\n"; return 1; }
            if (labels.count(lbl)) { cerr << "Duplicate label: " << lbl << "\n"; return 1; }
            labels[lbl] = addr;
            s = trim(s.substr(cp + 1));
            if (s.empty()) continue;
        }

        if (s[0] == '.') {
            auto toks = split(s);
            string d = upper(toks[0]);
            if (toks.size() != 2) {
                cerr << "Directive " << d << " requires exactly 1 argument: \"" << s << "\"\n";
                return 1;
            }
            try {
                if (d == ".ORG") {
                    addr = static_cast<int>(parse_imm(toks[1], labels));
                    if (addr < 0 || addr >= 4096) { cerr << ".ORG address out of range: " << addr << "\n"; return 1; }
                    if (!got_start) { start_addr = addr; got_start = true; }
                } else if (d == ".START") {
                    start_tok = toks[1];
                    got_start = true;
                    got_start_tok = true;
                } else if (d == ".INTR") {
                    intr_tok = toks[1];
                    got_intr_tok = true;
                } else if (d == ".WORD") {
                    if (addr < 0 || addr >= 4096) { cerr << "Address out of range: " << addr << "\n"; return 1; }
                    code_at[addr] = s; addr += 1;
                } else {
                    cerr << "Unknown directive: " << d << "\n"; return 1;
                }
            } catch (exception& e) {
                cerr << "Error at \"" << s << "\": " << e.what() << "\n";
                return 1;
            }
            continue;
        }

        auto toks = split(s);
        const OpInfo* op = find_op(toks[0]);
        if (!op) { cerr << "Unknown mnemonic: " << toks[0] << "\n"; return 1; }
        if (addr < 0 || addr + (op->has_imm ? 1 : 0) >= 4096) {
            cerr << "Address out of range: " << addr << "\n"; return 1;
        }
        code_at[addr] = s;
        addr += op->has_imm ? 2 : 1;
    }

    // Pass 2: resolve deferred .START / .INTR directives (supports forward labels)
    try {
        if (got_start_tok) start_addr = static_cast<int>(parse_imm(start_tok, labels));
        if (got_intr_tok)  intr_addr  = static_cast<int>(parse_imm(intr_tok, labels));
    } catch (exception& e) {
        cerr << "Error resolving .START/.INTR: " << e.what() << "\n";
        return 1;
    }
    if (start_addr < 0 || start_addr >= 4096 || intr_addr < 0 || intr_addr >= 4096) {
        cerr << "Vector address out of range (start=" << start_addr << ", intr=" << intr_addr << ")\n";
        return 1;
    }
    int max_addr = addr;
    vector<uint32_t> mem(4096, 0);
    mem[0] = static_cast<uint32_t>(start_addr);
    mem[1] = static_cast<uint32_t>(intr_addr);

    for (auto& [a, line] : code_at) {
        auto toks = split(line);
        string m = upper(toks[0]);

        if (m == ".WORD") {
            try {
                mem[a] = parse_imm(toks[1], labels);
            } catch (exception& e) {
                cerr << "Error at \"" << line << "\": " << e.what() << "\n";
                return 1;
            }
            continue;
        }

        const OpInfo* op = find_op(m);
        int rdst=0, rs1=0, rs2=0;
        uint32_t imm=0;

        try {
            switch (op->format) {
                case 0: {
                    if (toks.size() != 1) throw runtime_error("expected 0 operands");
                    break;
                }
                case 1: { // INC/NOT Rdst
                    if (toks.size() != 2) throw runtime_error("expected 1 register operand");
                    int r = parse_reg(toks[1]);
                    rdst = r; rs2 = r;
                    break;
                }
                case 2: { // MOV/SWAP Rdst, Rsrc
                    if (toks.size() != 3) throw runtime_error("expected 2 register operands");
                    rdst = parse_reg(toks[1]);
                    rs2  = parse_reg(toks[2]);
                    break;
                }
                case 3: { // ADD/SUB/AND Rdst, Rs1, Rs2
                    if (toks.size() != 4) throw runtime_error("expected 3 register operands");
                    rdst = parse_reg(toks[1]);
                    rs1  = parse_reg(toks[2]);
                    rs2  = parse_reg(toks[3]);
                    break;
                }
                case 4: { // IADD Rdst, Rsrc, #imm
                    if (toks.size() != 4) throw runtime_error("expected Rdst, Rsrc, #imm");
                    rdst = parse_reg(toks[1]);
                    rs1  = parse_reg(toks[2]);
                    imm  = parse_imm(toks[3], labels);
                    break;
                }
                case 5: { // jumps + CALL
                    if (toks.size() != 2) throw runtime_error("expected target operand");
                    imm = parse_imm(toks[1], labels);
                    break;
                }
                case 6: { // LDD Rdst, off(Rs)
                    if (toks.size() != 3) throw runtime_error("expected Rdst, offset(Rbase)");
                    rdst = parse_reg(toks[1]);
                    string offrs = toks[2];
                    auto p = offrs.find('('), q = offrs.find(')');
                    if (p == string::npos || q == string::npos || q <= p || q + 1 != offrs.size())
                        throw runtime_error("bad mem operand: " + offrs);
                    imm = parse_imm(offrs.substr(0, p), labels);
                    rs1 = parse_reg(offrs.substr(p+1, q-p-1));
                    break;
                }
                case 7: { // STD Rsrc1, off(Rs2)
                    if (toks.size() != 3) throw runtime_error("expected Rdata, offset(Rbase)");
                    rs2 = parse_reg(toks[1]);     // data source
                    string offrs = toks[2];
                    auto p = offrs.find('('), q = offrs.find(')');
                    if (p == string::npos || q == string::npos || q <= p || q + 1 != offrs.size())
                        throw runtime_error("bad mem operand: " + offrs);
                    imm = parse_imm(offrs.substr(0, p), labels);
                    rs1 = parse_reg(offrs.substr(p+1, q-p-1));
                    break;
                }
                case 8: { // OUT/PUSH Rsrc
                    if (toks.size() != 2) throw runtime_error("expected 1 register operand");
                    rs2 = parse_reg(toks[1]);
                    break;
                }
                case 9: { // IN/POP Rdst
                    if (toks.size() != 2) throw runtime_error("expected 1 register operand");
                    rdst = parse_reg(toks[1]);
                    break;
                }
                case 10: { // LDM Rdst, #imm
                    if (toks.size() != 3) throw runtime_error("expected Rdst, #imm");
                    rdst = parse_reg(toks[1]);
                    imm  = parse_imm(toks[2], labels);
                    break;
                }
                case 11: { // INT index
                    if (toks.size() != 2) throw runtime_error("expected interrupt index");
                    uint32_t idx_val = parse_imm(toks[1], labels);
                    if (idx_val > 1) throw runtime_error("INT index out of range (expected 0 or 1)");
                    rdst = static_cast<int>(idx_val) & 0x1;
                    break;
                }
            }
        } catch (exception& e) {
            cerr << "Error at \"" << line << "\": " << e.what() << "\n";
            return 1;
        }

        uint16_t instr = encode(op->opcode, rdst, rs1, rs2);
        mem[a] = static_cast<uint32_t>(instr);
        if (op->has_imm) mem[a + 1] = imm;
    }

    ofstream fout(argv[2]);
    if (!fout) { cerr << "Cannot write " << argv[2] << "\n"; return 1; }
    for (uint32_t w : mem) fout << bin32(w) << "\n";
    cerr << "6-Stage RISC Assembler - Copyright (c) 2026 Anton Magdy (@AntonMagdy111) [Apache-2.0]\n";
    cerr << "Assembled " << max_addr - 2 << " words into " << argv[2] << "\n";
    cerr << "Start address: " << start_addr;
    if (intr_addr) cerr << ", intr vector: " << intr_addr;
    cerr << "\n";
    return 0;
}
