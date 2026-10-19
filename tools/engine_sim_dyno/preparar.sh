#!/bin/bash
# Dinamômetro sem tela do engine-sim (Linux / nuvem). Clona o engine-sim no
# commit testado, aplica os patches de compilação (MSVC -> clang) e compila.
#   bash tools/engine_sim_dyno/preparar.sh
#   tools/engine_sim_dyno/build/dyno som/engine_sim/06_phantom_subaru_ej25.mr
#   tools/engine_sim_dyno/build/dyno arquivo.mr lenta      (só a marcha lenta)
#   python tools/gravar_loops.py                           (loops de som, usa o build/gravar)
set -e
D=$(cd "$(dirname "$0")" && pwd)
cd "$D"
if [ ! -d es ]; then
  git clone https://github.com/ange-yaghi/engine-sim.git es
  git -C es checkout 85f7c3b959a908ed5232ede4f1a4ac7eafe6b630
  git -C es submodule update --init --depth 1 dependencies/submodules/piranha \
    dependencies/submodules/simple-2d-constraint-solver dependencies/submodules/csv-io
  git -C es apply "$D/engine_sim.patch"
  git -C es/dependencies/submodules/simple-2d-constraint-solver apply "$D/scs.patch"
fi
# os .wav de resposta ao impulso do escape (new/mild_exhaust.wav...) não estão
# no git do engine-sim, só no zip do release
if [ ! -f es/es/sound-library/new/mild_exhaust.wav ]; then
  curl -sSL -o /tmp/es011.zip \
    https://github.com/ange-yaghi/engine-sim/releases/download/v0.1.11a/engine-sim-build_0_1_11a.zip
  python3 -I - <<'PY'
import os, zipfile
z = zipfile.ZipFile("/tmp/es011.zip")
pre = "engine-sim-build_0_1_11a/es/sound-library/"
for n in z.namelist():
    if n.startswith(pre) and n.endswith(".wav"):
        out = "es/es/sound-library/" + n[len(pre):]
        os.makedirs(os.path.dirname(out), exist_ok=True)
        open(out, "wb").write(z.read(n))
PY
fi
if ! command -v flex >/dev/null || [ ! -d /usr/src/googletest ]; then
  apt-get update && apt-get install -y flex bison libboost-filesystem-dev googletest clang cmake
fi
CC=clang CXX=clang++ cmake -S . -B build -DFETCHCONTENT_SOURCE_DIR_GOOGLETEST=/usr/src/googletest -Wno-dev
cmake --build build -j4 --target dyno gravar
