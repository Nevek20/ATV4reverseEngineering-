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
camera_jitter.gd     tremida da câmera (Perlin por velocidade, só na terra, e sorteio na batida)
camera_piloto.gd     câmera do piloto (melhoria nossa): força G na cabeça, FOV e borrão pela velocidade, olhar pra curva e olhar livre
suspension_visual.gd balanças, amortecedores e freios do jogo se mexendo
vehicle_data.gd      leitor dos XMLs (base + veículo) e peças de fábrica
main.gd              cena: terreno, carro, câmera, HUD, menu de carros (Tab, V); VEHICLES = buggies, TRUCKS, frota() = os dois
piloto.gd            piloto do jogo sentado no ARSE, braços pela direção (STEER_LEFT)
volantes.gd          volantes gerados, um estilo por carro (melhoria nossa, no lugar do do jogo)
motor_som.gd         som do motor: loops do Engine Simulator por rpm e carga (melhoria nossa)
sfx_carro.gd         som de pneu, suspensão e pouso do jogo (portado do exe); som_jogo.gd toca os sons 989snd
fumaca.gd            fumaça do escapamento (melhoria nossa com o efeito ExhaustSmokeTrail que o jogo não usa)
sujeira.gd           sujeira do jogo na pintura e lama nas rodas, pelo 2º UV (_camada.obj); nível e cor vêm do car.gd
painel.gd            painel funcional (melhoria nossa): ponteiros, marcha e luz de troca, amador x PRO
motor_treme.gd       motor e escape tremendo (melhoria nossa): separa as peças do cofre da carroceria
motor_anima.gd       ventoinhas girando e polias + correia 3D (melhoria nossa) por cima do desenho do jogo
luzes.gd             lanterna de freio e luz de ré acesas (melhoria nossa): lente pelos pixels da cor da luz
farol.gd             farol aceso (melhoria nossa, no estilo da lanterna de freio) nas lentes de farol do modelo; H liga
terrain.gd           relevo e material do chão da pista RX01 (do stream do jogo)
data/                XMLs do jogo (física buggy_NN.xml, pontos, câmeras, peças)
assets/              modelos do pingu2obj: renegade, sphinx, buggy_NN, truck_NN, rodas; sfx (sons) e fx (fumaça) do jogo (fora do git)
tests/               teste de física sem tela + rodar_testes.py
tools/               scripts Python de extração (pingu2obj, pintura, savestate)
som/engine_sim/      um .mr do Engine Simulator por buggy (NN_) e por truck (tNN_, t13 = Silverado), tools/gerar_motores.py
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
:: + CAM_OFF=0.3,0.9,-4 CAM_ALVO=0,0.85,-2.6 câmera livre (frame do jogo); PICK=x,y;x,y diz
::   a malha, textura, UV e ponto do jogo embaixo de cada pixel do print; CULL=0 carroceria com as 2 faces

