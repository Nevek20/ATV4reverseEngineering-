extends SceneTree
## Motor tremendo (motor_treme.gd, melhoria nossa): em cada buggy conta as
## peças e faces que saem da carroceria pro motor, o centro do motor e confere
## que a carroceria + motor têm as mesmas faces de antes (nada some).
## Uso: godot --headless --path . -s res://tests/teste_motor_treme.gd
const Car := preload("res://car.gd")
const Main := preload("res://main.gd")

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
		print("teste_motor_treme: %s" % ("ok" if falhas == 0 else "FALHA"))
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


func _faces(m: Mesh) -> int:
	var n := 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		var ix = a[Mesh.ARRAY_INDEX]
		n += (ix.size() if ix != null and ix.size() > 0 else a[Mesh.ARRAY_VERTEX].size()) / 3
	return n


func _conferir() -> void:
	var v: Dictionary = Main.VEHICLES[i]
	var mt = car.motor_treme
	if mt == null:
		print("%-12s sem motor separado" % v.name)
		return
	var original: Mesh = load(car.model_path)
	var antes := _faces(original)
	var depois := _faces(car.body_mi.mesh) + _faces(mt.malha.mesh)
	var ok := antes == depois
	if not ok:
		falhas += 1
	print("%-12s %2d peças %4d faces tremem (de %d)  centro (%.2f, %.2f, %.2f)  %s" % [
		v.name, mt.pecas, mt.faces, antes, mt.centro.x, mt.centro.y, mt.centro.z, "ok" if ok else "FALHA faces %d -> %d" % [antes, depois]])
