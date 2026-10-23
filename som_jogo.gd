extends Node
## Toca um som do jogo (989snd) extraído por tools/sfx_jogo.py pra
## assets/sfx: cada som é um programa de grãos em sequência (sons.json):
##   tom              toca um .wav (loop se o banco marca loop)
##   filho            roda outro som junto, com volume próprio
##   repete / volta   repete o trecho pra sempre
##   sorteia n        toca 1 dos próximos n grãos, sorteado
##   espera_sorteada  espera de 0 até o dado
## e "espera" depois de cada grão. O desvio de tom aleatório (grão 27) fica
## de fora: nos save states as batidas da suspensão tocam com tom 1.0 exato.
## volume (linear, do jeito que o exe calcula) e tom (multiplica a taxa do
## .wav) valem pra todas as vozes do som.

const PASTA := "res://assets/sfx"
const MAX_VOZES := 6

static var _db: Dictionary = {}
static var _cache: Dictionary = {}

var volume := 1.0
var tom := 1.0
var ganho := 1.0                  # trim nosso (sfx_carro.gd), multiplica o volume
var nome := ""
var _som: Dictionary = {}
var _cursores: Array = []
var _vozes: Array = []            # {p: AudioStreamPlayer, amp: float, loop: bool}
var tocando := false


static func banco() -> Dictionary:
	if _db.is_empty():
		var f := FileAccess.open(PASTA.path_join("sons.json"), FileAccess.READ)
		if f:
			_db = JSON.parse_string(f.get_as_text())
	return _db


static func existe(b: String, n: String) -> bool:
	var d := banco()
	return not d.is_empty() and d.bancos.has(b) and d.bancos[b].has(n)


func tocar(b: String, n: String) -> void:
	parar()
	if not existe(b, n):
		return
	_som = banco().bancos[b]
	nome = n
	tocando = true
	_cursores.append(_cursor(n, 1.0))
	_rodar(0.0)


func parar() -> void:
	for v in _vozes:
		v.p.queue_free()
	_vozes.clear()
	_cursores.clear()
	tocando = false
	nome = ""


func _cursor(n: String, amp: float) -> Dictionary:
	var s: Dictionary = _som[n]
	return {"s": s, "pc": 0, "espera": 0.0, "volta": -1, "amp": amp * float(s.vol) / 127.0}


func _process(dt: float) -> void:
	if not tocando:
		return
	_rodar(dt)
	var vivas: Array = []
	for v in _vozes:
		var p: AudioStreamPlayer = v.p
		if not p.playing:
			p.queue_free()
			continue
		vivas.append(v)
		_aplicar(v)
	_vozes = vivas
	if _cursores.is_empty() and _vozes.is_empty():
		tocando = false


func _aplicar(v: Dictionary) -> void:
	var p: AudioStreamPlayer = v.p
	p.volume_db = linear_to_db(maxf(volume * ganho * v.amp, 1e-5))
	p.pitch_scale = clampf(tom, 0.05, 8.0)


func _rodar(dt: float) -> void:
	var tick: float = banco().get("tick_s", 0.001)
	var i := 0
	while i < _cursores.size():
		var c: Dictionary = _cursores[i]
		c.espera -= dt
		var prog: Array = c.s.prog
		var passos := 0
		while c.espera <= 0.0 and c.pc < prog.size() and passos < 64:
			passos += 1
			var g: Array = prog[c.pc]
			c.pc += 1
			match g[0]:
				"tom":
					_voz(c.s.tons[int(g[1])], c.amp)
					c.espera += float(g[2]) * tick
				"filho":
					if _som.has(g[1]):
						_cursores.append(_cursor(g[1], c.amp * float(g[2]) / 127.0))
					c.espera += float(g[3]) * tick
				"repete":
					c.volta = c.pc
				"volta":
					if c.volta >= 0:
						c.pc = c.volta
						c.espera = maxf(c.espera, 1e-4)   # no máximo uma volta por quadro
				"sorteia":
					var n := int(g[1])
					var k: int = c.pc + randi() % maxi(n, 1)
					var e: Array = prog[k]
					if e[0] == "tom":
						_voz(c.s.tons[int(e[1])], c.amp)
						c.espera += float(e[2]) * tick
					c.pc += n
				"espera_sorteada":
					c.espera += randf() * float(g[1]) * tick
		if c.pc >= prog.size():
			_cursores.remove_at(i)
		else:
			i += 1


func _voz(t: Dictionary, amp: float) -> void:
	if _vozes.size() >= MAX_VOZES:
		# sai a voz curta mais velha; os loops (camadas do som) ficam
		var k := -1
		for j in _vozes.size():
			if not _vozes[j].loop:
				k = j
				break
		if k < 0:
			return
		_vozes[k].p.queue_free()
		_vozes.remove_at(k)
	var p := AudioStreamPlayer.new()
	p.stream = _wav(t)
	add_child(p)
	var v := {"p": p, "amp": amp * minf(float(t.vol) / 127.0, 1.0), "loop": bool(t.loop)}
	_aplicar(v)
	p.play()
	_vozes.append(v)


static func _wav(t: Dictionary) -> AudioStreamWAV:
	var caminho: String = PASTA.path_join(t.arq)
	if _cache.has(caminho):
		return _cache[caminho]
	var st: AudioStreamWAV = null
	if ResourceLoader.exists(caminho):
		st = load(caminho)
	if st == null:
		st = AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(caminho))
	if st and t.loop:
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = int(t.ini)
		st.loop_end = int(t.fim)
	elif st:
		st.loop_mode = AudioStreamWAV.LOOP_DISABLED
	_cache[caminho] = st
	return st