:: peças da suspensão x RAM do jogo (120 matrizes, 6 buggies + Goliath e Buccaneer), tremida e chão
%GODOT% --headless --path . -s res://tests/teste_pecas.gd
%GODOT% --headless --path . -s res://tests/teste_tremida.gd
%GODOT% --headless --path . -s res://tests/teste_chao.gd
%GODOT% --headless --path . -s res://tests/teste_mao.gd     :: espelho (lado das peças, esterço)
%GODOT% --headless --path . -s res://tests/teste_tremida_camera.gd
set VEL=20 & %GODOT% --headless --path . -s res://tests/teste_batida.gd   :: Storm na parede: velocidade da batida e tremida da câmera
%GODOT% --headless --path . -s res://tests/teste_freio.gd   :: patinada, ABS e trava
%GODOT% --headless --path . -s res://tests/teste_roda.gd    :: giro das rodas por torque (no ar, preso)
%GODOT% --headless --path . -s res://tests/teste_camera_passo.gd  :: câmera de órbita sem vai e volta
%GODOT% --headless --path . -s res://tests/teste_camera_ram.gd    :: câmera parada x RAM de 6 save states (4 buggies, 2 trucks)
%GODOT% --headless --path . -s res://tests/teste_camera_piloto.gd :: câmera do piloto: freada, curva, FOV, borrão, mouse (números de projeto)
%GODOT% --path . --write-movie camera.avi --fixed-fps 60 -s res://tests/gravar_camera.gd -- 0   :: prévia: acelera, freia, curva e olha pro lado (EFEITOS=0 sem efeitos)
%GODOT% --headless --path . -s res://tests/teste_largada.gd       :: largada do Renegade no RX01 x vídeo PAL e save states
%GODOT% --headless --path . -s res://tests/teste_pedais.gd        :: freio parado, ré pelo freio, corte no ar (0x202df0)
%GODOT% --headless --path . -s res://tests/teste_derrapagem.gd    :: remake no estado da RAM: força por roda, 1.16 s de derrapagem, sujeira e lama das rodas
%GODOT% --headless --path . -s res://tests/teste_volante.gd       :: punhos do piloto no aro nos 13 carros (0 cm) e giro do volante
%GODOT% --headless --path . --fixed-fps 50 -s res://tests/teste_treme.gd -- 0   :: volante tremendo: parado, reto, derrapando, solto
%GODOT% --headless --path . -s res://tests/teste_som.gd           :: som do motor: loops, tom e crossfade nos 12 buggies, 12 trucks e o bônus
%GODOT% --headless --path . -s res://tests/teste_sfx.gd           :: tom do pneu x pitch das vozes do SPU em 7 save states; material da FL x RAM
%GODOT% --headless --path . --fixed-fps 50 -s res://tests/teste_ladeira.gd -- 0   :: pneu parado em barranco: som não pode piscar
%GODOT% --path . --write-movie cascalho.avi --fixed-fps 60 -s res://tests/gravar_cascalho.gd -- 0  :: derrapando no cascalho escuro: trocas Gravel/Dirt e áudio do pneu
%GODOT% --headless --path . -s res://tests/teste_motor_treme.gd   :: peças e faces do motor que treme nos 12 carros
%GODOT% --headless --path . -s res://tests/teste_motor_anima.gd   :: ventoinhas, polias e correia nos 12 (nada some, correia encosta)
%GODOT% --headless --path . -s res://tests/teste_luzes.gd         :: cor do vértice nos materiais e lanterna de freio nos 12 (acende e apaga)
%GODOT% --headless --path . -s res://tests/teste_farol.gd         :: farol: lentes achadas (Hurricane 2, Storm 6), lente e brilho, acende e apaga
:: + print_tela com FAROL=1/0 força o farol aceso/apagado
:: + print_tela com FREIO=1/0 e RE=1/0 forçam lanterna e ré acesas/apagadas, COR_VERTICE=0 tira a cor do vértice
%GODOT% --path . --write-movie motor.avi --fixed-fps 60 -s res://tests/gravar_motor.gd -- 7   :: prévia: lenta, 7000 e volta (CAM_OFF/CAM_ALVO)
:: + print_tela com MOTOR_COR=1 pinta de vermelho as peças que tremem
%GODOT% --path . --write-movie previa.avi --fixed-fps 60 -s res://tests/gravar_som.gd -- 8   :: prévia com áudio (acelera e solta; VIRA=5 derrapa, SEM_MOTOR=1)
set VEL=110 & %GODOT% --headless --path . res://tests/teste_entrada.tscn   :: reto até VEL e vira tudo: quando passa de 20° (jogo: 110 não derrapa)
:: + SOLTA=1.3 solta o volante (DEPOIS=-1 contra-esterça, ACEL=0 solta o acelerador), DUR=8 segundos depois de virar
%GODOT% --headless --path . -s res://tests/medir_tremor.gd -- 60 tremor.csv  :: distância câmera-carro por quadro

:: terreno do RX01 (alturas + material) a partir do stream do jogo
python tools/extrair_material.py <dados>/stream/RX01.000 assets/terrain --materiais <dados>/unpacked/xml/12280

:: checar um script sem abrir o editor
%GODOT% --headless --path . --check-only --script res://car.gd

:: sons de pneu, suspensão e pouso do jogo -> assets/sfx (wav + sons.json com o ADSR de cada tom)
python tools/sfx_jogo.py <unpacked>
:: textura da fumaça (Sprites/Particles, caixa Dust0), da sujeira (GEN_DIRT_DIRT) e da lama do pneu (UNI_TyreOverlay) -> assets/fx
python tools/fx_jogo.py <unpacked>
:: + print_tela com SUJEIRA=0.8 força o nível da sujeira, PAINEL=6900,137 fixa rpm e km/h no painel,
::   SEM_PAINEL=1 esconde o nosso (pra ver o que sobrou do modelo)

:: piloto (malha, esqueleto, animação da direção, textura) -> assets/piloto
python tools/piloto.py <unpacked>

