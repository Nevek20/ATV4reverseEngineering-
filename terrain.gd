extends Node3D
## Terreno da pista RX_01 tirado do stream do jogo (STREAMT/RX/RX01.000) por
## tools/extrair_material.py. Grade de SIZE x SIZE pontos, 1 m entre eles,
## linha = z, ponto (i, j) = (x = i, z = j) do remake = mundo do jogo
## (x, z + 1024). Bate com a RAM dos save states da largada: altura do contato
## das rodas a 0.1 mm e material igual.
##   rx01_height.bin   float32, altura do jogo (FUN_00299a60)
##   rx01_material.bin u8, índice i do material = Material_(i+1) do
##                     Levels/RX_01/Env/Materials.xml (data/materials_rx01.xml);
##                     célula de 2 m (entrada E do tile, byte0 & 0xF)
## Triângulo de cada célula pela diagonal (i+1, j)-(i, j+1), igual ao jogo e
## ao HeightMapShape3D do Godot (Godot Physics e Jolt, testado).

@export var height_path := "res://assets/terrain/rx01_height.bin"
@export var material_path := "res://assets/terrain/rx01_material.bin"
@export var materials_xml := "res://data/materials_rx01.xml"
@export var texture_path := "res://assets/terrain/rx01_terrain.jpg"
@export var size := 1025          # pontos por lado
@export var mesh_step := 2        # malha visual usa 1 ponto a cada N (colisão usa todos)

var heights := PackedFloat32Array()
var mat_map := PackedByteArray()
var materials := []               # atributos de cada Material_N do XML (N - 1)


func _ready() -> void:
	var f := FileAccess.open(height_path, FileAccess.READ)
	if f == null:
		push_error("Não achei %s" % height_path)
		return
	heights = f.get_buffer(size * size * 4).to_float32_array()
	f.close()
	f = FileAccess.open(material_path, FileAccess.READ)
	if f:
		mat_map = f.get_buffer(size * size)
		f.close()
	materials = load_materials(materials_xml)
	_build_collision()
	_build_mesh()


## Material_1..N do Materials.xml da pista, em ordem (só os atributos)
static func load_materials(path: String) -> Array:
	var out := []
	var x := XMLParser.new()
	if x.open(path) != OK:
		push_error("Não achei %s" % path)
		return out
	while x.read() == OK:
		if x.get_node_type() != XMLParser.NODE_ELEMENT or not x.get_node_name().begins_with("Material_"):
			continue
		var i := x.get_node_name().trim_prefix("Material_").to_int() - 1
		var at := {}
		for k in x.get_attribute_count():
			at[x.get_attribute_name(k)] = x.get_attribute_value(k)
		while out.size() <= i:
			out.append({})
		out[i] = at
	return out


func height_at(x: float, z: float) -> float:
	# altura no triângulo da célula, diagonal (i+1, j)-(i, j+1) como o jogo
	x = clampf(x, 0.0, size - 1.001)
	z = clampf(z, 0.0, size - 1.001)
	var ix := int(x)
	var iz := int(z)
	var fx := x - ix
	var fz := z - iz
	var h00 := heights[iz * size + ix]
	var h10 := heights[iz * size + ix + 1]
	var h01 := heights[(iz + 1) * size + ix]
	var h11 := heights[(iz + 1) * size + ix + 1]
	if fx + fz <= 1.0:
		return h00 + (h10 - h00) * fx + (h01 - h00) * fz
	return h11 + (h01 - h11) * (1.0 - fx) + (h10 - h11) * (1.0 - fz)


## índice do material do chão no ponto (x, z) do remake (-1 sem mapa)
func material_at(x: float, z: float) -> int:
	if mat_map.is_empty():
		return -1
	var ix := clampi(floori(x), 0, size - 1)
	var iz := clampi(floori(z), 0, size - 1)
	return mat_map[iz * size + ix]


## WheelJitter do material (0x202760); -1 = sem material
func wheel_jitter(m: int, fallback: float) -> float:
	if m < 0 or m >= materials.size():
		return fallback
	return float(materials[m].get("WheelJitter", fallback))


## nome curto do material: "COMMON_3(TARMAC/COMMON)*" -> "TARMAC/COMMON"
func material_name(m: int) -> String:
	if m < 0 or m >= materials.size():
		return "?"
	var n: String = materials[m].get("Name", "?")
	var a := n.find("(")
	var b := n.find(")")
	return n.substr(a + 1, b - a - 1) if a >= 0 and b > a else n


func _build_collision() -> void:
	var shape := HeightMapShape3D.new()
	shape.map_width = size
	shape.map_depth = size
	shape.map_data = heights
	var cs := CollisionShape3D.new()
	cs.shape = shape
	var body := StaticBody3D.new()
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	body.physics_material_override = pm
	body.add_child(cs)
	# o HeightMapShape3D fica centralizado na origem do nó
	body.position = Vector3((size - 1) / 2.0, 0.0, (size - 1) / 2.0)
	add_child(body)


func _build_mesh() -> void:
	@warning_ignore("integer_division")
	var n := (size - 1) / mesh_step + 1     # divisão inteira de propósito
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(n * n)
	norms.resize(n * n)
	uvs.resize(n * n)
	var span := float(size - 1)
	for j in n:
		var z := j * mesh_step
		for i in n:
			var x := i * mesh_step
			var h := heights[z * size + x]
			var k := j * n + i
			verts[k] = Vector3(x, h, z)
			uvs[k] = Vector2(x / span, z / span)
			# normal pela diferença central
			var xl := maxi(x - 1, 0)
			var xr := mini(x + 1, size - 1)
			var zu := maxi(z - 1, 0)
			var zd := mini(z + 1, size - 1)
			var dx := heights[z * size + xr] - heights[z * size + xl]
			var dz := heights[zd * size + x] - heights[zu * size + x]
			norms[k] = Vector3(-dx / float(xr - xl), 1.0, -dz / float(zd - zu)).normalized()

	var idx := PackedInt32Array()
	idx.resize((n - 1) * (n - 1) * 6)
	var p := 0
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			idx[p] = a; idx[p + 1] = b; idx[p + 2] = c
			idx[p + 3] = b; idx[p + 4] = d; idx[p + 5] = c
			p += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := StandardMaterial3D.new()
	if ResourceLoader.exists(texture_path):
		mat.albedo_texture = load(texture_path)
	else:
		mat.albedo_color = Color(0.45, 0.38, 0.3)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
