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

## Motor e câmbio

- **0x246858 motor** (struct E em obj+0x2ac): E[1] acelerador, E[2] torque,
  E[4] carga, E[5] rpm, E[6] fator do limitador, E[8] inércia extra.
  Torque = acel·lim·curva_drive(rpm)·escala − curva_atrito(rpm)·escala_atrito.
  rpm += (T − carga)·dt / inércia, preso na marcha lenta.
  Limitador em rampa: cai a Rev_limiter_engage_rate (15/s) acima da rpm de
  corte, sobe a Rev_limiter_disengage_rate abaixo da de volta.
- **0x20c558**: embreagem travada e rodas de tração no chão → rpm = rpm da
  roda × relação. Em troca (shift flag) o acelerador é multiplicado pela
  embreagem. **0x20c7a8** entradas do câmbio. **0x20c808** carga = torque da
  embreagem quando não travada.
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
- **Arrasto 0x20e5e8**: ar = Air_drag·v²·0.00065 kN. Atrito interno só com
  acelerador zero.
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
- Não portado: **0x210908** (roda travada gira a força quando slip < −0.25).

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
  (não portada) → zoom 0x3806a0 (FOV_MIN/MAX_ZOOM por mph, fração dt).
- Final 0x387320: pos = ant + min(taxa·dt,1)·(nova + dir·0.2 − ant), taxa
  10 subindo 5/s até 40.
- Projeção 0x390a80 / 0x64f0a0: meia-largura 0.5/zoom, meia-altura
  0.375/zoom (4:3). Zoom menor = mais aberto.
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
  s += min(1/dt, 30)·(direção − s)·dt (o volante do remake usa esse s, car.gd
  rider_s). mRiderMatchSteer = 0 nos buggies; IK das mãos só no ATV_Riding e
  Bike_Riding (0x1a15a0/0x1a1650), não no Truck_Riding que o Seated usa.
  Câmeras: mRenderRider = 0 em On_Front, On_Hood e Wheel (xml 14837).
  Ainda não portado (faltam parsers de .srd/.skl/.bac).
- Direção visual das rodas 0x21def8 / 0x20ede8: body+0x3c0 = direção ·
  lerp(Max_visual_steer_zero, _full, mph/SpeedMax), SpeedMax = curva
  BasicSteering/Angle_vs_speed (params+0x4e8 = 100); nos buggies 30°/30°.

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
