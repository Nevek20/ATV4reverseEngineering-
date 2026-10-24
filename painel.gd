extends Node3D
## Painel funcional (melhoria nossa; car.gd PAINEL). No jogo os relógios são
## textura parada (ponteiro pintado) e a maioria dos buggies não tem painel.
##
## Amador (vehicles.xml Level="Amateur": Mosquito, Inferno, Trident, Sphinx):
## conta-giros e velocímetro de ponteiro, mostrador branco. PRO (Level="Pro"):
## conta-giros, velocímetro, marcha digital e luz de troca, mostrador preto.
##
## Onde o modelo já tem relógio, o nosso vai por cima (DO_MODELO, medido no
## .obj): Renegade (placa cadilac_clock_index), Sphinx (chapa b_2 com relógios
## pintados, achados pelo UV) e Inferno (buracos pretos com aro). O que falta
## vai num conjunto preso na coluna da direção, atrás do volante, na linha
## entre o olho (câmera do piloto) e a metade de cima do aro.
##
## Valores: rpm do motor (car.rpm), velocímetro como o do jogo (1.06 x a
## velocidade pra frente, tests/teste_entrada.gd), marcha do car.gear_label().
## Escalas: conta-giros até o limitador + 1000 (vermelho do limitador),
## velocímetro até a velocidade no limitador na última marcha.
##
## Tudo no frame do modelo do jogo (filho do model_root, como a carroceria).

# mostradores do modelo: tipo -> [centro, normal (pro piloto), diâmetro]
const DO_MODELO := {
	"BUGGY_10": {"rpm": [Vector3(-0.437, 1.334, 0.674), Vector3(0.0, 0.62, -0.78), 0.115]},
	# os 2 grandes do meio da chapa (o da frente do piloto fica atrás do X do volante)
	"BUGGY_04": {"rpm": [Vector3(-0.098, 1.286, 0.591), Vector3(0.0, 0.65, -0.76), 0.10],
		"vel": [Vector3(0.095, 1.285, 0.592), Vector3(0.01, 0.65, -0.76), 0.10]},
	# o grande do meio e o pequeno à direita dele (o da esquerda fica atrás da mão)
	"BUGGY_02": {"rpm": [Vector3(0.01, 1.377, 0.606), Vector3(0.0, 0.34, -0.94), 0.15],
		"vel": [Vector3(0.154, 1.331, 0.589), Vector3(0.0, 0.34, -0.94), 0.07]},
}
const NA_FRENTE := 0.004      # nosso mostrador acima do do modelo (m)
const DIST := 0.13            # conjunto: além do aro, na linha do olho (m)
const ALTURA_ARO := 0.5       # ponto do aro que o olho mira (x raio, pra cima)
const MARGEM := 4.0           # graus acima da borda de baixo da câmera do piloto
const D_RPM_PRO := 0.095      # diâmetros (m)
const D_VEL_PRO := 0.075
const D_AMADOR := 0.08
const PONTEIRO_T := 0.05      # inércia do ponteiro (s)
const LEDS := 5
const LED_INICIO := 0.85      # 1º LED a 85% do rpm de troca, último na troca

var car
var pro := false
var mostradores := []         # [desenho 2D, tipo]
var marcha_lcd = null
var leds: Array[StandardMaterial3D] = []
var rpm_max := 9.0
var vel_max := 200.0
var t := 0.0
var fixo := Vector2(-1, -1)   # prints: PAINEL="rpm,km/h" fixa os ponteiros


