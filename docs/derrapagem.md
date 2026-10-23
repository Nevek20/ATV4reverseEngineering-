# Derrapagem do jogo, legível

Versão comentada das funções do exe (SCES_546.88, PAL) que fazem o carro
derrapar, na ordem em que rodam no passo da física. Não é o C do Ghidra: é o
que cada função faz, com nomes no lugar de offsets. Os números são do
Renegade (buggy_base.xml + buggy_10.xml) quando não dito.

O jogo não simula pneu de verdade. A derrapagem sai de três peças:

1. um **controlador de ângulo de derrapagem** (0x20efa0) que pede força
   lateral e torque de giro pra levar o carro a um ângulo alvo;
2. uma **elipse de atrito por roda** (0x2101e0) que corta o que o pneu não
   aguenta. É ela que deixa a traseira escapar;
3. um **limitador da velocidade de derrapagem** (0x210ce0) que mexe direto
   no giro do carro quando o ângulo muda rápido demais.

Mais dois ajudantes: o **corte de recuperação** (0x2120c0), que decide se o
carro volta sozinho, e o **powerslide** (0x214610, a "Clutch Turn").

No remake tudo isso fica em `car.gd`, `_tires()` e funções chamadas dali.

## Convenções

- Frame do carro do jogo: x = direita, y = cima, z = frente.
- `v_f` (corpo+0x418) velocidade pra frente, `v_l` (0x410) pro lado,
  `v_p` (0x440) no plano do chão. `mph = m/s x 2.2374146`.
- `beta` (0x6c0) ângulo de derrapagem: + = velocidade pra direita do bico.
- `steer` (0x370) direção suavizada, + = direita; `steer_raw` (0x36c).
- `thr` (0x380) acelerador suavizado.
- `yaw` giro do carro em torno do eixo do chão, + = virando pra direita.
- `mu` (0x780) atrito médio das rodas no chão. `tripla(tab, mu)` (0x21d8b0)
  escolhe entre os valores Minimum_friction / Maximum_friction / Special do
  XML pelo atrito; `curvas(tab, mu, x)` (0x21d938) faz o mesmo com curvas.
- `I_y` (corpo+0x104) inércia de giro: 3.808 t·m² no Renegade.
- `eixo_f`, `eixo_r` (0x3ac, 0x3b0): z médio das rodas a partir da ORIGEM do
  modelo: 1.5724 e -1.9324.
- No remake o corpo é espelhado: `steer` e `beta` têm o sinal trocado,
  então o produto `steer * beta` é o mesmo do jogo.

## Ordem no passo (0x20cd2c e 0x20cea0)

```
0x20ede8  curvatura pedida pela direção
0x20efa0  controle de derrapagem (chama 0x2120c0 nos modos B e C)
...       (0x2100a0 anti-arfagem)
0x214610  powerslide (só se Powerslide/Growth_rate > 0)
0x2101e0  elipse de atrito por roda + patinada (0x610)
0x210908  roda travando
0x210ce0  limitador da velocidade de derrapagem
0x2113e0  giro das rodas
0x211b58  aplica as forças de cada roda
```

## 1. Curvatura (0x20ede8)

```python
delta = steer * Angle_vs_speed(mph) * DEG          # ângulo das rodas
kappa = delta / ((eixo_f - eixo_r) + v_p**2 * Understeer_coefficient * DEG / G * 0.001)
if abs(v_f) < 0.223472:                            # 0.5 mph: some com o carro parado
    kappa *= abs(v_f) / 0.223472
# guardada em corpo+0x6c8 (bate com a RAM)
```

## 2. Controle de derrapagem (0x20efa0)

Primeiro o alvo. Acima de `Speed_for_zero_sideslip` (5 mph) o jogo QUER o
bico apontando pra dentro da curva, proporcional ao volante, até
`Maximum_sideslip_angle` (10°) a `Speed_for_maximum_sideslip` (100 mph).
Abaixo de 5 mph o alvo é a geometria do eixo de trás.

```python
f_cent = massa * v_p**2 * kappa                    # força centrípeta pedida

if mph > 100:   alvo = 10 * DEG * -steer
elif mph > 5:   alvo = (mph - 5) / 95 * 10 * DEG * -steer
else:           alvo = asin(abs(eixo_r) * kappa) * (1 - mph / 5)   # sinal de v_f
alvo *= corpo_0x790                                # 1.0 no RX01

erro_giro = sinal(v_f) * v_p * kappa - yaw         # quanto falta girar pra seguir a curva
```

