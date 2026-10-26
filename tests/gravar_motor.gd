extends SceneTree
## Prévia do motor animado (motor_anima.gd): carro parado com o giro forçado
## (lenta, sobe até 7000 rpm e volta) e a câmera perto do motor. Grava com o
## Movie Maker do Godot:
##   godot --path . --write-movie motor.avi --fixed-fps 60 -s res://tests/gravar_motor.gd -- 7
## (na nuvem: xvfb-run -a ... --rendering-driver opengl3). O argumento é o
## índice em main.VEHICLES; CAM_OFF=x,y,z e CAM_ALVO=x,y,z (frame do jogo,
## como no print_tela) trocam a câmera.

const DUR := 8.0

var main
var veh := 0
var t := 0.0
var pronto := false
var cam: Camera3D


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		veh = int(a[0])
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


static func _vec(nome: String, padrao: Vector3) -> Vector3:
	if not OS.has_environment(nome):
		return padrao
	var p := OS.get_environment(nome).split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


func _process(dt: float) -> bool:
	if not pronto:
		if main.car == null:
			return false
		if main.veh_idx != veh:
			main.car.queue_free()
			main.spawn_vehicle(veh, main.spawn_point(), deg_to_rad(main.SPAWN_YAW))
			return false
		pronto = true
		return false
	var car = main.car
	t += dt
	if t < 1.5:
		return false                  # assenta no chão
	if cam == null:
		car.freeze = true
		car.set_physics_process(false)
		if car.som:
			car.som.queue_free()
			car.som = null
		cam = Camera3D.new()
		root.add_child(cam)
		cam.fov = 45.0
		var x: Transform3D = car.global_transform
		cam.global_position = x * (_vec("CAM_OFF", Vector3(0.3, 0.9, -4.0)) * car.ESPELHO)
		cam.look_at(x * (_vec("CAM_ALVO", Vector3(0, 0.85, -2.6)) * car.ESPELHO), Vector3.UP)
		cam.current = true
	# giro: 2 s na lenta, sobe até 7000 em 2 s, segura 1 s, volta em 1.5 s
	var s := t - 1.5
	var rpm := 1000.0
	if s > 2.0 and s < 4.0:
		rpm = lerpf(1000.0, 7000.0, (s - 2.0) / 2.0)
	elif s >= 4.0 and s < 5.0:
		rpm = 7000.0
	elif s >= 5.0 and s < 6.5:
		rpm = lerpf(7000.0, 1000.0, (s - 5.0) / 1.5)
	car.rpm = rpm
	return t > 1.5 + DUR