func montar(c) -> bool:
	car = c
	pro = _nivel(car.vehicle_id) == "Pro"
	if OS.has_environment("PAINEL"):
		var f := OS.get_environment("PAINEL").split(",")
		fixo = Vector2(float(f[0]), float(f[1]) if f.size() > 1 else 0.0)
	var lim: float = car.P.get("lim_on", 8000.0)
	rpm_max = ceilf(lim / 1000.0) + 1.0
	var top: float = 0.0
	if car.gears.size() > 1:
		top = lim * car.P.wheel_r * car.RPM2RAD / (car.gears[car.gears.size() - 1] * car.P.final) * 3.6 * 1.06
	vel_max = maxf(ceilf(top / 20.0) * 20.0, 100.0)
	var tem: Dictionary = DO_MODELO.get(car.vehicle_id, {})
	var tipos := ["rpm", "vel"] + (["marcha", "luz"] if pro else [])
	var falta := tipos.filter(func(k): return not tem.has(k))
	for k in tem:
		if k in tipos:
			var m: Array = tem[k]
			_instrumento(k, m[0] + m[1].normalized() * NA_FRENTE, m[1], m[2], false)
	if falta.is_empty():
		return true
	# conjunto atrás do volante: âncora = onde vai o conta-giros
	var vol: Dictionary = car.pecas.get("volante", {})
	if not vol.has("centro"):
		return not tem.is_empty()
	var ce: Vector3 = car.sw_centro()
	var eixo: Vector3 = car.SW_AXIS.normalized()
	var raio: float = vol.get("raio", 0.19)
	var olho := ce + Vector3(0.0, car.FP_UP, -car.FP_BACK)
	var cima := (Vector3.UP - eixo * Vector3.UP.dot(eixo)).normalized()
	var d_rpm := D_RPM_PRO if pro else D_AMADOR
	var d_vel := D_VEL_PRO if pro else D_AMADOR
	# sobe a mira pelo aro até o conjunto caber na câmera do piloto (no
	# McKenzies o volante fica no pé da tela e o conjunto sumia)
	var olhar := Vector3(0.0, -car.FP_PITCH, 1.0).normalized()
	var cima_cam := Vector3(0.0, 1.0, car.FP_PITCH).normalized()
	var ancora := Vector3.ZERO
	var n := Vector3.BACK
	var alt := ALTURA_ARO
	while alt <= 1.6:
		var mira := ce + cima * raio * alt
		var dir := (mira - olho).normalized()
		ancora = mira + dir * DIST
		n = -dir
		var baixo := ancora - _base(n).y * (d_rpm * 0.5 + 0.012) - olho
		if rad_to_deg(atan2(baixo.dot(cima_cam), baixo.dot(olhar))) >= -car.FP_FOV * 0.5 + MARGEM:
			break
		alt += 0.05
	if tem.has("rpm"):
		# o conta-giros é o do modelo: o resto vai do lado dele
		ancora = tem.rpm[0] + tem.rpm[1].normalized() * NA_FRENTE
		n = tem.rpm[1].normalized()
	var b := _base(n)
	var gap := 0.008
	var lugar := {}
	if pro:
		lugar.rpm = ancora
		lugar.vel = ancora + b.x * (d_rpm * 0.5 + gap + d_vel * 0.5) - b.y * (d_rpm - d_vel) * 0.5
		lugar.marcha = ancora - b.x * (d_rpm * 0.5 + gap + 0.03) - b.y * (d_rpm * 0.5 - 0.02)
		lugar.luz = ancora + b.y * (d_rpm * 0.5 + 0.012)
	else:
		lugar.rpm = ancora - b.x * (d_rpm * 0.5 + gap * 0.5)
		lugar.vel = ancora + b.x * (d_vel * 0.5 + gap * 0.5)
	for k in falta:
		var d: float = {"rpm": d_rpm, "vel": d_vel, "marcha": 0.05, "luz": 0.0}[k]
		_instrumento(k, lugar[k], n, d, not tem.has("rpm"))
	if not tem.has("rpm"):
		_suporte(ancora, b, ce - eixo * 0.06)
	return true


func atualizar(delta: float) -> void:
	t += delta
	var k := 1.0 - exp(-delta / PONTEIRO_T)
	var v_f: float = car.linear_velocity.dot(car.global_transform.basis.z) * 3.6 * 1.06
	var rpm: float = car.rpm if fixo.x < 0.0 else fixo.x
	if fixo.x >= 0.0:
		v_f = fixo.y
		k = 1.0
	for m in mostradores:
		var alvo: float = rpm / 1000.0 if m.tipo == "rpm" else absf(v_f)
		var novo: float = m.valor + (alvo - m.valor) * k
		if absf(novo - m.valor) > 0.0005 * m.maximo:
			m.valor = novo
			m.queue_redraw()
	if marcha_lcd:
		var g: String = car.gear_label()
		if g != marcha_lcd.texto:
			marcha_lcd.texto = g
			marcha_lcd.queue_redraw()
	if not leds.is_empty():
		var troca: float = car.P.get("up_rpm", 7000.0)
		var no_limite: bool = rpm >= car.P.get("lim_on", 8000.0) - 50.0
		var pisca := fmod(t, 0.12) < 0.06
		for i in leds.size():
			var acende: float = troca * (LED_INICIO + (1.0 - LED_INICIO) * i / (leds.size() - 1))
			var on: bool = (rpm >= acende) and (not no_limite or pisca)
			leds[i].emission_energy_multiplier = 2.5 if on else 0.0


