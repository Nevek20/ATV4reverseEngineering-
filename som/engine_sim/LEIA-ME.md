# Motores no Engine Simulator

Um `.mr` por buggy pro Engine Simulator (ATG). Cada arquivo é independente,
no mesmo formato do exemplo do EJ25 (termina com `run(...)` e `main()`).

**Usar:** copia o conteúdo do arquivo pro `assets/main.mr` do engine-sim e
aperta Load Script.

**Mudar:** não edita os `.mr` na mão. Mexe em `tools/gerar_motores.py` e roda
`python tools/gerar_motores.py`. O gerador confere a geometria (PMS de cada
cilindro pelo virabrequim e pela bancada, igual ao engine-sim) e para se a
ordem de ignição não bater.

## Medido no dinamômetro

Plena carga, rpm fixa a cada 500. Engine-sim 85f7c3b (jan/2023) sem tela
(`tools/engine_sim_dyno`). Lenta = média de 2 s com borboleta fechada.

| buggy | motor | cc | ordem | cv alvo | cv medido | lenta alvo | lenta |
|---|---|---|---|---|---|---|---|
| Mosquito | VW Tipo 4 2.0 a ar | 1971 | 1-4-3-2 | 144 | 141 @ 5500 | 900 | 904 |
| Inferno | Chevy 305 small-block carb | 5001 | 1-8-4-3-6-5-7-2 | 198 | 200 @ 4000 | 750 | 717 |
| Trident | GM Ecotec 2.4 DOHC | 2384 | 1-3-4-2 | 196 | 263 @ 6500 | 900 | 866 |
| Sphinx | VW Tipo 1 2180 preparado | 2180 | 1-4-3-2 | 180 | 182 @ 6500 | 900 | 815 |
| Bulldog | GM 4.3 LV3 V6 90° | 4301 | 1-6-5-4-3-2 | 280 | 277 @ 4000 | 800 | 795 |
| Phantom | Subaru EJ25 (turbo de mentira) | 2457 | 1-3-2-4 | 297 | 304 @ 6500 | 800 | 809 |
| Kraken V8 | Chevy 454 big-block | 7439 | 1-8-4-3-6-5-7-2 | 363 | 371 @ 4500 | 700 | 696 |
| McKenzies | GM LS6 5.7 | 5665 | 1-8-7-2-6-5-4-3 | 405 | 408 @ 5000 | 800 | 796 |
| Viper | V10 8.0 tipo Viper | 7990 | 1-10-9-4-3-6-5-8-7-2 | 334 | 320 @ 4000 | 700 | 660 |
| Renegade | Cadillac Northstar 4.6 | 4565 | 1-2-7-3-4-5-6-8 | 441 | 435 @ 7000 | 700 | 865 |
| Hurricane | GM LS7 7.0 bravo | 7011 | 1-8-7-2-6-5-4-3 | 604 | 599 @ 7000 | 800 | 970 |
| Storm | Lancia Delta S4 1.8 (turbo de mentira) | 1759 | 1-3-4-2 | 417 | 410 @ 8000 | 1000 | 1110 |

## O que vale saber

- **Turbo de mentira (Phantom e Storm):** 297 cv num EJ25 a 6500 rpm e
  417 cv num 1.8 a 8400 pedem 16 e 25 bar de pressão média. Só com turbo
  (o STI e o S4 de verdade eram sobrealimentados). O engine-sim não tem
  turbo, então esses dois têm `energy_density` maior no combustível
  (55 e 87 kJ/g, normal 48), que faz o papel da pressão extra.
- **Trident:** escape escolhido pelo Matheus de ouvido, entre 4 opções:
  coletor 4-1 de corrida (primários iguais de 14 pol, tubo de 50) e quase
  sem silencioso (minimal_muffling_02). Com 4-2-1 e o silencioso mild ele
  saía 80-100% numa frequência só (apito de aspirador); com primários de
  tamanhos diferentes virou batidão de Fusca. O escape aberto deixa ele
  mais forte (263 cv, alvo 196) e tem um vale no dinamômetro a 5500: fica
  assim de propósito, abaixar o `k_fluxo` muda o som. A física não usa o
  .mr, então a potência daqui não mexe no carro.
- **Viper:** V10 90° de pino comum como o Viper de verdade, ignição
  desigual 54/90°. Soa diferente do LFA (72°, ignição igual). Filtro do
  escape real_engine_2, escolhido pelo Matheus de ouvido entre 3.
- **Filtro mild_exhaust:** 75% da energia entre 100 e 250 Hz, pico de
  +11.5 dB em 133 Hz. No Viper, de 4000 a 4500 rpm (5500-6000 no HUD), o
  som virava um zumbido grave: 90% num tom só e o dobro do volume. Mudar o
  tamanho dos tubos não resolve, tem que trocar o filtro. Mosquito,
  Phantom e Storm ainda usam (o Matheus gosta do som deles).
- **Bulldog:** V6 4.3 LV3, que é a família LS com 6 cilindros (285 cv de
  fábrica). Pino defasado, ignição a cada 120°.
- **Renegade, Hurricane e Storm:** a lenta ficou um pouco acima do alvo de
  propósito. Mais baixo que isso eles apagam (o LS7 bravo tem comando grande,
  lenta alta é normal).
- **Sphinx:** biela de 136 mm. Com 137,16 (a original) o engine-sim explode
  numericamente.
- **Câmbio e carro:** marchas na proporção do Renegade no save state
  (18.2/11.9/8.9/7.1/5.9), final que dá ~170 km/h na 5ª no corte, buggy
  de 1100 kg, pneu de 15".
- A versão do engine-sim com `run()` é mais nova que a do dinamômetro.
  Se a lenta ou a potência saírem diferentes, os botões são
  `idle_throttle_plate_position` (maior = lenta mais baixa) e o `k_fluxo`
  no gerador.

## Dinamômetro sem tela

```
bash tools/engine_sim_dyno/preparar.sh                       :: clona, aplica patch, compila (Linux)
tools/engine_sim_dyno/build/dyno som/engine_sim/08_mckenzies_gm_ls6.mr
tools/engine_sim_dyno/build/dyno som/engine_sim/08_mckenzies_gm_ls6.mr lenta
```
