extends SceneTree
## Derrapagem no cascalho escuro do RX01 (GRAVEL/ROCK misturado com terra em
## células de 2 m): põe o buggy no meio da mistura, acelera e vira tudo, e
## imprime quantas vezes o som de cada roda troca de sample (Gravel <-> Dirt).
## Com o Movie Maker grava o áudio (só pneu, sem motor):
##   godot --path . --write-movie cascalho.avi --fixed-fps 60 -s res://tests/gravar_cascalho.gd -- 0
## (na nuvem: xvfb-run -a ... --rendering-driver opengl3). Sem tela também
## roda (--headless), só pra contar as trocas. PONTO=600,400 muda o lugar
## (X, Z do remake).

const DUR := 9.0

var main
var veh := 0
var t := 0.0
var pronto := false
var trocas := [0, 0]
var nomes := ["", ""]
var passos := {}


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
		var xz := Vector2(600, 400)
		if OS.has_environment("PONTO"):
			var p := OS.get_environment("PONTO").split(",")
			xz = Vector2(float(p[0]), float(p[1]))
		var pos := Vector3(xz.x, main.terrain.height_at(xz.x, xz.y) + 1.5, xz.y)
		if main.veh_idx != veh:
			main.car.queue_free()
			main.spawn_vehicle(veh, pos, 0.0)
		else:
			main.car.reset_to(pos, 0.0)
		pronto = true
		return false
	var car = main.car
	if car.som:
		car.som.queue_free()
		car.som = null
	t += dt
	car.test_input = {"thr": 1.0 if t > 0.5 else 0.0, "steer": 1.0 if t > 2.5 else 0.0}
	if car.sfx:
		for k in 2:
			var n: String = car.sfx.rodas[k].som.nome
			if n != nomes[k]:
				if nomes[k] != "":
					trocas[k] += 1
					print("troca %s %s -> %s em %.3f s" % [["FL", "RL"][k], nomes[k], n, t])
				nomes[k] = n
		var c: String = car.sfx.rodas[0].som.nome
		passos[c] = passos.get(c, 0) + 1
	if int(t * 2.0) != int((t - dt) * 2.0):
		print("%.1f s  %3.0f km/h  FL %s  RL %s  derrapa %.2f  trocas FL %d RL %d" % [t,
			car.linear_velocity.length() * 3.6, nomes[0], nomes[1],
			car.sfx.derrapa if car.sfx else 0.0, trocas[0], trocas[1]])
	if t > DUR:
		print("trocas de sample em %.0f s: FL %d, RL %d (%.1f/s); quadros por sample na FL %s" % [
			DUR, trocas[0], trocas[1], (trocas[0] + trocas[1]) / DUR, passos])
		return true
	return false
