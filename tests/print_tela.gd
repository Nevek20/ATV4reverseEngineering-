extends SceneTree
## Tira um print do carro parado na pista, sem abrir o editor.
## "jogo" usa a câmera de corrida portada (a mesma do F5).
## Uso (precisa de tela; na nuvem: xvfb-run -a ... --rendering-driver opengl3):
##   godot --path . -s res://tests/print_tela.gd -- saida.png [lado|tras|frente|jogo|...] [veiculo]
##
## Diagnóstico da suspensão (variáveis de ambiente, todas opcionais). Com
## VISTAS, CURSOS ou MEDIR o carro assenta, congela e tira todos os prints de
## uma vez (paga os ~70 s de carga uma vez só):
##   VISTAS=lado0,frente0,tras0 vistas; os arquivos saem <saida>_<curso>_<vista>.png
##                              (vista terminada em _sc = sem carroceria, ex. lado0_sc)
##   CURSOS=nat,0,max,min       curso x forçado nas 4 rodas (m, + = comprimida):
##                              número, max/min (Maximum/Minimum_position que a
##                              física usa) ou nat (onde a física deixou parado)
##   CURSO=0.2                  atalho pra um curso só
##   MEDIR=1                    imprime as medidas de cada canto em cada curso e
##                              salva <saida>_medidas.json (ver _medir/_estatico)
##   CORPO=0                    esconde a carroceria em todas as vistas
##   PASTA=res://assets/buggy_02 (pasta com o pecas.json)  PONTOS=res://...
##   RODA_F=res://...  RODA_T=res://...
##                              troca pasta/pontos/rodas sem mexer no main.gd
##                              (teste de hipótese)
## Exemplo (Inferno, 3 vistas x 4 cursos, com medidas):
##   VISTAS=lado0,frente0,tras0,lado0_sc CURSOS=nat,0,max,min MEDIR=1 xvfb-run -a $GODOT --path . \
##     --rendering-driver opengl3 -s res://tests/print_tela.gd -- /tmp/inf.png lado 4

const Car := preload("res://car.gd")

var frames := 0
var main
var out := "print.png"
var view := "lado"
var veh := 0

# modo diagnóstico
var multi := false
var vistas: PackedStringArray = []
var cursos: PackedStringArray = []
var medir := false
var shots := []                 # [[curso, vista], ...]
var shot_i := 0
var wait := 0
var cur_curso := ""
var nat_x := []
var medidas := {}
var vcache := {}                # Mesh -> PackedVector3Array (frame do modelo)
var body_v := PackedVector3Array()

const OFFS := {"lado": Vector3(4.5, 1.2, 0.0), "tras": Vector3(0.0, 1.6, -6.0),
	"frente": Vector3(2.5, 1.0, 5.0), "outro_lado": Vector3(-4.5, 1.2, 0.0),
	"cima": Vector3(0.01, 7.0, 0.0), "tras_baixo": Vector3(1.5, 0.6, -4.0),
	"roda_tras": Vector3(-2.6, 1.0, -0.6), "persegue": Vector3(0.0, 2.3, -6.5),
	"frente_esq": Vector3(-3.5, 2.0, 4.5), "garagem_lado": Vector3(-5.0, 1.0, 0.6),
	"garagem_tras": Vector3(-3.2, 1.3, -4.6), "roda_tras_dentro": Vector3(0.0, 0.3, -0.8),
	# diagnóstico: lado (x > 0 = direita do jogo), frente e trás retos e baixos
	"lado0": Vector3(6.2, 0.7, 0.0), "outro_lado0": Vector3(-6.2, 0.7, 0.0),
	"frente0": Vector3(0.0, 0.7, 5.6), "tras0": Vector3(0.0, 0.7, -5.6)}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		view = args[1]
	if args.size() > 2:
		veh = int(args[2])
	if OS.has_environment("VISTAS"):
		vistas = OS.get_environment("VISTAS").split(",", false)
	if OS.has_environment("CURSOS"):
		cursos = OS.get_environment("CURSOS").split(",", false)
	elif OS.has_environment("CURSO"):
		cursos = [OS.get_environment("CURSO")]
	medir = OS.get_environment("MEDIR") == "1"
	multi = not vistas.is_empty() or not cursos.is_empty() or medir
	if multi:
		if vistas.is_empty():
			vistas = [view]
		if cursos.is_empty():
			cursos = ["nat"]
		for c in cursos:
			for v in vistas:
				shots.append([c, v])
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _overrides() -> bool:
	for k in ["PASTA", "PONTOS", "RODA_F", "RODA_T"]:
		if OS.has_environment(k):
			return true
	return false


