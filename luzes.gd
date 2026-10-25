extends Node3D
## Lanterna de freio acesa (melhoria nossa, car.gd LUZ_FREIO). O jogo carrega
## os pontos BRAKE_LIGHT/BRAKE_LIGHT2 (TAIL_LIGHT no Bulldog) do modelo e não
## usa: nenhuma string no exe, a lanterna é só a cor do modelo. A lente
## vermelha vem da cor do vértice (vidro claro x vértice 167, 24, 24) ou da
## textura (Inferno, pintura do Storm).
##
## As faces da lente = perto de um ponto (RAIO) e vermelhas na cor final
## (textura x cor do vértice, em linear). Elas ganham uma cópia por cima, um
## pouco pra fora pela normal, que SOMA a cor dela vezes GANHO + MIOLO quando
## o freio aperta. Só somar vermelho não aparecia: a lente apagada já é
## vermelho puro (vértice 1.3 x sol), então o miolo puxa pro rosado claro e
## cada lanterna ganha um HALO (brilho em volta, virado pra câmera, só de
## trás: some quando a câmera sai da frente da lente). Sem luz pontual: de
## dia um OmniLight vermelho pintava gaiola, estepe e chão de rosa.
## Freio = brake_in (o suavizado do jogo, 0x390): inclui o freio que o jogo
## segura parado (0x202df0), então acende parado na largada, e zera na ré
## pelo freio. Acende e apaga em ACENDE / APAGA segundos (lâmpada).

const PONTOS := ["BRAKE_LIGHT", "TAIL_LIGHT"]   # prefixos (BRAKE_LIGHT2 entra)
const RAIO := 0.15            # m: face com o centro até aqui do ponto
const VERMELHO := 3.0         # linear: r > VERMELHO·g e r > VERMELHO·b
const MIN_R := 0.03           # linear: lente muito escura não conta
const LIGA := 0.05            # brake_in acima disso = freando
const ACENDE := 0.06          # s
const APAGA := 0.15           # s
const GANHO := 6.0            # quanto a lente soma de luz acesa (x a cor dela)
const MIOLO := Color(0.45, 0.10, 0.06)   # + isso (linear): a lente acesa clareia
const AFASTA := 0.002         # m: cópia pra fora da face (sem brigar no z)
const HALO_TAM := Vector2(0.18, 0.45)    # m: diâmetro = 2.2 x a lente, entre esses
const HALO_FORCA := 1.2
const HALO_COR := Color(1.0, 0.10, 0.04)
const JUNTA := 0.10           # m: pontos mais perto que isso viram um (TAIL_LIGHT x BRAKE_LIGHT)

const SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool tem_tex = true;
uniform float aceso = 0.0;
uniform float ganho = 6.0;
uniform float afasta = 0.002;
uniform float cor_k = 0.0;
uniform vec3 miolo = vec3(0.45, 0.10, 0.06);

vec3 cor_v(vec3 c) {
	if (cor_k <= 0.0) {
		return vec3(1.0);
	}
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045))) * cor_k;
}

void vertex() {
	VERTEX += NORMAL * afasta;
}

void fragment() {
	vec3 t = tem_tex ? texture(tex, UV).rgb : vec3(1.0);
	ALBEDO = (t * cor_v(COLOR.rgb) * ganho + miolo) * aceso;
}
"""

# brilho em volta da lanterna: quadrado virado pra câmera (montado na vista),
# puxado PUXA pra frente (não some dentro da caixa da lanterna), mais forte
# quanto mais a lente olha pra câmera
const SHADER_HALO := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform, fog_disabled;
uniform float aceso = 0.0;
uniform float tam = 0.3;
uniform vec3 frente = vec3(0.0, 0.0, -1.0);
uniform vec3 cor = vec3(1.0, 0.1, 0.04);
uniform float forca = 1.2;
uniform float puxa = 0.12;
varying float ver;

void vertex() {
	vec3 c = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 f = normalize((MODELVIEW_MATRIX * vec4(frente, 0.0)).xyz);
	vec3 cam = normalize(-c);
	ver = smoothstep(0.0, 0.5, dot(f, cam));
	VERTEX = c + vec3(VERTEX.xy * tam, 0.0) + cam * puxa;
}

void fragment() {
	float a = clamp(1.0 - length(UV - vec2(0.5)) * 2.0, 0.0, 1.0);
	a *= a;
	ALBEDO = mix(cor, vec3(1.0, 0.55, 0.45), a * a) * a * aceso * forca * ver;
}
"""

var car = null
var faces := 0                    # quantas faces de lente achou
var aceso := 0.0
var halos := 0
var _mats: Array[ShaderMaterial] = []
var _imgs := {}