Depois um de três modos:

```python
if beta * alvo >= 0 or mph <= 5:
    if abs(beta) < abs(alvo):
        modo_A()        # derrapagem crescendo até o alvo
    else:
        modo_B()        # passou do alvo (é aqui que fica a derrapagem forte)
else:
    modo_C()            # derrapando pro lado contrário do volante (contra-esterço)
```

### Modo A: crescendo até o alvo

Pede só a força centrípeta e gira o carro com
`SideslipIncreaseYawAcceleration` (graus/s² pela velocidade), freando em
cosseno nos últimos `Increase_tail_off_threshold` (10°). Perto do alvo e com
o volante cru e suavizado do mesmo lado, mistura com "girar exatamente o que
falta" (`-erro_giro / dt`), peso `(10° - erro) / 10°` (DAT_00550658 = 10).
Teto: `MaximumYawAcceleration` (2000°/s²).

```python
f_lat = f_cent
acel = curvas(SideslipIncreaseYawAcceleration, mu, mph) * DEG * sinal(alvo - beta)
...cosseno e mistura...
torque = I_y * clamp(-acel * dt, ±2000 * DEG * dt) / dt
# o modo A NÃO passa pelo corte de recuperação
```

### Modo B: passou do alvo

A derrapagem já é maior que o alvo (o caso de virar tudo a 120 km/h: alvo
~7°, derrapagem 40°). Duas coisas:

```python
# 1) segura a velocidade lateral no ângulo alvo, no máximo
#    SideVelocityDecelerationStandard (30 mph/s na terra boa)
decel = tripla(SideVelocityDecelerationStandard, mu) * 0.44694445
v_alvo = tan(alvo) * abs(v_f)
a = (v_alvo - v_l) / dt  se |v_alvo - v_l| < decel*dt  senão  decel * -sinal(v_l)
f_lado = massa * a
f_lat = f_cent + f_lado

# parte dessa freada lateral vira empurrão pra frente, com acelerador:
# 0 até 5° de derrapagem, cheio a 30°, vezes Side_deceleration_to_fwd (0.75;
# 1.0 no powerslide). Também muda a altura da força pra frente (0x474).
f_frente = thr * |f_lado| * rampa(beta, 5°, 30°) * 0.75

# 2) torque que leva o giro pro giro da curva (erro_giro), limitado por
#    SideslipDecreaseYawAccelerationStandard, misturando ZeroThrottle e
#    FullThrottle pelo acelerador
lim = dt * lerp(curvas(ZeroThrottle, mu, mph), curvas(FullThrottle, mu, mph), thr) * DEG
torque = I_y * clamp(erro_giro, ±lim) / dt

torque *= 1 - corte_recuperacao()                  # 0x2120c0, ver abaixo
```

### Modo C: contra-esterço

O volante virou pro outro lado da derrapagem. A força centrípeta some até
5° de derrapagem, a lateral é freada com `SideVelocityDecelerationCounterSteer`
e o carro gira de volta com `SideslipDecreaseYawAccelerationCounterSteer`.
O teto do giro sobe com `Counter_steer_maximum_scale` conforme a derrapagem
(quadrático até `Counter_steer_maximum_scale_sideslip`) e o acelerador.

```python
fc = f_cent * max(0, (5 - |beta|°) / 5)
...freada lateral como no B, com a tabela CounterSteer...
taxa = sinal(alvo - beta) * curvas(SideslipDecreaseYawAccelerationCounterSteer, mu, mph) * DEG
s = min(1, (|beta|° / Counter_steer_maximum_scale_sideslip)**2) * thr
taxa = clamp(taxa, ±2000 * DEG * ((1 - s) + s * Counter_steer_maximum_scale))
torque = I_y * -taxa                               # (sinal de v_f)
torque *= 1 - corte_recuperacao()                  # 0x2120c0
```

### Divisão entre os eixos

Estática de bicicleta com os eixos a partir da origem do modelo, dividida
pela contagem FIXA de rodas por eixo (2 e 2), nas 4 rodas mesmo no ar:

```python
vao = eixo_f - eixo_r
roda_frente.fx += (-eixo_r / vao) * (f_lat + torque / -eixo_r) / 2
roda_tras.fx   += ( eixo_f / vao) * (f_lat - torque /  eixo_f) / 2
cada_roda.fz   += f_frente / 4                     # só andando pra frente
```

