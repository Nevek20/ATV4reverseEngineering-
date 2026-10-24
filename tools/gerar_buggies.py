"""
gerar_buggies.py
=================
Gera os assets dos 12 buggies como o jogo carrega na corrida: carroceria,
peças da suspensão, freios, rodas e pintura de fábrica. Também copia a
física (15144+N) e o arquivo de pontos pra data/vehicles.

Nada de adivinhar bloco pela posição: o jogo abre cada arquivo pelo caminho
e data/arquivos.tsv (re/indice_archive.py) diz em que bloco do unpacked cada
caminho está. Pra cada carro:
    Chassis   = DefaultConfig Chassis (data/vehicles.xml), ex. CHASSIS_Buggy_10
    Roda      = DefaultConfig Wheel, ex. TYRE_GENERIC_MEDIUM
    Peças     = grupo "High" do ComponentMap do carro (unpacked/xml/14881)
    Arquivo   = /Vehicles/Buggy/Models_4K/Chassis/<Chassis>/<Model>.pingu
                /Vehicles/Buggy/Models_4K/Wheel/<Roda>/<FrontWheel|RearWheel>.pingu
Se o arquivo 4K não tem bloco próprio (ficou cru dentro de um raw, ex. as
hastes do Renegade), usa o mesmo caminho no Models_5K (mesma malha).

Cada pasta ganha um pecas.json: Position do component map -> .obj. O
car.gd / suspension_visual.gd leem esse arquivo.

Uso (na pasta do projeto):
    python tools/gerar_buggies.py <unpacked> <texturas>
    python tools/gerar_buggies.py <unpacked> <texturas> --so 2,3
    python tools/gerar_buggies.py <unpacked> <texturas> --tabela   (só lista)
<texturas> é a pasta que o gob_tex2png.py gerou.
"""

import argparse
import json
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pingu2obj  # noqa: E402
import volante  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(AQUI)

# ordem da lista do jogo (FEOrder) e nome que aparece no menu do jogo
NOMES = ["Mosquito", "Inferno", "Trident", "Sphinx", "Bulldog", "Phantom",
         "Kraken V8", "McKenzies", "Viper", "Renegade", "Hurricane", "Storm"]
# pasta em assets/ (Renegade e Sphinx mantêm as pastas antigas)
PASTA = {4: "sphinx", 10: "renegade"}
# o volante vem grudado na carroceria no jogo; o tools/volante.py acha as
# tiras dele e o pingu2obj separa num .obj próprio (melhoria do remake: ele
# gira com a direção). No Renegade dá o mesmo que a marcação manual
# (43,46-47,144[16-28],145-150).
LOD = "Models_4K"


def ler_arquivos():
    """caminho em minúsculas -> (fonte, comprimido)"""
    out = {}
    for ln in open(os.path.join(PROJ, "data", "arquivos.tsv"), encoding="utf-8"):
        if ln.startswith("#"):
            continue
        cam, _, _, cu, fonte = ln.rstrip("\n").split("\t")
        out[cam.lower()] = (fonte, cu == "c")
    return out


def bloco(arqs, caminho):
    """número do bloco do unpacked/other, ou None se não tem bloco próprio"""
    f = arqs.get(caminho.lower())
    if not f:
        return None
    m = re.match(r"other/(\d+)_bloco\.bin$", f[0])
    return int(m.group(1)) if m and f[1] else None


def config_xml():
    """chassis, roda, mapa e câmeras de cada buggy, do data/vehicles.xml"""
    s = open(os.path.join(PROJ, "data", "vehicles.xml"), encoding="latin-1").read()
    out = {}
    for m in re.finditer(r'<Vehicle Name="(BUGGY_\d\d)".*?</Vehicle>', s, re.S):
        blk = m.group(0)
        out[m.group(1)] = {
            "chassis": re.search(r'DefaultConfig[^>]*Chassis="([^"]+)"', blk).group(1),
            "roda": re.search(r'DefaultConfig[^>]*Wheel="([^"]+)"', blk).group(1),
            "mapa": re.search(r'ComponentMap="([^"]+)"', blk).group(1),
            "cams": re.search(r'Cameras="([^"]+)"', blk).group(1),
        }
    return out


def mapa_high(unpacked, nome):
    """[(ComponentType, Model, Position, Mirror)] do grupo High do mapa"""
    s = open(os.path.join(unpacked, "xml", "14881_ATVCompMap_Generic.xml"), encoding="latin-1").read()
    s = re.sub(r"<!--.*?-->", "", s, flags=re.S)
    i = s.index('"%s"' % nome)
    j = s.index("</VehicleSet", i)
    g = re.search(r'<Group Name="High">(.*?)</Group>', s[i:j], re.S).group(1)
    out = []
    for c in re.finditer(r"<Component ([^>]*)/>", g):
        at = dict(re.findall(r'(\w+)="([^"]*)"', c.group(1)))
        out.append((at.get("ComponentType"), at.get("Model"), at.get("Position"), at.get("Mirror") == "1"))
    return out


