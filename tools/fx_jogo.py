"""
fx_jogo.py
==========
Textura da fumaça do escapamento (fumaca.gd) a partir do jogo -> assets/fx
(fora do git).

O efeito "ExhaustSmokeTrail" (Effects/#3ffdac18, xml 01416) usa a textura
Sprites/Particles (.bog, 128x128) na caixa "Dust0". A caixa vem do
Sprites/Particles.bed: 4 cantos u32 (u, v x 100000) logo antes do nome; a
Dust0 dá (0, 0)-(0.497, 0.247) = pixels (0, 0)-(64, 32). Branca, com o alfa
de nuvem (PS2: 0x80 = 1.0, aqui x2).

Uso:
    python tools/fx_jogo.py <unpacked> [saida=assets/fx]
"""

import os
import struct
import sys

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gob_tex2png import convert  # noqa: E402


def ler_arquivos():
    out = {}
    for ln in open(os.path.join(PROJ, "data", "arquivos.tsv"), encoding="utf-8"):
        if ln.startswith("#"):
            continue
        cam, _, tam, _, fonte = ln.rstrip("\n").split("\t")
        out[cam.lower()] = (fonte, int(tam))
    return out


def caminho(unpacked, arqs, nome):
    fonte, tam = arqs[nome.lower()]
    arq, _, off = fonte.partition("+")
    return os.path.join(unpacked, arq), int(off or 0), tam


def caixa(bed, nome):
    """(u0, v0, u1, v1) da caixa no .bed: 8 u32 antes do nome"""
    i = bed.find(nome.encode() + b"\0")
    if i < 32:
        raise ValueError("caixa %s não achada" % nome)
    c = struct.unpack_from("<8I", bed, i - 32)
    us, vs = c[0::2], c[1::2]
    return min(us) / 1e5, min(vs) / 1e5, max(us) / 1e5, max(vs) / 1e5


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    unpacked = sys.argv[1]
    saida = sys.argv[2] if len(sys.argv) > 2 else os.path.join(PROJ, "assets", "fx")
    os.makedirs(saida, exist_ok=True)
    arqs = ler_arquivos()
    gob, _, _ = caminho(unpacked, arqs, "Sprites/Particles.bog")
    bed_arq, off, tam = caminho(unpacked, arqs, "Sprites/Particles.bed")
    with open(bed_arq, "rb") as f:
        f.seek(off)
        bed = f.read(tam)
    im, info = convert(gob)
    if im is None:
        raise SystemExit("Particles.bog: " + str(info))
    w, h = im.size
    u0, v0, u1, v1 = caixa(bed, "Dust0")
    box = (round(u0 * w), round(v0 * h), round(u1 * w), round(v1 * h))
    im.crop(box).save(os.path.join(saida, "fumaca.png"))
    print("Dust0", box, "->", os.path.join(saida, "fumaca.png"))


if __name__ == "__main__":
    main()