## acha as lentes na carroceria e monta as cópias. false = nada achado
func montar(c) -> bool:
	car = c
	var mi: MeshInstance3D = car.body_mi
	if mi == null or not (mi.mesh is ArrayMesh):
		return false
	var pts: Array[Vector3] = []
	for k in car.points:
		for p in PONTOS:
			var q: Vector3 = car.points[k]
			if String(k).begins_with(p) and pts.all(func(o): return o.distance_to(q) > JUNTA):
				pts.append(q)
	if pts.is_empty():
		return false
	var sh := Shader.new()
	sh.code = SHADER
	var malha := ArrayMesh.new()
	var mesh: ArrayMesh = mi.mesh
	var k_cor: float = car.cor_k()
	# por ponto: soma dos centros, das normais, nº de faces e caixa da lente
	var grupos: Array = []
	for p in pts:
		grupos.append({"c": Vector3.ZERO, "n": Vector3.ZERO, "k": 0, "lo": Vector3.INF, "hi": -Vector3.INF})
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var ix := PackedInt32Array(range(vs.size()))
		if a[Mesh.ARRAY_INDEX] != null:
			ix = a[Mesh.ARRAY_INDEX]
		var m := mi.get_active_material(s) as StandardMaterial3D
		var tex: Texture2D = m.albedo_texture if m else null
		var img := _imagem(tex)
		var cols = a[Mesh.ARRAY_COLOR]
		var uvs = a[Mesh.ARRAY_TEX_UV]
		var nrs = a[Mesh.ARRAY_NORMAL]
		var novo := PackedInt32Array()
		for t in range(0, ix.size(), 3):
			var i0 := ix[t]
			var i1 := ix[t + 1]
			var i2 := ix[t + 2]
			var cen := (vs[i0] + vs[i1] + vs[i2]) / 3.0
			var perto := -1
			for j in pts.size():
				if cen.distance_to(pts[j]) < RAIO and (perto < 0 or
						cen.distance_to(pts[j]) < cen.distance_to(pts[perto])):
					perto = j
			if perto < 0:
				continue
			var cor := Color(1, 1, 1)
			if img and uvs != null:
				var uv: Vector2 = (uvs[i0] + uvs[i1] + uvs[i2]) / 3.0
				cor = _amostra(img, uv)
			if cols != null and k_cor > 0.0:
				var cv: Color = ((cols[i0] + cols[i1] + cols[i2]) / 3.0).srgb_to_linear()
				cor = Color(cor.r * cv.r * k_cor, cor.g * cv.g * k_cor, cor.b * cv.b * k_cor)
			if cor.r > MIN_R and cor.r > VERMELHO * cor.g and cor.r > VERMELHO * cor.b:
				novo.append_array([i0, i1, i2])
				var g: Dictionary = grupos[perto]
				g.c += cen
				g.k += 1
				if nrs != null:
					g.n += nrs[i0] + nrs[i1] + nrs[i2]
				for v in [vs[i0], vs[i1], vs[i2]]:
					g.lo = g.lo.min(v)
					g.hi = g.hi.max(v)
		if novo.is_empty():
			continue
		var b: Array = a.duplicate()
		b[Mesh.ARRAY_INDEX] = novo
		b[Mesh.ARRAY_TANGENT] = null
		malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b)
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("tex", tex)
		mat.set_shader_parameter("tem_tex", tex != null)
		mat.set_shader_parameter("ganho", GANHO)
		mat.set_shader_parameter("afasta", AFASTA)
		mat.set_shader_parameter("cor_k", k_cor)
		mat.set_shader_parameter("miolo", Vector3(MIOLO.r, MIOLO.g, MIOLO.b))
		malha.surface_set_material(malha.get_surface_count() - 1, mat)
		_mats.append(mat)
		faces += novo.size() / 3
	if faces == 0:
		return false
	var lente := MeshInstance3D.new()
	lente.name = "LanternaAcesa"
	lente.mesh = malha
	lente.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(lente)
	var sh_halo := Shader.new()
	sh_halo.code = SHADER_HALO
	for g in grupos:
		if g.k == 0:
			continue
		var n: Vector3 = g.n.normalized() if g.n.length() > 0.0 else Vector3(0, 0, -1)
		var ext: Vector3 = g.hi - g.lo
		var q := QuadMesh.new()
		var mat := ShaderMaterial.new()
		mat.shader = sh_halo
		mat.set_shader_parameter("tam", clampf(2.2 * maxf(ext.x, maxf(ext.y, ext.z)), HALO_TAM.x, HALO_TAM.y))
		mat.set_shader_parameter("frente", n)
		mat.set_shader_parameter("cor", Vector3(HALO_COR.r, HALO_COR.g, HALO_COR.b))
		mat.set_shader_parameter("forca", HALO_FORCA)
		q.material = mat
		var h := MeshInstance3D.new()
		h.name = "Halo"
		h.mesh = q
		h.position = g.c / float(g.k) + n * 0.02
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		h.extra_cull_margin = 1.0
		mi.add_child(h, true)
		_mats.append(mat)
		halos += 1
	return true


## freio 0..1 (brake_in); a lâmpada sobe em ACENDE e desce em APAGA
func atualizar(delta: float, freio: float) -> void:
	var alvo := 1.0 if freio > LIGA else 0.0
	if OS.has_environment("FREIO"):              # print_tela: 1 acesa, 0 apagada
		alvo = 1.0 if OS.get_environment("FREIO") == "1" else 0.0
	var vel := 1.0 / (ACENDE if alvo > aceso else APAGA)
	aceso = move_toward(aceso, alvo, delta * vel)
	for m in _mats:
		m.set_shader_parameter("aceso", aceso)


func _imagem(tex: Texture2D) -> Image:
	if tex == null:
		return null
	if _imgs.has(tex):
		return _imgs[tex]
	var img := tex.get_image()
	if img and img.is_compressed():
		img = img.duplicate()
		img.decompress()
	_imgs[tex] = img
	return img


## cor linear da textura no UV (repete fora de 0..1)
static func _amostra(img: Image, uv: Vector2) -> Color:
	var w := img.get_width()
	var h := img.get_height()
	var x := posmod(int(floor(uv.x * w)), w)
	var y := posmod(int(floor(uv.y * h)), h)
	return img.get_pixel(x, y).srgb_to_linear()
