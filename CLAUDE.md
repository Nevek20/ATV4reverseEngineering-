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
piloto.gd            piloto do jogo sentado no ARSE, braços pela direção (STEER_LEFT)
volantes.gd          volantes gerados, um estilo por carro (melhoria nossa, no lugar do do jogo)
motor_som.gd         som do motor: loops do Engine Simulator por rpm e carga (melhoria nossa)
sfx_carro.gd         som de pneu, suspensão e pouso do jogo (portado do exe); som_jogo.gd toca os sons 989snd
fumaca.gd            fumaça do escapamento (melhoria nossa com o efeito ExhaustSmokeTrail que o jogo não usa)
motor_treme.gd       motor e escape tremendo (melhoria nossa): separa as peças do cofre da carroceria
terrain.gd           relevo e material do chão da pista RX01 (do stream do jogo)
data/                XMLs do jogo (física buggy_NN.xml, pontos, câmeras, peças)
assets/              modelos do pingu2obj: renegade, sphinx, buggy_NN, rodas; sfx (sons) e fx (fumaça) do jogo (fora do git)
tests/               teste de física sem tela + rodar_testes.py
tools/               scripts Python de extração (pingu2obj, pintura, savestate)
som/engine_sim/      um .mr do Engine Simulator por buggy (gerados por tools/gerar_motores.py)
som/loops/           loops .wav de cada motor (lenta, on/off a cada 500 rpm), tools/gravar_loops.py
re/                  engenharia reversa: scripts do Ghidra, exe_util, dumps
docs/                engenharia_reversa.md (mapa do exe), derrapagem.md (código da derrapagem legível), assets.md, som_motor.md
```

## Comandos

```
:: testes de física (precisa do Godot de console)
set GODOT=C:\caminho\Godot_v4.x-stable_win64_console.exe
python tests/rodar_testes.py                  :: aceleração dos 3 carros
python tests/rodar_testes.py hs --veh 0       :: curva em alta no Renegade
python tests/rodar_testes.py accel --veh 1 --tune "{\"engine\":0.81}"
python tests/rodar_testes.py accel --veh 0 --mu 0.69 --amort 0.2   :: fora da pista
python tests/rodar_testes.py accel --veh 0 --hz 60                 :: passo NTSC (padrão 50 = PAL)

:: save state do PCSX2 -> valores reais do jogo
python tools/ler_savestate.py arquivo.p2s
python tools/ler_savestate.py arquivo.p2s --json estado.json   :: estado do carro pro remake

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
%GODOT% --headless --path . -s res://tests/teste_largada.gd       :: largada do Renegade no RX01 x vídeo PAL e save states
%GODOT% --headless --path . -s res://tests/teste_pedais.gd        :: freio parado, ré pelo freio, corte no ar (0x202df0)
%GODOT% --headless --path . -s res://tests/teste_derrapagem.gd    :: remake no estado da RAM: força por roda e 1.16 s de derrapagem
%GODOT% --headless --path . -s res://tests/teste_volante.gd       :: punhos do piloto no aro nos 13 carros (0 cm) e giro do volante
%GODOT% --headless --path . --fixed-fps 50 -s res://tests/teste_treme.gd -- 0   :: volante tremendo: parado, reto, derrapando, solto
%GODOT% --headless --path . -s res://tests/teste_som.gd           :: som do motor: loops, tom e crossfade nos 12 buggies
%GODOT% --headless --path . -s res://tests/teste_sfx.gd           :: tom do pneu x pitch das vozes do SPU em 7 save states
%GODOT% --headless --path . --fixed-fps 50 -s res://tests/teste_ladeira.gd -- 0   :: pneu parado em barranco: som não pode piscar
%GODOT% --headless --path . -s res://tests/teste_motor_treme.gd   :: peças e faces do motor que treme nos 12 carros
:: + print_tela com MOTOR_COR=1 pinta de vermelho as peças que tremem
%GODOT% --path . --write-movie previa.avi --fixed-fps 60 -s res://tests/gravar_som.gd -- 8   :: prévia com áudio (acelera e solta; VIRA=5 derrapa, SEM_MOTOR=1)
set VEL=110 & %GODOT% --headless --path . res://tests/teste_entrada.tscn   :: reto até VEL e vira tudo: quando passa de 20° (jogo: 110 não derrapa)
:: + SOLTA=1.3 solta o volante (DEPOIS=-1 contra-esterça, ACEL=0 solta o acelerador), DUR=8 segundos depois de virar
%GODOT% --headless --path . -s res://tests/medir_tremor.gd -- 60 tremor.csv  :: distância câmera-carro por quadro