:: assets dos 12 buggies (modelo, peças, freios, rodas, pintura; + <modelo>_camada.obj com o 2º UV)
python tools/gerar_buggies.py <unpacked> [<texturas>]   :: sem a pasta: "texturas" do lado da unpacked; para se não achar .png
python tools/gerar_buggies.py <unpacked> [<texturas>] --classe truck   :: os 12 trucks -> assets/truck_NN, data/vehicles/truck_NN*
:: só o alfa das texturas com furo (redes das janelas, treliça do Trident); o gerar_buggies já chama
python tools/alfa_texturas.py <unpacked>
:: só a pintura (cores, logos e número "00"; --numero 27, --sem-decalques); depois reimportar no Godot
python tools/gerar_pintura.py <unpacked> BUGGY_10 assets/renegade
python tests/teste_pintura.py <unpacked>      :: caixas do .bed x quadros do número (12 carros) e logos do DefaultDecals

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
O projeto roda em Forward+ (padrão) e o xvfb só tem OpenGL (Compatibility,
conta de cor diferente). Pra ver igual ao PC: `apt-get install -y
mesa-vulkan-drivers` e rodar com `VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json`
e `--rendering-method forward_plus --rendering-driver vulkan` (lavapipe, lento).
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
  embreagem L2 (troca 2->3 para 0.28 s); motor 1.0 = câmbio Prototype, que
  libera a final custom 0.61. A 60 Hz o remake fica a 1.2 mph.
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
  Relação final (0x21d2c8): GearboxLevel_Level0/1 dão FinalDriveRatio
  0.45/0.53; Level2/3/Prototype dão CustomFinalDriveRatio = a custom
  (GearRatioTuning FinalDrive, 0.61). RAM: Inferno, Bulldog, Phantom e
  Buccaneer de fábrica (Level0) 0.45; Renegade, Storm (Level3) e Goliath 0.61.
  Até out/2026 o remake usava sempre a custom (achado só com carros de
  câmbio Level3/Prototype). O Sphinx do b.p2s dá 0.61 com motor de fábrica:
  aquele Sphinx tinha câmbio comprado. Os efeitos das peças SOMAM (cada tipo,
  preso em 0..1); de fábrica nenhum tipo se repete fora o motor.
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
  Trucks (eixo rígido): LeftFrame/RightFrame giram tan(x / W.x) (tan, não
  atan) com W = WHEEL_FRONT_*_VISUAL (o jogo acha o ponto pelo começo do
  nome, na ordem do arquivo); RearAxle (Axle + Rear_Arm) gira em volta do
  ARM_PIVOT até o meio das rodas de trás. Goliath (goliath_dirt_budget.p2s)
  e Buccaneer (Buccaneer_Standard.p2s) batem com erro 0 (docs Peças,
  suspension_visual.pose_truck).
- Modelos: o pingu2obj vira os triângulos pelas normais do jogo e o Godot
  descarta a face de trás (`MODEL_CULL`). Total de materiais do .pingu em
  0xAC (0xBC conta menos).
- Carroceria usa a textura "white" = pintura gerada (tools/gerar_pintura.py).
  Logos e número (camadas Decal e Box/Text do XML 150xx, docs Pintura):
  caixas do .bed = fração x 100000 (não é 16.16); a k-ésima Decal de uma área
  usa o <ÁREA><k> do DefaultDecals (HOOD1, SIDE3, REARWING1); KeepAspect
  encaixa o logo na caixa e DEPOIS gira; número = "00" do perfil novo, altura
  = caixa x 0.55. Conferido no print do Renegade (ITP, ATTACK, OUTERWEARS,
  00, elf na ordem). Sphinx e BUGGY_03 ficam sem logo (o vehicles.xml deles
  tem chaves de moto). Depois de gerar, o Godot precisa reimportar a
  pintura.png (abrir o editor ou `--headless --import`), senão usa a velha.
- Cor do vértice (car.gd COR_VERTICE, material_do_jogo): o .pingu tem RGBA
  por vértice (0x80 = 1.0, até 2.0) e o PS2 multiplica a textura por ela:
  sombra "assada" do modelo e a cor das lanternas. Até out/2026 o remake
  ignorava (lanterna do Renegade branca: vidro claro x vértice 167, 24, 24;
  gaiola do Mosquito quase branca). O pingu2obj cortava em 1.0: agora sai
  codificada (docs/assets.md, pecas.json "cor_vertice": 2). Vale pra
  carroceria, rodas, peças, volante do jogo e os shaders por cima (sujeira,
  ventoinha: car.cor_k()). Sem rodar o gerar_buggies de novo o .obj velho
  funciona, só sem o acima de 1.0.
