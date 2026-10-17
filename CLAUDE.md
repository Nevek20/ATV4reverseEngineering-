# ATV4 Reborn

Remake em Godot 4 do **ATV Offroad Fury 4** (PS2, PAL, SCES_546.88), com o
objetivo de ficar **100% fiel ao jogo**. Os dados (física, câmera, peças,
pintura) vêm dos XMLs do próprio jogo e o comportamento vem do executável
desmontado no Ghidra. Nada de "parece certo": cada número tem que ter fonte
(XML, função do exe, save state ou vídeo).

## Como trabalhar comigo (Matheus)

- Português do Brasil, informal. Textos curtos. **Nunca usar travessão (—)**.
- Atuar como dev sênior: propor direção, revisar, apontar problema. Não só
  executar.
- Ciclos curtos e testados: muda, roda o teste, mostra o número, entrega.
- Toda entrega vem com:
  1. o que mudou (curto),
  2. o **commit como comando de cmd do Windows** pronto pra colar
     (`chcp 65001 >nul` + `git add ...` + `git commit -m "..." -m "..."`),
     **sem linha de co-autoria do Claude**,
  3. como rodar (abrir no Godot e F5, ou o comando).
- Antes de mudar física, rodar `python tests/rodar_testes.py` e comparar
  com as referências (ver abaixo). Se um número piorar, explicar por quê.

## Estrutura

```
car.gd               física do carro (portada do exe), visual das rodas
game_camera.gd       câmera de corrida do jogo (componentes do exe, 1/60 s)
camera_jitter.gd     tremida da câmera (Perlin por velocidade, só na terra)
suspension_visual.gd balanças, amortecedores e freios do jogo se mexendo
vehicle_data.gd      leitor dos XMLs (base + veículo) e peças de fábrica
main.gd              cena: terreno, carro, câmera, HUD, menu de carros (Tab, V)
terrain.gd           relevo e material do chão da pista RX01 (do stream do jogo)
data/                XMLs do jogo (física buggy_NN.xml, pontos, câmeras, peças)
assets/              modelos do pingu2obj: renegade, sphinx, buggy_NN, rodas (fora do git)
tests/               teste de física sem tela + rodar_testes.py
tools/               scripts Python de extração (pingu2obj, pintura, savestate)
re/                  engenharia reversa: scripts do Ghidra, exe_util, dumps
docs/                engenharia_reversa.md (mapa do exe), assets.md
```

## Comandos

```
:: testes de física (precisa do Godot de console)
set GODOT=C:\caminho\Godot_v4.x-stable_win64_console.exe
python tests/rodar_testes.py                  :: aceleração dos 3 carros
python tests/rodar_testes.py hs --veh 0       :: curva em alta no Renegade
python tests/rodar_testes.py accel --veh 1 --tune "{\"engine\":0.81}"
python tests/rodar_testes.py accel --veh 0 --mu 0.69 --amort 0.2   :: fora da pista

:: save state do PCSX2 -> valores reais do jogo
python tools/ler_savestate.py arquivo.p2s

:: print do carro parado (na nuvem: xvfb-run -a ... --rendering-driver opengl3)
%GODOT% --path . -s res://tests/print_tela.gd -- print.png lado

:: peças da suspensão x RAM do jogo (100 matrizes, 6 carros), tremida e chão
%GODOT% --headless --path . -s res://tests/teste_pecas.gd
%GODOT% --headless --path . -s res://tests/teste_tremida.gd
%GODOT% --headless --path . -s res://tests/teste_chao.gd
%GODOT% --headless --path . -s res://tests/teste_mao.gd     :: espelho (lado das peças, esterço)
%GODOT% --headless --path . -s res://tests/teste_tremida_camera.gd
%GODOT% --headless --path . -s res://tests/teste_freio.gd   :: patinada, ABS e trava
%GODOT% --headless --path . -s res://tests/teste_roda.gd    :: giro das rodas por torque (no ar, preso)
%GODOT% --headless --path . -s res://tests/teste_camera_passo.gd  :: câmera de órbita sem vai e volta
%GODOT% --headless --path . -s res://tests/medir_tremor.gd -- 60 tremor.csv  :: distância câmera-carro por quadro

:: terreno do RX01 (alturas + material) a partir do stream do jogo
python tools/extrair_material.py <dados>/stream/RX01.000 assets/terrain --materiais <dados>/unpacked/xml/12280

:: checar um script sem abrir o editor
%GODOT% --headless --path . --check-only --script res://car.gd

:: assets dos 12 buggies (modelo, peças, freios, rodas, pintura)
python tools/gerar_buggies.py <unpacked> <texturas>

:: caçar coisas no exe
python re/exe_util.py SCES_546.88 str NOME | jal 0xENDERECO | words 0xEND 32
```