# ------------------------------------------------------------------ montagem
## x = direita do jogo (direita de quem olha), y = cima, z = pro olho. Dentro
## do espelho isso dá determinante -1, que o espelho desfaz: o texto sai certo.
static func _base(n: Vector3) -> Basis:
	var z := n.normalized()
	var x := -Vector3.UP.cross(z).normalized()
	var y := (Vector3.UP - z * Vector3.UP.dot(z)).normalized()
	return Basis(x, y, z)


func _instrumento(tipo: String, p: Vector3, n: Vector3, d: float, caixa: bool) -> void:
	var no := Node3D.new()
	no.name = "Painel_" + tipo
	no.transform = Transform3D(_base(n), p)
	add_child(no)
	if tipo == "luz":
		_leds(no)
		return
	var tela: Node2D
	var tam := Vector2(d, d)
	if tipo == "marcha":
		tela = Lcd.new()
		tam = Vector2(0.05, 0.036)
		marcha_lcd = tela
	else:
		var m := Mostrador.new()
		m.tipo = tipo
		m.maximo = rpm_max if tipo == "rpm" else vel_max
		m.vermelho = car.P.get("lim_on", 8000.0) / 1000.0 if tipo == "rpm" else -1.0
		m.preto = pro
		tela = m
		mostradores.append(m)
	var vp := SubViewport.new()
	vp.size = Vector2i(256, int(256 * tam.y / tam.x))
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(tela)
	no.add_child(vp)
	var q := QuadMesh.new()
	q.size = tam
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = vp.get_texture()
	mat.emission_enabled = true
	mat.emission_texture = vp.get_texture()
	mat.emission_energy_multiplier = 0.35 if tipo != "marcha" else 1.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.35
	var face := MeshInstance3D.new()
	face.mesh = q
	face.material_override = mat
	no.add_child(face)
	if tipo != "marcha":
		# aro (cromado no amador, preto no PRO)
		var aro := MeshInstance3D.new()
		var to := TorusMesh.new()
		to.inner_radius = d * 0.5 - 0.001
		to.outer_radius = d * 0.5 + 0.006
		aro.mesh = to
		aro.rotation.x = PI * 0.5
		aro.material_override = _metal(pro)
		no.add_child(aro)
	if caixa:
		var cx := MeshInstance3D.new()
		if tipo == "marcha":
			var bx := BoxMesh.new()
			bx.size = Vector3(tam.x + 0.01, tam.y + 0.01, 0.03)
			cx.mesh = bx
		else:
			var cy := CylinderMesh.new()
			cy.top_radius = d * 0.5 + 0.004
			cy.bottom_radius = d * 0.5 + 0.002
			cy.height = 0.045
			cx.mesh = cy
			cx.rotation.x = PI * 0.5
		cx.position = Vector3(0, 0, -0.024)
		cx.material_override = _preto()
		no.add_child(cx)


func _leds(no: Node3D) -> void:
	const CORES := [Color(0.1, 1, 0.2), Color(0.1, 1, 0.2), Color(1, 0.85, 0.1), Color(1, 0.15, 0.1), Color(1, 0.15, 0.1)]
	var passo := 0.016
	var barra := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(passo * LEDS + 0.006, 0.014, 0.012)
	barra.mesh = bx
	barra.position = Vector3(0, 0, -0.006)
	barra.material_override = _preto()
	no.add_child(barra)
	for i in LEDS:
		var led := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.0045
		s.height = 0.009
		led.mesh = s
		led.position = Vector3((i - (LEDS - 1) * 0.5) * passo, 0, 0.001)
		var m := StandardMaterial3D.new()
		var c: Color = CORES[i * CORES.size() / LEDS]
		m.albedo_color = c.darkened(0.7)
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.0
		led.material_override = m
		leds.append(m)
		no.add_child(led)


