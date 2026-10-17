"""
pecas_da_ram.py
================
Tira de um save state do PCSX2 (parado, de preferência na largada) as
matrizes reais das peças do buggy (balanças, freios, amortecedores, rodas,
estepe) e o curso de cada roda, no formato de tests/ref_ram_pecas.json.

Acha os objetos cCompPlace_* pela vtable (0x5801e0..0x580898) e a classe
pelo método +0x1c lido no exe. Veículo em 0xc7eb00 (igual nos 6 saves).

Uso: python re/pecas_da_ram.py <SCES_546.88> <save.p2s> [saida.json]
"""
import json
import os
import struct
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tools"))
from ler_savestate import ler_ram  # noqa: E402

METH = {0x1fc5f0: 'Frame_FL', 0x1fc550: 'Frame_FR', 0x1fc730: 'Frame_RL', 0x1fc690: 'Frame_RR',
        0x1fc9f0: 'Brake_FL', 0x1fca78: 'Brake_FR', 0x1fcb00: 'Brake_RL', 0x1fcb88: 'Brake_RR',
        0x1fcd20: 'ShockF_FL', 0x1fcda8: 'ShockF_FR', 0x1fce30: 'Piston_RL', 0x1fced0: 'Chamber_RL',
        0x1fcf70: 'Piston_RR', 0x1fd010: 'Chamber_RR',
        0x1fd3e0: 'Wheel_FL', 0x1fd468: 'Wheel_FR', 0x1fd4f0: 'Wheel_RL', 0x1fd578: 'Wheel_RR',
        # RallyCompMap (FrontLeftWheel...) e estepe
        0x1fd1c0: 'Wheel_FL', 0x1fd248: 'Wheel_FR', 0x1fd2d0: 'Wheel_RL', 0x1fd358: 'Wheel_RR',
        0x1fd730: 'Spare'}
VEH = 0xc7eb00


def main():
    exe = open(sys.argv[1], "rb").read()
    ram = ler_ram(sys.argv[2])

    def ew(va):
        return struct.unpack_from("<I", exe, va - 0x100000 + 0x80)[0]

    def rd(a, f):
        return struct.unpack_from("<" + f, ram, a)

    corpo = rd(VEH + 0x9d4, "I")[0] & 0x1ffffff
    rodas = [rd(corpo + 0x254 + 4 * i, "I")[0] & 0x1ffffff for i in range(4)]
    x = [rd(w + 0xe8, "f")[0] + rd(VEH + 0xab0 + 4 * i, "f")[0] for i, w in enumerate(rodas)]
    curso = dict(zip(["FL", "RL", "FR", "RR"], [round(v, 5) for v in x]))
    pecas = {}
    for o in range(0x1000000, 0x1400000, 4):
        v = rd(o, "I")[0]
        if 0x5801e0 <= v <= 0x580898 and (v - 0x5801e0) % 0x28 == 0:
            nm = METH.get(ew(v + 0x1c))
            if nm and nm not in pecas:
                m = rd(o - 0x40, "16f")
                pecas[nm] = {"linhas": [[round(m[r * 4 + c], 5) for c in range(3)] for r in range(4)]}
    print("curso", curso)
    print("peças", sorted(pecas))
    out = {"curso": curso, "pecas": pecas}
    if len(sys.argv) > 3:
        json.dump(out, open(sys.argv[3], "w"), indent=1)


if __name__ == "__main__":
    main()
