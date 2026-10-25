extends SceneTree
## Lanterna de freio (luzes.gd, melhoria nossa) e cor do vértice (car.gd
## COR_VERTICE) nos 12 buggies: quantas faces de lente acharam perto dos
## pontos BRAKE_LIGHT, se a cor final delas é vermelha, se os materiais do jogo
## usam a cor do vértice e se a lanterna acende freando e apaga solta.
## Uso: godot --headless --path . -s res://tests/teste_luzes.gd
const Car := preload("res://car.gd")
const Main := preload("res://main.gd")
const Luzes := preload("res://luzes.gd")

var i := -1
var car = null
var vistos := {}
var falhas := 0


func _process(_dt: float) -> bool:
	if car != null:
		_conferir()
		car.free()
		car = null
	i += 1
	while i < Main.VEHICLES.size() and vistos.has(Main.VEHICLES[i].id):
		i += 1
	if i >= Main.VEHICLES.size():
		print("teste_luzes: %s" % ("ok" if falhas == 0 else "FALHA"))
		return true
	var v: Dictionary = Main.VEHICLES[i]
	vistos[v.id] = true
	car = Car.new()
	car.asset_dir = v.dir
	car.data_files = ["res://data/vehicles/buggy_base.xml", v.data]
	car.points_file = v.points
	car.vehicle_id = v.id
	car.suspension = false
	root.add_child(car)
	car.set_physics_process(false)
	car.set_process(false)
	return false


func _conferir() -> void:
	var v: Dictionary = Main.VEHICLES[i]
	var lz = car.luzes
	# cor do vértice ligada nos materiais da carroceria
	var com_cor := 0
	var mats := 0
	for s in car.body_mi.mesh.get_surface_count():
		var m := car.body_mi.get_active_material(s) as StandardMaterial3D
		if m and m.albedo_color.a > 0.0:      # a placa que o painel esconde fica de fora
			mats += 1
			com_cor += 1 if m.vertex_color_use_as_albedo else 0
	var ok_cor: bool = com_cor == mats and car.cor_k() > 4.0
	var linha := "%-9s %-10s cor do vértice %d/%d (k %.2f)" % [v.id, v.name, com_cor, mats, car.cor_k()]
	if lz == null:
		print(linha + "  sem lente achada  %s" % ("ok" if ok_cor else "FALHA"))
		falhas += 0 if ok_cor else 1
		return
	# acende freando, apaga soltando
	for k in 30:
		lz.atualizar(1.0 / 60.0, 1.0)
	var aceso_freando: float = lz.aceso
	for k in 30:
		lz.atualizar(1.0 / 60.0, 0.0)
	var aceso_solto: float = lz.aceso
	var ok: bool = ok_cor and lz.faces >= 2 and aceso_freando > 0.99 and aceso_solto < 0.01
	falhas += 0 if ok else 1
	print(linha + "  lente %3d faces  freando %.2f solto %.2f  %s" % [
		lz.faces, aceso_freando, aceso_solto, "ok" if ok else "FALHA"])
