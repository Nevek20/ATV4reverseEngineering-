# Mapa do executável (SCES_546.88, PAL)

Endereços virtuais. Dumps decompilados em `re/decomp/*.c` (gerados com o
DecompRefs.java). Unidades do jogo: massa em t, força/torque em kN e kN·m,
velocidades em mph (×0.44704 → m/s) ou m/s conforme o campo; mph = m/s ×
2.2374146 nas contas do exe.

## Carregamento de parâmetros

- `re/decomp/param_map.txt`: cada atributo do XML de física → offset no
  struct de parâmetros (ex.: Mass_non_tuned → +0x1428). Base em 0x2154c4..
- Interpolação "tunada": valor = lerp(non_tuned, fully_tuned, t), com t das
  peças (data/upgrades.xml, efeitos somados por tipo).

## Passo da física (PAL 50 Hz, NTSC 60 Hz)

- O jogo integra uma vez por quadro: 1/50 no PAL (nosso exe), 1/60 no NTSC.
  A física DEPENDE disso. Com a roda patinando em 1ª o giro vem da roda
  (0x20c558) e bate no limitador (Rev_limiter_engage/disengage_rate 15/s),
  enquanto a patinada 0x610 sobe a 3/s e volta a 4/s; o liga-desliga dessas
  rampas depende do passo. Passo menor = corte mais raso = mais força média.
- Conferido com dois vídeos: o Renegade PAL do Matheus (RX01) na 1ª vai de
  30 a 60 km/h em 1.25 s; o remake dá 1.36 s a 50 Hz e 0.92 s a 120 Hz.
  O speedrun do Sphinx (NTSC, mph) bate a 60 Hz em 1.7 mph do começo ao fim
  (a 50 Hz fica até 3.8 mph abaixo; a 120 Hz até 7 acima).
- Save state PAL patinando a 48.7 km/h (1ª): rodas de trás no limite da
  elipse (0x5c8 = 8.007 kN = 8.17 x 0.98; pedido 0x680 = 10.48), 6893 rpm,
  0x600 0.26, 0x610 0.32, limitador 1.0 naquele quadro.
- Save states PAL da largada de fábrica (acelerador no fundo, embreagem já
  travada): patinada 0x610 de trás / rpm = 0.48 / 1379 a 8.6 km/h, 0.48 /
  1568 a 9.8, 1.20 / 4763 a 19.8, 1.38 / 5766 a 22.1. A força na roda
  (0x5c8) bate com o remake na mesma patinada (7.03 kN em 0.48, 6.54 em
  1.38): o que falta é a patinada começar mais cedo. Com os pedais do
  0x202df0 e o câmbio no acelerador cru o remake dá 0.22/0.31/1.07/1.25
  (antes 0.00/0.04/0.76/0.94). Save state a 7.7 km/h: embreagem ABRINDO
  (0x314 = 2, de 1.0 pra 0.6; rpm 1013 < 1050), patinada 0.36, e o
  0x320 (rpm − rpm da roda quando começou a engatar) = 755. Ou seja, o jogo
  também cai abaixo de 1050 a ~3 km/h e reengata (remake: 786), igual ao
  remake. A diferença é que no jogo a embreagem chega a 1.0 até 7.7 km/h
  (remake 0.80): o carro anda mais devagar de 3 a 7.7 km/h. Hipótese: o
  freio automático segura mais no jogo; no remake o ABS solta o freio
  quando a roda para com o carro a ~1e-5 m/s (0x600 = −1) e o carro anda
  de passo em passo. Sobra uns 0.09 s na frente entre 5 e 14 km/h.

## Ficha do carro (tela de opções da corrida)

- **0x1f5e90** monta a ficha a partir dos parâmetros já com as peças
  (0x21d618: para cada slot i, (1-t)·P[0x1350+8i] + t·P[0x1354+8i]; slot 1 =
  Drive_torque -> P+0x58). Power HP = P+0x58 · 250 (classes 2 e 3) ou · 264
  (0 e 1); Weight lbs = massa (t, P+4) · 2204.6; Cornering = 10·(1 - (P+0x53c
  - mín)/(máx - mín)). Faixas por classe em 0x847cd0 (6 floats): classes 0/1
  potência 0.05..0.25, peso 0.07..0.18 t; classes 2/3 potência 0..3.8, peso
  0..2.4 t, cornering 16..27. O texto trunca: 1.08·250 em float dá 269.99997
  e aparece "269.9" (motor todo preparado).
- Peças de motor do buggy (upgrades.xml <Buggy>): Internals até 0.35,
  Management 0.2, Header 0.1, Exhaust 0.1, Intake 0.2 e o câmbio Prototype
  soma mais 0.05: máximo 1.0.

## Motor e câmbio

