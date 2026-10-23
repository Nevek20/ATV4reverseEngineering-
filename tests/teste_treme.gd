extends SceneTree
## Volante tremendo (car.gd VOLANTE_TREME, melhoria nossa): põe o buggy na
## largada do RX01, espera parado, acelera reto, vira tudo (derrapa) e solta.
## Imprime por fase a tremida do volante (graus), a vibração do controle
## (0x202ab8) e os trancos (pouso e suspensão). Parado o volante não pode
## tremer; derrapando tem que tremer mais que reto.
## Uso: godot --headless --path . -s res://tests/teste_treme.gd -- [veiculo]

const FASES := [["assenta", 1.0, 0.0, 0.0], ["parado", 1.5, 0.0, 0.0], ["reto", 6.0, 1.0, 0.0],
	["virando", 3.0, 1.0, 1.0], ["solto", 3.0, 0.0, 0.0]]

var main
var veh := 0
var t := 0.0
var pronto := false
var fase := 0
var t_fase := 0.0
var soma := {}


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		veh = int(a[0])
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _physics_process(dt: float) -> bool:
	if not pronto:
		if main.car == null:
			return false
		if main.veh_idx != veh:
			main.car.queue_free()
			main.spawn_vehicle(veh, main.spawn_point(), deg_to_rad(main.SPAWN_YAW))
			return false
		pronto = true
	var car = main.car
	var f: Array = FASES[fase]
	car.test_input = {"thr": f[2], "steer": f[3]}
	var s: Dictionary = soma.get(f[0], {"n": 0, "treme": 0.0, "max": 0.0, "vib": 0.0, "tranco": 0, "kmh": 0.0})
	var g := absf(rad_to_deg(car.treme))
	s.n += 1
	s.treme += g * g
	s.max = maxf(s.max, g)
	s.vib += car.vibracao
	s.kmh = car.linear_velocity.length() * 3.6
	if car.pouso > 0.0 or (car.pancada > 0.39 and s.get("ult", 0.0) < 0.39):
		s.tranco += 1
		if OS.has_environment("DETALHE"):
			print("  %s %.2f s: pouso %.2f  susp_taxa %.2f  pancada %.2f  %.0f km/h" % [
				f[0], t_fase, car.pouso, car.susp_taxa, car.pancada, car.linear_velocity.length() * 3.6])
	s["ult"] = car.pancada
	soma[f[0]] = s
	t_fase += dt
	if t_fase >= f[1]:
		t_fase = 0.0
		fase += 1
		if fase >= FASES.size():
			_fim()
			return true
	return false


func _fim() -> void:
	var ok := true
	for f in FASES:
		if f[0] == "assenta":
			continue
		var s: Dictionary = soma[f[0]]
		print("%-8s %5.0f km/h no fim  tremida rms %4.2f° max %4.2f°  vibração média %.2f  trancos %d" % [
			f[0], s.kmh, sqrt(s.treme / s.n), s.max, s.vib / s.n, s.tranco])
	var parado: float = soma["parado"].max
	if parado > 0.05:
		ok = false
		print("FALHA: volante tremendo parado (%.2f°)" % parado)
	if soma["virando"].treme / soma["virando"].n <= soma["reto"].treme / soma["reto"].n:
		ok = false
		print("FALHA: derrapando não treme mais que reto")
	print("teste_treme: %s" % ("ok" if ok else "FALHA"))