- Import do Godot: o .obj só é reimportado quando ELE muda; o .mtl não conta.
  Um gerar_buggies com a pasta de texturas errada (out/2026) gerou .mtl sem
  textura e o carro ficou branco; rodar de novo com a pasta certa não
  adiantava (o .obj saía igual). O pingu2obj põe "# mtl <md5>" no topo do
  .obj e o gerar_buggies para se a pasta de texturas não tiver .png.
- Halos do jogo (out/2026; até então achávamos que o jogo não usava os
  pontos BRAKE_LIGHT, porque o nome não está no exe): Setup/VehicleHaloMap.xml
  (data/vehicle_halo_map.xml) liga nome de ponto -> halo (VehicleHalos.xml,
  data/vehicle_halos.xml) + comportamento: BRAKE_LIGHT1-6 "BrakeLight"/Brake,
  REVERSE_LIGHT1-2 "ReverseLight"/Reverse, HEAD_LIGHT1-3 / FRONT_HALO1-10 /
  REAR_HALO1-5 / Night. O 0x203930 acende por quadro: freio com 0x390 >= 0.1,
  ré engatada, Night sempre (carro ativo); 0x2260a0 sobe 4/s e apaga na hora.
  RAM: halos de freio acesos com freio 1.0 (a.p2s, storm.p2s); nos prints do
  Screenshot.png aparece o brilho laranja com raios. Nenhum carro do jogo tem
  ponto HEAD_LIGHT/FRONT_HALO: o farol "Night" existe e nunca aparece. Os
  LIGHTRIG comprados (Lighting, 8 modelos Small/Large pelo LightRigCategory,
  mIsPhysical false) são só modelo, sem halo. Desenho: textura
  Sprites/lightglow2alpha (o desenho é o alfa; caixas GLOW e SPIKE), uma
  camada por Layer, tamanho Width/Height x 0.3 m (medido nos prints), nível
  HIGH (os raios a ±0.4 rad aparecem). docs/engenharia_reversa.md, Halos.
- Lanterna de freio e luz de ré (melhoria nossa, car.gd LUZ_FREIO,
  luzes.gd): no lugar do halo do jogo (o Matheus preferiu o nosso, out/2026).
  Lente = PIXELS da cor da luz (vermelho no freio, branco na
  ré) na cor final (textura x cor do vértice) até 15/12 cm do ponto,
  amostrados a cada 1 cm no triângulo; a cópia por cima soma a cor x 6 + um
  miolo claro só nesses pixels (máscara no shader) e cada lanterna ganha um
  halo virado pra câmera (só de trás) no centro e tamanho dos pixels acesos.
  No Storm a lanterna é pintada na textura (vermelho + branco da ré) em
  triângulos grandes: acender o triângulo inteiro desenhava triângulos
  claros. Freio = brake_in (0x390, inclui o freio que o jogo segura parado:
  acende na largada; zera na ré pelo freio); ré = marcha -1. Ré só nos 5
  com REVERSE_LIGHT (Mosquito, Bulldog, McKenzies, Viper, Storm). Sem
  OmniLight: de dia pintava gaiola, estepe e chão de rosa.
- Farol (melhoria nossa, car.gd FAROL, farol.gd; H no jogo liga e desliga,
  vale pra todos): mesma cara da lanterna de freio (lente acesa nos pixels
  claros com o shader do luzes.gd + brilho suave virado pra câmera). Testamos
  o halo do HEAD_LIGHT do jogo (brilho com raios, out/2026) e o Matheus achou
  mais feio: não voltar. Lentes = faces com textura light_64 ou headlight,
  agrupadas pelos vértices, viradas pra frente pela NORMAL do jogo (a ordem
  dos vértices vem virada do pingu2obj). Só o Hurricane (2) e o Storm (2
  faróis + 4 milhas) têm; no Mosquito a light_64 é a lanterna de trás.