- **0x246858 motor** (struct E em obj+0x2ac): E[1] acelerador, E[2] torque,
  E[4] carga, E[5] rpm, E[6] fator do limitador, E[8] inércia extra.
  Torque = acel·lim·curva_drive(rpm)·escala − curva_atrito(rpm)·escala_atrito.
  rpm += (T − carga)·dt / inércia, preso na marcha lenta.
  Limitador em rampa: cai a Rev_limiter_engage_rate (15/s) acima da rpm de
  corte, sobe a Rev_limiter_disengage_rate abaixo da de volta.
- **0x20c558**: embreagem travada e rodas de tração no chão → rpm = rpm da
  roda × relação. Em troca (shift flag) o acelerador é multiplicado pela
  embreagem. **0x20c7a8** entradas do câmbio: o acelerador do câmbio
  (câmbio+0xc) é o CRU 0x37c, não o suavizado. Ele entra na rampa da
  embreagem (2·(1 + t²) por s), na rpm de engate, no "engata solto acima de
  5 mph" e na troca. **0x20c808** carga = torque da embreagem quando não
  travada; travada, Σ "torque" do freio/relação (sem massa; só pesa com as
  rodas de trás fora do chão, não portado).
- **Pedais (corpo+0x368)**: cada comando tem cru e suavizado (InputRates):
  direção 0x36c/0x370, acelerador 0x37c/0x380, embreagem 0x384/0x388 (InputRates/Clutch; o jogo não tem freio de mão),
  freio 0x38c/0x390, flags 0x394. O motor (E[1] = 0x2b0) e o arrasto
  usam o suavizado; câmbio e "preso" usam o cru.
- **0x202df0** pedais do jogador no AutoManual (veículo+0xb14 = 1), mph =
  v pra frente·2.2374146: acima de 1 mph modo frente (corpo+0x2d8 = 0) e
  espera 0.1 s (veículo+0xb2c). Senão: soltar o freio zera a espera; freio
  gasta a espera e depois engata a ré (0x2d8 = 1) com o freio virando
  acelerador; acelerador volta pra frente (de ré a mais de 1 mph vira
  freio). Sem pedal e |v| < 0.2 mph (DAT_00550508): freio 1.0, a barra
  vermelha cheia na largada. No ar (0x4e4 > 0) o acelerador fica cortado
  até ser solto uma vez no voo (veículo+0xb30). car.gd _pedais_auto,
  tests/teste_pedais.gd.
- **Câmbio** (struct G em obj+0x2d0, params GP = P+0x138):
  0x2474a0 AutoManual (modo 3): troca por velocidade do carro.
  Velocidade de subir = up_rpm·r·rpm2rad/(relação·final); descer como
  0x246d88. Embreagem: 0 aberta, 1 engatando, 2 desengatando, 3 travada
  (trava com |dif| < lock_diff ou quando o escorregamento troca de sinal).
  Torque: estado 3 = torque do motor; 2 = min(cap, T>0); 1 = sinal·emb·cap.
  0x2470c0 Manual. Índices: 0 = ré, 6 = neutro.
- Força de tração: 0x310/(r·n_tração) por roda de tração no chão (contagem
  estática 0x3a8). Ré: Speed_limit / Drive_cut_speed_threshold; 0x20c278
  limita a velocidade de ré.
- **Arrasto 0x20e5e8** (na força 0x1a0, contra a velocidade 0x90, |v| =
  0xe0): kN = (Air_drag_coefficient·0.00065 + Damping médio 0x788 ·
  Ground_drag_coefficient·0.01)·v² + água (veículo+0xae8 ligado: média de
  veículo+0xaec+4i, Water_drag_*; não portado), no máximo massa·v/dt.
  Params+0x3e0..0x3fc = Misc (Air 1.25, Ground 2.0, água 0.5/0.1, atrito
  interno 5/80/3/5; iguais nos 6 save states). Atrito interno só com
  acelerador (0x380) zero e roda no chão.
- **Slip alvo 0x2101e0**: usa RpmMax da curva (9000), ou 0.95×limitador
  quando |direção| > 0.5 e < 40 mph.

## Suspensão

- Classe da roda vtable 0x585cc0: +0x1c integra (0x2484c8), +0x24 contatos
  (0x248768), +0x2c mola (0x248a80).
- F = k·curva(x/max ou x/min)·x + c·curva(|v|)·v (kN), ao longo da normal
  do chão no ponto de fixação. x < 0 com contato puxa o carro pra baixo.
- Batente x > max = correção de posição (regra de junção 0x23f6c0,
  aplicada em 0x23f5a0). Roda tem massa (0.05 t); x e v integrados.
- Anti-pitch 0x2100a0: acima de sen 5° (cheio a 10°) acelera I·5.5 rad/s²
  de volta. No ar, Pitch_torque constante (−0.5 kN·m).

