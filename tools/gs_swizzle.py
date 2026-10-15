"""
gs_swizzle.py
===============
Emula a memória de vídeo do GS do PS2 (só o endereçamento), pra
"desembaralhar" texturas.

No PS2 a textura é enviada pra VRAM num formato (ex: PSMCT16) e lida
em outro (ex: PSMT4). Cada formato espalha os pixels pela memória de
um jeito diferente (páginas, blocos, colunas). Então pra ver a imagem
certa fazemos o mesmo que o console: escreve na memória como foi
enviado e lê de volta como a GPU leria.

Tabelas baseadas na documentação do GS e no GSdx (PCSX2).
"""

BLOCK32 = [[0, 1, 4, 5, 16, 17, 20, 21],
           [2, 3, 6, 7, 18, 19, 22, 23],
           [8, 9, 12, 13, 24, 25, 28, 29],
           [10, 11, 14, 15, 26, 27, 30, 31]]
BLOCK16 = [[0, 2, 8, 10], [1, 3, 9, 11], [4, 6, 12, 14], [5, 7, 13, 15],
           [16, 18, 24, 26], [17, 19, 25, 27], [20, 22, 28, 30], [21, 23, 29, 31]]
BLOCK8 = BLOCK32
BLOCK4 = BLOCK16

COLWORD32 = [0, 1, 4, 5, 8, 9, 12, 13, 2, 3, 6, 7, 10, 11, 14, 15]
COLWORD16 = [0, 1, 4, 5, 8, 9, 12, 13, 0, 1, 4, 5, 8, 9, 12, 13,
             2, 3, 6, 7, 10, 11, 14, 15, 2, 3, 6, 7, 10, 11, 14, 15]
COLHALF16 = [0] * 8 + [1] * 8 + [0] * 8 + [1] * 8

_a = [0, 1, 4, 5, 8, 9, 12, 13]
_b = [2, 3, 6, 7, 10, 11, 14, 15]
_c = [8, 9, 12, 13, 0, 1, 4, 5]
_d = [10, 11, 14, 15, 2, 3, 6, 7]
COLWORD8 = [_a * 2 + _b * 2 + _c * 2 + _d * 2,
            _c * 2 + _d * 2 + _a * 2 + _b * 2]
COLBYTE8 = ([0] * 8 + [2] * 8) * 2 + ([1] * 8 + [3] * 8) * 2
COLWORD4 = [_a * 4 + _b * 4 + _c * 4 + _d * 4,
            _c * 4 + _d * 4 + _a * 4 + _b * 4]
COLBYTE4 = ([0] * 8 + [2] * 8 + [4] * 8 + [6] * 8) * 2 + \
           ([1] * 8 + [3] * 8 + [5] * 8 + [7] * 8) * 2


# ---- endereços (em bytes; PSMT4 em nibbles) ----
def addr32(bp, bw, x, y):
    page = (x >> 6) + (y >> 5) * bw
    block = BLOCK32[(y >> 3) & 3][(x >> 3) & 7]
    col = (y >> 1) & 3
    word = COLWORD32[((y & 1) << 3) + (x & 7)]
    return ((bp + page * 32 + block) << 8) + col * 64 + word * 4


def addr16(bp, bw, x, y):
    page = (x >> 6) + (y >> 6) * bw
    block = BLOCK16[(y >> 3) & 7][(x >> 4) & 3]
    col = (y >> 1) & 3
    i = ((y & 1) << 4) + (x & 15)
    return ((bp + page * 32 + block) << 8) + col * 64 + COLWORD16[i] * 4 + COLHALF16[i] * 2


def addr8(bp, bw, x, y):
    page = (x >> 7) + (y >> 6) * (bw >> 1)
    block = BLOCK8[(y >> 4) & 3][(x >> 4) & 7]
    col = (y >> 2) & 3
    i = ((y & 3) << 4) + (x & 15)
    return ((bp + page * 32 + block) << 8) + col * 64 + COLWORD8[col & 1][i] * 4 + COLBYTE8[i]


def naddr4(bp, bw, x, y):
    page = (x >> 7) + (y >> 7) * (bw >> 1)
    block = BLOCK4[(y >> 4) & 7][(x >> 5) & 3]
    col = (y >> 2) & 3
    i = ((y & 3) << 5) + (x & 31)
    return ((((bp + page * 32 + block) << 8) + col * 64 + COLWORD4[col & 1][i] * 4) << 1) + COLBYTE4[i]


class GSMem:
    def __init__(self):
        self.m = bytearray(4 * 1024 * 1024)

    # escrita (como o upload foi feito)
    def write(self, psm, bp, bw, w, h, data, x0=0, y0=0):
        m, i = self.m, 0
        if psm == 0x00:      # CT32
            for y in range(y0, y0 + h):
                for x in range(x0, x0 + w):
                    a = addr32(bp, bw, x, y)
                    m[a:a + 4] = data[i:i + 4]
                    i += 4
        elif psm == 0x02:    # CT16
            for y in range(y0, y0 + h):
                for x in range(x0, x0 + w):
                    a = addr16(bp, bw, x, y)
                    m[a:a + 2] = data[i:i + 2]
                    i += 2
        elif psm == 0x13:    # T8
            for y in range(y0, y0 + h):
                for x in range(x0, x0 + w):
                    m[addr8(bp, bw, x, y)] = data[i]
                    i += 1
        elif psm == 0x14:    # T4
            for y in range(y0, y0 + h):
                for x in range(x0, x0 + w):
                    v = data[i >> 1] >> (4 * (i & 1)) & 0xF
                    n = naddr4(bp, bw, x, y)
                    b = m[n >> 1]
                    m[n >> 1] = (b & 0x0F) | (v << 4) if n & 1 else (b & 0xF0) | v
                    i += 1
        else:
            raise ValueError(f"PSM 0x{psm:x} não suportado")

    # leitura (como a GPU lê a textura) -> lista de índices / bytes
    def read_indices(self, psm, bp, bw, w, h):
        m, out = self.m, bytearray(w * h)
        k = 0
        for y in range(h):
            for x in range(w):
                if psm == 0x14:
                    n = naddr4(bp, bw, x, y)
                    out[k] = m[n >> 1] >> 4 if n & 1 else m[n >> 1] & 0xF
                else:
                    out[k] = m[addr8(bp, bw, x, y)]
                k += 1
        return bytes(out)

    def read32(self, bp, bw, w, h):
        out = bytearray()
        for y in range(h):
            for x in range(w):
                a = addr32(bp, bw, x, y)
                out += self.m[a:a + 4]
        return bytes(out)
