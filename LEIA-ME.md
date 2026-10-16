# ATV4 Reborn (protótipo)

Protótipo em Godot 4 usando assets extraídos do ATV Offroad Fury 4.

## Antes de abrir

Os assets do jogo não vão pro git. Gere todos de uma vez (12 buggies:
carroceria, peças da suspensão, freios, rodas e pintura de fábrica), na
pasta do projeto:

```
python tools\gerar_buggies.py <pasta>\unpacked <pasta>\texturas
python tools\gerar_pintura.py <pasta>\unpacked BUGGY_04 assets\sphinx --nome pintura_speedrun.png --base 225,225,230 --primary 215,85,20 --secondary 45,35,175
```

`texturas` é a saída do `gob_tex2png.py` (uns 6 min). Sai tudo em `assets\`
(`renegade`, `sphinx`, `buggy_NN`, `rodas`). Abra o Godot uma vez pra
importar. Sem os assets o carro aparece como caixa e as rodas como cilindros.
Rode de novo sempre que o `pingu2obj.py` mudar.

`python tools\gerar_buggies.py <unpacked> <texturas> --tabela` só mostra os
blocos de cada carro. O pingu2obj vira os triângulos pelas normais do jogo e o
Godot descarta a face de trás (`MODEL_CULL` no car.gd).

## Claude Code

O `CLAUDE.md` tem o contexto do projeto (como trabalhamos, mapa do exe,
referências pra conferir). `docs/` tem os detalhes e `tests/rodar_testes.py`
roda a física sem tela. Comandos: `/teste` e `/entrega`.

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
| Tab | menu de carros (os 12 buggies + Sphinx do speedrun): clique ou Enter |
| V | próximo carro da lista |
| F | girar o modelo 180° (se ele parecer andar de ré) |
| 1/2, 3/4, 5/6, 7/8 | na câmera do piloto: altura, distância, inclinação e campo de visão (valores no HUD) |
| Esc | sair |

Controle de videogame também funciona (gatilhos e analógico esquerdo).

## O que já é do jogo

- Mão certa: o jogo usa outra convenção de eixos e até out/2026 o remake
  saía espelhado (pista e carro). Agora carro e pista ficam como no jogo
- Chão: relevo, textura e material da pista RX01 (tiles do STREAMT). A
  roda só treme na terra e no cascalho (no asfalto não), como no jogo; o HUD
  mostra o chão embaixo de cada roda. O carro larga na largada do jogo
- Carros: os 12 buggies, modelo, suspensão, rodas e pintura de fábrica do jogo
- Física: os XMLs do próprio jogo em `data/vehicles` (`buggy_base.xml` é a
  base da classe e `buggy_NN.xml` o veículo (Renegade = buggy_10 = 15154). Os arquivos
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

- Troca de pneu e aro (peças compradas): por enquanto só as de fábrica
- Atrito por tipo de chão (o jogo muda a aderência na terra, lama, água...)
- Roda travando no freio (função 0x210908 do jogo, ainda não portada)
- Tremida da câmera (jitter e batida) ainda não portada