- Alfa: o gob_tex2png salva sem alfa (no PS2 ele muitas vezes é brilho). Nos
  carros só 3 texturas têm furo de verdade: mesh_grey (redes das janelas,
  54%), Buggy_05_framework (treliça do Trident, 71%) e driver (7%).
  tools/alfa_texturas.py devolve o alfa delas e o car.gd vira recorte
  (_tem_alfa); as outras têm alfa cheio e não mudam.
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
- Mapa de material do RX01 CONFERIDO (out/2026): o material da FL na RAM
  (veículo+0xa88[0]) bate com o mapa no ponto de contato em drr_1, drr_3 e
  110; no 170 a roda está 1.2 mm depois da divisa da célula (o material da
  RAM é do passo seguinte). No 110 o PS2 tocava asfalto com as rodas da
  frente no cascalho porque elas saíram do asfalto 0.07 s antes: o loop do
  asfalto leva 0.34 s pra apagar (release) e o do cascalho só entra 0.25 s
  depois (espera do grão). Não tem malha de estrada por cima do relevo.
  tests/teste_sfx.gd confere os 2 (material x RAM e "som atrás do chão").
  O "grip" do ref_derrapagem.json NÃO é o atrito do material (0.80 até no
  asfalto).
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
- Câmera do piloto (melhoria nossa, camera_piloto.gd, main.gd modo 4): o
  olho fica no lugar calibrado (car.gd FP_*) e por cima vêm os efeitos de
  velocidade (referência do Matheus: The Crew Motorfest, com o olhar livre do
  Forza), cada um com chave em CameraPiloto.efeitos pro menu de opções; G liga
  e desliga todos. Força G: a cabeça é uma mola de pescoço (1.6 Hz, 70% do
  crítico) no frame do carro, empurrada pela aceleração medida a cada passo
  de 50 Hz (1 g de freada = 5 cm pra frente e olha pra baixo; curva = pra
  fora e inclina). Limite de 8 cm (6 de lado) chegando aos poucos (tanh): a
  freada do Renegade dá 1.8 g e com corte seco a cabeça grudava no limite. FOV +12° de 36 a 216 km/h. Olha pra curva: 60% do ângulo
  de deriva + 0.15 s de guinada, até 25°. Borrão: zoom radial só nas bordas
  de 72 a 200 km/h (CanvasLayer embaixo do HUD). Olhar livre: analógico
  direito ou mouse com o botão direito (150° pros lados, 35° pra cima e pra
  baixo), volta sozinho; a cabeça gira em volta do pescoço (10 cm atrás do
  olho). Sem efeitos a câmera olha reto (a de antes virava 1/4 do volante;
  o print_tela ainda usa essa, car.first_person_xf).
- Cabine fechada (melhoria nossa, car.gd CABINE_FECHADA, _face_de_dentro):
  a casca do jogo só tem a face de fora (ninguém entra no carro no jogo). No
  Storm, o único fechado, a nossa câmera do piloto via a estrada pelas portas,
  teto e piso. Cada triângulo sem gêmeo do outro lado ganha uma cópia virada
  (os de 2 faces já modelados ficam, senão piscam): na pintura "white" com
  FORRO cinza (de dentro não aparece a pintura de fora espelhada), no resto
  a mesma textura (a rede da janela aparece por dentro). Por fora só muda o
  que se vê pela janela. print_tela CULL=0 desliga o descarte da face de
  trás na carroceria (diagnóstico).
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
  Programa de grãos = BlockSoundHandler do 989snd (som_jogo.gd; a mesma
  biblioteca foi reimplementada no jak-project, game/sound/989snd): relógio
  de 240 Hz, espera de cada grão ANTES dele, RAND_PLAY sem repetir, RAND_PB
  pela faixa PBLow/PBHigh do tom, SET_REGISTER_RAND (tom com volume < 0 lê
  o registrador). Antes era 1 ms e espera depois: no cascalho escuro os
  estalos de pedrinha (GRAVELEMENT1) saíam ~11/s, todos no máximo e no
  mesmo tom ("barulho bugado"); agora 2.65/s, volume 90-115, ±2 semitons.
  Envelope do SPU (_env_anda, ADSR de cada tom): parar é key-off (StopSound,
  0x264f28), a voz desce pelo release (0.17 s na terra e no cascalho) e a
  terra sobe em ~0.5 s. sons.json sem "versao" 2 = sfx_jogo.py antigo (o HUD
  avisa).
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
  Storm não tem ponto EXHAUST no jogo: car.gd ESCAPE_NOSSO põe dois, medidos
  na boca das ponteiras cromadas do modelo (±0.57, 0.64, -2.49), 27° pra fora.
