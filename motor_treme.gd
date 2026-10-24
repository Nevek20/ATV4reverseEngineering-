extends Node3D
## Motor e escape tremendo (melhoria nossa, car.gd MOTOR_TREME). No jogo nada
## treme: o motor e o escape são parte da malha Body (sem peça Engine/Exhaust
## nos BuggyCompMap_*, cCompPlace_Body = identidade) e nenhum leitor do rpm
## monta matriz (varredura do exe; vídeo do Sphinx parado no corte: 0 px).
##
## Separação: as peças soltas da Body (pedaços sem vértice em comum com o
## resto) que cabem inteiras no cofre do motor saem pra uma malha própria:
## cofre = atrás do banco (ARSE.z - 0.45) até o escapamento (EXHAUST.z - 0.15)
## ou 0.8 m atrás do eixo traseiro, entre as rodas de trás (|x| < roda - 0.35)
## e de 0.25 a 1.75 m de altura. Ficam de fora a carroceria pintada ("white"),
## pneu ("ban"), preto, banco ("chair"), direção ("STEER"), painéis ("sheet",
## sem textura), luzes ("light" e peças a menos de 10 cm dos pontos
## BRAKE_LIGHT/REVERSE_LIGHT/HEAD_LIGHT: as lanternas mexiam), chapas e
## travessas (espessura < 8 cm e mais de 80 cm), peças grandes (mais de 300
## faces ou 1.6 m). Escape: as peças a menos de 12 cm dos pontos EXHAUST,
## atrás do banco, até 2.2 m (os canos compridos que saem do motor).
## Carro sem ponto EXHAUST (Storm, fechado, motor escondido) não treme.
## Movimento (escolha nossa): vibração sorteada e filtrada, mais forte na
## lenta (coxim de borracha) e menor no giro alto, e o balanço do torque: o
## motor gira em volta do virabrequim (eixo z) puxado pela carga, numa mola
## pouco amortecida (acelerou ou soltou = tranco e volta).

# na câmera de corrida (6 m) 1 pixel é ~8 mm. 6 mm sorteados a cada quadro
# ficou "tremelento" demais (Matheus): metade, e o sorteio passa por um filtro
const VIB_LENTA := 0.004          # m na marcha lenta
const VIB_ALTO := 0.001           # m no corte
const VIB_SUAVE := 0.03           # s: o motor segue o sorteio com essa constante
const BALANCO_GRAUS := 3.0        # inclinação com carga cheia
const BALANCO_HZ := 3.0           # frequência da mola do coxim
const BALANCO_AMORT := 0.25       # amortecimento (fração do crítico)

var malha: MeshInstance3D         # peças do motor
var malha_escape: MeshInstance3D  # canos do escape (tremem junto)
var centro := Vector3.ZERO        # centro do motor (frame do modelo)
var faces := 0
var pecas := 0
var _ang := 0.0
var _vel := 0.0
var _vib := Vector3.ZERO


