"""
volante.py
===========
Acha o volante dentro da malha da carroceria de um buggy.

No jogo o volante é parte da carroceria (BODY.pingu) e não gira: as tiras do
aro estão misturadas com outras peças e não há componente de volante no
component map. O volante girando é melhoria do remake (o Matheus soltou o do
Renegade na mão). Este script faz o mesmo pra qualquer carro:

  1. separa cada tira em pedaços (cada par de vértices com ADC recomeça);
  2. olha só os pedaços na frente do banco (ponto ARSE do arquivo de pontos);
  3. acha o aro com RANSAC: círculo de raio 0,13 a 0,25 m, plano virado pro
     piloto (normal com y > 0 e z < 0), o que tiver mais vértices em cima;
  4. o volante = pedaços com todos os vértices no disco do aro (perto do
     plano e até o raio do aro; o cubo do meio pode ser mais fundo): cubo,
     raios e aro.

Devolve o --split do pingu2obj (ex. "volante:43,46,47,144[16-28],145-150"),
o centro e o eixo (normal) do aro, no frame do modelo.

Uso: python tools/volante.py <BODY.pingu (bloco)> <pontos.bin>
"""

import math
import os
import random
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pingu2obj  # noqa: E402

# Renegade (medido na mão): centro do aro - ARSE
DO_BANCO = (0.047, 0.351, 0.347)
EIXO_REF = (0.0, 0.684, -0.729)
BUSCA = 0.40          # raio da busca em volta do chute (m)
TOL_PLANO = 0.035     # meia espessura do volante (m)
TOL_ARO = 0.035
CUBO = 0.09           # raio do cubo central, que é mais fundo (4 cm no Renegade)
TOL_CUBO = 0.07


def pontos(path):
    b = open(path, "rb").read()
    n = struct.unpack_from("<I", b, 0x10)[0]
    out = {}
    for i in range(n):
        o = 0x14 + 0x50 * i
        nm = b[o:o + 32].split(b"\0")[0].decode("latin-1")
        out[nm] = struct.unpack_from("<3f", b, o + 0x20)
    return out


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def norm(a):
    n = math.sqrt(dot(a, a))
    return (a[0] / n, a[1] / n, a[2] / n) if n > 1e-12 else (0.0, 0.0, 0.0)


def pedacos(strips):
    """(tira, início, fim) de cada pedaço; recomeça onde há 2 ADC seguidos"""
    out = []
    for i, st in enumerate(strips):
        adc = st[4]
        ini = [k for k in range(len(adc) - 1) if adc[k] and adc[k + 1] and (k == 0 or not adc[k - 1])]
        if not ini or ini[0] != 0:
            ini = [0] + ini
        ini.append(len(adc))
        for a, b in zip(ini, ini[1:]):
            if b - a >= 3:
                out.append((i, a, b))
    return out


def circulo(p1, p2, p3):
    """centro, raio e normal do círculo pelos 3 pontos"""
    a, b = sub(p2, p1), sub(p3, p1)
    n = cross(a, b)
    nn = dot(n, n)
    if nn < 1e-10:
        return None
    c = cross(n, a)
    d = cross(b, n)
    k = (dot(b, b) * 1.0, dot(a, a) * 1.0)
    cen = tuple(p1[i] + (k[0] * c[i] + k[1] * d[i]) / (2 * nn) for i in range(3))
    return cen, math.sqrt(dot(sub(p1, cen), sub(p1, cen))), norm(n)


def achar(strips, arse, seed=1):
    chute = tuple(arse[i] + DO_BANCO[i] for i in range(3))
    peds = pedacos(strips)
    r = _achar(strips, peds, chute, seed)
    # banco longe do volante (Chimera 31 cm, Lazarus 23 cm do chute): o lado de
    # lá do aro ficava fora da busca e o volante saía pela metade. Busca de
    # novo em volta do aro achado
    if r and math.dist(chute, r["centro"]) + r["raio"] + TOL_ARO > BUSCA:
        r = _achar(strips, peds, r["centro"], seed) or r
    return r


def _achar(strips, peds, chute, seed):
    perto = []
    for (i, a, b) in peds:
        vs = strips[i][0][a:b]
        if all(math.dist(v, chute) < BUSCA for v in vs):
            perto.append((i, a, b, vs))
    cand = [v for p in perto for v in p[3]]
    if len(cand) < 10:
        return None
    rnd = random.Random(seed)
    ref = norm(EIXO_REF)
    melhor = None
    for _ in range(4000):
        c = circulo(*rnd.sample(cand, 3))
        if not c:
            continue
        cen, r, n = c
        if not 0.13 <= r <= 0.25 or abs(dot(n, ref)) < 0.7:
            continue
        if dot(n, ref) < 0:
            n = (-n[0], -n[1], -n[2])
        nota = 0
        for v in cand:
            d = sub(v, cen)
            h = dot(d, n)
            rad = math.sqrt(max(0.0, dot(d, d) - h * h))
            if abs(h) < 0.02 and abs(rad - r) < 0.02:
                nota += 1
        if not melhor or nota > melhor[0]:
            melhor = (nota, cen, r, n)
    if not melhor:
        return None
    _, cen, r, n = melhor
    escolhidos = []
    for (i, a, b, vs) in perto:
        ok = True
        for v in vs:
            d = sub(v, cen)
            h = dot(d, n)
            rad = math.sqrt(max(0.0, dot(d, d) - h * h))
            tol = TOL_CUBO if rad < CUBO else TOL_PLANO
            if abs(h) > tol or rad > r + TOL_ARO:
                ok = False
                break
        if ok:
            escolhidos.append((i, a, b))
    return {"centro": cen, "eixo": n, "raio": r, "pedacos": escolhidos, "nota": melhor[0]}


def split_spec(strips, pedacos_):
    """formato do pingu2obj: tira inteira "44", pedaço "144[16-28]", tiras
    inteiras seguidas viram faixa "145-150" """
    por_tira = {}
    for i, a, b in pedacos_:
        por_tira.setdefault(i, []).append([a, b])
    toks = []
    inteiras = []
    for i in sorted(por_tira):
        partes = sorted(por_tira[i])
        juntas = [partes[0]]
        for a, b in partes[1:]:
            if a == juntas[-1][1]:
                juntas[-1][1] = b
            else:
                juntas.append([a, b])
        if juntas == [[0, len(strips[i][0])]]:
            inteiras.append(i)
            continue
        for a, b in juntas:
            toks.append((i, "%d[%d-%d]" % (i, a, b - 1)))
    grupos = []
    for i in inteiras:
        if grupos and grupos[-1][1] == i - 1:
            grupos[-1][1] = i
        else:
            grupos.append([i, i])
    for a, b in grupos:
        toks.append((a, str(a) if a == b else "%d-%d" % (a, b)))
    toks.sort()
    return "volante:" + ",".join(t for _, t in toks)


def main():
    d = open(sys.argv[1], "rb").read()
    strips = pingu2obj.parse(d)
    P = pontos(sys.argv[2])
    r = achar(strips, P["ARSE"])
    if not r:
        print("volante não achado")
        return
    print("centro (%.3f, %.3f, %.3f) eixo (%.3f, %.3f, %.3f) raio %.3f nota %d" % (
        *r["centro"], *r["eixo"], r["raio"], r["nota"]))
    print(split_spec(strips, r["pedacos"]))


if __name__ == "__main__":
    main()