:: terreno do RX01 (alturas + material) a partir do stream do jogo
python tools/extrair_material.py <dados>/stream/RX01.000 assets/terrain --materiais <dados>/unpacked/xml/12280

:: checar um script sem abrir o editor
%GODOT% --headless --path . --check-only --script res://car.gd

:: sons de pneu, suspensão e pouso do jogo -> assets/sfx (wav + sons.json)
python tools/sfx_jogo.py <unpacked>
:: textura da fumaça (Sprites/Particles, caixa Dust0) -> assets/fx/fumaca.png
python tools/fx_jogo.py <unpacked>

:: piloto (malha, esqueleto, animação da direção, textura) -> assets/piloto
python tools/piloto.py <unpacked>

:: assets dos 12 buggies (modelo, peças, freios, rodas, pintura)
python tools/gerar_buggies.py <unpacked> <texturas>

:: motores do Engine Simulator (12 .mr) e dinamômetro sem tela (Linux)
python tools/gerar_motores.py
bash tools/engine_sim_dyno/preparar.sh
tools/engine_sim_dyno/build/dyno som/engine_sim/08_mckenzies_gm_ls6.mr
python tools/gravar_loops.py [08 11]          :: loops de 2 s on/off a cada 500 rpm -> som/loops

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
- **Speedrun do Sphinx** (versão NTSC = física a 60 Hz; atv4-dados/videos,
  parte_00_00, largada em 25 s; relógio da corrida + HUD em mph lidos quadro
  a quadro, tabela em tests/rodar_testes.py). Carro pela ficha da tela de
  opções: DIRT PREMIUM, 269.9 HP (motor 1.0), 2204 lbs (BodyMass L2),
  embreagem L2 (troca 2->3 para 0.28 s). A 60 Hz o remake fica a 1.2 mph.
- **Renegade PAL** (gravação do Matheus no RX01, sozinho na pista, de
  fábrica = 440.6 HP; tabela em tests/teste_largada.gd) + save state
  patinando a 48.7 km/h em 1ª: 6893 rpm, roda de trás 34.09 rad/s (0x600
  0.26, 0x610 0.32), 8.0 kN por roda traseira (elipse 8.17 x 0.98).
  Mais 4 save states da largada (5_a_10, 15_a_20 e os _teste_2 do Matheus,
  ainda fora do atv4-dados/savestates): patinada de trás / rpm 0.48 /
  1379 a 8.6 km/h, 0.48 / 1568 a 9.8, 1.20 / 4763 a 19.8, 1.38 / 5766 a 22.1
  (teste_largada imprime remake x jogo). No vídeo, as barrinhas do lado do
  conta-giros são acelerador (verde) e freio (vermelho).
