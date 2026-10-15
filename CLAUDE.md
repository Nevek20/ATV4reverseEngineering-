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
suspension_visual.gd balanças, amortecedores e freios do jogo se mexendo
vehicle_data.gd      leitor dos XMLs (base + veículo) e peças de fábrica
main.gd              cena: terreno, carro, câmera, HUD, troca de carro (V)
terrain.gd           relevo da pista RX01
data/                XMLs do jogo (física, câmeras, veículos, peças)
assets/              modelos gerados pelo pingu2obj (NÃO vão pro git)
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

:: save state do PCSX2 -> valores reais do jogo
python tools/ler_savestate.py arquivo.p2s

:: caçar coisas no exe
python re/exe_util.py SCES_546.88 str NOME | jal 0xENDERECO | words 0xEND 32
```

Ghidra headless (Ghidra 12.1.3 + extensão ghidra-emotionengine-reloaded):

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
- Modelos: o pingu2obj vira os triângulos pelas normais do jogo e o Godot
  descarta a face de trás (`MODEL_CULL`). Total de materiais do .pingu em
  0xAC (0xBC conta menos).
- Carroceria usa a textura "white" = pintura gerada (tools/gerar_pintura.py).
- Física roda a 120 Hz com interpolação ligada; câmera em passos de 1/60
  interpolando no frame do carro (senão aparece "fantasma").

## Pendente / ideias

- Rodas de verdade (modelos de pneu/roda do jogo no lugar dos cilindros).
- Decalques e número na pintura (camadas Decal/Text do XML 150xx).
- Tremida da câmera (jitter e batida), componente 0x380418 + 0x380170.
- Roda travando no freio (0x210908).
- Atrito por tipo de chão (TireBehaviour por superfície).
- Som do motor (00002/00004/00005 xml: bancos e faders por buggy).
- Mais carros: a tabela VEHICLES em main.gd + blocos em docs/assets.md.