## suporte do conjunto: uma haste da caixa até a coluna da direção
func _suporte(ancora: Vector3, b: Basis, coluna: Vector3) -> void:
	var de := ancora - b.z * 0.04 - b.y * 0.03
	var v := coluna - de
	if v.length() < 0.02:
		return
	var h := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.008
	cy.bottom_radius = 0.008
	cy.height = v.length()
	h.mesh = cy
	var y := v.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	h.transform = Transform3D(Basis(x, y, x.cross(y)), de + v * 0.5)
	h.material_override = _preto()
	add_child(h)


static func _metal(escuro: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.08, 0.09) if escuro else Color(0.85, 0.86, 0.88)
	m.metallic = 0.6 if escuro else 1.0
	m.roughness = 0.35 if escuro else 0.18
	return m


static func _preto() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.04, 0.04, 0.045)
	m.roughness = 0.6
	return m


## Level do vehicles.xml (Amateur / Pro)
static func _nivel(id: String) -> String:
	var txt := FileAccess.get_file_as_string("res://data/vehicles.xml")
	var i := txt.find('<Vehicle Name="%s"' % id)
	if i < 0:
		return ""
	var j := txt.find('Level="', i)
	if j < 0 or j > txt.find(">", i):
		return ""
	j += 7
	return txt.substr(j, txt.find('"', j) - j)


# ------------------------------------------------------------------ 2D
## mostrador de ponteiro (256 x 256): 0 embaixo à esquerda, 270° no sentido
## do relógio até o máximo embaixo à direita
class Mostrador extends Node2D:
	var tipo := "rpm"
	var maximo := 9.0
	var vermelho := -1.0
	var preto := false
	var valor := 0.0

	func _ang(v: float) -> float:
		return deg_to_rad(135.0 + 270.0 * clampf(v / maximo, 0.0, 1.04))

	func _draw() -> void:
		var c := Vector2(128, 128)
		var r := 124.0
		var fundo := Color(0.06, 0.06, 0.07) if preto else Color(0.95, 0.95, 0.93)
		var tinta := Color(0.95, 0.95, 0.95) if preto else Color(0.08, 0.08, 0.08)
		var fonte := ThemeDB.fallback_font
		draw_circle(c, r, fundo)
		if vermelho > 0.0:
			draw_arc(c, r - 14, _ang(vermelho), _ang(maximo), 32, Color(0.85, 0.08, 0.05), 12.0)
		var passo := 1.0 if tipo == "rpm" else (20.0 if maximo <= 200.0 else 40.0)
		var n := int(round(maximo / passo))
		for i in n * 2 + 1:
			var v := i * passo * 0.5
			var a := _ang(v)
			var dirv := Vector2(cos(a), sin(a))
			var grande := i % 2 == 0
			draw_line(c + dirv * (r - (22 if grande else 14)), c + dirv * (r - 4), tinta, 4.0 if grande else 2.0)
			if grande:
				var txt := str(int(v))
				var p := c + dirv * (r - 42)
				draw_string(fonte, p + Vector2(-24, 9), txt, HORIZONTAL_ALIGNMENT_CENTER, 48, 24, tinta)
		draw_string(fonte, c + Vector2(-60, 52), "x1000 RPM" if tipo == "rpm" else "km/h",
			HORIZONTAL_ALIGNMENT_CENTER, 120, 18, tinta)
		var a := _ang(valor)
		var d := Vector2(cos(a), sin(a))
		var lado := Vector2(-d.y, d.x)
		var ponta := Color(1.0, 0.35, 0.05) if preto else Color(0.85, 0.05, 0.05)
		draw_colored_polygon(PackedVector2Array([c + d * (r - 16), c + lado * 5 - d * 18, c - lado * 5 - d * 18]), ponta)
		draw_circle(c, 12, Color(0.12, 0.12, 0.12))


## marcha digital (LCD âmbar)
class Lcd extends Node2D:
	var texto := "N"

	func _draw() -> void:
		var s := get_viewport_rect().size
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.03, 0.02))
		draw_rect(Rect2(Vector2(6, 6), s - Vector2(12, 12)), Color(0.12, 0.09, 0.02))
		draw_string(ThemeDB.fallback_font, Vector2(0, s.y * 0.78), texto, HORIZONTAL_ALIGNMENT_CENTER,
			s.x, int(s.y * 0.8), Color(1.0, 0.62, 0.08))