- **Derrapagem** (4 save states do Matheus a ~120 km/h na terra, volante
  todo e acelerador; tests/ref_derrapagem.json): forças por roda e 1.16 s
  de derrapagem batem (tests/teste_derrapagem.gd: 0.13 kN por roda, 0.4 m no fim).
  Mais 5 segurando o R1 do controle (= botão da embreagem, "freio de mão"),
  virando e acelerando: embreagem aberta (0x2ec = 0), motor batendo no
  limitador (~8000 rpm), Clutch Turn em 0. O remake bate (rpm, embreagem e
  força por roda). Segurar não faz Clutch Turn: ele só começa ao SOLTAR. Todo .p2s
  traz Screenshot.png: o relógio da corrida dá o tempo entre save states.
  Derrapagem natural ("SLIDE - Steer hard into turn" no treino): virando
  tudo a 173 km/h o remake chega no save state "170" (133 km/h, 35.7°,
  82°/s, HUD 114) em 1.6 s, e o HUD marca 130 / 160 quando solta, como o
  Matheus leu no jogo. O velocímetro do jogo é ~1.06 x a velocidade PRA
  FRENTE (cai quando o carro fica de lado). tests/teste_entrada.tscn.
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
- Física roda a 50 Hz = passo do PAL (nosso exe). O jogo DEPENDE do passo:
  com a roda patinando o motor fica batendo no limitador (rampas de 15/s) e
  a patinada sobe e desce (3/s, 4/s); com passo menor o corte é raso e a
  força média sobe. A 120 Hz a 1ª saía 28% forte. Vídeo NTSC (EUA) = 60 Hz
  (rodar_testes --hz 60; o veh=2 já roda assim). Interpolação ligada;
  câmera em passos de 1/60 interpolando no frame do carro (senão aparece
  "fantasma").
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
- Pedais: cada comando tem cru e suavizado (corpo+0x368; acelerador
  0x37c/0x380, freio 0x38c/0x390). Motor usa o suavizado; o CÂMBIO
  (0x20c7a8) e o "preso" usam o CRU. Parado sem pedal (< 0.2 mph) o jogo põe
  freio 1.0 sozinho (0x202df0): a barra vermelha cheia na largada não é o
  jogador freando. Freio parado vira ré na hora (0.1 s se vinha andando);
  no ar o acelerador corta até ser solto uma vez. car.gd _pedais_auto.
- O jogo NÃO tem freio de mão. O botão (corpo+0x384/0x388) é a EMBREAGEM:
  segurando abre a embreagem (> 0.1, 0x20c558); um toque virando e
  acelerando faz a "Clutch Turn" (powerslide 0x214610, car.gd
  _powerslide). O freio só tem o pedal (0x390). No remake é o Espaço.
- Derrapagem não volta sozinha: o 0x2120c0 (RecoveryTorqueCutting) corta o
  torque que endireita (modos B/C do 0x20efa0) pelo acelerador quando o
  volante está pra dentro da curva ou solto, e sobe a patinada de trás até
  0.2. Sai contra-esterçando ou soltando o acelerador. Sem ele o remake
  "consertava o carro pra pista" (docs/derrapagem.md).
  Testamos um ajuste NOSSO pro teclado por cima (cortar também abaixo dos
  12°, out/2026): o Matheus comparou lado a lado e ficou pior. O fiel é o
  certo; não "afrouxar" a derrapagem no chute.
- Piloto (piloto.gd, tools/piloto.py): .skl/.srd/.bac decifrados
  (docs Piloto). ROOT da animação em cima do ARSE, sem a rotação do ponto.
  STEER_LEFT no tempo |s|/6, espelhado com s > 0 do jogo (= rider_s < 0 no
  remake). Índice de osso no .srd vem x4. Some no capô e no para-choque
  (mRenderRider 0); na nossa câmera do piloto aparece sem o capacete (osso
  head encolhido: o olho fica dentro da cabeça dele), com braços e mãos no
  volante.
- Mãos no volante (melhoria nossa, car.gd MAOS_NO_VOLANTE): o volante gira o
  quanto os punhos giram no STEER_LEFT do jogo (39° a 62° no volante todo,
  por carro; antes era SW_TURNS = 149° sem fonte) e cada punho fica preso no
  aro por IK de dois ossos. Em 5 carros (Sphinx, Inferno, Kraken, McKenzies,
  Storm) o volante fica além do braço esticado (até 108%): a clavícula avança
  até 35°. tests/teste_volante.gd: 0.0 cm nos 13 carros.
  No quadro 0 do STEER_LEFT a mão direita pega a 22° do topo e a esquerda a
  44° (braços tortos na câmera do piloto): a direita agora é o espelho da
  esquerda no plano do volante (piloto.gd prender_no_volante). A mão
  também gira até a linha dos nós (indicador -> anelar) ficar ao longo do
  aro: na animação ela fica 25° a 43° torta e o aro saía de lado do punho
  ("mão mal encostando"). O ponto do punho (média dos vértices da mão) cai no
  buraco dos dedos dobrados, a ~5 mm do centro dele (corte da malha).
  Depois ela desce pelo aro até PEGA_GRAUS = 65° do topo (~9h30/2h30, vídeo
  de referência do Matheus; a 44° os braços subiam na frente da câmera no
  Bulldog e no Viper) e gira em volta da linha dos nós até o pulso ficar
  reto atrás do punho, na direção do eixo do volante (os carros bons já
  ficavam entre -28° e +10° disso). Seguir o antebraço do IK NÃO serve: no
  Renegade (volante perto e deitado) o antebraço fica quase na linha do aro,
  o ajuste fica indefinido e o pulso ia 7 cm pra dentro (braço em
  zigue-zague). No volante todo a mão de fora vai perto do topo e o
  antebraço passa na frente da câmera (pendente).