## mesmo que main.spawn_vehicle, mas com as trocas das variáveis de ambiente
func _spawn(i: int) -> void:
	var v: Dictionary = main.VEHICLES[i]
	main.car.queue_free()
	main.veh_idx = i
	var c = Car.new()
	c.asset_dir = OS.get_environment("PASTA") if OS.has_environment("PASTA") else v.dir
	c.data_files = ["res://data/vehicles/buggy_base.xml", v.data]
	c.points_file = OS.get_environment("PONTOS") if OS.has_environment("PONTOS") else v.points
	c.vehicle_id = v.id
	c.tune_override = v.get("tune", {})
	c.livery_file = v.get("livery", "pintura.png")
	if OS.has_environment("RODA_F"):
		c.wheel_front_file = OS.get_environment("RODA_F")
	if OS.has_environment("RODA_T"):
		c.wheel_rear_file = OS.get_environment("RODA_T")
	c.vehicle_name = "%s (%s)" % [v.name, v.id]
	main.add_child(c)
	main.car = c
	c.reset_to(main.spawn_point(), deg_to_rad(90.0))
	main.gcams.clear()
	main.cam_ready = false


func _process(_dt: float) -> bool:
	frames += 1
	if frames == 2 and (veh != main.veh_idx or _overrides()):
		if _overrides():
			_spawn(veh)
		else:
			main.car.queue_free()
			main.spawn_vehicle(veh, main.spawn_point(), deg_to_rad(90.0))
	if multi:
		return _process_multi()
	if frames == 90 and view != "jogo":
		_camera(view)
	if frames == 94:
		_chao()
	if frames == 95:
		root.get_viewport().get_texture().get_image().save_png(out)
		print("print salvo em ", out)
		return true
	return false


func _camera(v: String) -> void:
	var car: Node3D = main.car
	if multi:
		# _sc = sem carroceria (só suspensão e rodas). Esconde os filhos: o
		# main.gd mexe no model_root.visible todo quadro
		var corpo := not v.ends_with("_sc") and OS.get_environment("CORPO") != "0"
		for ch in car.model_root.get_children():
			ch.visible = corpo
		v = v.trim_suffix("_sc")
	var t := car.global_transform
	var off: Vector3 = OFFS.get(v, Vector3(4.5, 1.2, 0.0))
	var alvo := Vector3(0, 0.7, 0)
	if v.ends_with("0"):
		alvo = Vector3(0, 0.5, 0)
	if v.begins_with("roda_tras"):
		for w in car.wheels:
			if not w.front and w.px < 0.0:
				alvo = w.pivot.position
	var cam: Camera3D = root.get_node_or_null("CamPrint")
	if cam == null:
		cam = Camera3D.new()
		cam.name = "CamPrint"
		root.add_child(cam)
	cam.fov = 45.0
	cam.global_position = t * off
	cam.look_at(t * alvo, Vector3.UP)
	cam.current = true


## folga de cada roda até o chão (raio do modelo, raycast do centro)
func _chao() -> Dictionary:
	var c = main.car
	var res := {}
	var space: PhysicsDirectSpaceState3D = c.get_world_3d().direct_space_state
	for w in c.wheels:
		var mi: MeshInstance3D = w.spin_node.get_child(0)
		var p: Vector3 = mi.global_position
		var q := PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 3.0)
		q.exclude = [c.get_rid()]
		var hit := space.intersect_ray(q)
		var r: float = mi.get_aabb().size.y * 0.5
		var lp: Vector3 = c.global_transform.affine_inverse() * p - c.model_offset
		var nome := _canto(w)
		print("roda %s modelo (%.4f, %.4f, %.4f) curso %.4f" % [nome, lp.x, lp.y, lp.z, w.x])
		var d := {"curso": w.x, "r_modelo": r, "r_fisica": w.r, "min": w.min, "max": w.max}
		if hit:
			var h: float = p.y - hit.position.y
			print("roda %s: centro %.3f m do chão, raio modelo %.3f, raio física %.3f, folga %.3f" % [
				nome, h, r, w.r, h - r])
			d.altura_centro = h
			d.folga_modelo = h - r
			d.folga_fisica = h - w.r
		res[nome] = d
	return res