- Motor e escape tremendo (melhoria nossa, car.gd MOTOR_TREME,
  motor_treme.gd): no jogo são parte da Body e não tremem. Separação pelas
  peças soltas da malha que cabem inteiras no cofre (atrás do banco até o
  escape, entre as rodas de trás), sem pintura "white", pneu, sem textura,
  chapas/travessas e peças grandes. A textura "engie/engine" NÃO serve: é um
  atlas usado no painel, na frente e na gaiola. Conferido com prints
  vermelhos x normais (Sphinx, Phantom, McKenzies, Viper, Hurricane, Trident:
  só o metal do cofre). Também ficam de fora: lanternas (10 cm dos pontos
  BRAKE_LIGHT etc.), vigas/tubos retos (até 8 faces e > 30 cm; compridos e
  finos), chapas deitadas; a gêmea espelhada entra junto (os 2 escapes do
  Renegade). O que a regra erra vai em motor_treme.gd AJUSTES por carro
  (Viper: bloco de 8 faces e coletor; Phantom: barra em L do escape), achado
  com print_tela MOTOR_COR=2 (uma cor por peça, legenda no console,
  MOTOR_PAGINA=1,2 pras seguintes). Storm (motor escondido): só as 2
  ponteiras tremem (pelos pontos do ESCAPE_NOSSO).
  Vibração 3 mm na lenta, filtrada (6 mm por quadro ficou "tremelento").
- Motor animado (melhoria nossa, car.gd MOTOR_ANIMA, motor_anima.gd): no
  jogo nada gira (ventoinha e polia são desenho parado na textura).
  Ventoinhas dos radiadores (textura "black" centro (89, 26) r 23 px; Trident
  "tube02" (48, 48) r 15): os triângulos da placa (caixa do UV com o centro
  do círculo; uma peça do cockpit do Renegade usa só um pedaço e fica) saem
  pra uma malha com shader que gira o círculo da textura. Elétricas (escolha
  do Matheus): 3 voltas/s fixas. 2 no Renegade, Sphinx, Mosquito, Inferno,
  Trident e McKenzies, 1 no Bulldog. Polias e correia 3D (escolha dele, no
  lugar de só girar o desenho): a "chassis_tri02" tem 2 polias desenhadas
  ((99, 23) r 9 e (100, 51) r 8 px; no Phantom e no McKenzies o UV dá uma
  volta na textura); onde caem (Phantom, Kraken, McKenzies, Viper) vira
  cilindro do raio desenhado com a tampa = o desenho do jogo girando, e uma
  correia pelas tangentes de fora com nervuras correndo. Faces em planos
  diferentes (Phantom e Viper): tampas no plano da mais saliente. Giro
  "legível": polia maior 1 volta/s a cada 1000 rpm (o real, 17 a 133
  voltas/s, é só um disco borrado), borrão do quanto girou no quadro. Presas
  na malha "Motor" (tremem junto). Trident fica sem polia: lá a textura cai
  esticada em outras peças.
- Volante tremendo (melhoria nossa, car.gd VOLANTE_TREME, _vibracao): no
  jogo nada treme (nem volante, nem mãos, nem motor: varredura do exe e
  vídeo). A força é a do motor pequeno da vibração do CONTROLE (0x202ab8:
  carro de lado, roda patinando devagar, roda travada, trancos pela
  velocidade) + pouso (0x370df0) e suspensão (0x36e498) do som + a tremida
  de curso das rodas da frente na terra (0x202760). Graus = escolha nossa.
- Sujeira (car.gd SUJEIRA, _sujeira_passo; sujeira.gd; docs Sujeira): o
  nível sobe min(v, 15)·WheelDirtRate·5e-5 a cada passo de 50 Hz com roda
  no chão (suja até no asfalto), igual em todo o carro, e só zera no
  recomeço (T no remake, car.limpar_sujeira). A água NÃO limpa a carroceria
  no jogo. Desenho: o lote do .pingu tem uma 2ª textura pelo 2º UV
  (pingu2obj -> <modelo>_camada.obj). Na carroceria só a pintura ("white")
  tem: a "dirt", trocada pela GEN_DIRT_DIRT da pista, alfa = nível x alfa
  da textura. Gaiola e peças ficam limpas (como no jogo). Nas rodas é a
  UNI_TyreOverlay: lama com a cor do DustColour do chão e alfa
  WheelDirtAlpha (some no asfalto; a água lava, 0x224418), car.gd
  _roda_suja_passo. teste_derrapagem confere os 2 com a RAM. Piloto: nível
  do carro com projeção nos 3 eixos da POSE DE REPOUSO (CUSTOM0/1 da malha;
  pela posição animada a sujeira ficava parada e o braço andava por dentro
  dela). Nosso: o jeito do jogo no piloto não foi achado.
  Sem rodar o gerar_buggies de novo não há _camada.obj e o carro não suja;
  sem o fx_jogo novo não há lama_pneu.png e o pneu não suja (o HUD avisa).
  No RX01 (taxa 0.2) a lama do pneu cresce devagar e quase só patinando
  (x10) e some no asfalto (alfa 0); na lama do Hinter Valley a taxa é 3.0.
