"""
ler_savestate.py
=================
Lê um save state do PCSX2 (.p2s) e mostra o estado do carro do jogador
direto da RAM do PS2: física, motor, câmbio, rodas e câmera. Serve pra
conferir o remake número por número.

O .p2s é um zip com compressão zstd (método 93), então precisa de:
    python -m pip install zstandard

Uso:
    python ler_savestate.py arquivo.p2s
    python ler_savestate.py arquivo.p2s --dump eeMemory.bin   (salva a RAM)
    python ler_savestate.py arquivo.p2s --json estado.json      (estado do carro, coords do jogo)

Endereços (PAL SCES_546.88), achados no save state do Renegade:
    câmera de órbita: vtable 0x5b3f30 em +0x68; +0x10 posição, +0x40 direção,
        +0x50 zoom, +0x100 taxa da suavização final, [0] = alvo
    alvo (+0x2b0)->(+0xf0) = veículo; veículo +0xaa0 = origem do modelo;
        veículo +0x9d4 = corpo físico
    corpo físico: +0x04 massa (t), +0x70 posição do CoM, +0x90 velocidade,
        +0xb0/+0xc0/+0xd0 eixos (direita/cima/frente), +0xe0 velocidade (m/s),
        +0x418 velocidade pra frente, +0x4e4 tempo sem roda no chão,
        +0x8a8 rodas no chão, +0x2ac -> parâmetros do motor,
        +0x2d0 -> câmbio (+0x04 ré, +0x08.. marchas, +0x20 final,
        +0x9c embreagem máx), estado do motor perto de +0x2ac+... (rpm)
    rodas: objetos com vtable 0x585cc0
"""

import argparse
import struct
import sys
import zipfile


def ler_ram(p2s):
    try:
        import zstandard
    except ImportError:
        sys.exit("falta o zstandard: python -m pip install zstandard")
    z = zipfile.ZipFile(p2s)
    for i in z.infolist():
        if i.filename != "eeMemory.bin":
            continue
        z.fp.seek(i.header_offset)
        h = z.fp.read(30)
        n, e = struct.unpack("<HH", h[26:30])
        z.fp.seek(i.header_offset + 30 + n + e)
        data = z.fp.read(i.compress_size)
        if i.compress_type == 93:
            data = zstandard.ZstdDecompressor().decompress(data, max_output_size=i.file_size)
        elif i.compress_type == 8:
            import zlib
            data = zlib.decompress(data, -15)
        return data
    sys.exit("eeMemory.bin não está no save state")


class Ram:
    def __init__(self, m):
        self.m = m

    def u(self, a):
        return struct.unpack_from("<I", self.m, a & 0x1FFFFFF)[0]

    def f(self, a):
        return struct.unpack_from("<f", self.m, a & 0x1FFFFFF)[0]

    def v(self, a, n=3):
        return tuple(round(self.f(a + 4 * i), 4) for i in range(n))

    def achar(self, word):
        b = struct.pack("<I", word)
        out, i = [], self.m.find(b)
        while i != -1:
            out.append(i)
            i = self.m.find(b, i + 1)
        return out


def dist(a, b):
    return sum((a[i] - b[i]) ** 2 for i in range(3)) ** 0.5


