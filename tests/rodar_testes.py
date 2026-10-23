"""
rodar_testes.py
================
Roda o tests/flattest.tscn no Godot sem tela e resume o resultado.

Precisa do Godot de console no PATH ou na variável GODOT, ex. (cmd):
    set GODOT=C:\\Godot\\Godot_v4.7-stable_win64_console.exe

Uso (na pasta do projeto):
    python tests/rodar_testes.py                 # aceleração dos 3 carros + referências
    python tests/rodar_testes.py accel --veh 2   # um roteiro, um carro
    python tests/rodar_testes.py hs --veh 0 --st 0.6
    python tests/rodar_testes.py accel --veh 1 --tune "{\\"engine\\":0.81}"
    python tests/rodar_testes.py accel --veh 0 --bruto   # mostra as linhas do log

Referências (o que o jogo de verdade faz):
    Renegade, save state PCSX2 a 151 km/h em 4ª sem acelerar: rpm 6582,
        torque do motor -0.094 kN·m, curso frente ~0.22-0.25 / trás ~0.11-0.13
    Sphinx do speedrun (vídeo NTSC = física a 60 Hz; relógio da corrida e HUD
        em mph lidos quadro a quadro, tempo desde que o carro anda): 8 mph @
        0.52 s, 14 @ 1.0, 19 @ 1.48, 28 @ 1.98, 36 @ 2.48, 39 @ 2.97, 48 @
        3.45, 56 @ 3.95, 58 @ 4.45, 65 @ 4.93, 70 @ 5.43, 75 @ 5.92. O carro
        do accel veh=2 roda a 60 Hz por isso (--hz muda).
    Renegade PAL (gravação do Matheus no RX01, física a 50 Hz): tests/teste_largada.gd.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(AQUI)
LINHA = re.compile(r"t=\s*([\d.]+) v=\s*(-?[\d.]+)km/h g=(\S+) rpm=\s*(\d+) cl=([\d.]+) thr=([\d.]+)"
                   r".*?pitch=\s*(-?[\d.]+).*?x=\[([^\]]*)\] grd=(\d) sl=(-?[\d.]+)")
# speedrun do Sphinx (NTSC): segundos desde que o carro anda -> mph no HUD
REF_SPHINX = [(0.52, 8), (1.0, 14), (1.48, 19), (1.98, 28), (2.48, 36), (2.97, 39), (3.45, 48),
              (3.95, 56), (4.45, 58), (4.93, 65), (5.43, 70), (5.92, 75)]
HZ_SPHINX = "60"                         # o vídeo é da versão NTSC


def rodar(sc, veh, extra):
    godot = os.environ.get("GODOT", "godot")
    if not shutil.which(godot) and not os.path.isfile(godot):
        sys.exit("Não achei o Godot (%s). No cmd, antes de rodar:\n"
                 "  set GODOT=C:\\caminho\\Godot_v4.x-stable_win64_console.exe" % godot)
    env = dict(os.environ, SC=sc, VEH=str(veh), LDT=extra.get("ldt", "0.05"))
    for k in ("tune", "mu", "st", "amort", "hz"):
        if extra.get(k):
            env[k.upper()] = extra[k]
    cmd = [godot, "--headless", "--path", PROJ, "res://tests/flattest.tscn"]
    p = subprocess.run(cmd, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return p.stdout + p.stderr


def analisar(log):
    rows = []
    for l in log.splitlines():
        m = LINHA.search(l)
        if m:
            rows.append(dict(t=float(m[1]) - 1.0, kmh=float(m[2]), g=m[3], rpm=int(m[4]),
                             x=[float(v.strip().strip('"')) for v in m[8].split(",") if v.strip()]))
    return rows


def resumo_accel(rows):
    def ate(kmh):
        for r in rows:
            if r["kmh"] >= kmh:
                return round(r["t"], 2)
        return "-"

    mph = lambda v: v * 1.609344
    trocas, g0 = [], None
    for r in rows:
        if r["g"] not in ("-", g0) and g0 is not None:
            trocas.append(f'{g0}->{r["g"]} @ {r["t"]:.2f}s {r["kmh"] / 1.609344:.0f} mph')
        if r["g"] != "-":
            g0 = r["g"]
    vmax = max((r["kmh"] for r in rows if r["t"] < 24), default=0)
    out = [f"0-63 km/h {ate(63)}s | 0-99 {ate(99)}s | 0-160 {ate(160)}s | máx {vmax:.0f} km/h",
           f"mph: 20 {ate(mph(20))}s, 38 {ate(mph(38))}s, 57 {ate(mph(57))}s, 75 {ate(mph(75))}s",
           "trocas: " + ", ".join(trocas[:4])]
    return out


def contra_video(rows, ref):
    """velocidade do remake nos instantes do vídeo, contando desde que o carro
    anda (>= 1 mph depois de acelerar)"""
    anda = None
    for a, b in zip(rows, rows[1:]):
        va, vb = a["kmh"] / 1.609344, b["kmh"] / 1.609344
        if b["t"] > 0.0 and va < 1.0 <= vb:
            anda = a["t"] + (b["t"] - a["t"]) * (1.0 - va) / (vb - va)
            break
    if anda is None:
        return ["(não andou)"]
    pares, pior = [], 0.0
    for t, mph in ref:
        tt = t + anda - 0.12              # no vídeo o 1º mph aparece em 0.12 s
        v = None
        for a, b in zip(rows, rows[1:]):
            if a["t"] <= tt <= b["t"]:
                f = (tt - a["t"]) / (b["t"] - a["t"]) if b["t"] > a["t"] else 0.0
                v = (a["kmh"] + (b["kmh"] - a["kmh"]) * f) / 1.609344
        if v is None:
            continue
        pior = max(pior, abs(v - mph))
        pares.append(f"{t:.2f}s {mph}/{v:.1f}")
    return ["vídeo/remake (mph): " + "  ".join(pares), f"maior diferença {pior:.1f} mph"]


def resumo_coast(rows):
    """acelera até 13 s e solta: velocidade na hora e quanto tempo leva pra
    perder metade"""
    solta = next((r for r in rows if r["t"] >= 13.0), None)
    if not solta:
        return ["(log curto)"]
    meio = next((r for r in rows if r["t"] > solta["t"] and r["kmh"] <= solta["kmh"] / 2), None)
    out = [f'solta o acelerador a {solta["kmh"]:.0f} km/h']
    out.append(f'metade ({solta["kmh"] / 2:.0f} km/h) em {meio["t"] - solta["t"]:.1f} s' if meio
               else f'{rows[-1]["t"] - solta["t"]:.1f} s depois: {rows[-1]["kmh"]:.0f} km/h')
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sc", nargs="?", default="")
    ap.add_argument("--veh", type=int)
    ap.add_argument("--tune")
    ap.add_argument("--mu")
    ap.add_argument("--st")
    ap.add_argument("--amort", help="Damping do chão (fora da pista do RX01: 0.2, com --mu 0.69)")
    ap.add_argument("--hz", help="passos de física por segundo (projeto: 50 = PAL; 60 = NTSC)")
    ap.add_argument("--bruto", action="store_true")
    a = ap.parse_args()
    extra = {"tune": a.tune, "mu": a.mu, "st": a.st, "amort": a.amort, "hz": a.hz}
    casos = [(a.sc, a.veh if a.veh is not None else 0)] if a.sc else [("accel", 0), ("accel", 1), ("accel", 2)]
    for sc, veh in casos:
        ex = dict(extra)
        if veh == 2 and not a.hz:
            ex["hz"] = HZ_SPHINX              # speedrun é NTSC
        log = rodar(sc, veh, ex)
        cab = [l for l in log.splitlines() if l.startswith(("veiculo=", "gears="))]
        print(f"\n=== {sc} veh={veh} ({ex.get('hz') or '50'} Hz)")
        for l in cab:
            print("  " + l[:150])
        if "SCRIPT ERROR" in log or "Parse Error" in log:
            print("  [!] erro de script:")
            print("\n".join("    " + l for l in log.splitlines() if "ERROR" in l or "at:" in l))
            continue
        rows = analisar(log)
        if a.bruto:
            print("\n".join(l for l in log.splitlines() if l.startswith("t=")))
        if sc == "accel":
            for l in resumo_accel(rows):
                print("  " + l)
            if veh == 2:
                for l in contra_video(rows, REF_SPHINX):
                    print("  " + l)
        elif sc == "coast" and rows:
            for l in resumo_coast(rows):
                print("  " + l)
        elif rows:
            r = rows[-1]
            print(f'  fim: t {r["t"]:.1f}s {r["kmh"]:.0f} km/h marcha {r["g"]} rpm {r["rpm"]} x {r["x"]}')


if __name__ == "__main__":
    main()
