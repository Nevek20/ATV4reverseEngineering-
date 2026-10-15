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

- Arquivo "POINT 1.00": entradas de 0x50 bytes, nome em 0x04..0x24, xyz em
  0x24. Tabela de nomes no exe em 0x55070c (WHEEL_*, A_FRAME_*,
  A_FRAME_END_*, SHOCKS_TOP/BOTTOM_FRONT_*, SHOCK_PISTON/CHAMBER_R*, ARSE,
  LIGHTRIG, BUMPER...). "Esquerda" do jogo = x < 0 no modelo.
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

## Peças e pintura

- Component map (14881) BuggyCompMap_B: Body, Frames_*, Brake_*,
  Shock_Piston/Chamber_R*, Shock_Front_*, FrontWheel/RearWheel (Mirror=1 na
  esquerda). Animação das peças: não achei a função; o remake gira as
  balanças no pivô A_FRAME até a ponta seguir o curso.
- Pintura: textura "white" gerada em tempo real pelas camadas do XML 150xx
  (Buggy_NN_Base/Primary/Secondary/Detail + cores + decalques + número).

## Save state do PCSX2

`tools/ler_savestate.py` acha a câmera (vtable 0x5b3f30 em +0x68), o alvo,
o veículo (+0x2b0 → +0xf0) e o corpo (+0x9d4). Câmbio em corpo+0x2d0 (+0x08
marchas, +0x20 final, +0x9c embreagem máx, +0x60 rpm de subir). Motor em
corpo+0x2ac (parâmetros; estado logo antes, com rpm e limitador).
