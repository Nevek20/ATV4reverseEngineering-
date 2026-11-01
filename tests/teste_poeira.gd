extends SceneTree
## Poeira dos pneus (poeira.gd, porta do jogo) no RX01: o Renegade larga com o
## acelerador no fundo e o volante reto. A cada segundo imprime a velocidade,
## o material das rodas de trás (DustType), a força, as nuvens vivas e o
## tamanho e alfa médios delas. Confere: parado não solta, no asfalto
## (DustType None) a cor some em 1 s e para de soltar, na terra solta.
## Uso: godot --headless --path . -s res://tests/teste_poeira.gd [-- veh]

const Car := preload("res://car.gd")
const Main := preload("res://main.gd")
const Terrain := preload("res://terrain.gd")

var terrain
var car
var t := 0.0
var prox := 1.0
var max_vivas := 0
var parado_vivas := -1
var falhas := 0


func _initialize() -> void:
	terrain = Terrain.new()
	root.add_child(terrain)
	var a := OS.get_cmdline_user_args()
	var v: Dictionary = Main.frota()[int(a[0]) if a.size() > 0 else 0]
	car = Car.new()
	Main.configurar(car, v)
	car.terrain = terrain
	car.suspension = false
	root.add_child(car)
	car.test_input = {"thr": 0.0, "brk": 0.0, "steer": 0.0}


func _physics_process(dt: float) -> bool:
	if not car.is_inside_tree():
		return false
	if t == 0.0:
		var p: Vector2 = Main.SPAWN_XZ
		car.reset_to(Vector3(p.x, terrain.height_at(p.x, p.y) + 0.8, p.y), deg_to_rad(Main.SPAWN_YAW))
		if car.poeira == null:
			print("teste_poeira: FALHA (sem poeira: falta assets/fx/poeira.png? rode tools/fx_jogo.py)")
			return true
	t += dt
	car.test_input.thr = 1.0 if t > 1.5 else 0.0
	var pq = car.poeira
	if t >= 1.4 and parado_vivas < 0:
		parado_vivas = pq.vivas()
	max_vivas = maxi(max_vivas, pq.vivas())
	if t >= prox:
		prox += 1.0
		var tipos := ""
		for e in pq.emissores:
			var w: Dictionary = car.wheels[e.roda]
			var m: Dictionary = terrain.materials[w.mat] if w.hit and w.mat >= 0 else {}
			tipos += " %s(%s, alfa %.2f)" % [String(m.get("Name", "ar")).get_slice("(", 1).trim_suffix(")*"),
				m.get("DustType", "-"), (e.cor as Color).a]
		var tam := 0.0
		var alfa := 0.0
		var n: int = pq.vivas()
		for k in n:
			var tg := clampf(pq.n_idade[k] / pq.n_max[k], 0.0, 1.0)
			var f := 1.0 - pow(1.0 - tg, 4.0)
			tam += pq.n_ini[k] * (1.0 - f) + pq.n_alvo[k] * f
			var tt: float = pq.n_idade[k] / pq.n_vida[k]
			alfa += pq.n_a0[k] * (1.0 - tt * tt)
		var kmh: float = car.linear_velocity.length() * 3.6
		print("%4.1f s  %5.1f km/h  força %.2f  nuvens %4d  tamanho médio %.2f m  alfa médio %.2f %s" % [
			t, kmh, clampf((kmh / 3.6 - 0.5) / 35.0, 0.0, 1.0), n, tam / maxf(n, 1), alfa / maxf(n, 1), tipos])
	if t < 12.0:
		return false
	if parado_vivas != 0:
		falhas += 1
		print("FALHA: parado soltou %d nuvens" % parado_vivas)
	if max_vivas < 20:
		falhas += 1
		print("FALHA: andando soltou só %d nuvens" % max_vivas)
	print("teste_poeira: %s (máximo de nuvens vivas %d de %d)" % ["ok" if falhas == 0 else "FALHA", max_vivas, pq.max_nuvens])
	return true