## canto no padrão do jogo: E = x < 0 no modelo (car.gd chama x > 0 de Left)
func _canto(w: Dictionary) -> String:
	var x: float = w.px - main.car.model_offset.x
	return ("F" if w.front else "T") + ("E" if x < 0.0 else "D")


func _process_multi() -> bool:
	var car = main.car
	if frames < 90:
		return false
	if frames == 90:
		medidas.veiculo = main.VEHICLES[veh].name
		medidas.pontos = car.points_file
		medidas.pecas = car.pecas.get("pecas", {})
		medidas.rodas = [car.wheel_front_file, car.wheel_rear_file]
		medidas.chao_nat = _chao()
		# congela: física parada, sem interpolação (as peças vão direto pro lugar)
		car.set_physics_process(false)
		car.freeze = true
		car.linear_velocity = Vector3.ZERO
		car.angular_velocity = Vector3.ZERO
		car.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		for w in car.wheels:
			nat_x.append(w.x)
		main.hud.visible = false
		if medir:
			_body_verts()
			medidas.estatico = _estatico()
		medidas.cursos = {}
		wait = -1
		return false
	if shot_i >= shots.size():
		if medir:
			var f := FileAccess.open(out.get_basename() + "_medidas.json", FileAccess.WRITE)
			if f:
				f.store_string(JSON.stringify(medidas, "  "))
		print("prints: %d" % shots.size())
		return true
	var s: Array = shots[shot_i]
	if wait < 0:
		if s[0] != cur_curso:
			cur_curso = s[0]
			_apply_curso(cur_curso)
			if medir:
				medidas.cursos[cur_curso] = _medir()
		_camera(s[1])
		wait = 3
		return false
	wait -= 1
	if wait == 0:
		var path := "%s_%s_%s.png" % [out.get_basename(), s[0], s[1]]
		root.get_viewport().get_texture().get_image().save_png(path)
		print("print salvo em ", path)
		shot_i += 1
		wait = -1
	return false


func _apply_curso(c: String) -> void:
	var car = main.car
	for i in car.wheels.size():
		var w: Dictionary = car.wheels[i]
		match c:
			"nat":
				w.x = nat_x[i]
			"max":
				w.x = w.max
			"min":
				w.x = w.min
			_:
				w.x = float(c)
	car._update_visuals(0.0, 0.0)
	var txt := []
	for w in car.wheels:
		txt.append("%s %.3f" % [_canto(w), w.x])
	print("curso %s: %s" % [c, ", ".join(txt)])


# ------------------------------------------------------------ medidas
func _mesh_verts(mi: MeshInstance3D) -> PackedVector3Array:
	if mi == null or mi.mesh == null:
		return PackedVector3Array()
	if vcache.has(mi.mesh):
		return vcache[mi.mesh]
	var out_v := PackedVector3Array()
	for i in mi.mesh.get_surface_count():
		var a := mi.mesh.surface_get_arrays(i)
		out_v.append_array(a[Mesh.ARRAY_VERTEX])
	vcache[mi.mesh] = out_v
	return out_v


func _body_verts() -> void:
	var car = main.car
	for ch in car.model_root.get_children():
		if ch is MeshInstance3D:
			body_v.append_array(_mesh_verts(ch))


## xf da peça no frame do modelo (a malha já vem nas coordenadas do modelo)
func _xf(mi: MeshInstance3D) -> Transform3D:
	return Transform3D(Basis(), -main.car.model_offset) * mi.transform


static func _nearest(vs: PackedVector3Array, xf: Transform3D, p: Vector3) -> float:
	var best := INF
	for v in vs:
		best = minf(best, (xf * v).distance_squared_to(p))
	return sqrt(best)


## comprimento da malha ao longo de um eixo (projeção dos vértices)
static func _extent(vs: PackedVector3Array, axis: Vector3) -> Vector2:
	var lo := INF
	var hi := -INF
	for v in vs:
		var t := v.dot(axis)
		lo = minf(lo, t)
		hi = maxf(hi, t)
	return Vector2(lo, hi)


