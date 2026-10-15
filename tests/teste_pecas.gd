extends SceneTree
## Confere as peças da suspensão contra o jogo: matrizes das 18 peças do
## Renegade e do Sphinx tiradas da RAM dos save states (tests/ref_ram_pecas.json,
## linhas do jogo; 4ª linha = translação; frame do modelo), com o mesmo curso.
## Uso: godot --headless --path . -s res://tests/teste_pecas.gd

const Car := preload("res://car.gd")
const Main := preload("res://main.gd")
const TOL := 1e-3

var falhas := 0
var total := 0
var carros := []
var frames := 0


func _initialize() -> void:
	for i in [0, 1]:
		var v: Dictionary = Main.VEHICLES[i]
		var c = Car.new()
		c.asset_dir = v.dir
		c.data_files = ["res://data/vehicles/buggy_base.xml", v.data]
		c.points_file = v.points
		c.vehicle_id = v.id
		root.add_child(c)          # o _ready roda no 1º quadro
		carros.append(c)


func _process(_dt: float) -> bool:
	frames += 1
	if frames < 2:
		return false
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/ref_ram_pecas.json"))
	_conferir("renegade", carros[0], ref.renegade)
	_conferir("sphinx", carros[1], ref.sphinx)
	print("teste_pecas: %d de %d matrizes batem com a RAM (tolerância %s m)" % [total - falhas, total, TOL])
	quit(1 if falhas > 0 or total == 0 else 0)
	return true


func _xf(linhas: Array) -> Transform3D:
	var r := []
	for l in linhas:
		r.append(Vector3(l[0], l[1], l[2]))
	return Transform3D(Basis(r[0], r[1], r[2]), r[3])


func _cmp(nome: String, a: Transform3D, b: Transform3D, so_pos := false) -> void:
	total += 1
	var e := (a.origin - b.origin).length()
	if not so_pos:
		for i in 3:
			e = maxf(e, (a.basis[i] - b.basis[i]).length())
	var ok := e < TOL
	if not ok:
		falhas += 1
	print("  %-11s erro %.6f %s" % [nome, e, "ok" if ok else "FALHOU"])


func _conferir(nome: String, c, r: Dictionary) -> void:
	print("== %s" % nome)
	var susp = c.susp_vis
	if susp == null:
		print("  sem suspension_visual (faltam assets?)")
		falhas += 1
		return
	var p: Dictionary = r.pecas
	for k in susp.corners:
		var cn: String = ("F" if k.front else "R") + ("L" if k.left else "R")
		var x: float = r.curso[cn]
		var ps: Dictionary = susp.pose(k, x, 0.0)
		_cmp("Frame_" + cn, ps.frame, _xf(p["Frame_" + cn].linhas))
		_cmp("Brake_" + cn, ps.brake, _xf(p["Brake_" + cn].linhas))
		_cmp("Wheel_" + cn, Transform3D(Basis(), ps.hub), _xf(p["Wheel_" + cn].linhas), true)
		if k.front:
			_cmp("ShockF_" + cn, ps.shock, _xf(p["ShockF_" + cn].linhas))
		else:
			_cmp("Chamber_" + cn, ps.chamber, _xf(p["Chamber_" + cn].linhas))
			_cmp("Piston_" + cn, ps.piston, _xf(p["Piston_" + cn].linhas))
