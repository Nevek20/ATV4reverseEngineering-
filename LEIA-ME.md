# ATV4 Reborn (protótipo)

Protótipo em Godot 4 usando assets extraídos do ATV Offroad Fury 4.

## Antes de abrir

Copie **todos** os arquivos da pasta `renegade` (o `.obj`, o `.mtl` e os PNGs
que o `pingu2obj.py --copy-tex` gerou) para `assets/renegade/`.
Sem isso o carro aparece como uma caixa.

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
| C | trocar câmera (atrás, longe, capô, piloto) |
| F | girar o modelo 180° (se ele parecer andar de ré) |
| Esc | sair |

Controle de videogame também funciona (gatilhos e analógico esquerdo).

## O que já é do jogo

- Chão: relevo e textura da pista RX01 (tiles do STREAMT)
- Carro: modelo extraído do jogo
- Física: os XMLs do próprio jogo em `data/vehicles` (`buggy_base.xml` é a
  base da classe e `renegade.xml` o veículo). Massa, molas, amortecedores, curva
  de torque, marchas, embreagem, elipse de atrito, subesterço, derrapagem e
  gravidade no ar saem de lá
- Código de física portado do executável (SCES_546.88): pneus e derrapagem
  (parte 1), motor, embreagem, câmbio e roda patinando (parte 3), suspensão,
  anti-pitch e controles no ar (parte 4), arrasto do ar e atrito interno

## O que ainda é provisório

- Rodas (cilindros). A posição delas já é a do jogo
  (`data/vehicles/renegade_points.bin`, o arquivo 21712 do unpacked)
- Atrito por tipo de chão (o jogo muda a aderência na terra, lama, água...)
- Roda travando no freio (função 0x210908 do jogo, ainda não portada)