- Volantes gerados (melhoria nossa, car.gd VOLANTE_NOSSO, volantes.gd): o
  do jogo tem aro de 6 a 12 lados e raios tortos; 8 carros usam o mesmo X
  furado girado ~20°. No lugar vai um volante redondo e centralizado, no
  centro, raio e eixo do pecas.json (a IK das mãos não muda). Um estilo por
  carro (Volantes.POR_CARRO): os únicos do jogo melhorados (Renegade barra
  + losango, Bulldog barra larga, Inferno/Storm X de aço com rebites, Sphinx
  o X furado) e os das fotos do Matheus (buggy no Phantom, Sparco preto no
  Kraken, Sparco azul no Viper, Mountney no McKenzies, kart no Hurricane,
  espuma no Trident, Fusca Itamar no Mosquito; couro sobra). B no jogo troca;
  print_tela VOLANTE=nome PILOTO=0. Alisar o aro do jogo (VOLANTE_LISO)
  quebrou no Renegade e no Bulldog: não voltar.
  A coluna de direção da carroceria termina 1.1 cm atrás do aro (Renegade
  1.7, Storm 0.7 cm NA FRENTE) e atravessava o miolo recuado (dish): o
  volante avança pro piloto até a coluna acabar atrás dele (car.gd
  _montar_volante, de 0 a 5.6 cm no Kraken; teste_volante imprime). Os X
  ficam a 45° do topo, longe das mãos (65°).
- Volante: no jogo NÃO gira (é parte da carroceria). Girar é melhoria nossa
  (VOLANTE_GIRA no car.gd; tools/volante.py acha o aro). O que gira no jogo
  são os braços do piloto (piloto.gd).
- Som de pneu, suspensão e pouso = do jogo (sfx_carro.gd, docs Som de
  pneu): Suspen.bnk e VEHICLE.bnk existem mas o jogo NÃO carrega; a
  suspensão sai do Collide.bnk (BigSuspension/SmallSuspension) e o pneu do
  SURFACE.bnk, pelo SFX do material da pista. Só FL e RL tocam (+ Screech na
  FL no asfalto). Tom conferido com o SPU (tests/teste_sfx.gd).
  Mistura NOSSA por cima (o Matheus achou o pneu rolando cansativo e alto):
  sfx_carro.gd SO_DERRAPANDO (pneu só derrapando, patinando ou travado;
  ROLAGEM = quanto do rolar reto fica) e GANHO_PNEU 0.6. Patinada só conta
  com o pneu escorregando > 1 m/s (PATINA_MIN): parado num barranco a
  patinada medida divide por quase zero e o som piscava (teste_ladeira).
- Fumaça do escapamento (melhoria nossa, car.gd FUMACA, fumaca.gd): o jogo
  NÃO solta fumaça. O efeito ExhaustSmokeTrail (xml 01416) e os pontos
  EXHAUST/EXHAUST2 existem, mas o exe não lê nenhum (sem cBehaviour*/
  cRenderer*; tabela de pontos 0x550700 sem EXHAUST; vídeo sem fumaça).
  Usamos os parâmetros do efeito; taxa de emissão e saída do cano são nossas.
  Storm não tem ponto EXHAUST (sem fumaça).