Isso ainda é o PEDIDO. Quem decide o que o pneu entrega é a elipse (passo 5).

## 3. Corte de recuperação (0x2120c0, Sideslip/RecoveryTorqueCutting)

É o que faz o carro **não voltar sozinho** quando você segura o acelerador.
Só roda com `RecoveryTorqueCutting Enabled` e a elipse ligada
(`FrictionEllipse Enabled`, P+0x430), e a flag corpo+0x728 em 0 (0 em todos
os save states).

```python
def corte_recuperacao():
    if mph(v_p) <= 5 or v_f <= 0:
        return 0
    ang = |beta| em graus
    th  = Threshold_angle_vs_speed(mph de v_f)     # 12°
    mx  = Maximum_angle_vs_speed(mph de v_f)       # 15° parado, 50° a 100 mph
    cut = Maximum_cut_vs_speed(mph de v_f)         # 0 nos buggies
    mx = max(mx, th + 0.1)
    f = cut * thr * rampa(ang, th, mx)             # 0 nos buggies

    rodando = False
    if Steering_dependent and ang > th:
        if sinal(steer) != sinal(beta) or |steer| < 1e-6:
            # volante pra DENTRO da curva, ou solto: corta pelo acelerador
            if |steer| < 1e-6:
                r = distância (x, z) da roda FL ao CoM          # 2.30 m
                rodando = v_p / r < |yaw|                       # girando mais que isso: rodou
            f = thr
        else:
            # contra-esterçando: o corte cai com o volante
            f = (f - 1) * |steer| + 1                           # = 1 - |steer| com cut 0

    if f > 0.01:
        # sobe a patinada (0x610) de cada roda até Maximum_increased_*_slip_ratio x f
        # (trás 0.2, frente 0), no ritmo de SlipRatio/Growth_rate_during_wheel_spin (3/s)
        for roda in rodas:
            lim = min((0.0 se frente senão 0.2) * f, SlipRatio/Maximum)
            if -0.1 < roda.patinada < lim:
                corpo_0x540 = 1        # avisa o 0x2101e0 pra não devolver a patinada
                roda.patinada = min(roda.patinada + 3 * dt, lim)

    return 0 if rodando else f
```

Na prática, com acelerador no fundo e mais de 12° de derrapagem:

| volante                      | corte | o carro...                      |
|------------------------------|-------|---------------------------------|
| todo pra dentro da curva     | 1.0   | não endireita, segue de lado    |
| solto                        | 1.0   | não endireita (só a lateral freia) |
| meio contra-esterço          | 0.5   | endireita com metade da força   |
| todo contra-esterço          | 0.0   | endireita com tudo              |
| (soltou o acelerador)        | 0.0   | endireita com tudo              |

Conferido: nos 6 save states de derrapagem o Enabled e o Steering_dependent
estão 1 na RAM, e com o corte o remake dá a mesma força por roda que o jogo
(maior diferença 0.13 kN; sem o corte era 1.26 kN). O drr_1 é o Matheus
soltando o volante no meio da derrapagem: o jogo seguia girando a 79°/s.

Tentamos um ajuste nosso por cima (cortar também abaixo dos 12°, pra um
toque de teclado segurar mais): comparado com o jogo lado a lado ficou pior.
O fiel é o certo.

## 4. Powerslide, a "Clutch Turn" (0x214610)

Um toque no botão da embreagem (corpo+0x388) virando e acelerando. Não é o
que faz o carro derrapar ao virar forte: nos 6 save states o estado era 0.

```python
# estado corpo+0x74c, quantidade 0x744, escala 0x748, embreagem anterior 0x740
if tempo_no_ar > Maximum_air_time (0.1):   estado, qtd = 0, 0
elif estado == 0:
    if steer != 0 and thr > 0 and emb < emb_ant:  estado = 1      # soltou o botão
elif estado == 1:
    if emb > emb_ant or thr == 0:  estado = 3
    else:
        qtd += Growth_rate * dt                    # 60/s
        if qtd > 1:  qtd, estado = 1, 2
elif estado == 2:
    if emb > emb_ant:  estado = 0
    elif thr == 0 or steer * beta >= 0:  estado = 3
elif estado == 3:
    qtd -= Decay_rate * dt                         # 1/s
    if qtd < 0:  qtd, estado = 0, 0
esc = Scale_vs_speed(mph)
# efeitos: estados 1 e 2 -> elipse das rodas de tração no mínimo x 0.8;
# estado != 0 -> Side_deceleration_to_fwd 1.0 em vez de 0.75;
# qtd * esc mistura a curva de taxa do limitador (passo 6)
```

