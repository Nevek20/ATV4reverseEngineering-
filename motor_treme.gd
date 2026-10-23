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
## pneu ("ban"), sem textura (painéis), chapas e travessas (espessura < 8 cm e
## mais de 80 cm), peças grandes (mais de 300 faces ou 1.6 m).
## Movimento (escolha nossa): vibração sorteada a cada quadro, mais forte na
## lenta (coxim de borracha) e menor no giro alto, e o balanço do torque: o
## motor gira em volta do virabrequim (eixo z) puxado pela carga, numa mola
## pouco amortecida (acelerou ou soltou = tranco e volta).

# exagerado de propósito: na câmera de corrida (6 m) 1 pixel é ~8 mm
const VIB_LENTA := 0.006          # m na marcha lenta
const VIB_ALTO := 0.002           # m no corte
const BALANCO_GRAUS := 3.0        # inclinação com carga cheia
const BALANCO_HZ := 3.0           # frequência da mola do coxim
const BALANCO_AMORT := 0.25       # amortecimento (fração do crítico)

var malha: MeshInstance3D         # peças que tremem
var centro := Vector3.ZERO        # centro do motor (frame do modelo)
var faces := 0
var pecas := 0
var _ang := 0.0
var _vel := 0.0


## tira as peças do cofre da malha da carroceria (mi) e monta a malha delas
## aqui (filho do mesmo pai, mesma posição). false = nada pra tremer
func separar(mi: MeshInstance3D, pontos: Dictionary) -> bool:
	if not (mi.mesh is ArrayMesh) or not pontos.has("ARSE") or not pontos.has("WHEEL_REAR_LEFT"):
		return false
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
			info[r] = {"lo": Vector3.INF, "hi": -Vector3.INF, "n": 0, "mat": {}}
		var p: Dictionary = info[r]
		var v: PackedVector3Array = arrs[t[0]][Mesh.ARRAY_VERTEX]
		for k in 3:
			var q: Vector3 = v[t[1 + k]]
			p.lo = p.lo.min(q)
			p.hi = p.hi.max(q)
		p.n += 1
		var nome := _nome_mat(mesh, mi, t[0])
		p.mat[nome] = p.mat.get(nome, 0) + 1
	var sai := {}
	var c_lo := Vector3.INF
	var c_hi := -Vector3.INF
	for r in info:
		var p: Dictionary = info[r]
		if _treme(p, lo, hi):
			sai[r] = true
			c_lo = c_lo.min(p.lo)
			c_hi = c_hi.max(p.hi)
			pecas += 1
	if sai.is_empty():
		return false
	centro = (c_lo + c_hi) * 0.5
	# duas malhas com as mesmas superfícies e materiais
	var fica := ArrayMesh.new()
	var treme := ArrayMesh.new()
	var mats_fica: Array = []
	var mats_treme: Array = []
	for s in mesh.get_surface_count():
		var i_fica := PackedInt32Array()
		var i_treme := PackedInt32Array()
		for t in tri:
			if t[0] != s:
				continue
			var ids := PackedInt32Array([t[1], t[2], t[3]])
			if sai.has(_raiz(pai, t[4])):
				i_treme.append_array(ids)
			else:
				i_fica.append_array(ids)
		var m: Material = mi.get_surface_override_material(s)
		if m == null:
			m = mesh.surface_get_material(s)
		for par in [[fica, i_fica, mats_fica], [treme, i_treme, mats_treme]]:
			var ix: PackedInt32Array = par[1]
			if ix.is_empty():
				continue
			var a: Array = arrs[s].duplicate()
			a[Mesh.ARRAY_INDEX] = ix
			par[0].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
			par[2].append(m)
		faces += i_treme.size() / 3
	mi.mesh = fica
	for s in mats_fica.size():
		mi.set_surface_override_material(s, mats_fica[s])
	malha = MeshInstance3D.new()
	malha.name = "Motor"
	malha.mesh = treme
	var vermelho := OS.has_environment("MOTOR_COR")    # conferência: print_tela
	for s in mats_treme.size():
		var m: Material = mats_treme[s]
		if vermelho:
			var mr := StandardMaterial3D.new()
			mr.albedo_color = Color(1, 0, 0)
			m = mr
		malha.set_surface_override_material(s, m)
	add_child(malha)
	position = mi.position
	return true


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


static func _treme(p: Dictionary, lo: Vector3, hi: Vector3) -> bool:
	if p.n >= 300:
		return false
	for k in 3:
		if p.lo[k] < lo[k] or p.hi[k] > hi[k]:
			return false
	var d: Vector3 = p.hi - p.lo
	var dims := [d.x, d.y, d.z]
	dims.sort()
	if dims[2] >= 1.6 or (dims[0] < 0.08 and dims[2] > 0.8):
		return false
	var maior := ""
	for m in p.mat:
		if maior == "" or p.mat[m] > p.mat[maior]:
			maior = m
	var suf := maior.get_slice("_", 1).to_lower() if "_" in maior else maior.to_lower()
	return not (suf in ["textura", "white", "ban"])


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
	if malha == null or dt <= 0.0:
		return
	var r := clampf((rpm - 1000.0) / 7000.0, 0.0, 1.0)
	var amp := lerpf(VIB_LENTA, VIB_ALTO, r)
	var vib := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-0.3, 0.3)) * amp
	# mola do coxim: alvo pela carga, tranco quando a carga muda
	var w := TAU * BALANCO_HZ
	var alvo := deg_to_rad(BALANCO_GRAUS) * clampf(carga, 0.0, 1.0)
	var acc := w * w * (alvo - _ang) - 2.0 * BALANCO_AMORT * w * _vel
	_vel += acc * dt
	_ang += _vel * dt
	var giro := Basis(Vector3(0, 0, 1), _ang)
	malha.transform = Transform3D(giro, centro - giro * centro + vib)
