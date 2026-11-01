extends Node3D
## Poeira dos pneus (porta do jogo; docs/engenharia_reversa.md, Poeira).
##
## Tipos (Setup/Dust.xml -> data/dust.xml, carregado em 0x3affb0): Light,
## Medium, Heavy e Water, um conjunto pro carro da câmera (CamSubject) e outro
## pros outros (Other); só "Rear": sai das rodas de trás. O material do chão
## diz o tipo (DustType, None = sem poeira) e a cor (DustColour, RGBA).
##
## Emissão (0x225108, um por quadro do jogo = 50 Hz no PAL): com |v| >= 0.5
## m/s a força é (|v| - 0.5)/35 (cheia a ~128 km/h), presa em 0..1; a roda
## solta poeira com força > 0.1 e alfa da cor > 0.1. Quando o material muda, a
## cor vai da de agora pra DustColour dele em 1 s (sem poeira ou fora do chão:
## o alfa vai a 0 em 1 s, com o tipo de antes). Espaçamento entre nuvens e
## tamanho inicial pelo LOD (distância da câmera até CamMinLodDist, 30 m) e
## pelo quanto a câmera olha ao longo do movimento (ParticleSpacingLookAlong).
##
## Nuvens (0x227c50): uma a cada ParticleSpacing metros do caminho da roda,
## espalhadas no trecho do quadro (a de trás nasce mais velha). PARADAS no
## mundo (sem velocidade): nascem no ponto de contato com tamanho
## ParticleInitSize ± Delta e crescem até ParticleTargetSize ± Delta com
## 1 - (1 - idade/MaxParticleAge)^4 (0x3af590); alfa = força x alfa da cor x
## (1 - t²), t = idade / vida dela. Vida (0x3b5868, Power 1): uma nuvem vive
## MaxParticleAge e a seguinte MaxParticleAge/PowerRatio, alternando. O alfa
## de cada nuvem nova do mesmo quadro é multiplicado pela força de novo
## (0x3af170 grava alfa x força de volta no registro do tipo): no mesmo quadro
## a 1ª sai com força, a 2ª com força², ... (o jogo é assim).
## Desenho: textura Sprites/WorldFXdust (atlas 2 x 3 de nuvens, tools/fx_jogo.py
## -> assets/fx/poeira.png), quadrado virado pra câmera, centrado no ponto,
## cor = textura x DustColour (PS2: 0x80 = 1.0). Não portado: o canto escuro
## (o vértice 0 sai com a cor x 0.3; a ordem dos cantos não foi achada), a
## luz do lugar (corpo+0xc0) e a água.

const TEXTURA := "res://assets/fx/poeira.png"
const TIPOS := ["Light", "Medium", "Heavy", "Water"]
const COLUNAS := 2                # atlas da WorldFXdust
const LINHAS := 3

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform sampler2D tex : filter_linear_mipmap, repeat_disable;
uniform vec2 grade = vec2(2.0, 3.0);
uniform bool diag = false;        // POEIRA_COR=1: vermelho opaco (onde nasce e o tamanho)

void vertex() {
	// quadrado virado pra câmera, com o tamanho da instância
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s,
		INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	float k = INSTANCE_CUSTOM.x;
	vec2 cel = vec2(mod(k, grade.x), floor(k / grade.x));
	UV = (UV + cel) / grade;
}

