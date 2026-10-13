extends RefCounted
## Lê os XMLs de física do ATV Offroad Fury 4.
## O jogo carrega o XML base da classe (ex: Truck) e depois aplica por cima
## o XML do veículo, que só traz o que muda. Aqui é igual: base + override.
##
## Cada nó vira {"a": {atributos}, "k": {tag_filho: nó}}.

var root := {"a": {}, "k": {}}


func load_files(paths: Array) -> void:
	for p in paths:
		root = _merge(root, _parse(p))


static func _parse(path: String) -> Dictionary:
	var top := {"a": {}, "k": {}}
	var p := XMLParser.new()
	if p.open(path) != OK:
		push_error("Não consegui abrir %s" % path)
		return top
	var stack: Array = [top]
	while p.read() == OK:
		var t := p.get_node_type()
		if t == XMLParser.NODE_ELEMENT:
			var n := {"a": {}, "k": {}}
			for i in p.get_attribute_count():
				n["a"][p.get_attribute_name(i)] = p.get_attribute_value(i)
			stack.back()["k"][p.get_node_name()] = n
			if not p.is_empty():
				stack.append(n)
		elif t == XMLParser.NODE_ELEMENT_END:
			stack.pop_back()
	return top["k"].get("Root", top)


static func _merge(base: Dictionary, over: Dictionary) -> Dictionary:
	for k in over["a"]:
		base["a"][k] = over["a"][k]
	for k in over["k"]:
		if base["k"].has(k):
			_merge(base["k"][k], over["k"][k])
		else:
			base["k"][k] = over["k"][k]
	return base


func node(path: String) -> Dictionary:
	var n := root
	for part in path.split("/", false):
		if not n["k"].has(part):
			return {}
		n = n["k"][part]
	return n


func has(path: String, attr: String) -> bool:
	var n := node(path)
	return not n.is_empty() and n["a"].has(attr)


func f(path: String, attr: String, def := 0.0) -> float:
	var n := node(path)
	if n.is_empty() or not n["a"].has(attr):
		return def
	var s: String = n["a"][attr]
	if s == "true":
		return 1.0
	if s == "false":
		return 0.0
	return s.to_float()


## valor "tunado": o jogo interpola entre _non_tuned e _fully_tuned
## conforme o nível da peça instalada (0 = de fábrica, 1 = no máximo)
func tuned(path: String, attr: String, t: float) -> float:
	var a := f(path, attr + "_non_tuned")
	var b := f(path, attr + "_fully_tuned", a)
	return lerpf(a, b, t)


## curva do jogo: NumValues pontos igualmente espaçados de 0 até o máximo
func curve(path: String) -> Dictionary:
	var n := node(path)
	var c := {"v": PackedFloat32Array([0.0]), "max": 1.0, "scale": 1.0}
	if n.is_empty():
		return c
	var a: Dictionary = n["a"]
	var num := int(a.get("NumValues", "0"))
	var vals := PackedFloat32Array()
	for i in num:
		vals.append(String(a.get("Value%d" % i, "0")).to_float())
	if vals.is_empty():
		return c
	c["v"] = vals
	for k in ["RpmMax", "SpeedMax", "AccelerationMax", "SideslipMax", "VelocityMax", "Max"]:
		if a.has(k):
			c["max"] = String(a[k]).to_float()
			break
	for k in ["TorqueScale", "OrdinateScale", "ForceScale", "Scale", "AccelerationScale", "DampingScale"]:
		if a.has(k):
			c["scale"] = String(a[k]).to_float()
			break
	return c


static func sample(c: Dictionary, x: float) -> float:
	var v: PackedFloat32Array = c["v"]
	if v.size() == 1:
		return v[0]
	var pos := clampf(x / c["max"], 0.0, 1.0) * (v.size() - 1)
	var i := mini(int(pos), v.size() - 2)
	return lerpf(v[i], v[i + 1], pos - i)


## integral da curva de 0 até x (usada na mola progressiva)
static func integrate(c: Dictionary, x: float) -> float:
	var v: PackedFloat32Array = c["v"]
	var xmax: float = c["max"]
	if v.size() == 1:
		return v[0] * x
	var seg := xmax / (v.size() - 1)
	var total := 0.0
	var i := 0
	while i < v.size() - 1 and x > i * seg:
		var x0 := i * seg
		var x1 := minf(x, (i + 1) * seg)
		var y0 := v[i]
		var y1 := lerpf(v[i], v[i + 1], (x1 - x0) / seg)
		total += (y0 + y1) * 0.5 * (x1 - x0)
		i += 1
	if x > xmax:
		total += v[v.size() - 1] * (x - xmax)
	return total


## "trio de atrito" do jogo: valor pra atrito máximo, mínimo e especial.
## Igual à função 0x21d8b0 do executável.
func ftriple(path: String, stem: String) -> Dictionary:
	return {"max": f(path, "Maximum_friction_" + stem), "min": f(path, "Minimum_friction_" + stem),
		"sp": f(path, "Special_friction_" + stem, f(path, "Maximum_friction_" + stem)),
		"lmax": f(path, "Maximum_friction", 1.0), "lmin": f(path, "Minimum_friction", 0.1)}


static func triple(t: Dictionary, mu: float) -> float:
	if mu <= t.lmin:
		return t.min
	if mu > 1.0:
		return t.sp
	if mu >= t.lmax:
		return t.max
	return t.min + (mu - t.lmin) / (t.lmax - t.lmin) * (t.max - t.min)


## trio de curvas (x velocidade). Igual à função 0x21d938 do executável.
func fcurves(path: String, stem := "acceleration_vs_speed") -> Dictionary:
	var n := node(path)
	var a: Dictionary = n["a"] if not n.is_empty() else {}
	return {"max": curve(path + "/Maximum_friction_" + stem),
		"min": curve(path + "/Minimum_friction_" + stem),
		"sp": curve(path + "/Special_friction_" + stem),
		"lmax": String(a.get("Maximum_friction", "1")).to_float(),
		"lmin": String(a.get("Minimum_friction", "0.1")).to_float()}


static func fcurve_eval(c: Dictionary, mu: float, x: float) -> float:
	if mu <= c.lmin:
		return sample(c.min, x)
	if mu > 1.0:
		return sample(c.sp, x)
	if mu >= c.lmax:
		return sample(c.max, x)
	var lo := sample(c.min, x)
	return lo + (mu - c.lmin) / (c.lmax - c.lmin) * (sample(c.max, x) - lo)
