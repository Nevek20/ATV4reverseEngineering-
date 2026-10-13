extends Node3D
## Terreno da pista montado a partir das alturas extraídas dos tiles do jogo
## (STREAMT/RX/RX01.000). O arquivo .bin é uma grade de floats (little endian)
## de SIZE x SIZE pontos, 1 m entre eles, em linhas ao longo de Z.

@export var height_path := "res://assets/terrain/rx01_height.bin"
@export var texture_path := "res://assets/terrain/rx01_terrain.jpg"
@export var size := 1025          # pontos por lado
@export var mesh_step := 2        # malha visual usa 1 ponto a cada N (colisão usa todos)

var heights := PackedFloat32Array()


func _ready() -> void:
	var f := FileAccess.open(height_path, FileAccess.READ)
	if f == null:
		push_error("Não achei %s" % height_path)
		return
	heights = f.get_buffer(size * size * 4).to_float32_array()
	f.close()
	_build_collision()
	_build_mesh()


func height_at(x: float, z: float) -> float:
	# altura interpolada (bilinear) num ponto do mundo
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
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)


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
	var n := (size - 1) / mesh_step + 1
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