## Pneus e derrapagem

- **Powerslide = "Clutch Turn"** (0x214610, chamado em 0x20cea0 antes do
  0x2101e0 só se Powerslide/Growth_rate P+0xf64 > 0; treino: "Tap ... to
  initiate a clutch turn"). Estado corpo+0x74c, quantidade 0x744, escala
  0x748 = Scale_vs_speed(mph do 0x440), embreagem do passo anterior 0x740.
  0 -> 1: direção suavizada 0x370 != 0, acelerador 0x380 > 0 e a embreagem
  0x388 SOLTANDO (< 0x740). 1: quantidade += Growth_rate·dt até 1 (-> 2);
  embreagem subindo ou acelerador 0 -> 3. 2: embreagem subindo -> 0 (a
  quantidade fica); acelerador 0 ou direção·derrapagem 0x6c0 >= 0 -> 3. 3:
  quantidade −= Decay_rate·dt até 0 (-> 0). No ar > Maximum_air_time (0.1)
  zera. Efeitos: em 1/2 a elipse 0x670 das rodas de tração vai pro mínimo
  da curva × Scale_of_min_friction_ellipse_scale (0x214610 e 0x2101e0); em
  qualquer estado != 0 o Side_deceleration_to_fwd vira o do Powerslide
  (P+0xf70, 1.0 x 0.75; 0x20efa0); quantidade·escala mistura a curva de
  taxa de subida da derrapagem com Maximum_sideslip_rate_vs_sideslip do
  Powerslide (P+0xecc; 0x210ce0). Estado 3 escala a tração por
  Decay_drive_force_scale (1 nos buggies) e soma Decay_boost_acceleration
  (0 nos buggies). Nos 4 save states de derrapagem o estado era 0: a
  derrapagem "natural" de virar forte não usa o powerslide.

- **Conferido com save states** (tests/teste_derrapagem.gd, tests/
  ref_derrapagem.json; Renegade no RX01 a ~120 km/h, volante todo e
  acelerador no fundo): o remake no estado exato da RAM dá a mesma força
  por roda (0x5c0: x = lateral pro lado direito do carro, z = pra frente,
  kN) em poucos %; a 30 km/h a 60° a lateral da frente fica 14% abaixo
  (7.9 x 9.2 kN). Do drr_3 (118 km/h, −42°, 84°/s) até o drr_2 (1.16 s
  depois pelo relógio do Screenshot.png do .p2s) o remake termina a 0.4 m:
  30.0 x 30.7 km/h, girou 122 x 120°, derrapagem −67 x −60°, giro 163 x
  179°/s. No jogo o carro também roda segurando o volante todo.
- Estado da RAM pro remake: corpo = (−direita, cima, frente) do jogo
  transpostos (Terrain.dir_do_jogo), origem = origem do modelo menos
  corpo(0); velocidade angular = −dir_do_jogo(w) (vetor axial na
  transposição). O curso da RAM é do fim do passo, já subido até o chão
  (pen = 0); o teste tira 1 mm pra roda contar como no chão.

- **0x211b58 aplicação das forças**: por roda, em CoM + n·(soma do y do
  contato do eixo relativo ao CoM × escala) + frente·z_do_eixo.
  Lateral_scale_std 0.09; longitudinal = mistura de 0.5 e 0.2 por 0x474
  (= acel·frac·Side_decel_to_fwd).
- **0x20bf58 eixos 0x3ac/0x3b0**: média do z das rodas em coordenadas do
  MODELO (não relativo ao CoM). Entra na curvatura, divisão lateral e ponto
  de aplicação.
- **0x210ce0 limitador da taxa de sideslip**: β' = ((v_f·ΣFx − v_l·ΣFz)/m/v²
  − guinada)·sgn; máximo das curvas Sideslip/MaximumRate increase/decrease
  (rate_vs_sideslip); excesso vai direto pra velocidade angular. Abaixo de
  30 mph: guinada ≤ v / distância até a roda dianteira se a velocidade
  estiver > 30° da direção da roda.
- Contagens estáticas: força de sideslip nas 4 rodas dividida por 2/2;
  elipse em todas; tração e freio só nas rodas no chão mas divididas pela
  contagem estática (0x20efa0 / 0x20eb98).
- **0x20e160**: no chão, cancela a componente lateral da gravidade em
  rampa, aplicada na altura do chão.
- No ar **0x2129c0**: guinada (alvo direção·máx, acel direção·acc·dt),
  empurrão lateral (Maximum_force 2.5 kN, cauda de 2 s), arfagem com freio /
  sem acelerador.
