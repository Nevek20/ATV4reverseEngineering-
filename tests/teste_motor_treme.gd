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
		print("%-12s sem motor separado (sem ponto EXHAUST)" % v.name)
		return
	var original: Mesh = load(car.model_path)
	var antes: int = _faces(original) - (car.painel.apagadas if car.painel else 0)   # painel.gd APAGAR
	var depois := _faces(car.body_mi.mesh)
	for m in [car.body_mi, mt.malha, mt.malha_escape]:
		if m == null:
			continue
		if m != car.body_mi:
			depois += _faces(m.mesh)
		for f in m.get_children():      # ventoinhas que giram (motor_anima.gd)
			if f is MeshInstance3D and "Ventoinha" in str(f.name):
				depois += _faces(f.mesh)
	var ok := antes == depois
	if not ok:
		falhas += 1
	var bocas := []                     # malha da boca de cada cano (a fumaça segue)
	for k in mt.bocas:
		bocas.append(["fica", "motor", "escape"][mt.bocas[k]])
	print("%-12s %2d peças %4d faces tremem (de %d, escape %d)  centro (%.2f, %.2f, %.2f)  bocas %s  %s" % [
		v.name, mt.pecas, mt.faces, antes, _faces(mt.malha_escape.mesh) if mt.malha_escape else 0,
		mt.centro.x, mt.centro.y, mt.centro.z, ",".join(bocas), "ok" if ok else "FALHA faces %d -> %d" % [antes, depois]])
