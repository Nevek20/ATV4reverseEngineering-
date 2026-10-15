#!/bin/bash
# Instala o Ghidra 12.1.3 + ghidra-emotionengine-reloaded (R5900) e importa o
# exe do jogo num projeto, com a análise completa (~7 min). Feito pra nuvem
# (Linux, Java 21 já instalado). No Windows é a mesma coisa pelo instalador.
#
# Uso: bash re/instalar_ghidra.sh [caminho do SCES_546.88]
# Depois:
#   ~/.local/ghidra_12.1.3_PUBLIC/support/analyzeHeadless ~/ghidra_proj atv4 \
#     -process -noanalysis -readOnly -scriptPath re/ghidra_scripts \
#     -postScript DecompRefs.java saida.c lista.txt
set -euo pipefail

EXE="${1:-$HOME/atv4-dados/exe/SCES_546.88}"
[ -f "$EXE" ] || EXE=/home/user/atv4-dados/exe/SCES_546.88
GH="$HOME/.local/ghidra_12.1.3_PUBLIC"
# os nomes dos zips têm a data do build (achada testando a URL)
GZIP="https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.3_build/ghidra_12.1.3_PUBLIC_20260817.zip"
EZIP="https://github.com/chaoticgd/ghidra-emotionengine-reloaded/releases/download/v2.1.38/ghidra_12.1.3_PUBLIC_20261004_ghidra-emotionengine-reloaded.zip"

mkdir -p "$HOME/.local"
if [ ! -x "$GH/support/analyzeHeadless" ]; then
  tmp=$(mktemp -d)
  curl -sSL -o "$tmp/ghidra.zip" "$GZIP"
  unzip -q "$tmp/ghidra.zip" -d "$HOME/.local/"
  rm -rf "$tmp"
fi
if [ ! -d "$GH/Ghidra/Extensions/ghidra-emotionengine-reloaded" ]; then
  tmp=$(mktemp -d)
  curl -sSL -o "$tmp/ee.zip" "$EZIP"
  unzip -q "$tmp/ee.zip" -d "$GH/Ghidra/Extensions/"
  rm -rf "$tmp"
fi
echo "Ghidra em $GH"

if [ ! -d "$HOME/ghidra_proj/atv4.rep" ]; then
  [ -f "$EXE" ] || { echo "sem o exe ($EXE), pulei a importação"; exit 0; }
  mkdir -p "$HOME/ghidra_proj"
  MAXMEM=8G "$GH/support/analyzeHeadless" "$HOME/ghidra_proj" atv4 -import "$EXE" \
    -max-cpu 3 > "$HOME/ghidra_proj/import.log" 2>&1
  grep -E "REPORT|Total Time" "$HOME/ghidra_proj/import.log" | tail -3
fi
echo "projeto em $HOME/ghidra_proj (atv4)"
