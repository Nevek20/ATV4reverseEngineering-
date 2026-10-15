# Assets do jogo → projeto

Tudo sai da pasta `unpacked` (other/raw/gob/xml + manifest.json) gerada a
partir do archive.imp. Os scripts estão em `tools/` (rodar na pasta que tem
o `unpacked`). As texturas PNG vêm do `gob_tex2png.py` (pasta `texturas`).

## Blocos de cada carro

Cada carro ocupa um trecho do unpacked que termina na sombra dele
(gob `BUGGY_NN_shadow`): texturas, peças, modelo, pontos, freios, sombra.

| carro | id | física | modelo | pontos | peças (base) | freios | câmera |
|---|---|---|---|---|---|---|---|
| Renegade | BUGGY_10 | 15154 | 21711 | 21712 | 21694 | 21713 | BuggyCamSet_10 |
| Sphinx | BUGGY_04 | 15148 | 21531 | 21532 | 21513 | 21533 | BuggyCamSet_04 |

Peças a partir da base: +0/+1 balança dianteira E/D, +2/+3 traseira E/D,
+4 sombra (não usa), +5/+6 corpo do amortecedor traseiro, +7/+8
amortecedor dianteiro, +9/+10 haste traseira. Freios: +0..3 = DE, DD, TE, TD.

Ordem da lista do jogo (= FEOrder em data/vehicles.xml):
1 Mosquito (01), 2 Inferno, 3 Trident, 4 Sphinx, 5 Bulldog, 6 Phantom,
7 Kraken V8, 8 McKenzies, 9 Viper, 10 Renegade, 11 Hurricane, 12 Storm.
Física: 15144 + N (15145 = base e Mosquito).

## Rodas (iguais em todos os buggies de fábrica)

DefaultConfig (data/vehicles.xml): Wheel=TYRE_GENERIC_MEDIUM, Tire=DIRT_BUDGET,
Alloy=WHEEL_01 (= Wheel_Heavyclass_01 no 14882). Os nomes dos modelos não
aparecem em nenhum arquivo; a posição no unpacked é que diz quem é quem.

- Modelos de jogo dos 4 TYRE_GENERIC (grupo ALLOY + 2 modelos + TYRE), na
  ordem alfabética dos nomes: LARGE 21963/21964 (raio 0,60), MEDIUM
  21968/21969 (0,54), SANDCAR 21973/21974 (0,44, malha diferente), SMALL
  21978/21979 (0,46). A ordem por tamanho bate com os nomes.
- Primeiro modelo = FrontWheel, segundo = RearWheel (component map 14881,
  nessa ordem). As rodas da esquerda do jogo (x < 0) usam Mirror="1".
- O modelo já traz o aro: materiais ALLOY e TYRE. Essas texturas são iguais
  byte a byte a IG_WHEEL_HEAVYCLASS_01 (22398) e IG_TYRE_DIRT_BUDGET (22384),
  ou seja, as peças de fábrica. Hipótese (não confirmada no exe): trocar aro
  ou pneu troca só a textura (IG_WHEEL_HEAVYCLASS_0N, IG_TYRE_*).
- Raio do modelo (0,54) é maior que o Radius da física (0,50): o jogo usa o
  modelo como está.
- Os grupos de ~100 KB com texturas UI_TYRE_* (21862 a 22146, 5 por tipo de
  pneu) são os modelos do menu (FE), não os de corrida.

## Comandos

```
python pingu2obj.py unpacked\other\21711_bloco.bin --out renegade --copy-tex --split volante:44,53,54,234-242
for %b in (21694 21695 21696 21697 21699 21700 21701 21702 21703 21704 21713 21714 21715 21716) do python pingu2obj.py unpacked\other\%b_bloco.bin --out renegade --copy-tex
for %b in (21531 21513 21514 21515 21516 21518 21519 21520 21521 21522 21523 21533 21534 21535 21536) do python pingu2obj.py unpacked\other\%b_bloco.bin --out sphinx --copy-tex
for %b in (21968 21969) do python pingu2obj.py unpacked\other\%b_bloco.bin --out rodas --copy-tex
python gerar_pintura.py unpacked BUGGY_10 renegade
python gerar_pintura.py unpacked BUGGY_04 sphinx
python gerar_pintura.py unpacked BUGGY_04 sphinx --nome pintura_speedrun.png --base 225,225,230 --primary 45,35,175 --secondary 215,85,20
```
Depois copiar as pastas pra `assets\renegade`, `assets\sphinx` e `assets\rodas`.

## Formato .pingu (resumo)

- Malha em pacotes VIF (tiras de triângulos): UNPACK V4-32 posição (bit
  ADC 0x8000 no 4º campo = não fecha triângulo), V3-8 normal, V4-32/V2-32
  UV, V4-8 cor. Ver cabeçalho do pingu2obj.py.
- Lotes de material: registros de 0x50 bytes a partir de 0xD0; total em
  0xAC (0xBC às vezes conta menos); +0x14 slot de textura, +0x28 início,
  +0x48 nº de tiras. Lista de nomes de textura no raw logo antes do modelo
  (ou até 10 blocos antes, nas peças pequenas).
- Texturas com o mesmo nome em blocos diferentes são idênticas (byte a byte).
