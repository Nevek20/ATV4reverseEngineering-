"""
Pintura dos 12 buggies (tools/gerar_pintura.py) x dados do jogo, sem tela:

 1. escala do .bed: as bordas dos quadros claros onde vai o número (achados
    na pintura sem os decalques) x as caixas PLAYER_NUMBER do .bed. Ajuste
    quadro = k * caixa + b por eixo: k ~ 1 e b ~ 0 com a fração x 100000; a
    leitura antiga (16.16 com 1.5 = textura inteira) dá k = 0.983.
 2. logos: cada chave do DefaultDecals (vehicles.xml) vira uma camada Decal
    da área certa (HOOD1 = 1ª camada Hood) e o logo existe na BuggyLogos.
    BUGGY_03 e BUGGY_04 têm as chaves de moto (FRONT_01...): sem logo.

Uso: python tests/teste_pintura.py <unpacked>
"""

import os
import sys
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, "..", "tools"))
import gerar_pintura as GP  # noqa: E402

SEM_LOGO = {"BUGGY_03", "BUGGY_04"}     # chaves de moto no vehicles.xml
CLARO = 185                             # quadro do número: os 3 canais acima
MESMO = 0.15                            # quadro do tamanho da caixa (±15%)


def quadro(a, caixa):
    """bordas (px) da mancha clara que contém o centro da caixa, ou None"""
    H, W, _ = a.shape
    x0, y0, x1, y1 = caixa
    cx, cy = int((x0 + x1) / 2 * W), int((y0 + y1) / 2 * H)
    m = Image.fromarray(((a.min(axis=2) > CLARO) * 255).astype(np.uint8)).convert("L")
    if m.getpixel((cx, cy)) != 255:
        return None
    ImageDraw.floodfill(m, (cx, cy), 128)
    ys, xs = np.nonzero(np.array(m) == 128)
    return xs.min(), xs.max() + 1, ys.min(), ys.max() + 1


def ajuste(q, c):
    k, b = np.polyfit(c, q, 1)
    return k, b, np.abs(q - (k * c + b)).mean(), np.abs(q - c).mean()


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "/home/user/atv4-dados/unpacked"
    arq = GP.Arquivos(src)
    falhas = 0
    bordas = []
    for n in range(1, 13):
        veh = "BUGGY_%02d" % n
        img = GP.montar(src, veh, com_decalques=False, log=lambda *_: None)
        a = np.asarray(img).astype(int)
        H, W, _ = a.shape
        prefixo = "Lancia" if n == 12 else "Buggy_%02d" % n
        _, s = GP.achar_xml(os.path.join(src, "xml"), prefixo)
        raiz = ET.fromstring(s)
        # 1. quadros do número (só os do mesmo tamanho da caixa medem a borda)
        usados = []
        for lay in raiz.findall("LAYER[@Type='Box']"):
            if lay.find("LAYER[@Type='Text']") is None:
                continue
            caixa = arq.bed(lay.get("BedFile"))[lay.get("Box")]
            q = quadro(a, caixa)
            cx = (caixa[0] * W, caixa[2] * W, caixa[1] * H, caixa[3] * H)
            if q and all(abs((q[i + 1] - q[i]) - (cx[i + 1] - cx[i])) < MESMO * (cx[i + 1] - cx[i])
                         for i in (0, 2)):
                bordas.append(q + cx)
                usados.append(lay.get("Box"))
        # 2. logos
        padrao = {k.upper(): v for k, v in GP.decalques_padrao(veh).items()}
        logos = {k.upper() for k in arq.bed("BuggyLogos")}
        conta, camadas = {}, set()
        for lay in raiz.findall("LAYER[@Type='Decal']"):
            area = lay.get("DecalArea", "").replace(" ", "").upper()
            conta[area] = conta.get(area, 0) + 1
            camadas.add(area + str(conta[area]))
        achadas = [k for k in padrao if k in camadas]
        sem_logo = [padrao[k] for k in achadas if padrao[k].upper() not in logos]
        sobra = sorted(set(padrao) - camadas)
        if veh in SEM_LOGO:
            ok = not achadas
        else:
            ok = not sobra and not sem_logo and len(achadas) == len(padrao)
        falhas += not ok
        print("%-9s logos %2d de %2d camadas Decal%s%s  quadros medidos: %s  %s" % (
            veh, len(achadas), len(camadas), ("  sobrando " + ",".join(sobra)) if sobra else "",
            ("  sem logo " + ",".join(sem_logo)) if sem_logo else "", ", ".join(usados) or "-",
            "ok" if ok else "FALHA"))
    b = np.array(bordas, float)
    print("\n%d quadros do número do tamanho da caixa (px de 512):" % len(b))
    for nome, qi, ci in (("x", (0, 1), (4, 5)), ("y", (2, 3), (6, 7))):
        q = np.concatenate([b[:, qi[0]], b[:, qi[1]]])
        c = np.concatenate([b[:, ci[0]], b[:, ci[1]]])
        k, bb, res, dif = ajuste(q, c)
        k15 = ajuste(q, c * 100000 / (65536 * 1.5))
        ok = abs(k - 1) < 0.01 and abs(bb) < 2.0 and dif < 2.0
        falhas += not ok
        print("  %s: quadro = %.4f x caixa %+.2f px, borda a %.2f px da caixa  (16.16/1.5: k %.4f, %.2f px)  %s"
              % (nome, k, bb, dif, k15[0], k15[3], "ok" if ok else "FALHA"))
    print("teste_pintura: %s" % ("ok" if falhas == 0 else "FALHA (%d)" % falhas))
    sys.exit(1 if falhas else 0)


if __name__ == "__main__":
    main()
