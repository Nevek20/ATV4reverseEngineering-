extends RefCounted
## Desenho da sujeira no carro e no piloto (car.gd SUJEIRA; o nível sai do
## car.gd _sujeira_passo, porta do 0x223e68).
##
## No jogo: o objeto da sujeira (veículo+0xa80) guarda o nível (+0xc0) e,
## a cada quadro, põe alfa = nível·128 na cor de cada vértice das malhas do
## carro (0x3b3a78, 300 vértices por quadro; 17 malhas no Renegade: a
## carroceria e as peças, conferido na RAM). O nível é igual em todo o carro.
## A pista diz a textura (TrackProperties, Dirt mDirtTextureName =
## GEN_DIRT_DIRT em todas): Vehicles/Generic/Textures/GEN_DIRT_DIRT pro carro
## e Characters/Textures/Dirt/GEN_DIRT_DIRT pro piloto. Por cima da pintura
## vai a textura com alfa = alfa do vértice x alfa da textura (PS2: 0x80 =
## 1.0; no png x2, o tools/fx_jogo.py salva com alfa).
##
## Nosso: o UV dessa camada não achamos (sai no microcódigo da VU1). Aqui a
## textura é projetada nos 3 eixos da peça (triplanar), ESCALA metros por
## repetição, pra não depender do atlas de cada modelo.

const TEX := "res://assets/fx/sujeira.png"
const TEX_PILOTO := "res://assets/fx/sujeira_piloto.png"
const ESCALA := 1.2           # metros por repetição da textura (nosso)
const ESCALA_PILOTO := 0.6

const SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled;

uniform sampler2D sujeira : source_color, filter_linear_mipmap, repeat_enable;
uniform float nivel = 0.0;
uniform float escala = 1.2;
uniform sampler2D base : source_color, hint_default_white;
uniform bool recorte = false;

varying vec3 p_obj;
varying vec3 n_obj;

void vertex() {
	p_obj = VERTEX;
	n_obj = NORMAL;
}

void fragment() {
	if (recorte && texture(base, UV).a < 0.5) {
		discard;
	}
	vec3 w = pow(abs(normalize(n_obj)), vec3(4.0));
	w /= w.x + w.y + w.z;
	vec4 t = texture(sujeira, p_obj.zy / escala) * w.x
		+ texture(sujeira, p_obj.xz / escala) * w.y
		+ texture(sujeira, p_obj.xy / escala) * w.z;
	ALBEDO = t.rgb;
	ALPHA = t.a * nivel;
}
"""

var mats: Array[ShaderMaterial] = []
var byte := -1


## põe a camada em todas as malhas do carro e do piloto. Sem a textura
## (assets/fx fora do git) não desenha nada e devolve false.
func montar(car) -> bool:
	if not ResourceLoader.exists(TEX):
		return false
	var sh := Shader.new()
	sh.code = SHADER
	var tex: Texture2D = load(TEX)
	var tex_p: Texture2D = load(TEX_PILOTO) if ResourceLoader.exists(TEX_PILOTO) else tex
	var geral := _material(sh, tex, ESCALA)
	var piloto_mi: MeshInstance3D = car.piloto.malha if car.piloto else null
	for mi in _malhas(car):
		if mi == piloto_mi:
			mi.material_overlay = _material(sh, tex_p, ESCALA_PILOTO)
			continue
		var furada := false
		for s in mi.mesh.get_surface_count():
			furada = furada or _recorte(mi.get_active_material(s))
		if not furada:
			mi.material_overlay = geral
			continue
		# malha com rede (alfa recortado): a camada vai em cada superfície e
		# respeita o furo da textura de baixo
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(s)
			if m == null:
				continue
			var m2: Material = m.duplicate()
			if _recorte(m):
				var c := _material(sh, tex, ESCALA)
				c.set_shader_parameter("base", m.albedo_texture)
				c.set_shader_parameter("recorte", true)
				m2.next_pass = c
			else:
				m2.next_pass = geral
			mi.set_surface_override_material(s, m2)
	return true


## nível 0..1 -> camada. O jogo grava o byte (int)(nível·128): muda em degraus.
func atualizar(nivel: float) -> void:
	var b := int(nivel * 128.0)
	if b == byte:
		return
	byte = b
	for m in mats:
		m.set_shader_parameter("nivel", b / 128.0)


func _material(sh: Shader, tex: Texture2D, escala: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("sujeira", tex)
	m.set_shader_parameter("escala", escala)
	m.set_shader_parameter("nivel", maxf(byte, 0) / 128.0)
	mats.append(m)
	return m


static func _recorte(m: Material) -> bool:
	return m is BaseMaterial3D and m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR


static func _malhas(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in n.get_children():
		if c is MeshInstance3D and c.mesh:
			out.append(c)
		out.append_array(_malhas(c))
	return out
