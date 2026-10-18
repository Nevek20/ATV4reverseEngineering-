extends Node3D
## Piloto do jogo sentado no carro (cDriverComponentFactory_Seated ->
## AObjectRider 0x1829c8). Malha MALE_HIGH com 47 ossos, esqueleto
## InGame_Mid e a animação STEER_LEFT do Truck_Riding, tirados do jogo pelo
## tools/piloto.py (assets/piloto/piloto.json + piloto.png).
##
## Fica dentro do espelho do carro (frame do jogo), com o osso ROOT em cima do
## ponto ARSE do modelo. O jogo (0x190e50) toca o STEER_LEFT no tempo
## |s| x duração (1/6 s), s = direção suavizada do piloto (0x187060), e
## espelha a pose quando s > 0 (virando pra direita no jogo): cada osso pega
## o do outro lado (tabela de espelho do .skl) com x da posição e y, z da
## rotação trocados de sinal.

var skel: Skeleton3D
var malha: MeshInstance3D
var root_pos := Vector3.ZERO      # osso ROOT na animação: vai em cima do ARSE
# câmera do piloto (nossa, não existe no buggy do jogo): o capacete some (osso
# head encolhido) e ficam o corpo, os braços e as mãos no volante
var sem_cabeca := false
var _cabeca := -1
var _esp := PackedInt32Array()
var _tempos := PackedFloat32Array()
var _dur := 0.0
var _pos: Array = []              # [quadro][osso] Vector3
var _rot: Array = []              # [quadro][osso] Quaternion


## monta tudo a partir de dir/piloto.json; false se o asset não existe
func carregar(dir: String, cull: int) -> bool:
	var arq := dir.path_join("piloto.json")
	if not FileAccess.file_exists(arq):
		return false
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(arq))
	var ossos: Array = d.ossos
	var n := ossos.size()
	skel = Skeleton3D.new()
	add_child(skel)
	var skin := Skin.new()
	var glob: Array = []
	for b in n:
		skel.add_bone(ossos[b].nome)
		var m: Array = ossos[b].inv              # 4x4, translação em 12..14
		var inv := Transform3D(Basis(Vector3(m[0], m[1], m[2]), Vector3(m[4], m[5], m[6]),
			Vector3(m[8], m[9], m[10])), Vector3(m[12], m[13], m[14]))
		skin.add_bind(b, inv)
		glob.append(inv.affine_inverse())
		_esp.append(int(ossos[b].espelho))
	for b in n:
		var pai: int = ossos[b].pai
		if pai >= 0:
			skel.set_bone_parent(b, pai)
			skel.set_bone_rest(b, glob[pai].affine_inverse() * glob[b])
		else:
			skel.set_bone_rest(b, glob[b])

	# malha: o .srd vem com o triângulo no sentido da normal do jogo (anti-
	# horário de frente); o Godot quer horário
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var uv := PackedVector2Array()
	var p: Array = d.pos
	var q: Array = d.normal
	var t: Array = d.uv
	for i in p.size() / 3:
		pos.append(Vector3(p[3 * i], p[3 * i + 1], p[3 * i + 2]))
		nrm.append(Vector3(q[3 * i], q[3 * i + 1], q[3 * i + 2]).normalized())
		uv.append(Vector2(t[2 * i], t[2 * i + 1]))
	var pes := PackedFloat32Array(d.pesos)
	for i in pes.size() / 4:                     # o jogo soma 254/255 às vezes
		var s := pes[4 * i] + pes[4 * i + 1] + pes[4 * i + 2] + pes[4 * i + 3]
		if s > 0.0:
			for k in 4:
				pes[4 * i + k] /= s
	var tri: Array = d.tris
	var idx := PackedInt32Array()
	for i in tri.size() / 3:
		idx.append_array([tri[3 * i], tri[3 * i + 2], tri[3 * i + 1]])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_BONES] = PackedInt32Array(d.ossos_v)
	arr[Mesh.ARRAY_WEIGHTS] = pes
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _textura(dir.path_join("piloto.png"))
	mat.cull_mode = cull
	am.surface_set_material(0, mat)
	malha = MeshInstance3D.new()
	malha.mesh = am
	malha.skin = skin
	skel.add_child(malha)
	malha.skeleton = NodePath("..")

	# animação
	var a: Dictionary = d.steer_left
	_dur = a.dur
	_tempos = PackedFloat32Array(a.tempos)
	for qd in a.quadros:
		var ps: Array = []
		var rs: Array = []
		for o in qd:
			ps.append(Vector3(o[0], o[1], o[2]))
			rs.append(Quaternion(o[3], o[4], o[5], o[6]).normalized())
		_pos.append(ps)
		_rot.append(rs)
	# ROOT no quadro 0 = MAIN_CONTROL x ROOT local (0, 1.1315, 0.3032 no Renegade)
	_cabeca = skel.find_bone("head")
	var raiz := skel.find_bone("ROOT")
	var pai_raiz := skel.get_bone_parent(raiz)
	root_pos = _pos[0][pai_raiz] + _rot[0][pai_raiz] * _pos[0][raiz]
	pose(0.0)
	return true


func _textura(caminho: String) -> Texture2D:
	if ResourceLoader.exists(caminho):
		return load(caminho)
	var img := Image.load_from_file(ProjectSettings.globalize_path(caminho))
	return ImageTexture.create_from_image(img) if img else null


## s = direção suavizada do piloto do remake (car.gd rider_s, + = esquerda);
## no jogo é -s
func pose(s: float) -> void:
	if skel == null:
		return
	var s_jogo := -s
	var tm := absf(s_jogo) * _dur
	var esp := s_jogo > 0.0
	var k := 0
	while k < _tempos.size() - 2 and tm > _tempos[k + 1]:
		k += 1
	var f := clampf((tm - _tempos[k]) / maxf(_tempos[k + 1] - _tempos[k], 1e-6), 0.0, 1.0)
	for b in skel.get_bone_count():
		var src := _esp[b] if esp else b
		var p: Vector3 = _pos[k][src].lerp(_pos[k + 1][src], f)
		var r: Quaternion = _rot[k][src].slerp(_rot[k + 1][src], f)
		if esp:
			p.x = -p.x
			r = Quaternion(r.x, -r.y, -r.z, r.w)
		skel.set_bone_pose_position(b, p)
		skel.set_bone_pose_rotation(b, r)
	if _cabeca >= 0:
		skel.set_bone_pose_scale(_cabeca, Vector3.ONE * (0.001 if sem_cabeca else 1.0))


## posição do osso da cabeça no mundo (pra conferir a câmera do piloto)
func cabeca_global() -> Vector3:
	return skel.global_transform * skel.get_bone_global_pose(_cabeca).origin
