extends Node3D
## Lanterna de freio e luz de ré acesas (melhoria nossa, car.gd LUZ_FREIO). O
## jogo carrega os pontos BRAKE_LIGHT/BRAKE_LIGHT2 (TAIL_LIGHT no Bulldog) e
## REVERSE_LIGHT do modelo e não usa: nenhuma string no exe, a lanterna é só
## a cor do modelo. A lente vem da cor do vértice (vidro claro x vértice
## vermelho 167, 24, 24) ou da textura (Inferno, pintura do Storm).
##
## Lente = os PIXELS da cor da luz (vermelho no freio, branco na ré) na cor
## final (textura x cor do vértice, em linear) até RAIO do ponto. As faces que
## têm algum desses pixels (amostras a cada PASSO no triângulo, só as de
## dentro do raio: os triângulos da pintura do Storm são grandes e o centro
## deles caía longe do ponto da ré) ganham uma cópia por cima,
## um pouco pra fora pela normal, que SOMA a cor dela vezes GANHO + MIOLO só
## onde o pixel é da cor da luz (máscara no shader): no Storm a lanterna é
## pintada na textura (vermelho embaixo, branco da ré em cima) em triângulos
## grandes, e acender o triângulo inteiro desenhava triângulos claros.
## Cada lanterna ganha um HALO (brilho em volta, virado pra câmera, só de
## trás) no centro e no tamanho dos pixels acesos. Só somar não aparecia: a
## lente apagada já é vermelho puro (vértice 1.3 x sol). Sem luz pontual: de
## dia um OmniLight vermelho pintava gaiola, estepe e chão de rosa.
##
## Freio = brake_in (o suavizado do jogo, 0x390): inclui o freio que o jogo
## segura parado (0x202df0), então acende parado na largada, e zera na ré
## pelo freio. Ré = marcha -1 engatada. Acende e apaga em ACENDE / APAGA
## segundos (lâmpada). Só os carros com REVERSE_LIGHT no modelo têm ré.

const TIPOS := {
	"freio": {"pontos": ["BRAKE_LIGHT", "TAIL_LIGHT"], "raio": 0.15, "modo": 0,
		"halo": Color(1.0, 0.10, 0.04), "miolo": Color(0.45, 0.10, 0.06)},
	"re": {"pontos": ["REVERSE_LIGHT"], "raio": 0.12, "modo": 1,
		"halo": Color(1.0, 0.92, 0.80), "miolo": Color(0.35, 0.33, 0.30)},
}
const LIGA := 0.05            # brake_in acima disso = freando
const ACENDE := 0.06          # s
const APAGA := 0.15           # s
const GANHO := 6.0            # quanto a lente soma de luz acesa (x a cor dela)
const AFASTA := 0.002         # m: cópia pra fora da face (sem brigar no z)
const HALO_TAM := Vector2(0.10, 0.30)    # m: diâmetro = 1.6 x os pixels acesos, entre esses
const HALO_FORCA := 0.9
const JUNTA := 0.10           # m: pontos mais perto que isso viram um (TAIL_LIGHT x BRAKE_LIGHT)
const PASSO := 0.01           # m: amostras no triângulo (grade baricêntrica), até 20 por lado

# máscara da cor da luz (a mesma conta no shader e em _mascara)
const GLSL_MASCARA := """
float mascara(vec3 c, int qual) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	if (qual == 0) {
		return smoothstep(2.0, 4.0, c.r / max(max(c.g, c.b), 1e-4)) * smoothstep(0.02, 0.05, c.r);
	}
	float sat = (mx - mn) / max(mx, 1e-4);
	return smoothstep(0.15, 0.35, mx) * (1.0 - smoothstep(0.25, 0.45, sat));
}
"""

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
uniform int modo = 0;            // 0 vermelho (freio), 1 branco (ré)

vec3 cor_v(vec3 c) {
	if (cor_k <= 0.0) {
		return vec3(1.0);
	}
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045))) * cor_k;
}
%s
void vertex() {
	VERTEX += NORMAL * afasta;
}