## tira as peças do cofre da malha da carroceria (mi) e monta a malha delas
## aqui (filho do mesmo pai, mesma posição). false = nada pra tremer
func separar(mi: MeshInstance3D, pontos: Dictionary) -> bool:
	if not (mi.mesh is ArrayMesh) or not pontos.has("ARSE") or not pontos.has("WHEEL_REAR_LEFT") \
			or not pontos.has("EXHAUST"):
		return false
	var escapes: Array = []
	var luzes: Array = []
	for k in pontos:
		if k.begins_with("EXHAUST"):
			escapes.append(pontos[k])
		elif k.begins_with("BRAKE_LIGHT") or k.begins_with("REVERSE_LIGHT") or k.begins_with("HEAD_LIGHT"):
			luzes.append(pontos[k])
	var mesh: ArrayMesh = mi.mesh
	var lo: Vector3
	var hi: Vector3
	var cof := _cofre(pontos)
	lo = cof[0]
	hi = cof[1]
	# triângulos de todas as superfícies, vértices soldados pela posição
	var pai := {}
	var tri: Array = []               # [superfície, i0, i1, i2, chave]
	var arrs: Array = []
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		arrs.append(a)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var n := ix.size() if ix.size() > 0 else v.size()
		for t in range(0, n - 2, 3):
			var ids := [ix[t], ix[t + 1], ix[t + 2]] if ix.size() > 0 else [t, t + 1, t + 2]
			var ks := []
			for i in ids:
				ks.append(Vector3i((v[i] * 10000.0).round()))
			_unir(pai, ks[0], ks[1])
			_unir(pai, ks[0], ks[2])
			tri.append([s, ids[0], ids[1], ids[2], ks[0]])
	# peças: caixa, faces e material por peça
	var info := {}
	for t in tri:
		var r = _raiz(pai, t[4])
		if not info.has(r):
			info[r] = {"lo": Vector3.INF, "hi": -Vector3.INF, "n": 0, "mat": {}, "d_esc": INF, "d_luz": INF}
		var p: Dictionary = info[r]
		var v: PackedVector3Array = arrs[t[0]][Mesh.ARRAY_VERTEX]
		for k in 3:
			var q: Vector3 = v[t[1 + k]]
			p.lo = p.lo.min(q)
			p.hi = p.hi.max(q)
			for e in escapes:
				p.d_esc = minf(p.d_esc, q.distance_to(e))
			for l in luzes:
				p.d_luz = minf(p.d_luz, q.distance_to(l))
		p.n += 1
		var nome := _nome_mat(mesh, mi, t[0])
		p.mat[nome] = p.mat.get(nome, 0) + 1
	var sai := {}
	var c_lo := Vector3.INF
	var c_hi := -Vector3.INF
	for r in info:
		var p: Dictionary = info[r]
		var tipo := _tipo(p, lo, hi)
		if tipo == 0:
			continue
		sai[r] = tipo
		pecas += 1
		if tipo == 1:
			c_lo = c_lo.min(p.lo)
			c_hi = c_hi.max(p.hi)
	if not c_lo.is_finite():
		return false
	centro = (c_lo + c_hi) * 0.5
	# duas malhas com as mesmas superfícies e materiais
	var malhas := [ArrayMesh.new(), ArrayMesh.new(), ArrayMesh.new()]   # fica, motor, escape
	var mats := [[], [], []]
	for s in mesh.get_surface_count():
		var ixs := [PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
		for t in tri:
			if t[0] != s:
				continue
			var k: int = sai.get(_raiz(pai, t[4]), 0)
			var ix: PackedInt32Array = ixs[k]
			ix.append_array(PackedInt32Array([t[1], t[2], t[3]]))
			ixs[k] = ix
		var m: Material = mi.get_surface_override_material(s)
		if m == null:
			m = mesh.surface_get_material(s)
		for k in 3:
			var ix: PackedInt32Array = ixs[k]
			if ix.is_empty():
				continue
			var a: Array = arrs[s].duplicate()
			a[Mesh.ARRAY_INDEX] = ix
			malhas[k].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
			mats[k].append(m)
			if k > 0:
				faces += ix.size() / 3
	mi.mesh = malhas[0]
	for s in mats[0].size():
		mi.set_surface_override_material(s, mats[0][s])
	malha = _instancia("Motor", malhas[1], mats[1], Color(1, 0, 0))
	malha_escape = _instancia("Escape", malhas[2], mats[2], Color(0, 0.3, 1))
	position = mi.position
	return true


## conferência (print_tela com MOTOR_COR=1): motor vermelho, escape azul
func _instancia(nome: String, m: ArrayMesh, mats: Array, cor: Color) -> MeshInstance3D:
	if m.get_surface_count() == 0:
		return null
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = m
	for s in mats.size():
		var mat: Material = mats[s]
		if OS.has_environment("MOTOR_COR"):
			var mc := StandardMaterial3D.new()
			mc.albedo_color = cor
			mat = mc
		mi.set_surface_override_material(s, mat)
	add_child(mi)
	return mi


static func _cofre(pontos: Dictionary) -> Array:
	var a: Vector3 = pontos["ARSE"]
	var rl: Vector3 = pontos["WHEEL_REAR_LEFT"]
	var z_tras := rl.z - 0.8
	for k in ["EXHAUST", "EXHAUST2"]:
		if pontos.has(k):
			z_tras = minf(z_tras, pontos[k].z)
	z_tras -= 0.15
	var meia := absf(rl.x) - 0.35
	return [Vector3(-meia, 0.25, z_tras), Vector3(meia, 1.75, a.z - 0.45)]


## 0 = fica na carroceria, 1 = motor, 2 = escape
static func _tipo(p: Dictionary, lo: Vector3, hi: Vector3) -> int:
	if p.n >= 300 or _proibido(_material(p)) or p.d_luz < 0.10:
		return 0
	var d: Vector3 = p.hi - p.lo
	var dims := [d.x, d.y, d.z]
	dims.sort()
	var no_cofre := true
	for k in 3:
		if p.lo[k] < lo[k] or p.hi[k] > hi[k]:
			no_cofre = false
	if no_cofre and dims[2] < 1.6 and not (dims[0] < 0.08 and dims[2] > 0.8):
		return 1
	# canos do escape: encostam no ponto EXHAUST, atrás do banco, entre as rodas
	if p.d_esc < 0.12 and dims[2] < 2.2 and p.hi.z <= hi.z and p.lo.x >= lo.x and p.hi.x <= hi.x:
		return 2
	return 0


static func _material(p: Dictionary) -> String:
	var maior := ""
	for m in p.mat:
		if maior == "" or p.mat[m] > p.mat[maior]:
			maior = m
	return maior


## pintura, pneu, preto, banco, direção, painéis e luzes nunca tremem
static func _proibido(nome: String) -> bool:
	var n := nome.to_lower()
	var suf := n.get_slice("_", 1) if "_" in n else n
	if suf in ["textura", "white", "ban", "black", "chair", "steer"]:
		return true
	for x in ["sheet", "light", "dakar"]:
		if x in n:
			return true
	return false


static func _nome_mat(mesh: ArrayMesh, mi: MeshInstance3D, s: int) -> String:
	var m := mesh.surface_get_material(s)
	if m and m.resource_name != "":
		return m.resource_name
	var o := mi.get_surface_override_material(s)
	return o.resource_name if o else "sem_textura"


static func _raiz(pai: Dictionary, k):
	var r = k
	while pai.has(r) and pai[r] != r:
		r = pai[r]
	var c = k
	while pai.has(c) and pai[c] != r:
		var prox = pai[c]
		pai[c] = r
		c = prox
	return r


static func _unir(pai: Dictionary, a, b) -> void:
	if not pai.has(a):
		pai[a] = a
	if not pai.has(b):
		pai[b] = b
	var ra = _raiz(pai, a)
	var rb = _raiz(pai, b)
	if ra != rb:
		pai[ra] = rb


## rpm do jogo (1000..8000), carga 0..1 (car.som_carga)
func atualizar(rpm: float, carga: float, dt: float) -> void:
	if dt <= 0.0 or (malha == null and malha_escape == null):
		return
	var r := clampf((rpm - 1000.0) / 7000.0, 0.0, 1.0)
	var amp := lerpf(VIB_LENTA, VIB_ALTO, r)
	var sorteio := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-0.3, 0.3)) * amp
	_vib += (sorteio - _vib) * (1.0 - exp(-dt / VIB_SUAVE))
	var vib := _vib
	# mola do coxim: alvo pela carga, tranco quando a carga muda
	var w := TAU * BALANCO_HZ
	var alvo := deg_to_rad(BALANCO_GRAUS) * clampf(carga, 0.0, 1.0)
	var acc := w * w * (alvo - _ang) - 2.0 * BALANCO_AMORT * w * _vel
	_vel += acc * dt
	_ang += _vel * dt
	var giro := Basis(Vector3(0, 0, 1), _ang)
	var t := Transform3D(giro, centro - giro * centro + vib)
	for m in [malha, malha_escape]:
		if m:
			m.transform = t
