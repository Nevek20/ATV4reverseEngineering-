extends Node3D
## Peças da suspensão do jeito que o jogo põe. Cada peça do component map vira
## uma classe cCompPlace_<Position> (fábricas 0x208d40..0x2097e8) que copia uma
## matriz de pose recalculada a cada quadro (0x21dff8..0x221d58). Tudo no frame
## do modelo e a partir do curso x de cada roda. Conferido contra as matrizes
## das peças na RAM do Renegade e do Sphinx (tests/teste_pecas.gd).
##
## balança (0x21eec0): eixo u = linha 2 da matriz do ponto A_FRAME_* (vem do
##   arquivo de pontos, muda por carro), d = A_FRAME_END - A_FRAME,
##   r = |d.x*u.z + d.z*u.x|, ângulo = atan(x / r), gira em volta do A_FRAME.
## roda (0x220110): centro = WHEEL girado com a balança; na frente o y vira
##   WHEEL.y + x. A roda não herda a rotação da balança (só giro e direção).
## freio (0x221748 / 0x221928): o da frente gira só com a direção em volta do
##   WHEEL e vai junto com o centro da roda; o de trás só translada.
## amortecedor dianteiro (0x21f590): peça rígida, gira em z em volta do
##   SHOCKS_TOP até apontar pro SHOCKS_BOTTOM girado com a balança; ângulo
##   negativo na esquerda.
## traseiro (0x21fb68): câmara e haste com a mesma rotação em x; a haste é
##   levada até o SHOCK_PISTON girado (com o x original).
## rally (Storm, 0x220528 / 0x220cf0): roda = WHEEL + x, sem balança no meio.
## estepe (0x221a88): fixo, matriz e posição do ponto SpareWheel01Centre.
## O curso usado em tudo isso já tem a tremida das rodas no chão (car.gd,
## 0x202760), então balança, cubo, freio e amortecedor tremem juntos.
##
## Convenção: o jogo usa vetor-linha (v' = v*R + t, linhas = eixos). No Godot
## as colunas do Basis são as linhas do jogo: EixoAngulo(a, u) = Basis(u, a),
## Rx/Ry/Rz = Basis(RIGHT/UP/BACK, a), t = p - B*p pra girar em volta de p.
## "Esquerda" do jogo é x < 0 no modelo. Este nó fica dentro do espelho do
## carro (car.gd, escala (-1, 1, 1)): tudo aqui é frame do JOGO e o espelho
## põe no Godot, onde a esquerda do jogo vira +X. O ângulo de esterço que
## chega em update() já é o do jogo (car.gd a_jogo).

var car                      # car.gd
var off := Vector3.ZERO      # model_offset do carro
var corners := []            # um por roda
var rally := false
var spares := []             # transform de cada estepe (frame do modelo)


func build(c, pts: Dictionary, rot: Dictionary, dir: String, pecas: Dictionary,
		is_rally: bool, spare: Array, spare_mesh: Mesh) -> void:
	car = c
	off = c.model_offset
	rally = is_rally
	for side in ["LEFT", "RIGHT"]:
		for axle in ["FRONT", "REAR"]:
			var left: bool = side == "LEFT"
			var front: bool = axle == "FRONT"
			var k := {"left": left, "front": front}
			# roda da física do mesmo canto (w.left = esquerda do jogo)
			for w in c.wheels:
				if w.front == front and w.left == left:
					k.wheel = w
			var piv_name := "A_FRAME_%s_%s" % [axle, side]
			var end_name := "A_FRAME_END_%s_%s" % [axle, side]
			var wheel_name := "WHEEL_%s_%s" % [axle, side]
			if not (k.has("wheel") and pts.has(piv_name) and pts.has(end_name) and rot.has(piv_name)):
				continue
			k.pivot = pts[piv_name]
			k.end = pts[end_name]
			k.w0 = pts.get(wheel_name, c.jogo(Vector3(k.wheel.px, k.wheel.y0, k.wheel.pz)))
			k.u = (rot[piv_name] as Basis).z          # linha 2 do jogo
			var d: Vector3 = pts[end_name] - k.pivot
			k.r = absf(d.x * k.u.z + d.z * k.u.x)
			var pos := ("Front" if front else "Rear") + ("Left" if left else "Right")
			k.frame = _part(dir, pecas.get(pos + "Frame", ""))
			k.brake = _part(dir, pecas.get(pos + "FrameBrake", ""))
			if front:
				var t := "SHOCKS_TOP_FRONT_%s" % side
				var b := "SHOCKS_BOTTOM_FRONT_%s" % side
				k.shock = _part(dir, pecas.get(pos + "Shocks", ""))
				if k.shock and pts.has(t) and pts.has(b):
					k.top = pts[t]
					k.bottom = pts[b]
			else:
				var s := "L" if left else "R"
				var ch := "SHOCK_CHAMBER_R%s" % s
				var pi := "SHOCK_PISTON_R%s" % s
				k.chamber = _part(dir, pecas.get(pos + "ShockChamber", ""))
				k.piston = _part(dir, pecas.get(pos + "ShockPiston", ""))
				if (k.chamber or k.piston) and pts.has(ch) and pts.has(pi):
					k.top = pts[ch]
					k.bottom = pts[pi]
			corners.append(k)
	# estepe (BuggyCompMap_A1/B1/C1: RearWheel em SpareWheel01)
	for s in spare:
		var pn: String = s + "Centre"
		if spare_mesh and pts.has(pn):
			var mi := _mesh_instance(spare_mesh)
			var xf := Transform3D(rot.get(pn, Basis()), pts[pn])
			_place(mi, xf)
			spares.append(xf)


