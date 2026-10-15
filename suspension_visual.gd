extends Node3D
## Suspensão visual com as peças do próprio jogo (BuggyCompMap_B):
## balanças (Frames_*), amortecedores traseiros em duas peças (Shock_Chamber
## preso no chassi + Shock_Piston preso na balança), amortecedores dianteiros
## (Shock_Front_*) e discos/pinças de freio (Brake_*).
##
## As peças vêm modeladas no lugar (coordenadas do modelo) e o arquivo de
## pontos diz onde cada uma gira: A_FRAME_* (pivô da balança), A_FRAME_END_*
## (ponta, na roda), SHOCKS_TOP/BOTTOM_FRONT_*, SHOCK_CHAMBER/PISTON_R*.
## A cada quadro a balança gira no pivô até a ponta subir o mesmo tanto que a
## roda (curso x da física); o que é preso na balança acompanha, e os
## amortecedores apontam de um ponto ao outro.
##
## Blocos (unpacked/other), na ordem em que aparecem antes do modelo do carro:
##   base+0/1 balança dianteira E/D, +2/3 traseira E/D, +4 sombra (não usa),
##   +5/6 corpo do amortecedor traseiro, +7/8 amortecedor dianteiro,
##   +9/10 haste do amortecedor traseiro. Freios: brakes+0..3 = DE, DD, TE, TD.
## "Esquerda" no jogo é x < 0 no modelo.

var car                      # car.gd
var off := Vector3.ZERO      # model_offset do carro
var corners := []            # um por roda: {wheel, frame, end, brake, shocks...}


func build(c, pts: Dictionary, dir: String, base: int, brakes: int) -> void:
	car = c
	off = c.model_offset
	for side in ["LEFT", "RIGHT"]:
		for axle in ["FRONT", "REAR"]:
			var left: bool = side == "LEFT"
			var front: bool = axle == "FRONT"
			var k := {}
			# roda da física do mesmo canto (car.gd chama de Left o lado x > 0)
			for w in c.wheels:
				if w.front == front and (w.px - off.x < 0.0) == left:
					k.wheel = w
			if not k.has("wheel"):
				continue
			var i_side := 0 if left else 1
			var pivot_name := "A_FRAME_%s_%s" % [axle, side]
			var end_name := "A_FRAME_END_%s_%s" % [axle, side]
			if not (pts.has(pivot_name) and pts.has(end_name)):
				continue
			k.pivot = pts[pivot_name]
			k.end = pts[end_name]
			k.front = front
			var fb := base + (0 if front else 2) + i_side
			k.frame = _part(dir, fb)
			var bi := (0 if front else 2) + i_side
			k.brake = _part(dir, brakes + bi) if brakes >= 0 else null
			if front:
				var t := "SHOCKS_TOP_FRONT_%s" % side
				var b := "SHOCKS_BOTTOM_FRONT_%s" % side
				if pts.has(t) and pts.has(b):
					k.top = pts[t]
					k.bottom = pts[b]
					k.shock = _part(dir, base + 7 + i_side)
			else:
				var s := "L" if left else "R"
				var ch := "SHOCK_CHAMBER_R%s" % s
				var pi := "SHOCK_PISTON_R%s" % s
				if pts.has(ch) and pts.has(pi):
					k.top = pts[ch]
					k.bottom = pts[pi]
					k.chamber = _part(dir, base + 5 + i_side)
					k.piston = _part(dir, base + 9 + i_side)
			# eixo da balança: horizontal e perpendicular ao braço
			var d: Vector3 = k.end - k.pivot
			var axis := Vector3.UP.cross(d)
			k.axis = axis.normalized() if axis.length() > 1e-4 else Vector3.RIGHT
			corners.append(k)


func _part(dir: String, block: int) -> MeshInstance3D:
	var path := "%s/%d_bloco.obj" % [dir, block]
	if not ResourceLoader.exists(path):
		return null
	var mesh := load(path) as Mesh
	if mesh == null:
		return null
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


## ângulo que gira a ponta da balança até ela subir dy
func _arm_angle(k: Dictionary, dy: float) -> float:
	var d: Vector3 = k.end - k.pivot
	var ax: Vector3 = k.axis
	var u := d - ax * d.dot(ax)          # parte que gira
	var a := u.y
	var b := ax.cross(u).y
	var r := sqrt(a * a + b * b)
	if r < 1e-5:
		return 0.0
	var c := clampf((a + dy) / r, -1.0, 1.0)
	var phi := atan2(b, a)
	var t1 := phi + acos(c)
	var t2 := phi - acos(c)
	t1 = wrapf(t1, -PI, PI)
	t2 = wrapf(t2, -PI, PI)
	return t1 if absf(t1) < absf(t2) else t2


## transform (no frame do modelo) que gira em torno de p
static func _about(p: Vector3, basis: Basis) -> Transform3D:
	return Transform3D(basis, p - basis * p)


## base que leva a direção a até a direção b (menor rotação)
static func _aim(a: Vector3, b: Vector3) -> Basis:
	a = a.normalized()
	b = b.normalized()
	var ax := a.cross(b)
	var s := ax.length()
	if s < 1e-6:
		return Basis()
	return Basis(ax / s, atan2(s, a.dot(b)))


func _place(mi: MeshInstance3D, xf: Transform3D) -> void:
	if mi:
		mi.transform = Transform3D(Basis(), off) * xf


func update(steer_angle: float) -> void:
	for k in corners:
		var w: Dictionary = k.wheel
		var dy: float = clampf(w.x, w.min, w.max)
		var th := _arm_angle(k, dy)
		var arm := _about(k.pivot, Basis(k.axis, th))
		_place(k.frame, arm)
		# no jogo a roda é filha da balança (FrontLeftFrameWheel): o centro dela
		# descreve o mesmo arco da ponta (só a posição; o contato da física
		# continua reto)
		var wp := Vector3(w.px, w.y0, w.pz) - off
		w.pivot.position = off + arm * wp
		if k.brake:
			var bx := arm
			if k.front and steer_angle != 0.0:
				var c: Vector3 = arm * k.end
				bx = _about(c, Basis(Vector3.UP, steer_angle)) * arm
			_place(k.brake, bx)
		if not k.has("top"):
			continue
		var top: Vector3 = k.top
		var bot: Vector3 = k.bottom
		var bot2: Vector3 = arm * bot           # ponto de baixo vai com a balança
		var rot := _aim(bot - top, bot2 - top)
		if k.has("shock"):
			# peça única: gira no topo e encolhe/estica no próprio eixo
			var axis := (bot - top).normalized()
			var s := (bot2 - top).length() / maxf((bot - top).length(), 1e-4)
			var sc := Basis(Vector3.RIGHT + axis * axis.x * (s - 1.0),
				Vector3.UP + axis * axis.y * (s - 1.0),
				Vector3.BACK + axis * axis.z * (s - 1.0))
			_place(k.shock, _about(top, rot * sc))
		else:
			_place(k.chamber, _about(top, rot))
			# a haste vai junto com o ponto de baixo e aponta pro topo
			var rot2 := _aim(top - bot, top - bot2)
			_place(k.piston, Transform3D(rot2, bot2 - rot2 * bot))
