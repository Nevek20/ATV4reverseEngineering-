extends SceneTree
## Poeira dos pneus (poeira.gd) na câmera de corrida: o carro larga no RX01,
## acelera e vira um pouco pra sair do asfalto (DustType None) pra terra.
## Grava com o Movie Maker:
##   godot --path . --write-movie poeira.avi --fixed-fps 30 -s res://tests/gravar_poeira.gd -- 0
## DUR=8 segundos, VIRA=0.12 volante (+ = esquerda), QUANDO=1.5 quando vira (s),
## SEM_POEIRA=1 esconde as nuvens (comparar), POEIRA_COR=1 nuvens vermelhas

var main
var veh := 0
var t := 0.0
var dur := 8.0
var vira := 0.12
var quando := 1.5
var pronto := false


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		veh = int(a[0])
	if _env("DUR") != "":
		dur = float(_env("DUR"))
	if _env("VIRA") != "":
		vira = float(_env("VIRA"))
	if _env("QUANDO") != "":
		quando = float(_env("QUANDO"))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


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
		pronto = true
		return false
	var car = main.car
	main.hud.visible = false
	if car.poeira and _env("SEM_POEIRA") == "1":     # comparação: esconde as nuvens
		car.poeira.visible = false
	t += dt
	if int(t * 2.0) != int((t - dt) * 2.0):
		var mats := ""
		for w in car.wheels:
			if not w.front:
				var m: Dictionary = main.terrain.materials[w.mat] if w.hit and w.mat >= 0 else {}
				mats += " " + String(m.get("Name", "ar")).get_slice("(", 1).trim_suffix(")*")
		print("%.1f s  %.0f km/h  nuvens %d %s" % [t, car.linear_velocity.length() * 3.6, car.poeira.vivas() if car.poeira else -1, mats])
	car.test_input = {"thr": 1.0 if t > 0.5 else 0.0, "brk": 0.0,
		"steer": vira if t > quando and t < quando + 1.2 else 0.0}
	return t > dur
