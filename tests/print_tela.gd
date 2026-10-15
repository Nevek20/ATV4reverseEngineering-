extends SceneTree
## Tira um print do carro parado na pista, sem abrir o editor.
## Uso (precisa de tela; na nuvem: xvfb-run):
##   godot --path . -s res://tests/print_tela.gd -- saida.png [lado|tras|frente] [veiculo]

var frames := 0
var main
var out := "print.png"
var view := "lado"
var veh := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		view = args[1]
	if args.size() > 2:
		veh = int(args[2])
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(_dt: float) -> bool:
	frames += 1
	if frames == 2 and veh != main.veh_idx:
		main.car.queue_free()
		main.spawn_vehicle(veh, main.spawn_point(), deg_to_rad(90.0))
	if frames == 90:
		var car: Node3D = main.car
		var t := car.global_transform
		var off := {"lado": Vector3(4.5, 1.2, 0.0), "tras": Vector3(0.0, 1.6, -6.0),
			"frente": Vector3(2.5, 1.0, 5.0)}.get(view, Vector3(4.5, 1.2, 0.0)) as Vector3
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.fov = 45.0
		cam.global_position = t * off
		cam.look_at(t * Vector3(0, 0.7, 0), Vector3.UP)
		cam.current = true
	if frames == 95:
		root.get_viewport().get_texture().get_image().save_png(out)
		print("print salvo em ", out)
		return true
	return false