void fragment() {
	vec3 t = tem_tex ? texture(tex, UV).rgb : vec3(1.0);
	vec3 c = t * cor_v(COLOR.rgb);
	ALBEDO = (c * ganho + miolo) * mascara(c, modo) * aceso;
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
	ALBEDO = mix(cor, vec3(1.0, 0.75, 0.65), a * a) * a * aceso * forca * ver;
}
"""

var car = null
var faces := {"freio": 0, "re": 0}     # faces de lente achadas por tipo
var halos := {"freio": 0, "re": 0}
var aceso := {"freio": 0.0, "re": 0.0}
var _mats := {"freio": [], "re": []}
var _imgs := {}


## acha as lentes na carroceria e monta as cópias. false = nada achado
func montar(c) -> bool:
	car = c
	var mi: MeshInstance3D = car.body_mi
	if mi == null or not (mi.mesh is ArrayMesh):
		return false
	var sh := Shader.new()
	sh.code = SHADER % GLSL_MASCARA
	var sh_halo := Shader.new()
	sh_halo.code = SHADER_HALO
	for tipo in TIPOS:
		_montar_tipo(mi, tipo, sh, sh_halo)
	return faces.freio + faces.re > 0


func _montar_tipo(mi: MeshInstance3D, tipo: String, sh: Shader, sh_halo: Shader) -> void:
	var def: Dictionary = TIPOS[tipo]
	var pts: Array[Vector3] = []
	for k in car.points:
		for p in def.pontos:
			var q: Vector3 = car.points[k]
			if String(k).begins_with(p) and pts.all(func(o): return o.distance_to(q) > JUNTA):
				pts.append(q)
	if pts.is_empty():
		return
	var mesh: ArrayMesh = mi.mesh
	var k_cor: float = car.cor_k()
	var modo: int = def.modo
	# por ponto: soma e caixa dos pixels acesos (amostras) e soma das normais
	var grupos: Array = []
	for p in pts:
		grupos.append({"c": Vector3.ZERO, "n": Vector3.ZERO, "k": 0, "lo": Vector3.INF, "hi": -Vector3.INF})
	var malha := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var ix := PackedInt32Array(range(vs.size()))
		if a[Mesh.ARRAY_INDEX] != null:
			ix = a[Mesh.ARRAY_INDEX]
		var m := mi.get_active_material(s) as StandardMaterial3D
		if m == null or m.albedo_color.a <= 0.0:
			continue
		var tex: Texture2D = m.albedo_texture
		var img := _imagem(tex)
		var cols = a[Mesh.ARRAY_COLOR]
		var uvs = a[Mesh.ARRAY_TEX_UV]
		var nrs = a[Mesh.ARRAY_NORMAL]
		var novo := PackedInt32Array()
		for t in range(0, ix.size(), 3):
			var i := [ix[t], ix[t + 1], ix[t + 2]]
			var v0: Vector3 = vs[i[0]]
			var v1: Vector3 = vs[i[1]]
			var v2: Vector3 = vs[i[2]]
			var cen := (v0 + v1 + v2) / 3.0
			var r_tri := maxf(cen.distance_to(v0), maxf(cen.distance_to(v1), cen.distance_to(v2)))
			if pts.all(func(q): return cen.distance_to(q) - r_tri > def.raio):
				continue
			var lado := maxf(v0.distance_to(v1), maxf(v1.distance_to(v2), v2.distance_to(v0)))
			var n_div := clampi(ceili(lado / PASSO), 2, 20)
			var acesos := 0
			var normal_em := -1
			for u in n_div + 1:
				for w in n_div + 1 - u:
					var b := Vector3(u, w, n_div - u - w) / float(n_div)
					var p: Vector3 = v0 * b.x + v1 * b.y + v2 * b.z
					var perto := -1
					for j in pts.size():
						if p.distance_to(pts[j]) < def.raio and (perto < 0 or
								p.distance_to(pts[j]) < p.distance_to(pts[perto])):
							perto = j
					if perto < 0:
						continue
					var cor := Color(1, 1, 1)
					if img and uvs != null:
						cor = _amostra(img, uvs[i[0]] * b.x + uvs[i[1]] * b.y + uvs[i[2]] * b.z)
					if cols != null and k_cor > 0.0:
						var cv: Color = (cols[i[0]] * b.x + cols[i[1]] * b.y + cols[i[2]] * b.z).srgb_to_linear()
						cor = Color(cor.r * cv.r * k_cor, cor.g * cv.g * k_cor, cor.b * cv.b * k_cor)
					if _mascara(cor, modo) > 0.5:
						var g: Dictionary = grupos[perto]
						acesos += 1
						normal_em = perto
						g.c += p
						g.k += 1
						g.lo = g.lo.min(p)
						g.hi = g.hi.max(p)
			if acesos == 0:
				continue
			novo.append_array(PackedInt32Array(i))
			if nrs != null:
				grupos[normal_em].n += nrs[i[0]] + nrs[i[1]] + nrs[i[2]]
		if novo.is_empty():
			continue
		var arr: Array = a.duplicate()
		arr[Mesh.ARRAY_INDEX] = novo
		arr[Mesh.ARRAY_TANGENT] = null
		malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("tex", tex)
		mat.set_shader_parameter("tem_tex", tex != null)
		mat.set_shader_parameter("ganho", GANHO)
		mat.set_shader_parameter("afasta", AFASTA)
		mat.set_shader_parameter("cor_k", k_cor)
		mat.set_shader_parameter("modo", modo)
		var mio: Color = def.miolo
		mat.set_shader_parameter("miolo", Vector3(mio.r, mio.g, mio.b))
		malha.surface_set_material(malha.get_surface_count() - 1, mat)
		_mats[tipo].append(mat)
		faces[tipo] += novo.size() / 3
	if faces[tipo] == 0:
		return
	var lente := MeshInstance3D.new()
	lente.name = "Lente_" + tipo
	lente.mesh = malha
	lente.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(lente)
	for g in grupos:
		if g.k == 0:
			continue
		var n: Vector3 = g.n.normalized() if g.n.length() > 0.0 else Vector3(0, 0, -1)
		var ext: Vector3 = g.hi - g.lo
		var q := QuadMesh.new()
		var mat := ShaderMaterial.new()
		mat.shader = sh_halo
		mat.set_shader_parameter("tam", clampf(1.6 * maxf(ext.x, maxf(ext.y, ext.z)), HALO_TAM.x, HALO_TAM.y))
		mat.set_shader_parameter("frente", n)
		var hc: Color = def.halo
		mat.set_shader_parameter("cor", Vector3(hc.r, hc.g, hc.b))
		mat.set_shader_parameter("forca", HALO_FORCA)
		q.material = mat
		var h := MeshInstance3D.new()
		h.name = "Halo_" + tipo
		h.mesh = q
		h.position = g.c / float(g.k) + n * 0.02
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		h.extra_cull_margin = 1.0
		mi.add_child(h, true)
		_mats[tipo].append(mat)
		halos[tipo] += 1


## freio 0..1 (brake_in) e ré engatada; a lâmpada sobe em ACENDE e desce em APAGA
func atualizar(delta: float, freio: float, re := false) -> void:
	var alvos := {"freio": 1.0 if freio > LIGA else 0.0, "re": 1.0 if re else 0.0}
	if OS.has_environment("FREIO"):              # print_tela: 1 acesa, 0 apagada
		alvos.freio = 1.0 if OS.get_environment("FREIO") == "1" else 0.0
	if OS.has_environment("RE"):
		alvos.re = 1.0 if OS.get_environment("RE") == "1" else 0.0
	for tipo in alvos:
		var vel := 1.0 / (ACENDE if alvos[tipo] > aceso[tipo] else APAGA)
		aceso[tipo] = move_toward(aceso[tipo], alvos[tipo], delta * vel)
		for m in _mats[tipo]:
			m.set_shader_parameter("aceso", aceso[tipo])


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


## a máscara do shader (GLSL_MASCARA) na CPU
static func _mascara(c: Color, qual: int) -> float:
	var mx := maxf(c.r, maxf(c.g, c.b))
	var mn := minf(c.r, minf(c.g, c.b))
	if qual == 0:
		return smoothstep(2.0, 4.0, c.r / maxf(maxf(c.g, c.b), 1e-4)) * smoothstep(0.02, 0.05, c.r)
	var sat := (mx - mn) / maxf(mx, 1e-4)
	return smoothstep(0.15, 0.35, mx) * (1.0 - smoothstep(0.25, 0.45, sat))
