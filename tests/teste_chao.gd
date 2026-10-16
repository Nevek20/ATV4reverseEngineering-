extends SceneTree
## Confere o chão do RX_01 (terrain.gd) com a RAM e a tremida por material:
##  1. altura (height_at e o raio na colisão) no contato das 24 rodas dos 6
##     save states da largada (tests/ref_ram_chao.json, W+0x130);
##  2. material embaixo de cada roda = W+0x140 da RAM (asfalto na largada);
##  3. Renegade na largada (asfalto, WheelJitter 0) não treme; numa terra
##     plana ali perto (572, 576; COMMON_2 DIRT/OFFTRACK2, 0.3) treme.
## Uso: godot --headless --path . -s res://tests/teste_chao.gd

const Car := preload("res://car.gd")
const Main := preload("res://main.gd")
const Terrain := preload("res://terrain.gd")
const TERRA := Vector2(572.0, 576.0)

var terrain
var car
var falhas := 0
var passo := 0
var t := 0.0


func _initialize() -> void:
	terrain = Terrain.new()
	root.add_child(terrain)


func _physics_process(dt: float) -> bool:
	passo += 1
	if passo == 2:
		_conferir_ram()
		var v: Dictionary = Main.VEHICLES[0]
		car = Car.new()
		car.asset_dir = v.dir
		car.data_files = ["res://data/vehicles/buggy_base.xml", v.data]
		car.points_file = v.points
		car.vehicle_id = v.id
		car.terrain = terrain
		car.suspension = false
		root.add_child(car)
		return false
	if car == null or not car.is_inside_tree():
		return false
	if t == 0.0:
		car.reset_to(Vector3(Main.SPAWN_XZ.x, terrain.height_at(Main.SPAWN_XZ.x, Main.SPAWN_XZ.y) + 0.8,
			Main.SPAWN_XZ.y), deg_to_rad(Main.SPAWN_YAW))
	t += dt
	if absf(t - 2.0) < dt * 0.5:
		_tremida("largada (asfalto)", 0.0)
		car.reset_to(Vector3(TERRA.x, terrain.height_at(TERRA.x, TERRA.y) + 0.8, TERRA.y), 0.0)
	if absf(t - 4.0) < dt * 0.5:
		_tremida("terra", 0.3)
		print("teste_chao: %s" % ("ok" if falhas == 0 else "%d falhas" % falhas))
		quit(1 if falhas else 0)
	return false


func _conferir_ram() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/ref_ram_chao.json"))
	var space: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
	var pior_h := 0.0
	var pior_raio := 0.0
	var n := 0
	for nome in ref.carros:
		for r in ref.carros[nome]:
			var x: float = r.x
			var z: float = r.z
			var y: float = r.y
			var h: float = terrain.height_at(x, z)
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, y + 5.0, z), Vector3(x, y - 5.0, z))
			var hit := space.intersect_ray(q)
			var hr: float = hit.position.y if not hit.is_empty() else INF
			pior_h = maxf(pior_h, absf(h - y))
			pior_raio = maxf(pior_raio, absf(hr - y))
			var m: int = terrain.material_at(x, z)
			if m != int(r.mat):
				falhas += 1
				print("%s %s: material %d, RAM %d" % [nome, r.roda, m, r.mat])
			n += 1
	print("%d rodas da RAM: maior erro de altura %.2f mm (height_at), %.2f mm (colisão)" % [
		n, pior_h * 1000.0, pior_raio * 1000.0])
	if pior_h > 0.002 or pior_raio > 0.002:
		falhas += 1
		print("altura FALHOU (limite 2 mm)")


## força 20 m/s no plano do chão e sorteia uma vez: só a roda no chão de
## material com WheelJitter > 0 treme
func _tremida(onde: String, wj: float) -> void:
	car.spd_ground = 20.0
	car._wheel_jitter()
	var txt := []
	var max_j := 0.0
	for i in car.jit_order:
		var w: Dictionary = car.wheels[i]
		txt.append("%s(%.1f)%s" % [terrain.material_name(w.mat), terrain.wheel_jitter(w.mat, -1.0),
			"" if w.hit else " no ar"])
		max_j = maxf(max_j, absf(w.jit))
		if not w.hit or absf(terrain.wheel_jitter(w.mat, -1.0) - wj) > 1e-6:
			falhas += 1
	var ok := max_j == 0.0 if wj == 0.0 else max_j > 0.0
	if not ok:
		falhas += 1
	print("%s: %s  maior tremida %.1f mm %s" % [onde, ", ".join(txt), max_j * 1000.0, "ok" if ok else "FALHOU"])
