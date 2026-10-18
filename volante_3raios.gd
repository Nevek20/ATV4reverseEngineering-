extends RefCounted
## Volante de 3 raios (melhoria nossa, car.gd VOLANTE_NOSSO). O do jogo é
## parte da carroceria, de 6 a 12 lados e com os raios em X girados uns 20°.
## Este segue as fotos de volantes de buggy que o Matheus mandou: aro preto
## emborrachado, mais grosso onde os raios encostam, 3 raios de alumínio com
## rasgos em 9h, 3h e 6h, centro recuado pro painel (dish), tampa cromada e
## marca amarela no topo. Tamanho e inclinação são os do volante do jogo
## (pecas.json: raio e eixo do aro, tools/volante.py).
##
## Montado em volta da origem, no frame do jogo: eixo = normal do aro (pro
## piloto), "cima" = o y do modelo no plano do aro.

const SEG := 72                 # segmentos em volta do aro
const LADOS := 14               # lados da seção do aro
const ARO_A := 0.016            # meia largura da seção (radial), m
const ARO_B := 0.018            # meia espessura (no eixo)
const LUVA := 0.30              # o aro engrossa 30% onde os raios encostam
const LUVA_ANG := 0.20          # largura da luva (rad)
const MARCA_ANG := 0.06         # meia largura da marca amarela do topo (rad)
const DISH := 0.035             # centro recuado pro painel
const CUBO := 0.05              # raio da placa do centro
const RAIO_LARG_CUBO := 0.046   # largura do raio perto do centro
const RAIO_LARG_ARO := 0.034    # e perto do aro
const TAMPA := 0.030            # tampa cromada
const TAMPA_ALT := 0.022


