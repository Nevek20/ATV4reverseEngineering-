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
var _pais := PackedInt32Array()
var _lp: Array = []               # pose local de agora (posição, rotação)
var _lr: Array = []

# Mãos no volante (melhoria nossa, car.gd MAOS_NO_VOLANTE: no buggy do jogo o
# volante não gira e o piloto não segue ele, mRiderMatchSteer = 0). O centro
# do punho de cada mão fica preso num ponto do aro, que gira com o volante; o
# braço chega lá por IK de dois ossos e o resto do corpo é a animação do jogo.
# O giro do volante sai da própria animação: em cada quadro do STEER_LEFT, a
# média do quanto os dois punhos giraram em volta do centro do aro.
var _vol := false
var _vc := Vector3.ZERO           # centro do aro (frame do esqueleto)
var _ve := Vector3.UP             # eixo do aro
var _giro := PackedFloat32Array() # giro do volante em cada quadro (rad, em volta de _ve)
var _maos: Array = []             # {sup, inf, mao, cent (punho no frame da mão), pega}
var _punho := {}                  # osso da mão -> centro do punho no frame dela
var alcance := 0.0                # conferência: distância até o alvo / braço esticado (> 1 = não alcança)
# onde as mãos pegam o aro, em graus a partir do topo (melhoria nossa; ~9h30
# e 2h30 como no vídeo de referência do Matheus). O quadro 0 do jogo dá 44°
const PEGA_GRAUS := 65.0


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
		_pais.append(int(ossos[b].pai))
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
	_lp.resize(n)
	_lr.resize(n)

	# centro de cada punho = média dos vértices da mão (osso principal da mão
	# ou dos dedos) no quadro 0, guardado no frame do osso da mão
	var g0 := _globais_quadro(0)
	var ov := PackedInt32Array(d.ossos_v)
	for nome in ["right_hand", "left_hand"]:
		var mao := skel.find_bone(nome)
		var soma := Vector3.ZERO
		var cnt := 0
		for i in pos.size():
			var o := ov[4 * i]
			if pes[4 * i] < 0.5 or (o != mao and not _desce_de(o, mao)):
				continue
			var v := Vector3.ZERO
			for k in 4:
				if pes[4 * i + k] > 0.0:
					var ob := ov[4 * i + k]
					v += pes[4 * i + k] * (g0[ob] * (glob[ob].affine_inverse() * pos[i]))
			soma += v
			cnt += 1
		if cnt > 0:
			_punho[mao] = g0[mao].affine_inverse() * (soma / cnt)
	pose(0.0)
	return true


func _desce_de(b: int, ancestral: int) -> bool:
	while b >= 0:
		b = _pais[b]
		if b == ancestral:
			return true
	return false


## transforms globais (frame do esqueleto) de todos os ossos num quadro da animação
func _globais_quadro(k: int) -> Array:
	var g: Array = []
	g.resize(_pais.size())
	for b in _pais.size():
		var t := Transform3D(Basis(_rot[k][b]), _pos[k][b])
		g[b] = t if _pais[b] < 0 else g[_pais[b]] * t
	return g


