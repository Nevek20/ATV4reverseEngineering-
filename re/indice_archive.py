"""
indice_archive.py
==================
Monta a tabela caminho -> bloco do unpacked (data/arquivos.tsv), do jeito
que o jogo acha os arquivos.

O jogo abre tudo pelo caminho (ex.: /Vehicles/Buggy/Models_4K/Chassis/
CHASSIS_Buggy_10/Body.pingu). O índice do archive (archive.bin, que fica
inteiro na RAM em 0x89ab50, 0x3d00b bytes) é uma árvore: cada pasta e cada
arquivo guarda o CRC32 do nome em minúsculas (refletido, tabela 0x7d3298,
init 0xffffffff, sem xor final; nos arquivos o bit 0 é a flag de
comprimido). Busca: FUN_0066c978 / 0066d110 / 0066d270 / 0066d308.

Os nomes não estão no índice, só o CRC. Pra voltar do CRC pro nome o script
junta todas as strings do exe, da RAM e dos XMLs/raw e testa cada uma (com
várias extensões). Sai uma linha por arquivo:

    caminho  offset  tamanho  c|u  fonte

fonte = arquivo do unpacked (other/20800_bloco.bin) ou, pros não comprimidos
que ficaram dentro de um bloco raw, raw/NNNNNr_bloco.bin+deslocamento.
Pasta sem nome conhecido aparece como #crc.

Uso (uns 3 min):
    python re/indice_archive.py <save.p2s ou ram.bin> <unpacked> <SCES_546.88> [--out data/arquivos.tsv]
"""

import argparse
import bisect
import glob
import json
import os
import re
import struct
import sys
import zlib

AQUI = os.path.dirname(os.path.abspath(__file__))
ARQ_BIN = (0x89ab50, 0x3d00b)
EXT = ["bog", "bed", "hsc", "pfx", "pss", "ptx", "pmb", "sbk", "skn", "ani", "pan",
       "lua", "pts", "pingu", "gob", "xml", "pfn", "psm", "point", "pnt", "bin", "dat",
       "txt", "vag", "vab", "hd", "bd", "ipu", "anim", "col", "tex", "shadow", "font",
       "fnt", "csv", "ini", "cfg", "bnk", "sfx", "str", "tga", "bmp", "png", "wav",
       "seq", "vh"]


# nomes de arquivo de verdade; corta lixo que colide no CRC ("ONy?za.ini")
NOME_OK = re.compile(r"^[A-Za-z_][A-Za-z0-9_\-. ]*$")


def crc(s):
    return zlib.crc32(s.lower().encode("latin-1")) ^ 0xFFFFFFFF


class Indice:
    """árvore do archive.bin (registros com varint, ver FUN_0066d110)"""

    def __init__(self, buf):
        self.b = buf
        h = struct.unpack_from("<11I", buf, 0)
        self.t12 = 0x2C        # registros de pasta compartilhados (12 bytes)
        self.tA = h[7]         # registros de arquivo compartilhados (8 bytes)
        self.raiz = h[9]

    def varint(self, p):
        v = s = 0
        while True:
            c = self.b[p]
            p += 1
            v |= (c & 0x7F) << s
            s += 7
            if not c & 0x80:
                return v, p

    def no(self, p):
        fl, p = self.varint(p)
        if fl & 1 == 0:
            hs = struct.unpack_from("<I", self.b, p)[0]
            p += 4
            _, p = self.varint(p)
            pulo, p = self.varint(p)
            nf, p = self.varint(p)
        else:
            ix, p = self.varint(p)
            hs, pulo, nf = struct.unpack_from("<3I", self.b, self.t12 + ix * 12)
        return fl, hs, pulo, nf, p

    def arquivos(self, p, n):
        out, off = [], 0
        for _ in range(n):
            if self.b[p] & 1 == 0:
                hs = struct.unpack_from("<I", self.b, p)[0]
                p += 4
                v, p = self.varint(p)
            else:
                ix, p = self.varint(p)
                hs, v = struct.unpack_from("<2I", self.b, self.tA + (ix >> 1) * 8)
            out.append((hs, off, v >> 1, v & 1))
            off = (off + (v >> 1) + 0xF) & ~0xF
        return out, p

    def andar(self, p, base, pasta, res):
        fl, hs, pulo, nf, q = self.no(p)
        fs, q = self.arquivos(q, nf)
        for fh, off, sz, c in fs:
            res.append((pasta, fh, base + off, sz, c))
        if fl & 2:
            while True:
                cfl, chs, cpulo, _, _ = self.no(q)
                self.andar(q, base + (cfl >> 3), pasta + [chs], res)
                if not cfl & 4:
                    break
                q += cpulo