static func montar(raio: float, eixo: Vector3) -> ArrayMesh:
	var n := eixo.normalized()
	var cima := Vector3.UP - n * n.dot(Vector3.UP)
	cima = cima.normalized()
	var lado := n.cross(cima)
	var raios: Array = [lado, -lado, -cima]           # 9h, 3h e 6h

	var mesh := ArrayMesh.new()
	var preto := _material(Color(0.035, 0.035, 0.04), 0.0, 0.9)
	var amarelo := _material(Color(0.95, 0.72, 0.05), 0.0, 0.8)
	var aluminio := _material(Color(0.85, 0.86, 0.88), 0.7, 0.35)
	aluminio.albedo_texture = _textura_rasgos()
	aluminio.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	aluminio.alpha_scissor_threshold = 0.5
	aluminio.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cromo := _material(Color(0.86, 0.86, 0.88), 1.0, 0.12)

	# aro: tubo de seção elíptica, mais grosso nas luvas dos raios; a marca do
	# topo sai num material separado
	var st_aro := SurfaceTool.new()
	var st_marca := SurfaceTool.new()
	st_aro.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_marca.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	var nrs: Array = []
	for i in SEG + 1:
		var th := TAU * i / SEG
		var radial := cima * cos(th) + lado * sin(th)
		var k := 1.0
		for r in raios:
			var d := absf(radial.signed_angle_to(r, n))
			k += LUVA * exp(-pow(d / LUVA_ANG, 2.0))
		var anel: Array = []
		var anel_n: Array = []
		for j in LADOS:
			var ph := TAU * j / LADOS
			var a := ARO_A * k
			var b := ARO_B * k
			anel.append(radial * (raio + a * cos(ph)) + n * (b * sin(ph)))
			anel_n.append((radial * (b * cos(ph)) + n * (a * sin(ph))).normalized())
		pts.append(anel)
		nrs.append(anel_n)
	for i in SEG:
		var th := TAU * (i + 0.5) / SEG
		var dist_topo := absf(wrapf(th, -PI, PI))
		var st := st_marca if dist_topo < MARCA_ANG else st_aro
		for j in LADOS:
			var j2 := (j + 1) % LADOS
			_quad(st, pts[i][j], pts[i + 1][j], pts[i + 1][j2], pts[i][j2],
				nrs[i][j], nrs[i + 1][j], nrs[i + 1][j2], nrs[i][j2])
	_fechar(mesh, st_aro, preto)
	_fechar(mesh, st_marca, amarelo)

	# placa de alumínio: disco do centro (recuado) + 3 raios que sobem até o
	# aro; os rasgos são o alfa da textura (u ao longo do raio)
	var st_p := SurfaceTool.new()
	st_p.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centro := -n * DISH
	var nseg := 24
	for i in nseg:
		var a0 := TAU * i / nseg
		var a1 := TAU * (i + 1) / nseg
		var p0 := centro + (cima * cos(a0) + lado * sin(a0)) * CUBO
		var p1 := centro + (cima * cos(a1) + lado * sin(a1)) * CUBO
		_tri(st_p, centro, p0, p1, n, Vector2(0.02, 0.5), Vector2(0.02, 0.5), Vector2(0.02, 0.5))
	for r in raios:
		var perp: Vector3 = n.cross(r)
		var ini: Vector3 = centro + r * (CUBO * 0.6)
		var fim: Vector3 = r * raio
		var passos := 8
		for s in passos:
			var t0 := float(s) / passos
			var t1 := float(s + 1) / passos
			var c0 := ini.lerp(fim, t0)
			var c1 := ini.lerp(fim, t1)
			var w0 := lerpf(RAIO_LARG_CUBO, RAIO_LARG_ARO, t0) * 0.5
			var w1 := lerpf(RAIO_LARG_CUBO, RAIO_LARG_ARO, t1) * 0.5
			var nr := (fim - ini).cross(perp).normalized()
			if nr.dot(n) < 0.0:
				nr = -nr
			_quad_uv(st_p, c0 - perp * w0, c1 - perp * w1, c1 + perp * w1, c0 + perp * w0, nr,
				Vector2(t0, 0.0), Vector2(t1, 0.0), Vector2(t1, 1.0), Vector2(t0, 1.0))
	_fechar(mesh, st_p, aluminio)

	# tampa cromada no centro (cilindro com tampo), virada pro piloto
	var st_t := SurfaceTool.new()
	st_t.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := centro
	var topo := centro + n * TAMPA_ALT
	for i in nseg:
		var a0 := TAU * i / nseg
		var a1 := TAU * (i + 1) / nseg
		var d0 := cima * cos(a0) + lado * sin(a0)
		var d1 := cima * cos(a1) + lado * sin(a1)
		_quad(st_t, base + d0 * TAMPA, topo + d0 * TAMPA * 0.85, topo + d1 * TAMPA * 0.85, base + d1 * TAMPA,
			d0, d0, d1, d1)
		_tri(st_t, topo, topo + d1 * TAMPA * 0.85, topo + d0 * TAMPA * 0.85, n,
			Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	_fechar(mesh, st_t, cromo)
	return mesh


static func _material(cor: Color, metal: float, rugo: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.metallic = metal
	m.roughness = rugo
	return m


## alumínio dos raios: dois rasgos arredondados ao longo do raio (alfa 0)
static func _textura_rasgos() -> ImageTexture:
	var w := 32
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var u := float(y) / (h - 1)                  # ao longo do raio
		for x in w:
			var v := float(x) / (w - 1)              # de um lado ao outro
			var cor := Color(1, 1, 1, 1)
			for vc in [0.33, 0.67]:
				var dx: float = (v - vc) / 0.09
				var du := 0.0
				if u < 0.32:
					du = (0.32 - u) / 0.09
				elif u > 0.80:
					du = (u - 0.80) / 0.09
				if dx * dx + du * du < 1.0:
					cor = Color(1, 1, 1, 0)
			img.set_pixel(x, y, cor)
	# a textura é (u ao longo, v através) -> imagem com y = u, x = v
	var tex := ImageTexture.create_from_image(img)
	return tex


static func _fechar(mesh: ArrayMesh, st: SurfaceTool, mat: Material) -> void:
	var arr := st.commit_to_arrays()
	if (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
		return
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


## triângulo com a frente pro lado da normal (o Godot quer horário de frente)
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, nr: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	if (b - a).cross(c - a).dot(nr) > 0.0:
		var t := b
		b = c
		c = t
		var tu := ub
		ub = uc
		uc = tu
	for p in [[a, ua], [b, ub], [c, uc]]:
		st.set_normal(nr)
		st.set_uv(p[1])
		st.add_vertex(p[0])


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3) -> void:
	for t in [[a, b, c, na, nb, nc], [a, c, d, na, nc, nd]]:
		var p0: Vector3 = t[0]
		var p1: Vector3 = t[1]
		var p2: Vector3 = t[2]
		var n0: Vector3 = t[3]
		var n1: Vector3 = t[4]
		var n2: Vector3 = t[5]
		if (p1 - p0).cross(p2 - p0).dot(n0 + n1 + n2) > 0.0:
			var tp := p1
			p1 = p2
			p2 = tp
			var tn := n1
			n1 = n2
			n2 = tn
		for v in [[p0, n0], [p1, n1], [p2, n2]]:
			st.set_normal(v[1])
			st.set_uv(Vector2.ZERO)
			st.add_vertex(v[0])


static func _quad_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, nr: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	_tri(st, a, b, c, nr, Vector2(ua.y, ua.x), Vector2(ub.y, ub.x), Vector2(uc.y, uc.x))
	_tri(st, a, c, d, nr, Vector2(ua.y, ua.x), Vector2(uc.y, uc.x), Vector2(ud.y, ud.x))
