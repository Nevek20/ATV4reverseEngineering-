"""
pegar_pontos.py
=================
Os carros do jogo guardam a posição das rodas (e de suspensão, escapamento,
luzes...) num arquivo de pontos que começa com "POINT 1.00". Cada ponto tem
0x50 bytes: nome (WHEEL_FRONT_LEFT, SHOCK_CHAMBER_RL...) + posição x, y, z.

Esse script acha todos os arquivos de pontos que têm rodas, lista em
pontos.txt (com as posições das 4 rodas) e zipa tudo em pontos.zip.
Os mais perto do modelo do Renegade (21711) aparecem primeiro.

Uso:
    python pegar_pontos.py unpacked
"""

import os
import struct
import sys
import zipfile

src = sys.argv[1] if len(sys.argv) > 1 else "unpacked"
RENEGADE = 21711


def pontos(data):
    out = {}
    off = 0x10
    while off + 0x50 <= len(data):
        e = data[off:off + 0x50]
        nome = e[4:0x24].split(b"\0")[0].decode("latin-1", "replace")
        out[nome] = struct.unpack("<3f", e[0x24:0x30])
        off += 0x50
    return out


achados = []
for pasta in ("other", "raw"):
    d = os.path.join(src, pasta)
    if not os.path.isdir(d):
        continue
    for f in os.listdir(d):
        p = os.path.join(d, f)
        with open(p, "rb") as fh:
            data = fh.read()
        if not data.startswith(b"POINT") or b"WHEEL_" not in data:
            continue
        num = "".join(c for c in f.split("_")[0] if c.isdigit())
        num = int(num) if num else 10 ** 9
        achados.append((abs(num - RENEGADE), f, p, data))

achados.sort()
with open("pontos.txt", "w", encoding="utf-8") as txt:
    for dist, f, p, data in achados:
        pts = pontos(data)
        rodas = {k: v for k, v in pts.items() if k.startswith("WHEEL_")}
        txt.write(f"{f}  ({len(data)} bytes, {len(pts)} pontos)\n")
        for k, (x, y, z) in sorted(rodas.items()):
            txt.write(f"    {k:28s} {x:7.3f} {y:7.3f} {z:7.3f}\n")

with zipfile.ZipFile("pontos.zip", "w", zipfile.ZIP_DEFLATED) as z:
    for dist, f, p, data in achados:
        z.writestr(f, data)

print(f"[+] {len(achados)} arquivos de pontos com rodas")
print("[+] lista em pontos.txt, arquivos em pontos.zip")
if achados:
    print(f"[+] mais perto do Renegade: {achados[0][1]}")