## vértices de uma malha dentro do pneu (anel de 0.7 r a r, na largura da roda)
static func _no_pneu(vs: PackedVector3Array, xf: Transform3D, c: Vector3, r: float, hw: float) -> Array:
	var n := 0
	var fundo := 0.0
	for v in vs:
		var p := xf * v
		if absf(p.x - c.x) > hw:
			continue
		var rr := Vector2(p.y - c.y, p.z - c.z).length()
		if rr > 0.7 * r and rr < r:
			n += 1
			fundo = maxf(fundo, r - rr)
	return [n, fundo]


## coisas que não mudam com o curso: a peça bate com os pontos? corpo dentro da roda?
func _estatico() -> Dictionary:
	var car = main.car
	var susp = car.susp_vis
	var res := {}
	var off: Vector3 = car.model_offset
	for w in car.wheels:
		var nome := _canto(w)
		var d := {}
		var mi: MeshInstance3D = w.spin_node.get_child(0)
		var ab := mi.get_aabb()
		var r := ab.size.y * 0.5
		var hw := ab.size.x * 0.5
		var c := Vector3(w.px, w.y0, w.pz) - off
		d.ponto_roda = [c.x, c.y, c.z]
		d.r_modelo = r
		d.r_fisica = w.r
		d.largura_roda = ab.size.x
		# carroceria dentro do volume da roda (cilindro inteiro) na pose de repouso
		var n := 0
		var fundo := 0.0
		for v in body_v:
			if absf(v.x - c.x) > hw:
				continue
			var rr := Vector2(v.y - c.y, v.z - c.z).length()
			if rr < r:
				n += 1
				fundo = maxf(fundo, r - rr)
		d.corpo_no_volume_da_roda = n
		d.corpo_fundo = fundo
		res[nome] = d
	if susp == null:
		return res
	for k in susp.corners:
		var nome := _canto(k.wheel)
		var d: Dictionary = res[nome]
		d.pivo = [k.pivot.x, k.pivot.y, k.pivot.z]
		d.fim = [k.end.x, k.end.y, k.end.z]
		d.fim_ate_ponto_roda = (k.end - k.w0).length()
		d.eixo = [k.u.x, k.u.y, k.u.z]
		d.braco_r = k.r
		# a malha da peça passa pelos pontos? (distância ao vértice mais perto)
		if k.frame:
			var vs: PackedVector3Array = _mesh_verts(k.frame)
			d.balanca_pivo_fora = _nearest(vs, Transform3D(), k.pivot)
			d.balanca_fim_fora = _nearest(vs, Transform3D(), k.end)
			d.balanca_pivo_ate_corpo = _nearest(body_v, Transform3D(), k.pivot)
		else:
			d.balanca = "sem peça"
		if k.brake:
			var vb: PackedVector3Array = _mesh_verts(k.brake)
			var cb: Vector3 = k.brake.mesh.get_aabb().get_center()
			d.freio_centro = [cb.x, cb.y, cb.z]
			d.freio_radial = Vector2(cb.y - k.w0.y, cb.z - k.w0.z).length()
			d.freio_fim_fora = _nearest(vb, Transform3D(), k.end)
		if k.has("top"):
			d.amort_topo_ate_corpo = _nearest(body_v, Transform3D(), k.top)
			if k.has("shock") and k.shock:
				var vs2: PackedVector3Array = _mesh_verts(k.shock)
				d.amort_topo_fora = _nearest(vs2, Transform3D(), k.top)
				d.amort_baixo_fora = _nearest(vs2, Transform3D(), k.bottom)
			if k.has("chamber") and k.chamber:
				d.camara_topo_fora = _nearest(_mesh_verts(k.chamber), Transform3D(), k.top)
			if k.has("piston") and k.piston:
				d.haste_baixo_fora = _nearest(_mesh_verts(k.piston), Transform3D(), k.bottom)
			if k.has("chamber") and k.chamber and k.has("piston") and k.piston:
				# quanto a câmara e a haste se sobrepõem no eixo do amortecedor
				var ax: Vector3 = (k.bottom - k.top).normalized()
				var ec: Vector2 = _extent(_mesh_verts(k.chamber), ax)
				var ep: Vector2 = _extent(_mesh_verts(k.piston), ax)
				d.amort_sobreposicao = ec.y - ep.x
			if k.frame:
				d.amort_baixo_ate_balanca = _nearest(_mesh_verts(k.frame), Transform3D(), k.bottom)
	return res


