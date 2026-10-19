extends SceneTree
## Prévia do som do motor: põe o buggy na largada, espera parado, acelera
## tudo (sobe as marchas sozinho), solta e volta pra lenta. Rodar com o
## Movie Maker do Godot, que grava o áudio junto:
##   godot --path . --write-movie previa.avi --fixed-fps 60 -s res://tests/gravar_som.gd -- 7
## (na nuvem: xvfb-run -a ... --rendering-driver opengl3). O argumento é o
## índice em main.VEHICLES. Tempos (s): PARADO, ACELERA, SOLTA.

const PARADO := 1.5
const ACELERA := 9.0
const SOLTA := 5.0

var main
var veh := 0
var t := 0.0
var pronto := false


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		veh = int(a[0])
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(dt: float) -> bool:
	if not pronto:
		if main.car == null:
			return false
		if main.veh_idx != veh:
			main.car.queue_free()
			main.spawn_vehicle(veh, main.spawn_point(), deg_to_rad(main.SPAWN_YAW))
			return false
		pronto = true
	var car = main.car
	t += dt
	var thr := 1.0 if t > PARADO and t < PARADO + ACELERA else 0.0
	car.test_input = {"thr": thr}
	if OS.has_environment("DETALHE") or int(t * 4.0) != int((t - dt) * 4.0):
		print("%.2f s  %3.0f km/h  marcha %s  rpm %4.0f  real %4.0f  carga %.2f" % [
			t, car.linear_velocity.length() * 3.6, car.gear_label(), car.rpm, car.som.r_real if car.som else 0.0, car.som_carga])
	return t > PARADO + ACELERA + SOLTA