func _part(dir: String, file: String) -> MeshInstance3D:
	if file == "":
		return null
	var path := dir.path_join(file)
	if not ResourceLoader.exists(path):
		return null
	var mesh := load(path) as Mesh
	return _mesh_instance(mesh) if mesh else null


func _mesh_instance(mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		var m2: StandardMaterial3D = m.duplicate() if m is StandardMaterial3D else StandardMaterial3D.new()
		m2.cull_mode = car.MODEL_CULL
		mi.set_surface_override_material(i, m2)
	add_child(mi)
	mi.position = off
	return mi


## transform (no frame do modelo) que gira em volta de p
static func _about(p: Vector3, b: Basis) -> Transform3D:
	return Transform3D(b, p - b * p)


func _place(mi: MeshInstance3D, xf: Transform3D) -> void:
	if mi:
		mi.transform = Transform3D(Basis(), off) * xf


## matrizes de todas as peças pro curso x de cada canto (frame do modelo do
## jogo). steer = ângulo do jogo (Ry no frame do jogo). Separado do update pra
## o teste comparar com a RAM.
func pose(k: Dictionary, x: float, steer: float) -> Dictionary:
	var out := {}
	var b := Basis(k.u, atan(x / k.r)) if k.r > 1e-6 else Basis()
	var arm := _about(k.pivot, b)
	out.frame = arm
	var w0: Vector3 = k.w0
	var h: Vector3 = arm * w0
	if k.front:
		h.y = w0.y + x
	if rally:
		h = w0 + Vector3(0.0, x, 0.0)
	out.hub = h
	var bb := Basis(Vector3.UP, steer) if k.front else Basis()
	out.brake = Transform3D(bb, h - bb * w0)
	if k.has("top"):
		var top: Vector3 = k.top
		var bot: Vector3 = k.bottom
		if k.front:
			var b2: Vector3 = arm * bot
			var a := acos(clampf((bot - top).normalized().dot((b2 - top).normalized()), -1.0, 1.0))
			if k.left:
				a = -a
			out.shock = _about(top, Basis(Vector3.BACK, a))
		else:
			var q: Vector3 = arm * bot
			var p2 := Vector3(bot.x, q.y, q.z)
			# atan (não atan2), igual ao jogo
			var a := atan((top.y - bot.y) / (top.z - bot.z)) - atan((top.y - p2.y) / (top.z - p2.z))
			var r := Basis(Vector3.RIGHT, a)
			out.chamber = _about(top, r)
			out.piston = Transform3D(r, p2 - r * bot)
	return out


## steer_angle: ângulo das rodas no frame do jogo (car.gd a_jogo)
func update(steer_angle: float) -> void:
	for k in corners:
		var w: Dictionary = k.wheel
		# curso visual do jogo (0x222078) = curso + tremida (car.gd)
		var x: float = clampf(w.x, w.min, w.max) + w.get("jit", 0.0)
		var p := pose(k, x, steer_angle)
		_place(k.frame, p.frame)
		w.pivot.position = off + p.hub
		_place(k.brake, p.brake)
		if p.has("shock"):
			_place(k.shock, p.shock)
		if p.has("chamber"):
			_place(k.get("chamber"), p.chamber)
			_place(k.get("piston"), p.piston)