- Painel funcional (melhoria nossa, car.gd PAINEL, painel.gd): no jogo os
  relógios são textura parada e 9 dos 12 buggies não têm. Amador (Level do
  vehicles.xml: Mosquito, Inferno, Trident, Sphinx) = conta-giros e
  velocímetro de ponteiro, fundo branco; PRO = os dois + marcha digital +
  luz de troca (5 LEDs de 85% ao rpm de troca, piscam no limitador), fundo
  preto (escolha do Matheus). Conjunto preso na coluna, atrás do volante, na
  linha do olho pela metade de cima do aro (sobe até caber na câmera do
  piloto); LADO = do lado direito do volante (Phantom, McKenzies, Hurricane,
  Storm: o volante tampava). AJUSTE por carro = números do Matheus com 9/0
  (desce/sobe) e -/= (lado) na câmera do piloto (o HUD mostra; só o
  conjunto mexe). Os relógios do modelo saem pra o nosso não ficar em cima
  de outro (pedido dele): a placa cadilac_clock do Renegade some, os
  relógios pintados da chapa b_2 do Sphinx são repintados com pixels do
  fundo (_sem_relogios; LED = mancha pequena ou vermelha fora dos discos).
  Pelo editor (F5) a textura vem com mipmaps (import "Detect 3D"): pinta o
  nível 0 e refaz os mipmaps, senão de lado os relógios velhos voltavam. O Inferno tem 5 buracos de relógio vazios em losango:
  o aro e o fundo preto saem da malha (APAGAR, _apagar_faces), e no lugar
  vão conta-giros (13 cm, pra não varar o capô), velocímetro (DO_MODELO) e
  3 auxiliares de enfeite (AUX: temperatura que esquenta no 1º minuto, óleo
  pelo giro, voltagem 12.4/14.1). No Renegade as 3 placas lisas do painel,
  as caixas pretas atrás delas e o "V" embaixo do volante (2 barras sem
  textura da coluna até o painel; APAGAR com textura "") saem e 2
  auxiliares vão presos no conjunto, um de cada lado (AUX_CONJUNTO, nos
  círculos que o Matheus marcou no print). Velocímetro = 1.06 x velocidade
  pra frente (como o do jogo); conta-giros até o limitador + 1000. Telas 2D em
  SubViewport (texto sai certo: base com determinante -1 dentro do espelho).

- Trucks (out/2026, base): 12 (TRUCK_01..12, nomes do menu do jogo em
  text/15205_en.txt: Buccaneer, Shockwave, Shinto, Jericho, Punisher, Panther,
  Herbst Truggy, Herbst TT, Hammerhead, Fireball, Goliath, Chimera). Física =
  data/vehicles/truck_base.xml (Setup/VehicleParams/Truck/TRUCK.xml, mesmo
  formato do buggy, outros números) + truck_NN.xml pelo caminho do arquivo
  (o TRUCK_03.xml do jogo é vazio: só a base). Chassis trocados: TRUCK_04 usa
  o CHASSIS_Truck_11, TRUCK_11 o CHASSIS_Truck_12, TRUCK_12 o Dakar (a
  pintura é do chassis: gerar_pintura acha pelo vehicles.xml). Mapas:
  TruckCompMap_B1/B2 (LeftFrame, RightFrame, FrontLeft/RightBrake, RearAxle
  com 2 modelos, Axle e Rear_Arm; o Rear_Arm do Shinto no 4K é vazio),
  TruckCompMap_A2 (Punisher, RearFreeAxle), BuggyCompMap_A1 (Panther, igual
  buggy) e RallyCompMap (Chimera, igual Storm). As melhorias nossas ficam
  desligadas nos trucks (car.gd melhorias, main.gd) até a base ser conferida
  com save states. Goliath parado (RAM): massa 1.90 t, marchas
  21.9/14.3/10.6/8.5/7.0, final 1.1636, CoM (0, 0.85, -0.609), curso máx
  0.55 / 0.76 = remake. O Goliath do save state tem as peças Prototype
  (motor 0.35 + 0.2 + 0.1 + 0.2, escape L3 0.1, câmbio Prototype 0.05 =
  1.0; de fábrica 0.81): com --tune engine 1.0 o remake dá embreagem
  1.023 e torque 2.964, igual à RAM. O Storm do storm.p2s também (torque
  1.764 = fully_tuned). Buccaneer de fábrica ("tudo Standard", DIRT_BUDGET):
  massa 1.70 t, marchas 17.5/11.4/8.5/6.8/5.6, final 1.0825 (Level0),
  embreagem 0.379, torque 1.088, CoM (0, 0.679, 0.414), curso máx 0.28/0.35
  = remake. Câmera dos trucks = a dos buggies (FollowOrbitFar parada: 6.87 m
  atrás e 3.0 acima no Buccaneer, 7.65/3.39 no Goliath, zoom 0.5;
  tests/teste_camera_ram.gd).
