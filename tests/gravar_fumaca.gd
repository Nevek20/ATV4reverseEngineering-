extends SceneTree
## Fumaça x boca do escapamento: o carro acelera reto e uma câmera presa nele
## (no quadro desenhado, interpolado) olha o cano de perto de trás e de lado.
## A fumaça tem que nascer na boca do cano parado, acelerando e com o motor
## tremendo. Grava com o Movie Maker:
##   godot --path . --write-movie fumaca.avi --fixed-fps 60 -s res://tests/gravar_fumaca.gd -- 0
## (na nuvem só no Forward+ com lavapipe: no Compatibility do xvfb as
## partículas não aparecem; os primeiros ~20 quadros vêm sem fumaça). DUR=6 segundos,
## ACEL=0 fica parado; VEL0=80 começa andando; CAM=1.2,0.4,-1.0 câmera em volta do cano (frame do
## corpo, a partir do ponto EXHAUST), CAM=jogo a câmera de corrida. FUMACA_COR=1 pinta a fumaça de vermelho.

var main
var veh := 0
var t := 0.0
var dur := 6.0
var pronto := false
var cam: Camera3D
var cano := Vector3.ZERO
var off := Vector3(0.6, 0.25, -0.9)


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		veh = int(a[0])
	dur = float(_env("DUR")) if _env("DUR") != "" else 6.0
	var p := _env("CAM").split(",")
	if p.size() == 3:
		off = Vector3(float(p[0]), float(p[1]), float(p[2]))
	elif _env("CAM") not in ["", "jogo"]:
		push_error("CAM: x,y,z ou jogo (veio '%s')" % _env("CAM"))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


## variável de ambiente sem espaço nas pontas: no cmd do Windows
## "set CAM=jogo & ..." guarda "jogo " (com o espaço antes do &)
static func _env(nome: String) -> String:
	return OS.get_environment(nome).strip_edges()


func _process(dt: float) -> bool:
	if main == null:
		return true
	if not pronto:
		if main.car == null:
			return false
		if main.veh_idx != veh:
			main.car.queue_free()
			main.spawn_vehicle(veh, main.spawn_point(), deg_to_rad(main.SPAWN_YAW))
			return false
		var car = main.car
		for k in car.points:
			if String(k).begins_with("EXHAUST"):
				cano = car.corpo(car.points[k])
				break
		if _env("VEL0") != "":              # VEL0=80: já começa andando (km/h)
			car.linear_velocity = car.forward() * float(_env("VEL0")) / 3.6
			car.test_input = {"thr": 1.0, "brk": 0.0, "steer": 0.0}
		pronto = true
		if _env("CAM") == "jogo":           # CAM=jogo: câmera de corrida do main
			return false
		cam = Camera3D.new()
		cam.fov = 50.0
		cam.near = 0.02
		root.add_child(cam)
		cam.current = true
		return false
	var car = main.car
	main.hud.visible = false
	if car.luzes:
		car.luzes.visible = false       # a lanterna de freio acesa parado parecia fumaça vermelha
	t += dt
	var acel := _env("ACEL") != "0"
	var ja := _env("VEL0") != ""
	car.test_input = {"thr": 1.0 if acel and (ja or t > 1.0) else 0.0, "brk": 0.0, "steer": 0.0}
	if cam == null:
		return t > dur
	var xf: Transform3D = car.get_global_transform_interpolated()
	var lado := Vector3(off.x * signf(cano.x if cano.x != 0.0 else 1.0), off.y, off.z)
	cam.global_transform = xf * Transform3D(Basis(), cano + lado).looking_at(cano, Vector3.UP)
	if int(t * 2.0) != int((t - dt) * 2.0):
		print("%.1f s  %3.0f km/h  rpm %4.0f" % [t, car.linear_velocity.length() * 3.6, car.rpm])
	return t > dur
