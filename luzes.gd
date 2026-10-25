extends Node3D
## Lanterna de freio acesa (melhoria nossa, car.gd LUZ_FREIO). O jogo carrega
## os pontos BRAKE_LIGHT/BRAKE_LIGHT2 (TAIL_LIGHT no Bulldog) do modelo e não
## usa: nenhuma string no exe, a lanterna é só a cor do modelo. A lente
## vermelha vem da cor do vértice (vidro claro x vértice 167, 24, 24) ou da
## textura (Inferno, pintura do Storm).
##
## As faces da lente = perto de um ponto (RAIO) e vermelhas na cor final
## (textura x cor do vértice, em linear). Elas ganham uma cópia por cima, um
## pouco pra fora pela normal, que SOMA a própria cor (blend_add) vezes GANHO
## quando o freio aperta. Sem luz pontual: de dia um OmniLight vermelho
## pintava gaiola, estepe e chão de rosa (fica pra noite, se tiver).
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
const AFASTA := 0.002         # m: cópia pra fora da face (sem brigar no z)

const SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool tem_tex = true;
uniform float aceso = 0.0;
uniform float ganho = 6.0;
uniform float afasta = 0.002;
uniform float cor_k = 0.0;

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
	ALBEDO = t * cor_v(COLOR.rgb) * aceso * ganho;
}
"""

var car = null
var faces := 0                    # quantas faces de lente achou
var aceso := 0.0
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
			if String(k).begins_with(p):
				pts.append(car.points[k])
	if pts.is_empty():
		return false
	var sh := Shader.new()
	sh.code = SHADER
	var malha := ArrayMesh.new()
	var mesh: ArrayMesh = mi.mesh
	var k_cor: float = car.cor_k()
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
		var novo := PackedInt32Array()
		for t in range(0, ix.size(), 3):
			var i0 := ix[t]
			var i1 := ix[t + 1]
			var i2 := ix[t + 2]
			var cen := (vs[i0] + vs[i1] + vs[i2]) / 3.0
			var perto := false
			for p in pts:
				if cen.distance_to(p) < RAIO:
					perto = true
					break
			if not perto:
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
	return true


## freio 0..1 (brake_in); a lâmpada sobe em ACENDE e desce em APAGA
func atualizar(delta: float, freio: float) -> void:
	var alvo := 1.0 if freio > LIGA else 0.0
	if OS.get_environment("FREIO") == "1":       # print_tela: lanterna acesa
		alvo = 1.0
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
