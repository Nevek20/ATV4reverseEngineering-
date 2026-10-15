# Engenharia reversa

- `exe_util.py`: acha strings, quem chama uma função, imediatos, tabelas.
- `ghidra_scripts/DecompRefs.java`: decompila funções por endereço ou string.
  `DumpAccess.java` (offsets lidos/escritos por função) e `ScoreFuncs.java`
  (ranqueia funções pelos parâmetros de física que leem).
- `map_params.py` + `decomp/param_map.txt`: atributo do XML → offset no struct.
- `decomp/`: dumps já decompilados (física, câmera, peças). Código do jogo:
  fica só no seu PC, o .gitignore deixa fora do GitHub.

Projeto do Ghidra: importar o SCES_546.88 com a extensão
ghidra-emotionengine-reloaded (processador R5900) e rodar a análise uma vez:
```
analyzeHeadless C:\ghidra_proj atv4 -import SCES_546.88
```
Depois usar `-process -noanalysis -readOnly` pra só ler.
