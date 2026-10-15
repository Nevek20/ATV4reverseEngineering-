"""
gerar_buggies.py
=================
Gera os assets dos 12 buggies de uma vez: carroceria, peças da suspensão,
freios, rodas e pintura de fábrica. Também copia a física (15144+N) e o
arquivo de pontos pra data/vehicles.

Os blocos de cada carro saem do manifest.json: cada carro ocupa um trecho
do unpacked que termina na sombra dele (gob BUGGY_NN_shadow, LANCIA_shadow
no 12º). Dentro do trecho:
    11 peças (< 20 KB) antes do modelo: balança DE, DD, TE, TD, sombra,
        corpo do amortecedor traseiro E/D, amortecedor dianteiro E/D,
        haste traseira E/D (ordem do suspension_visual.gd)
    modelo (o maior bloco), pontos (começa com "POINT"),
    4 blocos depois dos pontos: freios DE, DD, TE, TD
O Mosquito (BUGGY_01) não tem as 11 peças; só modelo, pontos e freios.

Uso (na pasta do projeto):
    python tools/gerar_buggies.py <unpacked> <texturas>
    python tools/gerar_buggies.py <unpacked> <texturas> --so 2,3
    python tools/gerar_buggies.py <unpacked> <texturas> --tabela   (só lista os blocos)
<texturas> é a pasta que o gob_tex2png.py gerou.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(AQUI)

# ordem da lista do jogo (FEOrder) e nome que aparece no menu do jogo
NOMES = ["Mosquito", "Inferno", "Trident", "Sphinx", "Bulldog", "Phantom",
         "Kraken V8", "McKenzies", "Viper", "Renegade", "Hurricane", "Storm"]
# pasta em assets/ (Renegade e Sphinx mantêm as pastas antigas)
PASTA = {4: "sphinx", 10: "renegade"}
# volante separado (peça móvel), tiras medidas na malha
SPLIT = {10: ["volante:44,53,54,234-242"]}
# rodas de jogo (frente, trás), ver docs/assets.md
RODAS = {
    "TYRE_GENERIC_LARGE": (21963, 21964),
    "TYRE_GENERIC_MEDIUM": (21968, 21969),
    "TYRE_GENERIC_SANDCAR": (21973, 21974),
    "TYRE_GENERIC_SMALL": (21978, 21979),
    "Wheel_Rally": (21267, 21268),
}


def indice(e):
    try:
        return int(str(e["index"]).split("_")[-1])
    except ValueError:
        return None


def mapear(unpacked):
    man = json.load(open(os.path.join(unpacked, "manifest.json")))
    E = {}
    for e in man:
        k = indice(e)
        if k is not None:
            E[k] = e
    sombras = []
    for n in range(1, 13):
        alvo = ("LANCIA_shadow" if n == 12 else
                "BUGGY_01_shadow_new" if n == 1 else "BUGGY_%02d_shadow" % n)
        sombras.append(min(k for k, e in E.items() if e.get("name") == alvo))

    def is_points(k):
        with open(os.path.join(unpacked, E[k]["file"]), "rb") as f:
            return f.read(5) == b"POINT"

    carros = []
    for n, fim in enumerate(sombras, 1):
        ini = sombras[n - 2] if n > 1 else fim - 40
        outros = [k for k in range(ini + 1, fim) if k in E and E[k]["type"] == "other"]
        modelo = max(outros, key=lambda k: E[k]["usize"])
        pontos = next(k for k in outros if k > modelo and is_points(k))
        depois = [k for k in outros if k > pontos and not is_points(k)]
        antes = [k for k in outros if k < modelo and not is_points(k) and E[k]["usize"] < 20000]
        carros.append({
            "n": n, "id": "BUGGY_%02d" % n, "nome": NOMES[n - 1],
            "modelo": modelo, "pontos": pontos,
            "pecas": antes[:11] if len(antes) >= 11 else [],
            "freios": depois[:4],
        })
    return carros


def config_xml():
    """roda e câmeras de cada buggy, do data/vehicles.xml"""
    s = open(os.path.join(PROJ, "data", "vehicles.xml"), encoding="latin-1").read()
    out = {}
    for m in re.finditer(r'<Vehicle Name="(BUGGY_\d\d)".*?</Vehicle>', s, re.S):
        blk = m.group(0)
        out[m.group(1)] = {
            "roda": re.search(r'DefaultConfig[^>]*Wheel="([^"]+)"', blk).group(1),
            "cams": re.search(r'Cameras="([^"]+)"', blk).group(1),
        }
    return out


def pingu(unpacked, tex, bloco, out, split=()):
    cmd = [sys.executable, os.path.join(AQUI, "pingu2obj.py"),
           os.path.join(unpacked, "other", "%d_bloco.bin" % bloco),
           "--out", out, "--tex", tex, "--copy-tex"]
    for s in split:
        cmd += ["--split", s]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout, r.stderr)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("unpacked")
    ap.add_argument("texturas")
    ap.add_argument("--assets", default=os.path.join(PROJ, "assets"))
    ap.add_argument("--so", help="só esses carros (ex: 2,3)")
    ap.add_argument("--tabela", action="store_true", help="só mostra os blocos")
    a = ap.parse_args()

    carros = mapear(a.unpacked)
    cfg = config_xml()
    so = {int(x) for x in a.so.split(",")} if a.so else None
    for c in carros:
        c.update(cfg[c["id"]])
        print("%2d %-10s modelo %d pontos %d peças %s freios %s roda %s" % (
            c["n"], c["nome"], c["modelo"], c["pontos"],
            c["pecas"][0] if c["pecas"] else "-", c["freios"], c["roda"]))
    if a.tabela:
        return

    rodas = os.path.join(a.assets, "rodas")
    for f, t in RODAS.values():
        for b in (f, t):
            pingu(a.unpacked, a.texturas, b, rodas)
    print("[+] rodas em", rodas)

    dados = os.path.join(PROJ, "data", "vehicles")
    for c in carros:
        if so and c["n"] not in so:
            continue
        n = c["n"]
        out = os.path.join(a.assets, PASTA.get(n, "buggy_%02d" % n))
        pingu(a.unpacked, a.texturas, c["modelo"], out, SPLIT.get(n, ()))
        for b in c["pecas"] + c["freios"]:
            pingu(a.unpacked, a.texturas, b, out)
        subprocess.run([sys.executable, os.path.join(AQUI, "gerar_pintura.py"),
                        a.unpacked, c["id"], out])
        # física e pontos (dados pequenos, ficam no git)
        shutil.copy(os.path.join(a.unpacked, "xml", "%d_root.xml" % (15144 + n)),
                    os.path.join(dados, "buggy_%02d.xml" % n))
        shutil.copy(os.path.join(a.unpacked, "other", "%d_bloco.bin" % c["pontos"]),
                    os.path.join(dados, "buggy_%02d_points.bin" % n))
        print("[+] %s em %s" % (c["nome"], out))
    print("Abra o projeto no Godot uma vez pra ele importar os .obj novos.")


if __name__ == "__main__":
    main()