- Patinada por roda **0x610+4i** (0x2101e0, 2ª volta): roda saturada na
  elipse com força·v_f > 0 cresce Growth_rate_during_wheel_spin até o limite
  do motor (giro de referência, Maximum); com força contra o movimento e
  pedal (0x390) > 0.1 desce Growth_rate_during_wheel_lock até −1. Fora da
  elipse volta pra 0 (Recovery_rate_during_wheel_lock / _spin). Sem
  condição de acelerador nem de marcha (vale em ré).
- **Freio 0x20eb98**: desaceleração = pedal 0x390·0.44694445·
  Maximum_deceleration·escala(atrito 0x780), no máximo o que zera a
  velocidade PREVISTA (0x211e48, com a tração 0x5c8 e o 0x1a0 já somados:
  gravidade do 0x20e160 e arrasto). Ordem no passo (0x20cd2c): 0x20da90,
  0x20df58, 0x20e160, 0x20e5e8, 0x20e8d8, 0x20eb98, 0x20ede8, 0x20efa0,
  0x2100a0. Por isso o freio segura o carro parado contra a tração.
- **ABS 0x20eb98** (flag 0x620+4i): Enable_ABS do Footbrake; patinada medida
  (0x600) <
  ABS_engagement_slip_ratio (−0.2) solta o freio da roda, ≥
  ABS_disengagement_slip_ratio (−0.01) volta. Todos os buggies têm ABS
  (conferido na RAM). Roda fora do chão zera a flag.
- **Trava 0x210908** (depois da elipse, antes do 0x210ce0; globais
  0x5506a4..b4 = ligado, 2 mph, −0.25, −1, rampa linear): roda sem ABS
  soltando, com patinada medida (0x600) < −0.25, tem a força (mesmo tamanho) virada pra
  contra o deslize do contato: velocidade local do corpo (0x410, global
  0x550680 = 0) com a frente trocada por −v_f·patinada (0x630, 0x20df58).
  Em −1 fica toda contra. Com o ABS dos buggies não chega a agir.

## Giro das rodas

- Ordem do passo (0x1727a0): motor/câmbio 0x209e38 (0x20c0d0 guarda a
  posição em 0x880, 0x20c558 giro do motor) → integra corpo e rodas → pneus
  0x20a0b0 (0x20df58 patinada medida, ABS, forças, 0x20cea0: 0x2101e0
  patinada, 0x210908 trava, 0x210ce0, **0x2113e0 torque das rodas**,
  0x211b58).
- Roda (vtable 0x585cc0): raio W+0x30, inércia W+0x3c = Mass·R²/2 (RAM
  0.00625 / 0.0060025 t·m²), flags W+0x40 (2 = tração, 4 = frente), torque
  W+0x44, giro W+0x48, ângulo W+0x4c. **0x2484c8** integra: ω += T·dt/I,
  ângulo += ω·dt (mod 2π). 0x249930 é de outra classe de contato de pneu que
  os buggies não usam (sem instância na RAM).
- **0x20df58** patinada medida 0x600 = ω·R/v_f − 1 (v_f = 0x418; 0x550680 =
  0, não usa a velocidade do ponto da roda); |v_f| ≤ 1e-6 → 0.1·ω (0x550684);
  roda no ar → 0. Quem lê: ABS, trava, 0x630, 0x20c558, partículas/vibração.
- **0x211e48** v_ref = v_f + (Σ forças pra frente das rodas 0x5c8 + força
  0x1a0 · frente) · dt / massa: a velocidade prevista no fim do passo.
- **0x2113e0** torque por roda. Contagens 0x3a0 (frente), 0x3a4 (trás), 0x3a8
  (tração), 0x3cc = rodas de TRÁS no chão (W+0x18 < 0, 0x20d568).
  Motor na roda = embreagem 0x2ec · relação total 0x300 · torque 0x2b4 ·
  0x720 (=1) / 0x3a8. "Torque" do freio = pedal·0.447·Maximum_deceleration·
  escala(atrito médio 0x780)·(Front_bias ou 1 − bias)/rodas do eixo·R, SEM a
  massa. Roda solta no chão: T = I·(v_ref·(1 + 0x610)/R − ω)/dt (ω vira o
  alvo exato). Solta no ar: perde max(180°/s² 0x5506c4, freio/I). Tração
  com 0x3cc ≥ 1: igual à solta no chão (ou, preso, giro do motor·embreagem/
  relação). Tração com 0x3cc = 0: embreagem travada (0x314 = 3) → giro do
  motor/relação; senão motor − sinal(ω)·freio, com freio maior parando a
  roda e motor maior sem passar do giro do motor.
- Preso (0x890/0x894/0x870): acelerador 0x37c > 0, botão da embreagem 0x388 = 0,
  |v_f| < 0.5 e o corpo dentro de 3 cm (0.0009 m²) por mais de 0.33 s. Aí
  v_ref = deslocamento do passo (0x70 − 0x880)·frente/dt e o giro do motor
  não vem das rodas.
