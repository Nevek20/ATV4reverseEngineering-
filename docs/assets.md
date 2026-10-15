# Assets do jogo → projeto

Tudo sai da pasta `unpacked` (other/raw/gob/xml + manifest.json) gerada a
partir do archive.imp. Os scripts estão em `tools/` (rodar na pasta que tem
o `unpacked`). As texturas PNG vêm do `gob_tex2png.py` (pasta `texturas`).

## Blocos de cada carro

Cada carro ocupa um trecho do unpacked que termina na sombra dele
(gob `BUGGY_NN_shadow`): texturas, peças, modelo, pontos, freios, sombra.

| # | carro | id | física | modelo | pontos | peças | freios | roda | câmera |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Mosquito | BUGGY_01 | 15145 | 21447 | 21448 | - | 21449 | MEDIUM | BuggyCamSet_01 |
| 2 | Inferno | BUGGY_02 | 15146 | 21474 | 21475 | 21458..21469 | 21476 | SANDCAR | BuggyCamSet_02 |
| 3 | Trident | BUGGY_03 | 15147 | 21500 | 21501 | 21486..21497 | 21502 | SANDCAR | BuggyCamSet_03 |
| 4 | Sphinx | BUGGY_04 | 15148 | 21531 | 21532 | 21513..21523 | 21533 | MEDIUM | BuggyCamSet_04 |
| 5 | Bulldog | BUGGY_05 | 15149 | 21563 | 21564 | 21546..21556 | 21565 | SMALL | BuggyCamSet_05 |
| 6 | Phantom | BUGGY_06 | 15150 | 21589 | 21590 | 21574..21585 | 21591 | MEDIUM | BuggyCamSet_06 |
| 7 | Kraken V8 | BUGGY_07 | 15151 | 21619 | 21620 | 21602..21613 | 21621 | LARGE | BuggyCamSet_07 |
| 8 | McKenzies | BUGGY_08 | 15152 | 21649 | 21650 | 21632..21642 | 21651 | LARGE | BuggyCamSet_08 |
| 9 | Viper | BUGGY_09 | 15153 | 21681 | 21682 | 21663..21674 | 21683 | MEDIUM | BuggyCamSet_09 |
| 10 | Renegade | BUGGY_10 | 15154 | 21711 | 21712 | 21694..21704 | 21713 | MEDIUM | BuggyCamSet_10 |
| 11 | Hurricane | BUGGY_11 | 15155 | 21740 | 21741 | 21724..21735 | 21742 | MEDIUM | BuggyCamSet_11 |
| 12 | Storm | BUGGY_12 | 15156 | 21769 | 21770 | 21752..21764 | 21776 | Rally | LanciaCam |

`tools/gerar_buggies.py` acha tudo isso sozinho no manifest. Peças = os 11
blocos pequenos (< 20 KB) antes do modelo, às vezes com uma textura no meio
(por isso a lista e não "base + n"): [0/1] balança dianteira E/D, [2/3]
traseira E/D, [4] sombra (não usa), [5/6] corpo do amortecedor traseiro,
[7/8] amortecedor dianteiro, [9/10] haste traseira. Freios: os 4 blocos
depois dos pontos = DE, DD, TE, TD. Conferido pela posição de cada peça
(bounding box) contra os pontos A_FRAME/SHOCK de cada carro.
- Mosquito (BuggyCompMap_C1): não tem as 11 peças no trecho dele; só
  modelo, pontos e os 4 freios. Os blocos de ~35 KB antes dele (21418 a
  21441) são para-choques (Bumper), e os de 21332 a 21401 são carrocerias menores com
  pontos próprios (provável LOD, não conferido).
- Phantom: tem um 2º arquivo de pontos (21587, sem amortecedor dianteiro)
  antes do modelo; o certo é o 21590, logo depois do modelo.
- Hurricane: 2 peças a mais (21737/21738, atrás) que não estão na lista.
- Storm (BUGGY_12, Lancia, RallyCompMap): pontos sem amortecedores, freios
  separados do modelo por texturas (21776). Pintura usa as texturas Lancia_*.

Ordem da lista do jogo (= FEOrder em data/vehicles.xml):
1 Mosquito (01), 2 Inferno, 3 Trident, 4 Sphinx, 5 Bulldog, 6 Phantom,
7 Kraken V8, 8 McKenzies, 9 Viper, 10 Renegade, 11 Hurricane, 12 Storm.
Física: 15144 + N (15145 = base e Mosquito).

## Rodas

DefaultConfig (data/vehicles.xml): Wheel=TYRE_GENERIC_<tamanho> (coluna
roda da tabela; Storm usa Wheel_Rally), Tire=DIRT_BUDGET, Alloy=WHEEL_01
(= Wheel_Heavyclass_01 no 14882). Os nomes dos modelos não
aparecem em nenhum arquivo; a posição no unpacked é que diz quem é quem.