def mapear(unpacked):
    arqs = ler_arquivos()
    cfg = config_xml()
    carros = []
    for n in range(1, 13):
        vid = "BUGGY_%02d" % n
        c = dict(cfg[vid], n=n, id=vid, nome=NOMES[n - 1], pecas={}, rodas={}, faltando=[])
        base = "Vehicles/Buggy/%s/Chassis/%s/" % (LOD, c["chassis"])
        c["pontos"] = bloco(arqs, base + "Body.pts")
        for tipo, model, pos, _ in mapa_high(unpacked, c["mapa"]):
            if tipo == "Chassis":
                b = bloco(arqs, base + model + ".pingu")
                if b is None:
                    b = bloco(arqs, base.replace(LOD, "Models_5K") + model + ".pingu")
                if b is None:
                    c["faltando"].append(model)
                    continue
                c["pecas"][pos] = b
            elif tipo == "Wheel":
                b = bloco(arqs, "Vehicles/Buggy/%s/Wheel/%s/%s.pingu" % (LOD, c["roda"], model))
                if b is None:
                    c["faltando"].append(model)
                    continue
                c["rodas"][model] = b
                c.setdefault("posicoes_roda", []).append(pos)
        carros.append(c)
    return carros


def copiar(dados, dst):
    """grava só se mudou (não mexe na data do arquivo à toa)"""
    if os.path.exists(dst) and open(dst, "rb").read() == dados:
        return
    open(dst, "wb").write(dados)


def pingu(unpacked, tex, bloco_, out, split=()):
    cmd = [sys.executable, os.path.join(AQUI, "pingu2obj.py"),
           os.path.join(unpacked, "other", "%d_bloco.bin" % bloco_),
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
    so = {int(x) for x in a.so.split(",")} if a.so else None
    for c in carros:
        print("%2d %-10s %-17s %-15s corpo %s pontos %s rodas %s peças %d%s" % (
            c["n"], c["nome"], c["chassis"], c["mapa"], c["pecas"].get("Body"), c["pontos"],
            "/".join(str(c["rodas"].get(k)) for k in ("FrontWheel", "RearWheel")),
            len(c["pecas"]) - 1, ("  faltando: " + ", ".join(c["faltando"])) if c["faltando"] else ""))
    if a.tabela:
        return

    rodas_dir = os.path.join(a.assets, "rodas")
    feitas = set()
    dados = os.path.join(PROJ, "data", "vehicles")
    for c in carros:
        if so and c["n"] not in so:
            continue
        n = c["n"]
        out = os.path.join(a.assets, PASTA.get(n, "buggy_%02d" % n))
        os.makedirs(out, exist_ok=True)
        vol = None
        corpo = os.path.join(a.unpacked, "other", "%d_bloco.bin" % c["pecas"]["Body"])
        pts = volante.pontos(os.path.join(a.unpacked, "other", "%d_bloco.bin" % c["pontos"]))
        if "ARSE" in pts:
            strips = pingu2obj.parse(open(corpo, "rb").read())
            vol = volante.achar(strips, pts["ARSE"])
        for pos, b in c["pecas"].items():
            split = ()
            if pos == "Body" and vol:
                split = (volante.split_spec(strips, vol["pedacos"]),)
            pingu(a.unpacked, a.texturas, b, out, split)
        for b in c["rodas"].values():
            if b not in feitas:
                pingu(a.unpacked, a.texturas, b, rodas_dir)
                feitas.add(b)
        subprocess.run([sys.executable, os.path.join(AQUI, "gerar_pintura.py"),
                        a.unpacked, c["id"], out])
        pos_rodas = c.get("posicoes_roda", [])
        info = {
            "carro": c["nome"], "id": c["id"], "chassis": c["chassis"], "mapa": c["mapa"],
            "roda": c["roda"], "lod": LOD,
            "pecas": {pos: "%d_bloco.obj" % b for pos, b in c["pecas"].items()},
            "rodas": {k: "../rodas/%d_bloco.obj" % b for k, b in c["rodas"].items()},
            # RallyCompMap põe a roda em FrontLeftWheel (sem balança no meio)
            "rally": any(p.endswith("Wheel") and "Frame" not in p for p in pos_rodas),
            "estepe": [p for p in pos_rodas if p.startswith("SpareWheel")],
        }
        if vol:
            info["volante"] = {"centro": [round(v, 4) for v in vol["centro"]],
                               "eixo": [round(v, 4) for v in vol["eixo"]],
                               "raio": round(vol["raio"], 4)}
        json.dump(info, open(os.path.join(out, "pecas.json"), "w"), indent=1)
        # física e pontos (dados pequenos, ficam no git). O XML vai com fim de
        # linha LF, igual ao git, senão no Windows aparece como modificado
        xml = open(os.path.join(a.unpacked, "xml", "%d_root.xml" % (15144 + n)), "rb").read()
        copiar(xml.replace(b"\r\n", b"\n"), os.path.join(dados, "buggy_%02d.xml" % n))
        pts = open(os.path.join(a.unpacked, "other", "%d_bloco.bin" % c["pontos"]), "rb").read()
        copiar(pts, os.path.join(dados, "buggy_%02d_points.bin" % n))
        print("[+] %s em %s" % (c["nome"], out))
    # redes das janelas e treliça do Trident: alfa do jogo de volta (o
    # gob_tex2png salva sem alfa)
    subprocess.run([sys.executable, os.path.join(AQUI, "alfa_texturas.py"), a.unpacked])
    print("Abra o projeto no Godot uma vez pra ele importar os .obj novos.")


if __name__ == "__main__":
    main()
