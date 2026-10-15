"""
exe_util.py
============
Utilidades pra caçar coisas no executável do PS2 (SCES_546.88, ELF MIPS
R5900) sem abrir o Ghidra. Tudo em endereço virtual.

Uso:
    python re/exe_util.py EXE str A_FRAME_END_FRONT_LEFT     onde fica a string e quem aponta pra ela
    python re/exe_util.py EXE jal 0x38d5f8                   quem chama a função
    python re/exe_util.py EXE imm 0x50,0x14 lwc1,swc1        instruções com esse imediato
    python re/exe_util.py EXE words 0x5506c0 40              palavras (e strings apontadas)
    python re/exe_util.py EXE floats 0x5b4c38 16             floats

Dica: string referenciada por "lui + addiu" não aparece como ponteiro; o
'str' também procura addiu com os 16 bits baixos do endereço (confirme o
lui na mão). Tabelas de nomes (ex.: pontos do modelo em 0x55070c) aparecem
como ponteiro.
"""

import struct
import sys

OPS = {0x39: "swc1", 0x2B: "sw", 0x31: "lwc1", 0x23: "lw", 0x09: "addiu",
       0x3E: "sqc2", 0x1F: "sq", 0x36: "lqc2", 0x0F: "lui", 0x0D: "ori"}


class Elf:
    def __init__(self, path):
        self.d = open(path, "rb").read()
        d = self.d
        phoff = struct.unpack_from("<I", d, 0x1C)[0]
        n = struct.unpack_from("<H", d, 0x2C)[0]
        sz = struct.unpack_from("<H", d, 0x2A)[0]
        self.segs = []
        for i in range(n):
            t, off, va, pa, fsz, msz, fl, al = struct.unpack_from("<8I", d, phoff + i * sz)
            if t == 1:
                self.segs.append((off, va, fsz))

    def v2f(self, v):
        for off, va, fsz in self.segs:
            if va <= v < va + fsz:
                return off + v - va
        return None

    def f2v(self, o):
        for off, va, fsz in self.segs:
            if off <= o < off + fsz:
                return va + o - off
        return None

    def words(self):
        for off, va, fsz in self.segs:
            for j in range(off, off + fsz - 3, 4):
                yield va + j - off, struct.unpack_from("<I", self.d, j)[0]

    def cstr(self, v):
        o = self.v2f(v)
        if o is None:
            return None
        e = self.d.find(b"\0", o)
        s = self.d[o:e]
        return s.decode("latin-1") if s and all(32 <= c < 127 for c in s) else None


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        return
    e = Elf(sys.argv[1])
    cmd, arg = sys.argv[2], sys.argv[3]
    if cmd == "str":
        i = e.d.find(arg.encode() + b"\0")
        while i != -1:
            v = e.f2v(i)
            print(f"string em {v:#x}")
            lo = v & 0xFFFF
            for a, w in e.words():
                if w == v:
                    print(f"  ponteiro em {a:#x}")
                elif (w >> 26) == 9 and (w & 0xFFFF) == lo:
                    print(f"  addiu ..{lo:#06x} em {a:#x}")
            i = e.d.find(arg.encode() + b"\0", i + 1)
    elif cmd == "jal":
        alvo = int(arg, 16)
        for a, w in e.words():
            if (w >> 26) == 3 and ((w & 0x3FFFFFF) << 2) == alvo:
                print(f"jal em {a:#x}")
    elif cmd == "imm":
        imms = {int(x, 16) for x in arg.split(",")}
        want = set(sys.argv[4].split(",")) if len(sys.argv) > 4 else set(OPS.values())
        for a, w in e.words():
            op = w >> 26
            if (w & 0xFFFF) in imms and OPS.get(op) in want:
                print(f"{a:#x} {OPS[op]} {w & 0xFFFF:#x} base r{(w >> 21) & 31}")
    elif cmd in ("words", "floats"):
        v = int(arg, 16)
        n = int(sys.argv[4]) if len(sys.argv) > 4 else 16
        for k in range(n):
            o = e.v2f(v + 4 * k)
            w = struct.unpack_from("<I", e.d, o)[0]
            if cmd == "floats":
                print(f"{v + 4 * k:#x} {struct.unpack_from('<f', e.d, o)[0]}")
            else:
                s = e.cstr(w) if 0x100000 <= w < 0x800000 else None
                print(f"{v + 4 * k:#x} {w:#010x} {s or ''}")


if __name__ == "__main__":
    main()