void fragment() {
	vec4 t = texture(tex, UV);
	// PS2: textura x cor do vértice (0x80 = 1.0) no espaço de cor da tela
	vec3 c = t.rgb * COLOR.rgb;
	ALBEDO = mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
	ALPHA = t.a * COLOR.a;
	if (diag) {
		ALBEDO = vec3(1.0, 0.0, 0.0);
		ALPHA = 1.0;
	}
}
"""

var car = null
var tipos: Array = []             # um dict por tipo (CamSubject/Rear)
var max_nuvens := 1024            # NumGroups x NumParticlesPerGroup da pista (RX01: 32 x 32)
var por_grupo := 32
var emissores: Array = []         # um por roda de trás
var mm: MultiMesh
var mmi: MultiMeshInstance3D
var rnd := RandomNumberGenerator.new()
# nuvens vivas (arrays paralelos)
var n_pos := PackedVector3Array()
var n_idade := PackedFloat32Array()
var n_vida := PackedFloat32Array()
var n_max := PackedFloat32Array()     # MaxParticleAge do tipo (crescimento)
var n_ini := PackedFloat32Array()
var n_alvo := PackedFloat32Array()
var n_a0 := PackedFloat32Array()
var n_cor := PackedColorArray()
var n_cel := PackedFloat32Array()
var buf := PackedFloat32Array()   # buffer da MultiMesh (20 floats por nuvem)


func montar(c) -> bool:
	car = c
	if c.terrain == null or not FileAccess.file_exists(TEXTURA):
		return false
	tipos = _ler_tipos("res://data/dust.xml", "CamSubject")
	if tipos.is_empty():
		return false
	var cfg := _ler_config("res://data/dust_rx01.xml")
	if not cfg.is_empty():
		max_nuvens = cfg.grupos * cfg.por_grupo
		por_grupo = cfg.por_grupo
	for i in car.wheels.size():
		if not car.wheels[i].front:
			emissores.append({"roda": i, "estado": 0, "ultimo": Vector3.ZERO, "cont": 0,
				"mat": -99, "tipo": -1, "cor": Color(0, 0, 0, 0), "de": Color(0, 0, 0, 0),
				"para": Color(0, 0, 0, 0), "t": 1.0})
	var img := Image.load_from_file(ProjectSettings.globalize_path(TEXTURA))
	if img == null:
		return false
	img.generate_mipmaps()
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("tex", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("grade", Vector2(COLUNAS, LINHAS))
	mat.set_shader_parameter("diag", OS.get_environment("POEIRA_COR") == "1")
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = mat
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = max_nuvens
	mm.visible_instance_count = 0
	mmi = MultiMeshInstance3D.new()
	mmi.name = "Nuvens"
	mmi.multimesh = mm
	mmi.top_level = true
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 16384.0
	add_child(mmi)
	mmi.global_transform = Transform3D.IDENTITY
	return true


## um quadro do jogo (0x225108): v = velocidade do carro (mundo)
func passo(dt: float, v: Vector3) -> void:
	var vel := v.length()
	if vel < 0.5:
		return
	var forca_vel := (vel - 0.5) / 35.0
	var cam: Camera3D = car.get_viewport().get_camera_3d() if car.is_inside_tree() else null
	var lod := 0.0
	var olha := 0.0
	if cam:
		var dc: Vector3 = car.global_position - cam.global_position
		olha = clampf((-cam.global_transform.basis.z).dot(v / vel), 0.0, 1.0)
		lod = dc.length_squared()
	for e in emissores:
		var w: Dictionary = car.wheels[e.roda]
		# material embaixo da roda: o tipo e a cor
		var mat: int = w.mat if w.hit else -1
		if mat != e.mat:
			_troca_material(e, mat)
		e.t = minf(e.t + dt, 1.0)
		e.cor = (e.de as Color).lerp(e.para, e.t)
		var forca := clampf(forca_vel, 0.0, 1.0)
		if e.tipo < 0 or forca <= 0.1 or (e.cor as Color).a <= 0.1 or not w.hit:
			e.estado = 0                  # 0x227968: o grupo acaba
			continue
		var tp: Dictionary = tipos[e.tipo]
		var l := clampf(lod / (tp.lod * tp.lod), 0.0, 1.0)
		var espaco := lerpf(lerpf(tp.espaco, tp.espaco_olha, olha), tp.espaco_lod, l)
		var ini := lerpf(tp.ini, tp.ini_lod, l)
		_emitir(e, w.point, maxf(espaco, 0.01), ini, forca, tp, dt)


## 0x225108: material novo embaixo da roda. Sem material ou DustType None:
## o alfa vai a 0 (o tipo fica o de antes)
func _troca_material(e: Dictionary, mat: int) -> void:
	e.mat = mat
	e.de = e.cor
	e.t = 0.0
	var tipo := -1
	var cor := Color(0, 0, 0, 0)
	if mat >= 0 and mat < car.terrain.materials.size():
		var m: Dictionary = car.terrain.materials[mat]
		tipo = TIPOS.find(String(m.get("DustType", "None")))
		cor = m.get("DustColour", Color(0, 0, 0, 0))
	if tipo < 0:
		e.para = Color((e.cor as Color).r, (e.cor as Color).g, (e.cor as Color).b, 0.0)
		return
	e.tipo = tipo
	if cor.a < 1e-6:
		e.para = Color((e.cor as Color).r, (e.cor as Color).g, (e.cor as Color).b, 0.0)
	else:
		e.para = cor


## 0x227c50: nuvens a cada `espaco` metros do caminho desde a última
func _emitir(e: Dictionary, p: Vector3, espaco: float, ini: float, forca: float, tp: Dictionary, dt: float) -> void:
	var cor: Color = e.cor
	if e.estado == 0:
		e.estado = 2
		e.ultimo = p
		e.cont = 0
		_nuvem(e, p, 0.0, ini, cor.a * forca, cor, tp)
		return
	var d: Vector3 = p - e.ultimo
	var n := int(d.length() / espaco)
	if n < 1:
		return
	var passo_v := d.normalized() * espaco
	var a := cor.a
	for k in n:
		e.ultimo += passo_v
		a *= forca                        # 0x3af170 grava alfa x força no registro
		_nuvem(e, e.ultimo, dt * float(n - 1 - k) / float(n), ini, a, cor, tp)


## 0x3af170: uma nuvem nova
func _nuvem(e: Dictionary, p: Vector3, idade: float, ini: float, alfa: float, cor: Color, tp: Dictionary) -> void:
	if n_pos.size() >= max_nuvens:
		return
	var idx: int = e.cont
	e.cont = (idx + 1) % por_grupo
	n_pos.append(p)
	n_idade.append(idade)
	n_vida.append(tp.vidas[idx % tp.vidas.size()])
	n_max.append(tp.idade_max)
	n_ini.append(ini + rnd.randf_range(-tp.ini_delta, tp.ini_delta))
	n_alvo.append(tp.alvo + rnd.randf_range(-tp.alvo_delta, tp.alvo_delta))
	n_a0.append(clampf(alfa, 0.0, 1.0))
	n_cor.append(cor)
	n_cel.append(float(idx % (COLUNAS * LINHAS)))


## envelhece e desenha (0x3af590)
func _process(delta: float) -> void:
	if mm == null:
		return
	var i := 0
	while i < n_pos.size():
		n_idade[i] += delta
		if n_idade[i] >= n_vida[i]:
			_tira(i)
		else:
			i += 1
	var n := n_pos.size()
	if buf.size() != max_nuvens * 20:
		buf.resize(max_nuvens * 20)
	for k in n:
		var tg := clampf(n_idade[k] / n_max[k], 0.0, 1.0)
		var f := 1.0 - pow(1.0 - tg, 4.0)
		var tam := n_ini[k] * (1.0 - f) + n_alvo[k] * f
		var t := n_idade[k] / n_vida[k]
		var a := n_a0[k] * (1.0 - t * t)
		var p := n_pos[k]
		var o := k * 20
		buf[o] = tam
		buf[o + 5] = tam
		buf[o + 10] = tam
		buf[o + 3] = p.x
		buf[o + 7] = p.y
		buf[o + 11] = p.z
		var c := n_cor[k]
		buf[o + 12] = c.r
		buf[o + 13] = c.g
		buf[o + 14] = c.b
		buf[o + 15] = a
		buf[o + 16] = n_cel[k]
	if n > 0:
		mm.buffer = buf
	mm.visible_instance_count = n


func _tira(i: int) -> void:
	var u := n_pos.size() - 1
	n_pos[i] = n_pos[u]
	n_idade[i] = n_idade[u]
	n_vida[i] = n_vida[u]
	n_max[i] = n_max[u]
	n_ini[i] = n_ini[u]
	n_alvo[i] = n_alvo[u]
	n_a0[i] = n_a0[u]
	n_cor[i] = n_cor[u]
	n_cel[i] = n_cel[u]
	n_pos.resize(u)
	n_idade.resize(u)
	n_vida.resize(u)
	n_max.resize(u)
	n_ini.resize(u)
	n_alvo.resize(u)
	n_a0.resize(u)
	n_cor.resize(u)
	n_cel.resize(u)


## quantas nuvens vivas (testes)
func vivas() -> int:
	return n_pos.size()


## Setup/Dust.xml: Dust/Vehicle/<conjunto>/Rear/<tipo>, na ordem de TIPOS
static func _ler_tipos(arq: String, conjunto: String) -> Array:
	var x := XMLParser.new()
	if x.open(arq) != OK:
		return []
	var dentro := false
	var achados := {}
	while x.read() == OK:
		if x.get_node_type() == XMLParser.NODE_ELEMENT_END and x.get_node_name() == conjunto:
			dentro = false
		if x.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		var nome := x.get_node_name()
		if nome == conjunto:
			dentro = true
		elif dentro and nome in TIPOS:
			var g := func(k: String) -> float: return x.get_named_attribute_value_safe(k).to_float()
			var idade_max: float = g.call("MaxParticleAge")
			var potencia := int(g.call("Power"))
			var razao: float = g.call("PowerRatio")
			achados[nome] = {"lod": g.call("CamMinLodDist"), "espaco": g.call("ParticleSpacing"),
				"espaco_olha": g.call("ParticleSpacingLookAlong"), "espaco_lod": g.call("ParticleSpacingMinLod"),
				"ini": g.call("ParticleInitSize"), "ini_lod": g.call("ParticleInitSizeMinLod"),
				"ini_delta": g.call("ParticleInitSizeDelta"), "alvo": g.call("ParticleTargetSize"),
				"alvo_delta": g.call("ParticleTargetSizeDelta"), "idade_max": idade_max,
				"vidas": _vidas(idade_max, potencia, razao)}
	var out: Array = []
	for t in TIPOS:
		if not achados.has(t):
			return []
		out.append(achados[t])
	return out


## 0x3b5868: vida de cada nuvem pela posição dela no grupo (2^Power valores):
## a 1ª MaxParticleAge, as outras divididas por PowerRatio^nível
static func _vidas(idade_max: float, potencia: int, razao: float) -> PackedFloat32Array:
	var n := 1 << potencia
	var t := PackedFloat32Array()
	t.resize(n)
	var passo := 1
	for nivel in potencia + 1:
		var v := idade_max / pow(razao, float(potencia - nivel))
		for s in range(1, n + 1):
			if s % passo == 0:
				t[n - s] = v
		passo *= 2
	return t


static func _ler_config(arq: String) -> Dictionary:
	var x := XMLParser.new()
	if x.open(arq) != OK:
		return {}
	var em_poeira := false
	while x.read() == OK:
		if x.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		var nome := x.get_node_name()
		if nome == "Dust":
			em_poeira = true
		elif nome == "Dirt":
			em_poeira = false
		elif nome == "Settings" and em_poeira:
			return {"grupos": x.get_named_attribute_value_safe("NumGroups").to_int(),
				"por_grupo": x.get_named_attribute_value_safe("NumParticlesPerGroup").to_int()}
	return {}