- Carro bônus resgatado (out/2026): a CHASSIS_Truck_04 está completa no
  jogo (4K, 5K, menu, COMPOSITOR 15106 com a pintura Truck_04_*) e nenhum
  veículo usa. É uma Chevrolet Silverado cabine dupla pre-runner (texturas
  preRunnerTruck_*, gravatinha da Chevrolet na preRunnerTruck_front): a
  carroceria original do Jericho ("Pre Runner"), que no vehicles.xml ficou
  com a CHASSIS_Truck_11 (sem logo nenhum; nenhum outro carro tem marca
  real). No remake é o "Silverado", último do menu (gerar_buggies.py BONUS,
  --so 13; main.gd "bonus"): física, peças de fábrica, mapa
  (TruckCompMap_B1) e decalques do Jericho, câmera TruckCamSet_04 (o
  Jericho usa a 11). Não substitui o Jericho.
- Câmera do save state: só a câmera ativa atualiza. ler_savestate pegava a
  mais perto do carro, e parado essa é uma que a introdução da corrida
  deixou (zoom 0.6027, suavização 17.85/s em a.p2s, b.p2s, Goliath e
  Buccaneer). A ativa é a de suavização ~40/s (corrigido out/2026).

## Pendente / ideias

- Trucks: conferir física andando (Punisher acelerando e virando).
  Tração: car.gd REAR_DRIVE vale pra todos (conferir nos trucks).
- Curso parado: em TODOS os carros (8 save states parados) o remake fica
  1 a 4 cm menos comprimido que a RAM (frente ~1 cm, trás ~3 cm; Buccaneer
  3.9 na frente, Goliath 4.2 atrás): o carro senta mais alto. Suspeita: o
  contato pneu-chão (0x248768; o pneu afunda 0.2 a 5.8 cm parado no jogo).
  Mexe em toda a física: investigar com rodar_testes do lado.

- Pneu e aro comprados (hipótese: troca de textura, ver docs/assets.md).
- Batida: o RX01 do remake só tem o relevo (sem paredes, cercas e pedras do
  jogo), então a tremida da batida só aparece quando o casco bate no chão.
  Trava do 0x380418 (veículo+0xa6c/0xa74/0xa78) não portada.
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
  Trucks (out/2026): 13 motores (t01..t12 + t13 Silverado), carro real pelo
  modelo 3D ou escolha nossa variando a família (docs/som_motor.md, Trucks);
  o som do motor toca nos trucks mesmo com as outras melhorias desligadas
  (car.gd _load_som); pasta pelo id (motor_som.pasta_do_carro, tNN_) ou pela
  entrada "som" do main.gd (bônus). Falta o Matheus ouvir.
- Piloto: montar a textura dele como o jogo (5 camadas por parte + cores do
  perfil; hoje usa o rider_fury pronto), LOD MID/LOW, piloto feminino.
- Câmera do piloto: referência do Matheus = cockpit do Dirt Rally 2.0
  (horizonte perto do meio, volante cortado embaixo, muita estrada).
- Sinal do giro/direção visual: falta save state andando com volante virado.
- Sujeira: água (veículo+0xae8 e o registro DAT_007f4bf8+0x20 que lava as
  rodas: cor 0, alfa 0, taxa 30, lido no save state do Hinter Valley) não
  portada: o RX01 não tem água. Reflexo menor com o carro sujo
  (0x22ace8, 1 - nível) não portado. Sujeira do piloto como o jogo.
- Para-choque e luzes comprados (componentes Bumper/Lighting; de fábrica é NOT_INSTALLED).
  Os LIGHTRIG são só modelo (sem halo); o Matheus acha feios.
