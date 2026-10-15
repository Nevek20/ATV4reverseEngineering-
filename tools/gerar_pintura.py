"""
gerar_pintura.py
=================
Monta a pintura (livery) de um veículo do jeito que o jogo faz em tempo
real e salva como pintura.png na pasta do modelo.

No modelo, a carroceria usa uma textura chamada "white" que não existe no
disco: o jogo gera ela juntando camadas descritas num XML (ex.: 15100 pro
Buggy_10):

    Buggy_10_Base       cor BASE preenchendo tudo (o alfa dela é o brilho)
    Buggy_10_Primary    máscara pintada com a cor PRIMARY
    Buggy_10_Secondary  máscara pintada com a cor SECONDARY
    Buggy_10_Detail     detalhes já coloridos (rebites, grelhas, logos)

Depois vêm decalques e números (ainda não feito aqui; os quadros brancos
são onde o número entra).

Uso:
    python gerar_pintura.py unpacked BUGGY_10 renegade
    python gerar_pintura.py unpacked BUGGY_04 sphinx
    python gerar_pintura.py unpacked BUGGY_04 sphinx --nome pintura_speedrun.png --base 225,225,230 --primary 215,85,20 --secondary 45,35,175

As cores padrão são as do XML (as de fábrica). --base/--primary/--secondary
trocam a cor, como na oficina de pintura do jogo.
"""

import os
import re
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gob_tex2png import convert  # noqa: E402


def achar_xml(xml_dir, prefixo):
    alvo = f'Path="{prefixo}_Base"'
    for f in sorted(os.listdir(xml_dir)):
        if f.endswith(".xml"):
            s = open(os.path.join(xml_dir, f), encoding="latin-1").read()
            if alvo in s:
                return f, s
    return None, None


def cor(s, nome):
    m = re.search(r'Name="%s"\s*>\s*<Diffuse R="(\d+)" G="(\d+)" B="(\d+)"' % nome, s)
    return tuple(int(x) for x in m.groups()) if m else None


def achar_gob(gob_dir, nome):
    # o nome no disco nem sempre bate a caixa com o XML (Buggy_03_base)
    for f in sorted(os.listdir(gob_dir)):
        if f.lower().endswith(f"_{nome}.gob".lower()):
            return os.path.join(gob_dir, f)
    return None


def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("veh")
    ap.add_argument("out")
    ap.add_argument("--nome", default="pintura.png")
    ap.add_argument("--base")
    ap.add_argument("--primary")
    ap.add_argument("--secondary")
    a = ap.parse_args()
    src, veh, out = a.src, a.veh, a.out
    prefixo = re.sub(r"^BUGGY", "Buggy", veh, flags=re.I)
    prefixo = re.sub(r"^TRUCK", "Truck", prefixo, flags=re.I)
    if prefixo == "Buggy_12":
        prefixo = "Lancia"          # o Storm usa as texturas Lancia_*
    xml_nome, s = achar_xml(os.path.join(src, "xml"), prefixo)
    if not s:
        print(f"[!] não achei o XML da pintura de {prefixo}")
        return
    cores = {k: cor(s, k) for k in ("BASE", "PRIMARY", "SECONDARY")}
    for k in ("base", "primary", "secondary"):
        v = getattr(a, k)
        if v:
            cores[k.upper()] = tuple(int(x) for x in v.split(","))
    print(f"[+] {xml_nome}: base {cores['BASE']} primária {cores['PRIMARY']} secundária {cores['SECONDARY']}")

    camadas = {}
    for k in ("Base", "Primary", "Secondary", "Detail"):
        g = achar_gob(os.path.join(src, "gob"), f"{prefixo}_{k}")
        if not g:
            print(f"[!] faltou a textura {prefixo}_{k}")
            continue
        im, info = convert(g)
        if im is None:
            print(f"[!] {g}: {info}")
            continue
        camadas[k] = im.convert("RGBA")

    if "Base" not in camadas:
        return
    w, h = camadas["Base"].size
    base = cores["BASE"] or (255, 255, 255)
    img = Image.new("RGB", (w, h), base)
    for k, c in (("Primary", cores["PRIMARY"]), ("Secondary", cores["SECONDARY"])):
        if k in camadas and c:
            cam = camadas[k].resize((w, h))
            img = Image.composite(Image.new("RGB", (w, h), c), img, cam.getchannel("A"))
    if "Detail" in camadas:
        cam = camadas["Detail"].resize((w, h))
        img = Image.composite(cam.convert("RGB"), img, cam.getchannel("A"))

    os.makedirs(out, exist_ok=True)
    dst = os.path.join(out, a.nome)
    img.save(dst)
    print(f"[+] salvo {dst} ({w}x{h})")


if __name__ == "__main__":
    main()