- Motor e escape tremendo (melhoria nossa, car.gd MOTOR_TREME,
  motor_treme.gd): no jogo são parte da Body e não tremem. Separação pelas
  peças soltas da malha que cabem inteiras no cofre (atrás do banco até o
  escape, entre as rodas de trás), sem pintura "white", pneu, sem textura,
  chapas/travessas e peças grandes. A textura "engie/engine" NÃO serve: é um
  atlas usado no painel, na frente e na gaiola. Conferido com prints
  vermelhos x normais (Sphinx, Phantom, McKenzies, Viper, Hurricane, Trident:
  só o metal do cofre). Amplitude exagerada (6 mm na lenta) pra aparecer na
  câmera de corrida (1 px ~ 8 mm a 6 m).
- Volante tremendo (melhoria nossa, car.gd VOLANTE_TREME, _vibracao): no
  jogo nada treme (nem volante, nem mãos, nem motor: varredura do exe e
  vídeo). A força é a do motor pequeno da vibração do CONTROLE (0x202ab8:
  carro de lado, roda patinando devagar, roda travada, trancos pela
  velocidade) + pouso (0x370df0) e suspensão (0x36e498) do som + a tremida
  de curso das rodas da frente na terra (0x202760). Graus = escolha nossa.

## Pendente / ideias

- Pneu e aro comprados (hipótese: troca de textura, ver docs/assets.md).
- Decalques e número na pintura (camadas Decal/Text do XML 150xx).
- Tremida da câmera na BATIDA (a por velocidade já está, camera_jitter.gd):
  precisa do sistema de colisão do corpo (corpo+0x7a0); fórmula em
  docs/engenharia_reversa.md, Câmera.
- Som do motor (melhoria nossa, plano combinado com o Matheus): o jogo só
  tem 3 bancos de motor (02/03/04, XMLs 00002/00004/00005) repetidos nos 12
  buggies (o Mosquito soa igual ao Kraken V8). Plano: o Matheus monta cada
  motor no Engine Simulator e grava loops de 1-2 s a cada 500 rpm,
  acelerando e soltando, cortados no zero da onda; no Godot um tocador faz
  crossfade + pitch entre os 2 samples vizinhos e mistura acelerando/
  soltando pelo acelerador. RPM: opção (b), o 1000-8000 do jogo (igual nos
  12) esticado pra faixa real de cada motor. Constante pra voltar ao som do
  jogo quando ele for portado. Motor proposto por buggy (nome interno do
  vehicles.xml + base real + HP de fábrica, com fontes) e o jeito de
  gravar: docs/som_motor.md. Feito: os 12 .mr (som/engine_sim, LEIA-ME
  com cv e lenta medidos), os loops (som/loops) e o tocador (motor_som.gd,
  car.gd SOM_MOTOR; N no jogo deixa mudo). Ajuste de volume: K_RPM, K_OFF
  e PISO_DB no motor_som.gd. FECHADO (out/2026, o Matheus aprovou os 12):
  Trident e Viper com escape/filtro escolhidos de ouvido entre variantes.
  Zumbido ou apito num tom só = filtro mild_exhaust do engine-sim (pico em
  133 Hz), não o tamanho do tubo (som/engine_sim/LEIA-ME.md).
- Piloto: montar a textura dele como o jogo (5 camadas por parte + cores do
  perfil; hoje usa o rider_fury pronto), LOD MID/LOW, piloto feminino.
- Câmera do piloto: referência do Matheus = cockpit do Dirt Rally 2.0
  (horizonte perto do meio, volante cortado embaixo, muita estrada).
- Sinal do giro/direção visual: falta save state andando com volante virado.
- Para-choque e luzes comprados (componentes Bumper/Lighting; de fábrica é NOT_INSTALLED).
- Mapa de material do RX01: no save state 110 (1ª curva) o PS2 tocava
  asfalto e o mapa do remake diz cascalho nas rodas da frente
  (tests/teste_sfx.gd avisa). O atrito do pneu usa o mesmo mapa: conferir
  (pode ser uma malha de estrada por cima do relevo).