## liga as mãos no volante: centro, eixo e raio do aro no frame do esqueleto
func prender_no_volante(centro: Vector3, eixo: Vector3, raio: float) -> void:
	if _punho.size() < 2:
		return
	_vc = centro
	_ve = eixo.normalized()
	var g0 := _globais_quadro(0)
	_maos.clear()
	# a mão esquerda pega o aro e a direita é o espelho dela no plano do
	# volante (no quadro 0 do jogo a direita fica a 22° do topo e a esquerda a
	# 44°: na câmera do piloto os braços saíam tortos)
	var esq := skel.find_bone("left_hand")
	var c_esq: Vector3 = g0[esq] * _punho[esq]
	var rel := c_esq - _vc
	rel -= _ve * rel.dot(_ve)
	var no_aro := _vc + rel.normalized() * raio
	# a mão gira (o mínimo) até a linha dos nós dos dedos (indicador ->
	# anelar) ficar ao longo do aro: na animação ela fica 25° a 43° torta e o
	# aro saía de lado do punho (mão "mal encostando")
	var nos: Vector3 = g0[skel.find_bone("left_ring_01")].origin - g0[skel.find_bone("left_index_01")].origin
	var tang := _ve.cross(rel.normalized())
	if tang.dot(nos) < 0.0:
		tang = -tang
	var b_esq: Basis = Basis(Quaternion(nos.normalized(), tang)) * g0[esq].basis
	var pega_esq := Transform3D(b_esq, no_aro - b_esq * _punho[esq])
	# desce pela borda do aro até PEGA_GRAUS do topo, girando junto com ele
	# (a 44° os braços subiam na frente da câmera do piloto)
	var cima := (Vector3.UP - _ve * _ve.y).normalized()
	var ang := cima.signed_angle_to(rel, _ve)
	var gira := Basis(_ve, deg_to_rad(PEGA_GRAUS) * signf(ang) - ang)
	pega_esq = Transform3D(gira, _vc - gira * _vc) * pega_esq
	no_aro = _vc + gira * (no_aro - _vc)
	tang = gira * tang
	# pulso reto: a mão gira em volta da linha dos nós (no aro) até o
	# comprimento dela (pulso -> punho) ficar na linha do antebraço do IK
	var sup := skel.find_bone("left_upper_arm")
	var inf := skel.find_bone("left_lower_arm")
	var ombro: Vector3 = g0[sup].origin
	var l1: float = ombro.distance_to(g0[inf].origin)
	var l2: float = g0[inf].origin.distance_to(g0[esq].origin)
	var compr := _punho[esq].normalized() as Vector3
	for it in 8:
		var pulso := pega_esq.origin
		var cot := _cotovelo(ombro, g0[inf].origin, pulso, l1, l2)
		var ante := (pulso - cot).normalized()
		var h: Vector3 = pega_esq.basis * compr
		var phi := (h - tang * h.dot(tang)).signed_angle_to(ante - tang * ante.dot(tang), tang)
		var r := Basis(tang, phi)
		pega_esq = Transform3D(r * pega_esq.basis, no_aro + r * (pega_esq.origin - no_aro))
	# reflexão no plano do volante (normal = lado do carro) e, nos ossos, a
	# troca de lado do esqueleto (x negado, como o espelho da animação)
	var nl := _ve.cross(Vector3.UP).normalized()
	var S := Basis(Vector3.RIGHT - 2.0 * nl * nl.x, Vector3.UP - 2.0 * nl * nl.y, Vector3.BACK - 2.0 * nl * nl.z)
	var reflexo := Transform3D(S, 2.0 * nl * nl.dot(_vc))
	var dir_ := skel.find_bone("right_hand")
	var pega_dir := Transform3D(S * pega_esq.basis * Basis.FLIP_X, reflexo * pega_esq.origin)
	pega_dir = pega_dir.translated(reflexo * no_aro - pega_dir * _punho[dir_])
	for lado in [["right_upper_arm", "right_lower_arm", dir_, pega_dir], ["left_upper_arm", "left_lower_arm", esq, pega_esq]]:
		_maos.append({"sup": skel.find_bone(lado[0]), "inf": skel.find_bone(lado[1]), "mao": lado[2],
			"cent": _punho[lado[2]], "pega": lado[3]})
	_giro.clear()
	for k in _tempos.size():
		var gk := _globais_quadro(k)
		var soma := 0.0
		for m in _maos:
			var a0: Vector3 = g0[m.mao] * m.cent - _vc
			var a1: Vector3 = gk[m.mao] * m.cent - _vc
			soma += (a0 - _ve * a0.dot(_ve)).signed_angle_to(a1 - _ve * a1.dot(_ve), _ve)
		_giro.append(soma / _maos.size())
	_vol = true


func no_volante() -> bool:
	return _vol


## cotovelo do IK de dois ossos (ombro -> cotovelo -> pulso) com o cotovelo
## no plano que a animação dá (cot0 = cotovelo da animação)
func _cotovelo(ombro: Vector3, cot0: Vector3, pulso: Vector3, l1: float, l2: float) -> Vector3:
	var para := pulso - ombro
	var d := clampf(para.length(), absf(l1 - l2) + 1e-4, l1 + l2 - 1e-4)
	var dir := para.normalized()
	var polo := (cot0 - ombro) - dir * (cot0 - ombro).dot(dir)
	if polo.length_squared() < 1e-10:
		polo = dir.cross(_ve)
	polo = polo.normalized()
	var x := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	return ombro + dir * x + polo * sqrt(maxf(l1 * l1 - x * x, 0.0))


## giro do volante (rad, em volta do eixo do aro) pra direção suavizada s do
## remake, o mesmo que as mãos fazem no STEER_LEFT (espelhado: sinal trocado)
func giro_volante(s: float) -> float:
	var kf := _quadro(absf(s) * _dur)
	var g := lerpf(_giro[int(kf.x)], _giro[int(kf.x) + 1], kf.y)
	return -g if -s > 0.0 else g


## quadro e fração no tempo tm do STEER_LEFT
func _quadro(tm: float) -> Vector2:
	var k := 0
	while k < _tempos.size() - 2 and tm > _tempos[k + 1]:
		k += 1
	return Vector2(k, clampf((tm - _tempos[k]) / maxf(_tempos[k + 1] - _tempos[k], 1e-6), 0.0, 1.0))


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
	var esp := s_jogo > 0.0
	var kf := _quadro(absf(s_jogo) * _dur)
	var k := int(kf.x)
	var f := kf.y
	for b in skel.get_bone_count():
		var src := _esp[b] if esp else b
		var p: Vector3 = _pos[k][src].lerp(_pos[k + 1][src], f)
		var r: Quaternion = _rot[k][src].slerp(_rot[k + 1][src], f)
		if esp:
			p.x = -p.x
			r = Quaternion(r.x, -r.y, -r.z, r.w)
		_lp[b] = p
		_lr[b] = r
	if _vol:
		_segura_volante(giro_volante(s))
	for b in skel.get_bone_count():
		skel.set_bone_pose_position(b, _lp[b])
		skel.set_bone_pose_rotation(b, _lr[b])
	if _cabeca >= 0:
		skel.set_bone_pose_scale(_cabeca, Vector3.ONE * (0.001 if sem_cabeca else 1.0))