- **0x20c558** (motor): 0x304 = ω da roda de tração mais rápida·9.549;
  embreagem travada, não preso e 0x3cc ≥ 1 → rpm = 0x304·relação (mín.
  marcha lenta). Embreagem forçada aberta 0x31c: 0x5ac, botão da embreagem 0x388 > 0.1,
  mais de 1 s no ar (0x3d0) abaixo de câmbio+0x90 (1050 rpm), ou pedal >
  0.9 com roda de tração em 0x600 < −0.9 (0x55067c).
- No chão o 0x600 de um passo sai igual à 0x610 do anterior (por isso a
  aproximação antiga dava os mesmos números); muda em derrapagem (v_ref não
  conta o giro do carro), no ar (tração gira com o motor, frente perde
  giro), parado contra um muro e na roda da tela. tests/teste_roda.gd.

## Pontos do modelo

- Arquivo "POINT 1.00": contagem em 0x10, entradas de 0x50 bytes a partir
  de 0x14: nome 0x00..0x20, xyz em 0x20, matriz 3x3 em linhas em 0x2c
  (escala 0.01; na RAM fica normalizada, +0x30/+0x40/+0x50 do objeto).
  Loader 0x62fa18; tabela por id 0x222b38 (enum em 0x550700: 1..4 WHEEL,
  9..16 A_FRAME/A_FRAME_END, 21..24 SHOCKS_BOTTOM/TOP_FRONT, 25..28
  SHOCK_PISTON/CHAMBER, 29/30 SpareWheel, 31 LIGHTRIG, 32 BUMPER). Nomes
  também em 0x55070c. "Esquerda" do jogo = x < 0 no modelo.
- CoM do XML em coordenadas do modelo. Corpo físico +0x70 = CoM; veículo
  +0xaa0 = origem do modelo (= CoM − R·CoM_local).

## Câmera (BuggyCamSet_NN em data/cameras.xml = 14880)

- Loader 0x38d5f8 (offsets dos parâmetros), defaults 0x38d498, caller
  0x38ce58 (lê CameraSets, 12 câmeras de seguir + 6 montadas).
- Construtor da órbita 0x38dc30; update base 0x387320 (passo fixo 1/60;
  reset 0x38e0c0 = 0.5 s de updates). Só a câmera ativa atualiza.
- Componentes em ordem: altura por velocidade 0x383418 (m/s) → offset no
  frame do carro só com guinada 0x383588 → amortecimento Y 0x383cf8/0x384168
  (taxa de subida se vy > 1; cai na hora, volta devagar) → subida em descida
  0x385238 (−dir.y·DOWN_INCLINE, DECAY, taxa máx) → órbita 0x386950
  (direção = frente puxada pra velocidade por MaxCourseFollowAmount;
  SlerpRate e no máx SlerpMaxAngle graus por passo; distância por mph) →
  descolar/recolar 0x384ef8 (MAX_POS_CHANGE 1, BEGIN 2 s, REATTACH 2 s) →
  altura mínima do chão 0x384c80 (1.45 m, taxa 30) → mira 0x37f2f8
  (LOOK_OFFSET; y da mira some com mph/LOOK_MAX_SPEED) → tremida 0x380418
  (camera_jitter.gd, abaixo) → zoom 0x3806a0 (FOV_MIN/MAX_ZOOM por mph,
  fração dt).
- Final 0x387320: pos = ant + min(taxa·dt,1)·(nova + dir·0.2 − ant), taxa
  10 subindo 5/s até 40.
- Projeção 0x390a80 / 0x64f0a0: meia-largura 0.5/zoom, meia-altura
  0.375/zoom (4:3). Zoom menor = mais aberto.
- Tremida (vtable 0x5b4fb8: update 0x380418, aplica 0x380170; construtor
  0x380348/0x380090, loader 0x38cc48). Parâmetros só do GenericCameraData
  pelo tipo da câmera (os Jitter* dos CameraSet são ignorados: conferido nos
  componentes vivos na RAM). Defaults: SpeedStart 0, SpeedMax 1, Perlin 0,
  Decay 0.95, CollSpeed 10/30, CollMass 0.01/0.1.
  Velocidade: f = clamp((|v| − Start·0.44694445)/((Max − Start)·0.44694445)),
  a = veículo+0xac0·f², e veículo+0xac0 = média do WheelJitter embaixo de
  FL, RL, FR no chão (0x202760). Duas ondas Perlin (Amp/4, Freq) e
  (Amp, Freq·1.05), fase sorteada; n = tabela(fase)·amp·a, fase += dt·freq
  mod 1 (0x3aa668/0x3aa6e0, tabela de 257 floats em RAM 0xd0e7f0 =
  data/ruido_camera.bin). Direção nova = dir + direita·n1 + cima·n2,
  matriz refeita (0x61e010). Órbita: 70 a 100 mph, Amp 0.03, Freq 0.3;
  capô/para-choque: 0 a 75 mph, Amp 0.04, Freq 0.25.
  Batida (NÃO portada, falta o sistema de colisão): última colisão do corpo
  (corpo+0x7a0 + idx·0x40, idx = corpo+0x860, −1 sem) dá c = rampa da
  velocidade (CollisionSpeedFor*) × rampa da massa do outro (+0x60 → +0x78,
  CollisionMassFor*) × CollisionJitterMagMax; amp = max(c, amp)·Decay por
  passo (com trava por veículo+0xa74/0xa78), somando sorteio uniforme
  [−amp, amp) nas duas componentes (x·31415821+1 mod 2^30, semente 0x8383a8).