Na nuvem (Claude Code web) o `.claude/hooks/session-start.sh` instala o
Godot 4.7.1 de Linux, Pillow e zstandard e já deixa `$GODOT` pronto.
Os arquivos do jogo ficam no repo privado `Nevek20/atv4-dados` (exe,
stream, unpacked). As texturas não vão pra lá: saem do unpacked com
`python tools/gob_tex2png.py <dados>/unpacked/gob --out <dados>/texturas`
(uns 6 min).

Ghidra headless (Ghidra 12.1.3 + extensão ghidra-emotionengine-reloaded).
Na nuvem: `bash re/instalar_ghidra.sh` baixa os dois e importa o exe com a
análise (~7 min) em `~/ghidra_proj` (projeto `atv4`).

```
analyzeHeadless <proj_dir> atv4 -process -noanalysis -readOnly ^
  -scriptPath re/ghidra_scripts -postScript DecompRefs.java saida.c lista.txt
```
`lista.txt` = um endereço `0x...` ou uma string por linha; decompila as
funções que contêm o endereço ou referenciam a string.

Arquivos do jogo ficam fora do repo, na pasta de engenharia reversa do
Matheus: `C:\Users\Guida\Desktop\Estudo de programação\ATV 4 Engenharia reversa`
(`unpacked\` com other/raw/gob/xml, o exe, os scripts antigos).

## Referências pra conferir (o jogo de verdade)

- **Save state do Renegade** (151 km/h, 4ª, sem acelerar): massa 1.2 t,
  CoM (0, 0.639, -0.4), marchas 18.2/11.9/8.9/7.1/5.9, final 1.1636,
  embreagem máx 0.6127, rpm 6582, torque -0.094 kN·m, curso frente
  ~0.22-0.25 / trás ~0.11-0.13, câmera (longe) zoom 0.41, suavização 40/s.
- **Speedrun do Sphinx** (vídeo, HUD em mph): 20 mph em 1.45 s; trocas a
  38 mph (2.55 s), 57 mph (3.95 s), 75 mph (5.95 s). Bate com
  "Sphinx speedrun" (motor 0.81, BodyMass L2, Clutch L2, final 0.61).
- **Gravação PCSX2 do Renegade**: carro ocupa ~27% da largura (em 4:3) a
  122 km/h na câmera perto; bate com a câmera portada.

## Fatos que já custaram caro (não reabrir sem motivo)

- Arquivos de física = ordem da lista do jogo: 15145 é a base E o 1º buggy,
  15146 o 2º... Renegade = 15154 (BUGGY_10), Sphinx = 15148 (BUGGY_04).
  O 15150 é o Phantom (já usamos por engano).
- Peças de fábrica: `data/vehicles.xml` DefaultConfig + `data/upgrades.xml`
  (efeitos). Embreagem máx usa a soma das peças de MOTOR, não o Clutch_Level.
  Relação final usa a custom (GearRatioTuning FinalDrive), não o
  FinalDriveRatio do GearboxLevel 0/1.
- A câmera mira a ORIGEM DO MODELO (veículo +0xaa0), não o CoM.
- Zoom -> FOV: meia-altura do frustum = 0.375/zoom (tela 4:3), KEEP_HEIGHT.
- Blocos: nunca pela posição no unpacked. data/arquivos.tsv (índice do
  archive, re/indice_archive.py) dá caminho -> bloco. Corrida usa
  Models_4K; as peças do carro N vêm DEPOIS do BODY dele (pasta alfabética).
  SANDCAR 4K = 21059/21060; 21973/21974 é TYRE_GENERIC_RALLY 5K.
- Suspensão = cCompPlace_* do exe (docs/engenharia_reversa.md, Peças): eixo
  da balança = linha 2 da matriz do ponto A_FRAME_*, ângulo atan(x/r). Roda
  e freio não giram com a balança. tests/teste_pecas.gd confere com a RAM
  de 6 carros (save states em atv4-dados/savestates: Bulldog, Phantom,
  Storm, Inferno; Renegade e Sphinx são os a.p2s/b.p2s), inclusive a frente
  do Bulldog em x, a traseira do Phantom e o Storm em z, rally e estepe.
- Modelos: o pingu2obj vira os triângulos pelas normais do jogo e o Godot
  descarta a face de trás (`MODEL_CULL`). Total de materiais do .pingu em
  0xAC (0xBC conta menos).
- Carroceria usa a textura "white" = pintura gerada (tools/gerar_pintura.py).
- Rodas sem escala (tamanho = modelo). Frente: centro gira com a balança em
  x/z e y = WHEEL.y + curso; trás: arco inteiro. O pneu afunda uns cm parado
  no jogo também.
- Física roda a 120 Hz com interpolação ligada; câmera em passos de 1/60
  interpolando no frame do carro (senão aparece "fantasma"). O passo de
  física do jogo no PAL é 1/50 (a tremida das rodas sorteia a 50 Hz).
  Cada passo da câmera de órbita usa o carro NO TEMPO DELE (posição de agora
  menos velocidade x o que sobrou do acumulador). Sem isso, a 60 Hz saem
  quadros com 0 e 2 passos e o carro vai e volta na tela (14 cm a 60 km/h,
  42 cm a 180; tests/teste_camera_passo.gd).
- MÃO: o jogo é mão esquerda (esquerda do jogo = x < 0 no modelo), o Godot
  mão direita. Até out/2026 o remake saía todo ESPELHADO. Agora: carro =
  nó `espelho` (escala (-1,1,1)) com tudo do jogo em frame do jogo dentro
  (malha, suspensão, rodas, volante); a física usa car.corpo(p) e a
  esquerda do jogo é +X (w.left). Mundo = Terrain.do_jogo: remake
  (X, Y, Z) = (z - 1024, y, x) do jogo (transposição, mantém a diagonal do
  terreno). Ângulo de esterço no frame do jogo = -steer (car.gd a_jogo).
  Câmeras do XML: x negado no _parse. Nunca converter a mesma coisa duas
  vezes. tests/teste_chao.gd põe os 6 carros na pose da RAM e confere roda
  por roda (lado trocado = 2,4 m de erro); tests/teste_mao.gd confere
  carroceria, volante, olho, peças, espelho da roda e sinal do esterço.
- Terreno RX01: .bin no layout do jogo, transposto na carga (terrain.gd).
  Alturas e material saem do stream (tools/extrair_material.py), conferidos
  com a RAM (tests/teste_chao.gd). Diagonal da célula (i+1, j)-(i, j+1) = a
  do HeightMapShape3D. Material i = Material_(i+1) do data/materials_rx01.xml.
- Material do chão: só o atrito (pneu) e o Damping (arrasto do chão,
  0x20e5e8) mexem na física do buggy. Hardness, Sink e Bounciness o jogo
  carrega e não lê (varredura do exe, docs Terreno). Não "portar" eles.
- Giro da roda (0x2113e0): no chão ω = v_prevista·(1 + 0x610)/R, então o
  0x600 (ω·R/v − 1, que ABS/trava/embreagem leem) é a 0x610 do passo
  anterior. 0x3cc = rodas de TRÁS no chão (não "tração no chão"). O
  "torque" do freio ali não tem a massa (×1000 com inércia em kg·m²).
- Volante: no jogo NÃO gira (é parte da carroceria). Girar é melhoria nossa
  (VOLANTE_GIRA no car.gd; tools/volante.py acha o aro). O que gira no jogo
  são os braços do piloto, que ainda não temos.

## Pendente / ideias

- Pneu e aro comprados (hipótese: troca de textura, ver docs/assets.md).
- Decalques e número na pintura (camadas Decal/Text do XML 150xx).
- Tremida da câmera na BATIDA (a por velocidade já está, camera_jitter.gd):
  precisa do sistema de colisão do corpo (corpo+0x7a0); fórmula em
  docs/engenharia_reversa.md, Câmera.
- Som do motor (00002/00004/00005 xml: bancos e faders por buggy).
- Piloto sentado e animado (MALE_*.srd + InGame_Mid.skl + STEER_LEFT.bac,
  docs/engenharia_reversa.md "Piloto"): falta parser dos 3 formatos.
  Melhoria nossa depois: mãos tremendo no volante em alta velocidade.
- Câmera do piloto: referência do Matheus = cockpit do Dirt Rally 2.0
  (horizonte perto do meio, volante cortado embaixo, muita estrada).
- Sinal do giro/direção visual: falta save state andando com volante virado.
- Para-choque e luzes comprados (componentes Bumper/Lighting; de fábrica é NOT_INSTALLED).