## cada punho no seu ponto do aro, girado com o volante; o braço (ombro ->
## cotovelo -> pulso) chega lá por IK de dois ossos com o cotovelo no plano
## que a animação dá, e a mão gira junto com o volante
func _segura_volante(giro: float) -> void:
	var g: Array = []
	g.resize(_pais.size())
	for b in _pais.size():
		var t := Transform3D(Basis(_lr[b]), _lp[b])
		g[b] = t if _pais[b] < 0 else g[_pais[b]] * t
	var rot := Basis(_ve, giro)
	var gira := Transform3D(rot, _vc - rot * _vc)
	for m in _maos:
		var alvo: Transform3D = gira * m.pega
		var sup: int = m.sup
		var inf: int = m.inf
		var mao: int = m.mao
		var a: Vector3 = g[sup].origin
		var b0: Vector3 = g[inf].origin
		var w0: Vector3 = g[mao].origin
		var l1 := a.distance_to(b0)
		var l2 := b0.distance_to(w0)
		# volante longe (5 carros: braço esticado não chega): o ombro avança,
		# girando a clavícula na direção do aro até o pulso alcançar (até 35°)
		var omb: int = _pais[sup]
		var s0: Vector3 = g[omb].origin
		var alc := (l1 + l2) * 0.98
		alcance = maxf(alcance, (alvo.origin - a).length() / (l1 + l2))
		var eixo := (a - s0).cross(alvo.origin - s0)
		if (alvo.origin - a).length() > alc and eixo.length_squared() > 1e-10:
			eixo = eixo.normalized()
			var lo := 0.0
			var hi := deg_to_rad(35.0)
			for it in 12:
				var meio := (lo + hi) * 0.5
				if (alvo.origin - (s0 + Basis(eixo, meio) * (a - s0))).length() > alc:
					lo = meio
				else:
					hi = meio
			var q := Basis(eixo, hi)
			_lr[omb] = (g[_pais[omb]].basis.inverse() * (q * g[omb].basis)).get_rotation_quaternion()
			for o in [omb, sup, inf, mao]:
				g[o] = Transform3D(q * g[o].basis, s0 + q * (g[o].origin - s0))
			a = g[sup].origin
			b0 = g[inf].origin
			w0 = g[mao].origin
		var para := alvo.origin - a
		var d := clampf(para.length(), absf(l1 - l2) + 1e-4, l1 + l2 - 1e-4)
		var dir := para.normalized()
		var polo := (b0 - a) - dir * (b0 - a).dot(dir)
		if polo.length_squared() < 1e-10:
			polo = dir.cross(_ve)
		polo = polo.normalized()
		var x := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
		var cot := a + dir * x + polo * sqrt(maxf(l1 * l1 - x * x, 0.0))
		var r1 := Quaternion((b0 - a).normalized(), (cot - a).normalized())
		var w1: Vector3 = cot + r1 * (w0 - b0)
		var r2 := Quaternion((w1 - cot).normalized(), (a + dir * d - cot).normalized())
		var b_sup: Basis = Basis(r1) * g[sup].basis
		var b_inf: Basis = Basis(r2 * r1) * g[inf].basis
		_lr[sup] = (g[_pais[sup]].basis.inverse() * b_sup).get_rotation_quaternion()
		_lr[inf] = (b_sup.inverse() * b_inf).get_rotation_quaternion()
		_lr[mao] = (b_inf.inverse() * alvo.basis).get_rotation_quaternion()


## conferência (tests/teste_volante.gd): distância de cada punho até o seu
## ponto no aro e do cotovelo até o da animação, na pose de agora (m)
func erro_maos(s: float) -> Array:
	var g: Array = []
	g.resize(_pais.size())
	for b in _pais.size():
		var t := Transform3D(Basis(_lr[b]), _lp[b])
		g[b] = t if _pais[b] < 0 else g[_pais[b]] * t
	var rot := Basis(_ve, giro_volante(s))
	var gira := Transform3D(rot, _vc - rot * _vc)
	var out: Array = []
	for m in _maos:
		var alvo: Vector3 = (gira * m.pega) * m.cent
		out.append((g[m.mao] * m.cent).distance_to(alvo))
	return out


## posição do osso da cabeça no mundo (pra conferir a câmera do piloto)
func cabeca_global() -> Vector3:
	return skel.global_transform * skel.get_bone_global_pose(_cabeca).origin