- Câmeras montadas (MountOnHood/Front): PosOffset no frame do modelo,
  Orientation.X em graus, FOV fixo. MountOnFront fica dentro da carroceria
  (não desenha o carro).

## Peças (cCompPlace_<Position>)

- Cada componente do component map vira uma classe
  sprintf("cCompPlace_%s", Position) (0x222d88; registro 0x5502c8, fábricas
  0x208d40..0x2097e8, vtables 0x5801e0..0x580898). O método +0x1c
  (0x1fc150..0x1fd8c8) copia 4 linhas de uma pose P que fica no scratchpad
  (0x70000000, 0xe70 bytes) e é recalculada por quadro, sob demanda
  (0x21dff8..0x221d58). Monta P: 0x203930 / 0x221e48; render 0x22ace8.
- Convenção vetor-linha: v' = v·R + t, linhas = eixos. No Godot: colunas do
  Basis = linhas do jogo. Rx/Ry/Rz 0x61e1a8/0x61e2a0/0x61e528 = Basis(RIGHT/
  UP/BACK, a); eixo-ângulo 0x61e6c8 = Basis(u, a).
- Curso visual 0x222078: W+0xe8 + tremida (veículo+0xab0+4i). Rodas na
  ordem FL, RL, FR, RR (corpo+0x254).
- Balança (0x21eec0 FL, 0x21f050 FR, 0x21f1b8 RL, 0x21f320 RR): u = linha 2
  da matriz do A_FRAME_*, d = A_FRAME_END − A_FRAME, r = |d.x·u.z + d.z·u.x|,
  ângulo = atan(x/r), gira em volta do A_FRAME. Frente e trás iguais; o eixo
  sai do arquivo (Bulldog frente em x, Phantom trás e Storm em z).
- Centro da roda (0x220110..0x220460): WHEEL girado com a balança; só na
  frente o y vira WHEEL.y + x. Roda dianteira R = Rx(giro)·Ry(direção),
  traseira Rx(giro); esquerda com a linha 0 negada. Não herda a balança.
- Freios: frente (0x221748) R = Ry(direção), t = centro − WHEEL·R; trás
  (0x221928) só translada até o centro.
- Amortecedor dianteiro (0x21f590): rígido, Rz(±acos(...)) em volta do
  SHOCKS_TOP até o SHOCKS_BOTTOM girado (negativo na esquerda). Traseiro
  (0x21fb68..): câmara e haste com Rx(atan(...) − atan(...)), haste levada
  até o SHOCK_PISTON girado (x original). atan, não atan2.
- Rally (0x220528 / 0x220cf0): roda = WHEEL + x·dir, sem balança.
  Estepe/LIGHTRIG/BUMPER (0x221a88..): matriz e posição do ponto, fixos.
- Tremida 0x202760 (portada, car.gd _wheel_jitter): uma vez por passo de
  física (50 Hz no PAL: FUN_00172778, obj+0x70 = 50 se 0x7f3e8c == 3),
  todos os veículos. Zera as 5 entradas; pra FL, RL, FR (pula a RR) no chão
  (corpo+0x898+4i = W+0x10c): amp = min(1, WheelJitter·0.06392613·v), com
  v = corpo+0x440 (m/s no plano do chão, 0x20d568) e 0.06392613 =
  2.2374146/35; x = (x·31415821 + 1) mod 2^30 (gerador do piloto, semente =
  relógio em ms + índice); tremida = amp·(x·0.075/2^30 − 0.0375). Depois
  RR = RL (vem do eixo rígido dos ATVs, cCompPlace_RearFreeAxle 0x21ee00).
  WheelJitter = Materials.xml da pista (+0x3c, loader 0x3a9608): RX_01 0.3
  na terra/cascalho/grama, 0 no asfalto e gelo; material da roda = do
  triângulo do contato (W+0x140). A largada do RX_01 é asfalto. Entra em
  0x222078 (curso visual, sem clamp depois), então mexe balança, cubo,
  freio e amortecedor. tests/teste_tremida.gd.