## medidas de cada canto no curso atual (frame do modelo, metros e graus)
func _medir() -> Dictionary:
	var car = main.car
	var susp = car.susp_vis
	var off: Vector3 = car.model_offset
	var res := {}
	for w in car.wheels:
		var nome := _canto(w)
		var c: Vector3 = w.pivot.position - off
		var c0 := Vector3(w.px, w.y0, w.pz) - off
		var dd := c - c0
		var side := signf(c0.x)
		var d := {"x": w.x, "centro": [c.x, c.y, c.z],
			"desloc_fora": dd.x * side, "desloc_cima": dd.y, "desloc_frente": dd.z,
			"desloc_horiz": Vector2(dd.x, dd.z).length(),
			"ang_da_vertical": rad_to_deg(atan2(Vector2(dd.x, dd.z).length(), absf(dd.y))) if dd.length() > 1e-4 else 0.0}
		res[nome] = d
	if susp == null:
		return res
	for k in susp.corners:
		var w: Dictionary = k.wheel
		var nome := _canto(w)
		var d: Dictionary = res[nome]
		var dy: float = clampf(w.x, w.min, w.max)
		var th: float = atan(dy / k.r) if k.r > 1e-6 else 0.0
		d.ang_balanca = rad_to_deg(th)
		d.eixo = "(%.2f %.2f %.2f)" % [k.u.x, k.u.y, k.u.z]
		var arm: Transform3D = susp.pose(k, dy, 0.0).frame
		var c: Vector3 = w.pivot.position - off
		d.subiu_pedido = dy
		d.subiu_de_fato = c.y - k.w0.y
		var e: Vector3 = arm * k.end
		d.fim_ate_centro = (e - c).length()
		var mi: MeshInstance3D = w.spin_node.get_child(0)
		var ab := mi.get_aabb()
		var r := ab.size.y * 0.5
		var hw := ab.size.x * 0.5
		if k.frame:
			var xf: Transform3D = _xf(k.frame)
			var vs: PackedVector3Array = _mesh_verts(k.frame)
			d.balanca_ate_centro = _nearest(vs, xf, c)
			var np: Array = _no_pneu(vs, xf, c, r, hw)
			d.balanca_no_pneu = np[0]
			d.balanca_no_pneu_fundo = np[1]
		if k.brake:
			var xb: Transform3D = _xf(k.brake)
			var cb: Vector3 = xb * k.brake.mesh.get_aabb().get_center()
			d.freio_radial = Vector2(cb.y - c.y, cb.z - c.z).length()
			d.freio_axial_fora = (cb.x - c.x) * signf(c.x)
		if k.has("top"):
			var top: Vector3 = k.top
			var bot2: Vector3 = arm * k.bottom
			d.amort_comprimento = (bot2 - top).length()
			d.amort_variacao = (bot2 - top).length() - (k.bottom - top).length()
			if k.frame:
				d.amort_baixo_ate_balanca = _nearest(_mesh_verts(k.frame), _xf(k.frame), bot2)
			var ref: MeshInstance3D = null
			if k.has("shock"):
				ref = k.shock
			elif k.has("piston"):
				ref = k.piston
			if ref:
				d.amort_peca_baixo_ate_ponto = _nearest(_mesh_verts(ref), _xf(ref), bot2)
		var s1 := " sem balança"
		if d.has("balanca_ate_centro"):
			s1 = " balança->centro %.3f no pneu %d (%.3f)" % [d.balanca_ate_centro, d.balanca_no_pneu, d.balanca_no_pneu_fundo]
		var s2 := (" freio radial %.3f" % d.freio_radial) if d.has("freio_radial") else ""
		var s3 := ""
		if d.has("amort_variacao"):
			s3 = " amort %+.3f, ponta->balança %.3f" % [d.amort_variacao, d.get("amort_baixo_ate_balanca", -1.0)]
		print("%s x=%+.3f bal %+6.1f° (%s) centro sobe %+.3f fora %+.3f frente %+.3f (%.0f° da vertical) fim->centro %.3f%s%s%s" % [
			nome, w.x, d.ang_balanca, d.eixo, d.desloc_cima, d.desloc_fora, d.desloc_frente,
			d.ang_da_vertical, d.fim_ate_centro, s1, s2, s3])
	return res
