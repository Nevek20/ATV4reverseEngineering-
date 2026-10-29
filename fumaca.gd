extends Node3D
## Fumaça do escapamento (melhoria nossa, car.gd FUMACA). O jogo NÃO solta
## fumaça: o efeito "ExhaustSmokeTrail" existe no Effects/#3ffdac18 (xml 01416)
## e os pontos EXHAUST/EXHAUST2 no _points.bin, mas o exe não lê nenhum dos
## dois (sem as strings cBehaviour*/cRenderer*, tabela de pontos 0x550700 sem
## EXHAUST). Aqui o efeito dos devs vai nos pontos:
##   Life 0.5 s, cor 0.35 cinza com alfa 0.3, 0.2 m, cresce 0.6-0.8 m/s
##   (ExpandFromCentre), ângulo sorteado 0..pi, some nos últimos 30% da vida
##   (FadeOutTime 0.3 x Life), Momentum sem velocidade inicial = rastro parado
##   no mundo, no máximo 60 partículas por cano, textura Sprites/Particles
##   caixa Dust0 (tools/fx_jogo.py -> assets/fx/fumaca.png).
## O que o XML não tem (era do código que não existe) é escolha nossa: a taxa
## (TAXA_LENTA na marcha lenta até 120/s com o motor cheio, pela carga e pelo
## rpm) e uma saída de SAIDA m/s na direção do cano (linha 2 da matriz do
## ponto).

const TEXTURA := "res://assets/fx/fumaca.png"
const VIDA := 0.5
const MAX := 60                     # MaxParticles
const TAMANHO := 0.2
const CRESCE := 0.7                 # média do ExpandRate 0.6..0.8 (m/s)
const COR := Color(0.35, 0.35, 0.35, 0.3)
const SOME := 0.3                   # FadeOutTime x Life
const TAXA_LENTA := 0.15            # fração do máximo (120/s) parado
const SAIDA := 1.0                  # m/s pra fora do cano (nosso)

var canos: Array = []


## monta um emissor por ponto EXHAUST* do carro (frame do corpo): EXHAUST,
## EXHAUST2 e os repetidos dos trucks (EXHAUST~1, car._load_points)
func montar(car) -> bool:
	if not FileAccess.file_exists(TEXTURA) and not ResourceLoader.exists(TEXTURA):
		return false
	var tex := _textura()
	for nome: String in car.points:
		if not nome.begins_with("EXHAUST"):
			continue
		var p: Vector3 = car.corpo(car.points[nome])
		var d: Vector3 = car.points_rot[nome].z * car.ESPELHO   # linha 2 da matriz, jogo -> corpo
		var e := GPUParticles3D.new()
		e.name = nome
		e.amount = MAX
		e.lifetime = VIDA
		e.local_coords = false
		e.interpolate = true
		e.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
		e.process_material = _processo()
		e.draw_pass_1 = _malha(tex)
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(e)
		var up := Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		e.transform = Transform3D(Basis.looking_at(-d, up), p)   # +Z local = saída do cano
		canos.append(e)
	return not canos.is_empty()


## taxa pela carga do motor (car.som_carga) e pelo rpm
func atualizar(carga: float, rpm: float) -> void:
	var r := clampf((rpm - 1000.0) / 7000.0, 0.0, 1.0)
	var t := clampf(TAXA_LENTA + (1.0 - TAXA_LENTA) * carga * (0.4 + 0.6 * r), 0.0, 1.0)
	for e in canos:
		e.amount_ratio = t


func _processo() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 0, 1)
	m.spread = 8.0
	m.initial_velocity_min = SAIDA * 0.8
	m.initial_velocity_max = SAIDA * 1.2
	m.gravity = Vector3.ZERO
	m.angle_min = 0.0
	m.angle_max = 180.0
	m.color = COR
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(1.0 - SOME, Color(1, 1, 1, 1))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt
	# 0.2 m crescendo CRESCE m/s: no fim da vida (0.2 + 0.7·0.5) / 0.2 = 2.75x
	var c := Curve.new()
	c.max_value = 3.0
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, (TAMANHO + CRESCE * VIDA) / TAMANHO))
	var ct := CurveTexture.new()
	ct.curve = c
	m.scale_curve = ct
	return m


func _malha(tex: Texture2D) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(TAMANHO, TAMANHO)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	q.material = mat
	return q


static func _textura() -> Texture2D:
	if ResourceLoader.exists(TEXTURA):
		var t = load(TEXTURA)
		if t:
			return t
	var img := Image.load_from_file(ProjectSettings.globalize_path(TEXTURA))
	return ImageTexture.create_from_image(img) if img else null