- Conferido: tests/teste_pecas.gd compara 100 matrizes de 6 carros
  (Renegade, Sphinx, Inferno, Bulldog, Phantom, Storm) com a RAM dos save
  states parados na largada, erro < 0.01 mm. Classes das rodas de rally:
  método +0x1c 0x1fd1c0 FL, 0x1fd248 FR, 0x1fd2d0 RL, 0x1fd358 RR; estepe
  0x1fd730. Os caminhos carregados na RAM (Models_4K/Chassis/..., Wheel/...)
  são os mesmos do pecas.json de cada carro.

## Piloto e volante

- O volante NÃO gira no jogo: faz parte do BODY.pingu, desenhado com a
  matriz do carro (cCompPlace_Body +0x1c = 0x1fc100, identidade). Nenhum
  .pingu tem índice de matriz por vértice. O volante girando do remake é
  melhoria (car.gd VOLANTE_GIRA; tools/volante.py acha o aro).
- Quem mexe com a direção é o piloto: Driver="Seated" ->
  cDriverComponentFactory_Seated (0x1fe918, 0x1b1508) -> AObjectRider
  (0x1829c8), sentado no ponto ARSE (rider+0x2f0; origem = ARSE −
  (0, 1.1315, 0.3032)). Modelo MALE_HIGH/MID/LOW.srd (other/00514..00516),
  esqueleto InGame_Mid.skl (00519, 47 ossos). Animação Truck_Riding
  (Setup/RiderAnimation.xml): clip STEER_LEFT.bac (00312) tocado no tempo
  |s|·(1/6 s), espelhado com s > 0 (0x190e50). s suavizado em 0x187060:
  s += min(1/dt, 30)·(direção − s)·dt (o volante do remake usa a mesma
  suavização com o sinal trocado: car.gd rider_s = −s, + = esquerda). mRiderMatchSteer = 0 nos buggies; IK das mãos só no ATV_Riding e
  Bike_Riding (0x1a15a0/0x1a1650), não no Truck_Riding que o Seated usa.
  Câmeras: mRenderRider = 0 em On_Front, On_Hood e Wheel (xml 14837).
  Ainda não portado (faltam parsers de .srd/.skl/.bac).
- Direção visual das rodas 0x21def8 / 0x20ede8: body+0x3c0 = direção ·
  lerp(Max_visual_steer_zero, _full, mph/SpeedMax), SpeedMax = curva
  BasicSteering/Angle_vs_speed (params+0x4e8 = 100); nos buggies 30°/30°.

## Terreno (STREAMT/RX/RX01.000)

- tools/extrair_material.py decodifica o stream (formato no cabeçalho do
  script): 64 tiles de 128 m, patches 9x9 (FUN_0029bcb0, tabela 0x550c00),
  altura = FUN_00299a60 com a diagonal (i+1, j)-(i, j+1). A mesma diagonal
  do HeightMapShape3D do Godot (Godot Physics e Jolt, testado). Grade de
  1 m em assets/terrain/rx01_height.bin; o .bin antigo errava 1,5 m em
  média (até 32 m).
- Material: entrada E do tile, uma a cada 2 m, byte0 & 0xF = índice i ->
  Material_(i+1) do Levels/RX_01/Env/Materials.xml (unpacked/xml/12280,
  copiado em data/materials_rx01.xml). Mapa em rx01_material.bin.
- Os .bin ficam no layout do jogo (linha = z, coluna = x); terrain.gd
  transpõe na carga (ver Mão abaixo).
- Conferido: contato das rodas (W+0x130) e material (W+0x140) dos 6 save
  states da largada: altura a 0,1 mm, material 2 (COMMON_3 TARMAC) igual.
  tests/teste_chao.gd + tests/ref_ram_chao.json.
- Largada: centro das rodas no jogo (580.8, z 1564.3), frente a −115,1°;
  no remake (540.3, 580.8) e −154,9° (main.gd SPAWN_XZ/SPAWN_YAW).
- Atrito por material (0x20d568): cada roda no chão copia 3 campos do
  registro do material embaixo dela (veículo+0xd0 + idx·0x60, montado na
  carga pro pneu do carro) pra corpo+0x750+12i: atrito, Hardness, Damping;
  material −1 dá (1, 0, 0) e não soma. Médias 0x780/0x784/0x788 = soma das
  rodas com material / rodas no chão (0x3c8); no ar, 0. Tabela do carro =
  24 registros (o loader 0x3a9608 aloca 0x900), igual nos 6 save states
  (tests/ref_ram_chao.json "tabela").
  Registro (conferido na RAM, 13 materiais): +0x00 atrito = override
  "FRICTION TYRE <classe> <valor>" do Materials.xml (DIRT_BUDGET: 0.80
  terra, 0.69 fora da pista, 1.10 asfalto), +0x04 Hardness, +0x08 Damping,
  +0x10..0x2c cores de poeira e sujeira, +0x3c WheelJitter, +0x40
  Bounciness, +0x44 Sink, +0x4c Rockiness. Classe do pneu =
  vehicles.xml DefaultConfig Tire (todos os buggies: DIRT_BUDGET).