def estado(r, veh):
    """estado do carro do jogador em coordenadas do JOGO (mundo e frame do
    modelo), pro remake se colocar no mesmo lugar (tests/teste_derrapagem.gd).
    Rodas na ordem do jogo: FL, RL, FR, RR (corpo+0x254+4i)."""
    ph = r.u(veh + 0x9D4)
    v4 = lambda a: list(r.v(a, 3))
    e = {
        "origem": v4(veh + 0xAA0), "com": v4(ph + 0x70),
        "direita": v4(ph + 0xB0), "cima": v4(ph + 0xC0), "frente": v4(ph + 0xD0),
        "vel": v4(ph + 0x90), "w": v4(ph + 0xA0), "massa": 1.0 / r.f(ph + 0x130),
        # comandos (cru, suavizado): direção, acelerador, freio de mão, freio
        "direcao": [r.f(ph + 0x36C), r.f(ph + 0x370)], "acelerador": [r.f(ph + 0x37C), r.f(ph + 0x380)],
        "mao": [r.f(ph + 0x384), r.f(ph + 0x388)], "freio": [r.f(ph + 0x38C), r.f(ph + 0x390)],
        "rpm": r.f(ph + 0x2C0), "torque": r.f(ph + 0x2B4), "limitador": r.f(ph + 0x2C4),
        "marcha": r.u(ph + 0x2F0), "marcha_alvo": r.u(ph + 0x2F4), "embreagem": r.f(ph + 0x2EC),
        "estado_emb": r.u(ph + 0x314), "troca_t": r.f(ph + 0x2FC), "troca": r.u(ph + 0x318),
        "emb_sinal": r.f(ph + 0x320), "derrapagem": r.f(ph + 0x6C0), "ar": r.f(ph + 0x4E4),
        "esterco_vis": r.f(ph + 0x3C0), "stf": r.f(ph + 0x474),
        "rodas": [],
    }
    for i in range(4):
        w = r.u(ph + 0x254 + 4 * i)
        e["rodas"].append({
            "ponto": v4(w + 0x10), "raio": r.f(w + 0x30), "giro": r.f(w + 0x48),
            "curso": r.f(w + 0xE8), "curso_v": r.f(w + 0xF4), "contato": v4(w + 0x130),
            "patinada": r.f(ph + 0x610 + 4 * i), "medida": r.f(ph + 0x600 + 4 * i),
            "abs": r.u(ph + 0x620 + 4 * i), "grip": r.f(ph + 0x670 + 4 * i),
            # força da roda no passo (kN): x = pro lado direito do carro, z = pra frente
            "forca": v4(ph + 0x5C0 + 16 * i), "pedida": v4(ph + 0x680 + 16 * i),
        })
    return e


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("p2s")
    ap.add_argument("--dump", help="salva a RAM (32 MB) nesse arquivo")
    ap.add_argument("--json", help="salva o estado do carro (coordenadas do jogo) nesse arquivo")
    a = ap.parse_args()
    m = ler_ram(a.p2s)
    if a.dump:
        open(a.dump, "wb").write(m)
        print(f"[+] RAM salva em {a.dump}")
    r = Ram(m)

    # câmeras de órbita: a ativa é a que está perto do alvo
    cams = [x - 0x68 for x in r.achar(0x5B3F30)]
    best = None
    for c in cams:
        t = r.u(c)
        if not 0x100000 <= t < 0x2000000:
            continue
        try:
            veh = r.u(r.u(t + 0x2B0) + 0xF0)
            alvo = r.v(veh + 0xAA0)
        except struct.error:
            continue
        d = dist(r.v(c + 0x10), alvo)
        if best is None or d < best[0]:
            best = (d, c, t, veh)
    if not best:
        sys.exit("não achei a câmera do jogador")
    _, cam, tgt, veh = best
    ph = r.u(veh + 0x9D4)
    print(f"câmera {cam:#x}  alvo {tgt:#x}  veículo {veh:#x}  corpo {ph:#x}")
    if a.json:
        import json
        json.dump(estado(r, veh), open(a.json, "w"), indent=1)
        print(f"[+] estado salvo em {a.json}")

    pos = r.v(ph + 0x70)
    origem = r.v(veh + 0xAA0)
    up, fwd = r.v(ph + 0xC0), r.v(ph + 0xD0)
    dlt = [origem[i] - pos[i] for i in range(3)]
    com_y = -sum(dlt[i] * up[i] for i in range(3))
    com_z = -sum(dlt[i] * fwd[i] for i in range(3))
    print("\n== corpo")
    print(f"massa {r.f(ph + 4):.4f} t   CoM no modelo ~ (0, {com_y:.3f}, {com_z:.3f})")
    print(f"posição (CoM) {pos}   origem do modelo {origem}")
    print(f"velocidade {r.v(ph + 0x90)}  |v| {r.f(ph + 0xE0):.3f} m/s = {r.f(ph + 0xE0) * 3.6:.1f} km/h")
    print(f"pra frente {r.f(ph + 0x418):.3f} m/s   sem chão há {r.f(ph + 0x4E4):.3f} s   rodas no chão {r.u(ph + 0x8A8)}")
    print(f"frente {fwd}  cima {up}")

    g = r.u(ph + 0x2D0)
    print("\n== câmbio")
    print(f"ré {r.f(g + 4):.3f}  marchas {[round(r.f(g + 8 + 4 * i), 4) for i in range(5)]}  final {r.f(g + 0x20):.4f}")
    print(f"embreagem máx {r.f(g + 0x9C):.4f} kN·m   troca sobe {r.f(g + 0x60):.0f} rpm")

    e = r.u(ph + 0x2AC)
    print("\n== motor (parâmetros)")
    print(f"rpm máx curva {r.f(e + 0xC):.0f}  marcha lenta {r.f(e + 0x10):.0f}  torque {r.f(e + 0x18):.4f}")
    # estado do motor: procura o rpm logo depois dos parâmetros
    for off in range(0x0, 0x400, 4):
        x = e - 0x700 + off
        rpm = r.f(x + 0x14)
        lim = r.f(x + 0x18)
        if 500 < rpm < 12000 and abs(lim - 1.0) < 1e-3 and 0 <= r.f(x + 4) <= 1.0:
            print(f"estado: acelerador {r.f(x + 4):.2f}  torque {r.f(x + 8):.4f}  rpm {rpm:.1f}  limitador {lim:.2f}")
            break

    print("\n== rodas (curso x: + = comprimida)")
    for w in r.achar(0x585CC0):
        base = w - 0x10
        if r.u(base + 0x2C) != ph + 0x70:       # roda aponta pro corpo (+0x70)
            continue
        att = r.v(base + 0x3C)
        # curso: [x, mínimo, máximo, velocidade, velocidade máx] no fim do objeto
        for k in range(40, 90):
            a = base + 4 * k
            if abs(r.f(a + 4) + 0.2) < 1e-4 and abs(r.f(a + 16) - 10.0) < 1e-4:
                print(f"  ponto {att}  x {r.f(a):.4f} (máx {r.f(a + 8):.2f})  v {r.f(a + 12):.3f}  ω {r.f(base + 0x74):.2f} rad/s")
                break

    print("\n== câmera")
    print(f"posição {r.v(cam + 0x10)}  direção {r.v(cam + 0x40)}  zoom {r.f(cam + 0x50):.4f}")
    print(f"câmera - origem {tuple(round(r.f(cam + 0x10 + 4 * i) - origem[i], 3) for i in range(3))}")
    print(f"suavização final {r.f(cam + 0x100):.2f}/s")


if __name__ == "__main__":
    main()
