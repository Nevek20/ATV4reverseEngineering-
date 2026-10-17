extends SceneTree
## Mede a tremedeira da câmera de órbita na cena principal: acelera reto e, a
## cada quadro (depois de a cena pôr a câmera), guarda a distância câmera ->
## carro interpolado. Com a câmera certa ela muda devagar; o vai e volta
## aparece como segunda diferença grande de um quadro pro outro.
## Uso: godot --headless --path . -s res://tests/medir_tremor.gd -- <fps> <saida.csv>

var main
var car
var linhas := []
var saida := ""
var t := 0.0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	Engine.max_fps = int(a[0]) if a.size() > 0 else 60
	saida = a[1] if a.size() > 1 else "user://tremor.csv"
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	# lê depois do _process da cena (prioridade alta = roda por último)
	var sc := GDScript.new()
	sc.source_code = "extends Node\nvar cb: Callable\nfunc _process(d: float) -> void:\n\tcb.call(d)\n"
	sc.reload()
	var n := Node.new()
	n.set_script(sc)
	n.process_priority = 1000
	n.set("cb", _medir)
	root.add_child(n)


func _medir(dt: float) -> void:
	if car == null:
		car = main.car
		return
	if car.test_input == null:
		car.test_input = {"thr": 1.0, "brk": 0.0, "steer": 0.0}
	t += dt
	var xf: Transform3D = car.get_global_transform_interpolated()
	var d: float = main.cam.global_position.distance_to(xf.origin)
	linhas.append("%.5f,%.6f,%.5f,%.3f" % [t, dt, d, car.linear_velocity.length()])
	if t > 12.0:
		var f := FileAccess.open(saida, FileAccess.WRITE)
		f.store_string("t,dt,dist,v\n" + "\n".join(linhas) + "\n")
		f.close()
		quit()
