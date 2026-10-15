extends SceneTree
## Tira um print do carro parado na pista, sem abrir o editor.
## "jogo" usa a câmera de corrida portada (a mesma do F5).
## Uso (precisa de tela; na nuvem: xvfb-run):
##   godot --path . -s res://tests/print_tela.gd -- saida.png [lado|tras|frente|jogo|...] [veiculo]

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
	if frames == 90 and view != "jogo":
		var car: Node3D = main.car
		var t := car.global_transform
		var off := {"lado": Vector3(4.5, 1.2, 0.0), "tras": Vector3(0.0, 1.6, -6.0),
			"frente": Vector3(2.5, 1.0, 5.0), "outro_lado": Vector3(-4.5, 1.2, 0.0),
			"cima": Vector3(0.01, 7.0, 0.0), "tras_baixo": Vector3(1.5, 0.6, -4.0),
			"roda_tras": Vector3(-2.6, 1.0, -0.6), "persegue": Vector3(0.0, 2.3, -6.5), "frente_esq": Vector3(-3.5, 2.0, 4.5), "garagem_lado": Vector3(-5.0, 1.0, 0.6), "garagem_tras": Vector3(-3.2, 1.3, -4.6), "roda_tras_dentro": Vector3(0.0, 0.3, -0.8)}.get(
			view, Vector3(4.5, 1.2, 0.0)) as Vector3
		var alvo := Vector3(0, 0.7, 0)
		if view.begins_with("roda_tras"):
			for w in car.wheels:
				if not w.front and w.px < 0.0:
					alvo = w.pivot.position
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.fov = 45.0
		cam.global_position = t * off
		cam.look_at(t * alvo, Vector3.UP)
		cam.current = true
	if frames == 94:
		# folga de cada roda até o chão (raio do modelo, raycast do centro)
		var c = main.car
		var space: PhysicsDirectSpaceState3D = c.get_world_3d().direct_space_state
		for w in c.wheels:
			var mi: MeshInstance3D = w.spin_node.get_child(0)
			var p: Vector3 = mi.global_position
			var q := PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 3.0)
			q.exclude = [c.get_rid()]
			var hit := space.intersect_ray(q)
			var r: float = mi.get_aabb().size.y * 0.5
			if hit:
				print("roda %s%s: centro %.3f m do chão, raio %.3f, folga %.3f" % [
					"F" if w.front else "T", "E" if w.px > 0 else "D",
					p.y - hit.position.y, r, p.y - hit.position.y - r])
	if frames == 95:
		root.get_viewport().get_texture().get_image().save_png(out)
		print("print salvo em ", out)
		return true
	return false
