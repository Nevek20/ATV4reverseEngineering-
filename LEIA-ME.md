# ATV4 Reborn (protótipo)

Protótipo em Godot 4 usando assets extraídos do ATV Offroad Fury 4.

## Antes de abrir

Copie **todos** os arquivos da pasta `renegade` (o `.obj`, o `.mtl` e os PNGs
que o `pingu2obj.py --copy-tex` gerou) para `assets/renegade/`.
Sem isso o carro aparece como uma caixa.

Pro Sphinx, gere o modelo do mesmo jeito e copie pra `assets/sphinx/`:

```
python pingu2obj.py unpacked\other\21531_bloco.bin --out sphinx --copy-tex
```

### Peças da suspensão

As balanças, amortecedores e freios são blocos separados. Gere com textura
(no cmd, na pasta do `pingu2obj.py`) e copie o conteúdo de cada pasta pra
`assets/renegade/` e `assets/sphinx/`:

```
for %b in (21694 21695 21696 21697 21699 21700 21701 21702 21703 21704 21713 21714 21715 21716) do python pingu2obj.py unpacked\other\%b_bloco.bin --out renegade --copy-tex
for %b in (21513 21514 21515 21516 21518 21519 21520 21521 21522 21523 21533 21534 21535 21536) do python pingu2obj.py unpacked\other\%b_bloco.bin --out sphinx --copy-tex
```

Sem essas peças o carro roda normal, só sem a suspensão aparecendo.

## Rodar

1. Abra o Godot, clique em **Importar** e escolha o `project.godot`
2. Espere importar os assets e aperte **F5**

## Controles

| tecla | ação |
|---|---|
| W / S ou setas | acelerar / frear (parado, segure S pra engatar a ré) |
| A / D | virar |
| Espaço | powerslide (freio de mão): a traseira escorrega |
| M | câmbio automático / manual |
| P | alterna pneus/derrapagem: portados do jogo x modelo antigo |
| L | força lateral: por eixo como no jogo x remendo antigo (pra comparar) |
| E / Q | sobe / desce marcha (manual; abaixo da 1ª vem a ré, como no jogo) |
| R | desvirar o carro |
| T | voltar para o início |
| C | trocar câmera (perto, longe, capô, para-choque, piloto) |
| V | trocar de carro (Renegade, Sphinx de fábrica, Sphinx do speedrun) |
| F | girar o modelo 180° (se ele parecer andar de ré) |
| Esc | sair |

Controle de videogame também funciona (gatilhos e analógico esquerdo).

## O que já é do jogo

- Chão: relevo e textura da pista RX01 (tiles do STREAMT)
- Carro: modelo extraído do jogo
- Física: os XMLs do próprio jogo em `data/vehicles` (`buggy_base.xml` é a
  base da classe e `renegade.xml` o veículo (15154 = BUGGY_10). Os arquivos
  seguem a ordem da lista do jogo: 15145 é a base e também o 1º buggy (Mosquito),
  15146 o 2º, e assim até 15156 (Storm). Ex.: Sphinx = 15148). Massa, molas, amortecedores, curva
  de torque, marchas, embreagem, elipse de atrito, subesterço, derrapagem e
  gravidade no ar saem de lá
- Peças de fábrica de cada carro: `data/vehicles.xml` (DefaultConfig, 14887) +
  `data/upgrades.xml` (efeito de cada peça, 14889). Conferido no save state
- Código de física portado do executável (SCES_546.88): pneus e derrapagem
  (parte 1), motor, embreagem, câmbio e roda patinando (parte 3), suspensão,
  anti-pitch e controles no ar (parte 4), arrasto do ar e atrito interno
- Câmera: `data/cameras.xml` (o 14880 do unpacked, CameraSet `BuggyCamSet_10`)
  com o código da câmera do exe portado em `game_camera.gd`: órbita que segue
  a direção da velocidade, distância e zoom por velocidade, amortecimento de
  altura, subida em descida, altura mínima do chão. Só a câmera "piloto" é
  inventada

- Suspensão visual (`suspension_visual.gd`): balanças giram no pivô do jogo
  (A_FRAME_*) até a ponta acompanhar o curso da roda, amortecedores apontam
  de um ponto ao outro, freios e rodas vão presos na balança

## O que ainda é provisório

- Rodas (cilindros). A posição delas já é a do jogo
  (`data/vehicles/renegade_points.bin`, o arquivo 21712 do unpacked)
- Atrito por tipo de chão (o jogo muda a aderência na terra, lama, água...)
- Roda travando no freio (função 0x210908 do jogo, ainda não portada)
- Tremida da câmera (jitter e batida) ainda não portada