- Quem usa: a elipse (0x2101e0) e a tração (0x20e8d8, só com
  TractionControl ligado, desligado nos buggies) usam o atrito da roda com
  min(·, 1); a elipse desliga com atrito ≥ Disabling_friction (2.0,
  params+0x43c). Freio, derrapagem e o resto usam a média 0x780, que acima
  de 1 cai no valor "Special" do trio. Damping médio = arrasto do chão
  (0x20e5e8): 0.2 fora da pista, 0.1 cascalho, 0 terra comum e asfalto.
- Não usados pelo buggy (varri 0x100000..0x480000 decompilado): a média da
  Hardness (0x784) não tem leitor; Bounciness (+0x40) e Sink (+0x44) são
  carregados e copiados mas ninguém lê (nem da tabela global DAT_007f4bf8,
  que só é lida pra nomes, IsDirt +0x48 e WheelDirtRate +0x54). A função
  0x238e08 que lê +0x754 é de outra classe de veículo. Os outros leitores
  do material (veículo+0xa88) são poeira, som, marca de pneu e sujeira da
  roda (esta usa o giro W+0x48 e a patinada 0x600).

## Mão (espelho)

- O jogo é mão esquerda: x direita, y cima, z frente; WHEEL_*_LEFT em x < 0
  no modelo e, no mundo, FL - FR aponta pra -(cima x frente) se lido como
  mão direita. O Godot é mão direita, então copiar os números direto
  espelha tudo (foi assim até out/2026; o Matheus confirmou no jogo).
- Carro: S = diag(-1, 1, 1). car.gd põe malha, suspensão (cCompPlace),
  rodas e volante embaixo de um nó com escala S, em frame do jogo (o
  teste_pecas continua comparando direto com a RAM). Física no frame do
  Godot: ponto do jogo -> car.corpo(p) = (p + model_offset)·S; esquerda do
  jogo = +X (w.left). Rotação em y e z troca de sinal sob S (em x não): o
  ângulo das rodas no jogo é -steer·vis_steer (steer + = esquerda no
  remake, então no jogo ângulo + = direita, como o STEER_LEFT espelhado com
  s > 0 do piloto). Volante: -rider_s.
- Mundo: W = transposição, remake (X, Y, Z) = (z − 1024, y, x) do jogo
  (Terrain.do_jogo / dir_do_jogo / pro_jogo). Inverter só o x também
  resolveria a mão, mas trocaria a diagonal das células do terreno.
  Pose de um carro do jogo no remake: W·T_jogo·T(−model_offset)·S, yaw do
  remake = 90° − yaw do jogo.
- Câmeras (cameras.xml): PosOffset/LOOK_OFFSET com x negado e Orientation
  com y e z negados (pseudovetor), no game_camera._parse.
- Sol: Sun Dir do Environment.xml do RX_01 (12282) passado por W.
- Física: espelho exato (accel igual; curva pra esquerda nova = curva pra
  direita antiga, Renegade e Mosquito com diferença zero; Sphinx igual até
  uma derrapagem de 48° em 8,6 s, onde 1 rpm de ruído cresce).

## Archive

- Busca por caminho FUN_0066c978 (0066d110 / 0066d270 / 0066d308): CRC32 de
  cada pedaço do caminho em minúsculas (refletido, tabela 0x7d3298, init −1,
  sem xor final), árvore varint no archive.bin (RAM 0x89ab50, 0x3d00b
  bytes). Ver re/indice_archive.py e data/arquivos.tsv.

## Pintura

- Textura "white" gerada em tempo real pelas camadas do XML 150xx
  (Buggy_NN_Base/Primary/Secondary/Detail + cores + decalques + número).

## Save state do PCSX2

Rodas: ponteiros em corpo+0x254 (W), curso W+0xe8, giro W+0x4c (a tag
0x585cc0 fica em W−0x1c e às vezes está sobrescrita). Lista de peças do
buggy: 21 pares (flag, ptr) em 0x11dbce0 (a.ram), matriz em linhas no
pacote VIF apontado (rodas no mundo, peças no frame do modelo).
`tools/ler_savestate.py` acha a câmera (vtable 0x5b3f30 em +0x68), o alvo,
o veículo (+0x2b0 → +0xf0) e o corpo (+0x9d4). Câmbio em corpo+0x2d0 (+0x08
marchas, +0x20 final, +0x9c embreagem máx, +0x60 rpm de subir). Motor em
corpo+0x2ac (parâmetros; estado logo antes, com rpm e limitador).