- Modelos de jogo dos 4 TYRE_GENERIC (grupo ALLOY + 2 modelos + TYRE), na
  ordem alfabética dos nomes: LARGE 21963/21964 (raio 0,60), MEDIUM
  21968/21969 (0,54), SANDCAR 21973/21974 (0,44, malha diferente), SMALL
  21978/21979 (0,46). A ordem por tamanho bate com os nomes.
- Wheel_Rally (Storm) = 21267/21268 (raio 0,42; física 0,40). Na lista de
  rodas dos buggies do 14882 (Wheel_AntiFreeze, Inferno, Manx, Placeholder,
  Rally) os grupos 21255/21258 (IG_WHEEL_ITP_Meyer_Manx), 21262/21264 (Baja)
  e 21267/21268 (ALLOY + TYRE) seguem a ordem alfabética.
- Primeiro modelo = FrontWheel, segundo = RearWheel (component map 14881,
  nessa ordem). As rodas da esquerda do jogo (x < 0) usam Mirror="1".
- O modelo já traz o aro: materiais ALLOY e TYRE. Essas texturas são iguais
  byte a byte a IG_WHEEL_HEAVYCLASS_01 (22398) e IG_TYRE_DIRT_BUDGET (22384),
  ou seja, as peças de fábrica. Hipótese (não confirmada no exe): trocar aro
  ou pneu troca só a textura (IG_WHEEL_HEAVYCLASS_0N, IG_TYRE_*).
- Posição (medida no save state, matriz de cada roda na RAM, frame do
  modelo; as da esquerda com determinante -1 = Mirror): a roda fica no ponto
  WHEEL_* e sobe o curso da mola girando junto com a balança. A da frente
  gira no eixo comprido do carro (z), a de trás no eixo lateral (x), e o
  ângulo é o que faz o CENTRO DA RODA subir o curso x. Com essa regra as 8
  rodas (Renegade e Sphinx parados na largada) ficam a menos de 2 cm do jogo
  (suspension_visual.gd). Não existe deslocamento extra pra fora.
- No jogo o cubo traseiro do Renegade fica a 0,51 m do ponto de contato
  (wheel +0x15c) e o pneu tem raio 0,548: o pneu afunda ~4 cm no chão no
  jogo original também.
- Raio do modelo (0,54) é maior que o Radius da física (0,50): o jogo usa o
  modelo como está.
- Os grupos de ~100 KB com texturas UI_TYRE_* (21862 a 22146, 5 por tipo de
  pneu) são os modelos do menu (FE), não os de corrida.

## Referência em vídeo

Speedrun do Sphinx (Amateur National Buggy, 26m39s) no repo `atv4-dados`,
pasta `videos/` (720p, 60 fps, 6 partes de ~5 min). A câmera fica atrás do
carro quase o tempo todo; de lado só nas curvas e nos saltos.
- Pintura do speedrun: V grande azul (camada Secondary) e laterais laranja
  (Primary). Teto com listras vermelho/branco/azul (decalque, ainda não feito).
- De trás bate com o nosso: balança cinza até a roda, aro aparecendo por
  dentro embaixo. A balança traseira (21515/21516) entra no pneu pela frente
  embaixo; esse ponto não aparece no vídeo. Com a posição do save state
  (ver Rodas) isso é o que o jogo faz.

## Comandos

```
python tools\gerar_buggies.py <unpacked> <texturas>            :: os 12 + rodas + física/pontos
python tools\gerar_buggies.py <unpacked> <texturas> --tabela   :: só a tabela de blocos
python tools\gerar_pintura.py <unpacked> BUGGY_04 assets\sphinx --nome pintura_speedrun.png --base 225,225,230 --primary 215,85,20 --secondary 45,35,175
```
O Renegade sai com o volante separado (`--split volante:44,53,54,234-242`);
os outros ainda não (volante parado).

## Formato .pingu (resumo)

- Malha em pacotes VIF (tiras de triângulos): UNPACK V4-32 posição (bit
  ADC 0x8000 no 4º campo = não fecha triângulo), V3-8 normal, V4-32/V2-32
  UV, V4-8 cor. Ver cabeçalho do pingu2obj.py.
- Lotes de material: registros de 0x50 bytes a partir de 0xD0; total em
  0xAC (0xBC às vezes conta menos); +0x14 slot de textura, +0x28 início,
  +0x48 nº de tiras. Lista de nomes de textura no raw logo antes do modelo
  (ou até 10 blocos antes, nas peças pequenas).
- Texturas com o mesmo nome em blocos diferentes são idênticas (byte a byte).