def ler_ram(src):
    if src.lower().endswith(".p2s"):
        sys.path.insert(0, os.path.join(os.path.dirname(AQUI), "tools"))
        from ler_savestate import ler_ram as lr
        return lr(src)
    return open(src, "rb").read()


def strings(data, mn=3):
    return re.findall(rb"[\x20-\x7e]{%d,}" % mn, data)


def dicionario(alvos, fontes, manifest):
    toks = {e["name"] for e in manifest}
    for d in fontes:
        for s in strings(d):
            s = s.decode("latin-1")
            if len(s) <= 100:
                toks.add(s)
            for t in re.split(r"[\s/\\\"'=<>,;:()\[\]{}|%*?&]+", s):
                if t and len(t) <= 100:
                    toks.add(t)
    nomes = {}

    def tenta(n):
        if not NOME_OK.match(n):
            return
        h = crc(n)
        k = h & 0xFFFFFFFE
        if h in alvos or k in alvos:
            nomes.setdefault(h, set()).add(n)
            nomes.setdefault(k, set()).add(n)

    # pastas de LOD que não aparecem em nenhuma string (achadas testando)
    for lod in ("5K", "4K", "3K", "2K", "1K", "500", "Shadow"):
        toks.add("Models_" + lod)
    bases = set()
    for t in toks:
        tenta(t)
        m = re.match(r"^(.*)\.([A-Za-z0-9]{1,6})$", t)
        bases.add(m.group(1) if m else t)
    for b in bases:
        for e in EXT:
            tenta(b + "." + e)
    return nomes


def grafia(cands):
    # a grafia "Bonita" (maiúsculas e minúsculas), senão a primeira
    mix = sorted(x for x in cands if x != x.upper() and x != x.lower())
    return (mix or sorted(cands))[0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ram")
    ap.add_argument("unpacked")
    ap.add_argument("exe")
    ap.add_argument("--out", default=os.path.join(os.path.dirname(AQUI), "data", "arquivos.tsv"))
    a = ap.parse_args()

    ram = ler_ram(a.ram)
    buf = ram[ARQ_BIN[0]:ARQ_BIN[0] + ARQ_BIN[1]]
    idx = Indice(buf)
    res = []
    idx.andar(idx.raiz, 0x10, [], res)
    print(f"[+] {len(res)} arquivos no índice")

    manifest = json.load(open(os.path.join(a.unpacked, "manifest.json")))
    alvos = set()
    for pasta, fh, *_ in res:
        alvos.add(fh & 0xFFFFFFFE)
        alvos.update(pasta)
    fontes = [open(a.exe, "rb").read(), ram]
    for f in (glob.glob(os.path.join(a.unpacked, "xml", "*")) +
              glob.glob(os.path.join(a.unpacked, "text", "*")) +
              glob.glob(os.path.join(a.unpacked, "raw", "*r_bloco.bin"))):
        if os.path.getsize(f) < 20_000_000:
            fontes.append(open(f, "rb").read())
    nomes = dicionario(alvos, fontes, manifest)
    print(f"[+] {len(nomes)} CRCs com nome")

    por_off = {}
    for e in manifest:
        if e["type"] in ("other", "gob", "xml", "text"):
            por_off.setdefault(e["offset"], e)
    raws = sorted((e["offset"], e) for e in manifest if e["type"].startswith("raw"))
    ro = [o for o, _ in raws]

    def fonte(off, sz, comp):
        if comp:
            e = por_off.get(off)
            return e["file"] if e else ""
        i = bisect.bisect_right(ro, off) - 1
        if i < 0:
            return ""
        o, e = raws[i]
        if o <= off < o + e["usize"] + 64:
            return "%s+%d" % (e["file"], off - o)
        return ""

    def nome(h, arq=False):
        c = nomes.get(h) or (nomes.get(h & 0xFFFFFFFE) if arq else None)
        return grafia(c) if c else "#%08x" % h

    linhas = []
    for pasta, fh, off, sz, c in res:
        caminho = "/".join(nome(h) for h in pasta) + "/" + nome(fh, True)
        linhas.append("%s\t%d\t%d\t%s\t%s" % (caminho, off, sz, "c" if c else "u", fonte(off, sz, c)))
    linhas.sort()
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        f.write("# caminho\toffset\ttamanho\tc|u\tfonte (gerado por re/indice_archive.py)\n")
        f.write("\n".join(linhas) + "\n")
    print(f"[+] salvo {a.out}")


if __name__ == "__main__":
    main()
