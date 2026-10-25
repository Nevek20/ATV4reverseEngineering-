extends SceneTree
## Farol (farol.gd, melhoria nossa com o halo "Night" do jogo) nos 12 buggies:
## quantas lâmpadas acharam pelas texturas de farol do modelo (light_64,
## headlight), onde ficam, as camadas do halo (VehicleHaloMap HEAD_LIGHT ->
## VehicleHalos ReverseLight HIGH) e se acende em 0.25 s (4/s) e apaga na hora.
## Só o Hurricane (2 faróis) e o Storm (2 faróis + 4 milhas) têm lente de farol;
## no Mosquito a light_64 é a lanterna de trás. Os outros ficam sem (ok).
## Uso: godot --headless --path . -s res://tests/teste_farol.gd
const Car := preload("res://car.gd")
const Main := preload("res://main.gd")
const Farol := preload("res://farol.gd")
const ESPERADO := {"BUGGY_11": 2, "BUGGY_12": 6}   # lâmpadas por carro

var i := -1
var car = null
var vistos := {}
var falhas := 0
var com_farol := 0


func _initialize() -> void:
	var cam: Array = Farol.camadas_do_halo(Farol.PONTO)
	var ok: bool = cam.size() == 7 and cam[0].caixa == "GLOW" and is_equal_approx(cam[0].w, 1.3)
	print("halo do HEAD_LIGHT: %d camadas %s  %s" % [cam.size(),
		", ".join(cam.map(func(c): return "%s %.2fx%.2f %+.1f" % [c.caixa, c.w, c.h, c.angulo])), "ok" if ok else "FALHA"])
	falhas += 0 if ok else 1


func _process(_dt: float) -> bool:
	if car != null:
		_conferir()
		car.free()
		car = null
	i += 1
	while i < Main.VEHICLES.size() and vistos.has(Main.VEHICLES[i].id):
		i += 1
	if i >= Main.VEHICLES.size():
		var ok := com_farol == ESPERADO.size()
		falhas += 0 if ok else 1
		print("carros com farol: %d (esperado %d)  %s" % [com_farol, ESPERADO.size(), "ok" if ok else "FALHA"])
		print("teste_farol: %s" % ("ok" if falhas == 0 else "FALHA"))
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
	var f = car.farol
	if f == null:
		print("%-9s %-10s sem farol no modelo" % [v.id, v.name])
		return
	com_farol += 1
	Farol.ligado = true
	f.atualizar(0.1)
	var meio: float = f.aceso
	f.atualizar(0.2)
	var cheio: float = f.aceso
	Farol.ligado = false
	f.atualizar(1.0 / 60.0)
	var apagado: float = f.aceso
	Farol.ligado = true
	var ok: bool = f.lampadas.size() == ESPERADO.get(v.id, -1) and absf(meio - 0.4) < 1e-4 and cheio >= 1.0 and apagado == 0.0 \
		and f.lampadas.all(func(l): return l.n.z > 0.5 and l.c.z > 0.5)
	falhas += 0 if ok else 1
	print("%-9s %-10s %d lâmpadas %s  acende 0.1 s %.2f / 0.3 s %.2f, desliga %.2f  %s" % [v.id, v.name,
		f.lampadas.size(), " ".join(f.lampadas.map(func(l): return "(%.2f, %.2f, %.2f)" % [l.c.x, l.c.y, l.c.z])),
		meio, cheio, apagado, "ok" if ok else "FALHA"])
