extends SceneTree
## Carro caído de lado e de cabeça pra baixo em chão plano (casco de colisão,
## car._casco): solta cada carro a 3 m girado 90° e 180° em volta da frente,
## espera assentar e mede quanto a carroceria e as rodas (caixa das malhas)
## entram no chão. VEHS = índices da frota (padrão Renegade, Buccaneer,
## Jericho, Fireball, Goliath, Chimera). Com o casco do jogo a carroceria não
## pode entrar mais que uns cm (o casco é mais justo que a malha em alguns
## cantos); rodas de lado entram quando ficam pra fora do casco (no jogo a
## roda só encosta pela suspensão, até ~50° do eixo dela).
## Uso: godot --headless --path . -s res://tests/teste_de_lado.gd

const Car := preload("res://car.gd")
const Main := preload("res://main.gd")

var carros := []        # [car, nome, giro]
var t := 0.0


func _initialize() -> void:
	var vehs := (OS.get_environment("VEHS") if OS.has_environment("VEHS") else "0,13,16,22,23,24").split(",")
	var chao := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()      # plano infinito em y = 0
	chao.add_child(cs)
	root.add_child(chao)
	var k := 0
	for vi in vehs:
		var v: Dictionary = Main.frota()[int(vi)]
		for giro in [90.0, 180.0]:
			var c = Car.new()
			c.asset_dir = v.dir
			c.data_files = Main.dados(v)
			c.points_file = v.points
			c.vehicle_id = v.id
			c.suspension = false
			c.melhorias = false
			root.add_child(c)
			c.reset_to(Vector3(k * 12.0, 3.0, 0.0), 0.0)
			c.global_transform.basis = c.global_transform.basis * Basis(Vector3.BACK, deg_to_rad(giro))
			c.test_input = {"thr": 0.0, "brk": 0.0, "steer": 0.0}
			carros.append([c, v.name, giro])
			k += 1


## menor y (mundo) da caixa de uma malha
func _fundo(mi: MeshInstance3D) -> float:
	var a := mi.get_aabb()
	var xf := mi.global_transform
	var m := INF
	for i in 8:
		m = minf(m, (xf * a.get_endpoint(i)).y)
	return m


func _physics_process(dt: float) -> bool:
	t += dt
	if t < 5.0:
		return false
	print("carro de lado (90°) e capotado (180°), 5 s depois de cair de 3 m")
	for e in carros:
		var c = e[0]
		var corpo := _fundo(c.body_mi) if c.body_mi else 0.0
		var roda := INF
		for w in c.wheels:
			if w.has("spin_node") and w.spin_node.get_child_count() > 0:
				roda = minf(roda, _fundo(w.spin_node.get_child(0)))
		var up: Vector3 = c.global_transform.basis.y
		print("  %-14s %3d°  inclinação %5.1f°  carroceria %5.1f cm  roda %5.1f cm (negativo = dentro do chão)" % [
			e[1], int(e[2]), rad_to_deg(acos(clampf(up.y, -1.0, 1.0))), corpo * 100.0, roda * 100.0])
	return true