## 5. Elipse de atrito e patinada (0x2101e0)

Cada roda tem uma elipse: meia-largura (lateral) e meia-altura (pra frente),
em kN, vezes o "grip" da roda (0x670). Renegade: frente 15 x 8.17, trás
11 x 8.17. A força pedida (passos 2 a 4, tração e freio) que passa da
elipse é encolhida mantendo a direção.

```python
W = grip * tripla(HalfWidth, mu_roda) * Width_scale * 1000
H = grip * tripla(HalfHeight, mu_roda) * Height_scale * 1000
lim = 1 / sqrt(1/W**2 + (fz/fx)**2 / H**2)
if lim < |fx|:
    fx, fz = fx * lim/|fx|, fz * lim/|fx|          # saturou
    grip = max(grip - Shrink_rate * dt, MinimumScale)   # 1/s até 0.8
else:
    grip = min(grip + Recovery_rate * dt, 1)
```

É aqui que nasce a derrapagem natural: com o volante todo a 120 km/h o
pedido da traseira passa de 8.8 kN (11 x 0.8), a elipse corta, a traseira
fica com menos força que o modelo de bicicleta precisava e escapa.

Patinada de cada roda (0x610), na mesma função:

```python
if saturou:
    if fz * v_f > 0:   patinada = min(patinada + 3 * dt, limite_do_motor)   # girando em falso
    elif freio > 0.1:  patinada = max(patinada - 2 * dt, -1)                # travando
elif patinada < 0:     patinada = min(patinada + 2 * dt, 0)
elif not corpo_0x540:  patinada = max(patinada - 4 * dt, 0)    # o corte de recuperação segura
```

Com a traseira patinando o motor (preso nas rodas pela embreagem) sobe e
bate no limitador: é o "corta giro" que se ouve derrapando no jogo.

## 6. Limitador da velocidade de derrapagem (0x210ce0)

Com as forças que sobraram da elipse calcula quão rápido a derrapagem vai
mudar. Passou de `MaximumRate` (graus/s pela derrapagem), tira o excesso
direto do giro do carro. Só tira giro, nunca põe.

```python
beta_rate = ((v_f * soma_fx - v_l * soma_fz) / massa / v_p**2 - yaw) * sinal(v_f)
# abaixo de 30 mph e virando: giro <= v / distância até a roda da frente
if |v_f| > 2:
    crescendo = beta_rate * beta > 0
    maximo = curvas(Maximum_increase_rate_vs_sideslip se crescendo
                    senão Maximum_decrease_rate_vs_sideslip, mu, |beta|°)
    if powerslide e crescendo:
        maximo = lerp(maximo, Powerslide/Maximum_sideslip_rate_vs_sideslip(|beta|°), qtd * esc)
    if |beta_rate| > maximo:
        excesso = beta_rate - sinal(beta_rate) * maximo
        excesso = só a parte que reduz o giro atual
        if |v_f| < 20: excesso *= (|v_f| - 2) / 18
        giro += excesso * sinal(v_f)
```

## Por que o carro derrapa ao virar forte

1. Volante todo: o alvo é pequeno (até 10°) mas o pedido de força
   centrípeta é grande (`massa * v² * kappa`).
2. O modo A gira o carro rápido pra chegar no alvo; a divisão de bicicleta
   põe muita força lateral na traseira.
3. A traseira passa da elipse (8.8 kN): satura, o grip cai pra 0.8 e a
   patinada sobe.
4. A derrapagem passa do alvo: modo B. Ele tentaria endireitar, mas com o
   volante pra dentro e acelerando o corte de recuperação (passo 3) zera
   esse torque. O carro fica de lado; o 0x210ce0 só limita a velocidade com
   que o ângulo abre.
5. Pra sair: contra-esterçar ou soltar o acelerador.

## Onde conferir

- `tests/teste_derrapagem.gd`: remake no estado exato da RAM (6 save
  states), força por roda e 1.16 s de derrapagem do drr_3 ao drr_2.
- `tests/teste_entrada.tscn`: reta até `VEL` e vira tudo; `SOLTA=t` solta o
  volante depois de t s (`DEPOIS=-1` contra-esterça, `ACEL=0` solta o
  acelerador junto).
- `docs/engenharia_reversa.md`, Pneus e derrapagem: offsets e detalhes.
