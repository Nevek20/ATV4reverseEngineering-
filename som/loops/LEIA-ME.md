# Loops de som dos motores

Gerados do engine-sim (`som/engine_sim/*.mr`) com `python tools/gravar_loops.py`.
Uma pasta por buggy, 44100 Hz, mono, 16 bits.

- `lenta.wav`: marcha lenta, borboleta fechada.
- `on_RRRR.wav`: acelerando, borboleta toda aberta, rpm fixo (dinamômetro).
- `off_RRRR.wav`: soltando, borboleta fechada, motor arrastado no mesmo rpm.
- RRRR vai de 1000 até o corte, de 500 em 500.

**Corte:** cada loop tem um número inteiro de ciclos do motor (720°), por isso
dura de 1,95 a 2,10 s em vez de 2,00 cravado. Começa e termina num zero subindo
(última amostra < 0, primeira >= 0). Dos zeros possíveis fica o par em que a
onda mais combina dos dois lados da emenda (`emenda_corr` no info.csv, 1 =
perfeito, ficaram de 0,91 a 1,00). O salto na emenda é no máximo 2,4 vezes o
passo entre amostras vizinhas, então não estala.

**Godot:** o .wav tem o bloco `smpl` com o loop. Na importação, Loop Mode =
Detect From WAV (o padrão) já faz o loop.

**Volume:** o app do engine-sim passa o som por um nivelador (pico 30000,
ganho máximo 1,9). Aqui é o mesmo ganho, só que constante no loop todo, pra não
bombear. Por isso on e off saem com volume parecido, igual no app. A diferença
real está no `nivel_cru_db` do info.csv: pra deixar o off mais baixo no jogo,
toca com `volume_db = nivel_cru_db(off) - nivel_cru_db(on)` em relação ao on do
mesmo rpm (média -17 dB, vai de -39 a +4).
