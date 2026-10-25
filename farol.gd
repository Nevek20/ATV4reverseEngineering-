extends Node3D
## Farol aceso (melhoria nossa, car.gd FAROL; H no jogo liga e desliga). O jogo
## tem o halo de farol pronto e não usa: o VehicleHaloMap.xml (data/
## vehicle_halo_map.xml) liga os pontos HEAD_LIGHT* ao halo "ReverseLight" com
## o comportamento Night, que o 0x203930 acende sempre que o carro está ativo,
## mas nenhum carro do jogo tem ponto HEAD_LIGHT (nem FRONT_HALO/REAR_HALO).
## Aqui as lâmpadas saem das faces com textura de farol do modelo (LAMPADAS)
## viradas pra frente: Hurricane (2) e Storm (2 faróis + 4 milhas no
## para-choque). No Mosquito a light_64 é a lanterna de trás; os outros não
## têm farol no modelo.
##
## O halo é o do jogo (data/vehicle_halos.xml, nível HIGH): textura
## lightglow2alpha (tools/fx_jogo.py -> assets/fx/halo.png, o desenho é o alfa)
## com as caixas GLOW e SPIKE do .bed, uma camada por Layer (Width, Height,
## Angle em rad no plano da tela, Colour x A), somando a cor, virado pra
## câmera. Tamanho = Width/Height x ESCALA: 0.3, medido nos prints dos save
## states (halo de freio do Renegade e do Storm: miolo ~6 px com as lanternas
## 82 px uma da outra, raio vertical ~0.75 m). Acende subindo 4/s até 1 e
## apaga na hora (0x2260a0). Não portados (o desenho é no VU1): AngleScale,
## SizeScale e o ZedBias (aqui PUXA pra frente). Nossos: só de frente (o halo
## some virando de lado) e a borda de cada camada indo a 0 (BORDA no shader).

const LAMPADAS := ["light_64", "headlight"]  # nome da textura (minúsculo) das lentes
const PONTO := "HEAD_LIGHT"                 # ponto do VehicleHaloMap que o farol imita
const NIVEL := "HIGH"                       # LOWEST/LOW/MID/HIGH; os prints têm os raios de 0.4 rad do HIGH
const MAPA := "res://data/vehicle_halo_map.xml"
const HALOS := "res://data/vehicle_halos.xml"
const TEXTURA := "res://assets/fx/halo.png"
const CAIXAS := "res://assets/fx/halo.json"
const ESCALA := 0.3          # m por unidade de Width/Height (medido nos prints)
const SOBE := 4.0            # /s: 0x2260a0, +dt x 4 até 1; desligando zera
const FRENTE_MIN := 0.5      # lente conta como farol com a normal média nesse cone pra frente
const JUNTA := 0.002         # m: vértices mais perto que isso ligam as faces (mesma lâmpada)
const PUXA := 0.04           # m: halo puxado pra câmera (não some dentro da lâmpada)

static var ligado := true    # H no jogo (main.gd); vale pra todos os carros

const SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform, fog_disabled;
uniform sampler2D tex : filter_linear, repeat_disable;
uniform vec4 caixa = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 tam = vec2(0.39);
uniform float angulo = 0.0;
uniform vec4 cor = vec4(1.0);
uniform float aceso = 0.0;
uniform vec3 frente = vec3(0.0, 0.0, 1.0);
uniform float puxa = 0.04;
const float BORDA = 0.12;
varying float ver;
varying vec2 q;

void vertex() {
	vec3 c = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 f = normalize((MODELVIEW_MATRIX * vec4(frente, 0.0)).xyz);
	vec3 cam = normalize(-c);
	ver = smoothstep(0.0, 0.3, dot(f, cam));
	vec2 v = VERTEX.xy * tam;
	float s = sin(angulo);
	float k = cos(angulo);
	VERTEX = c + vec3(k * v.x - s * v.y, s * v.x + k * v.y, 0.0) + cam * puxa;
	q = UV;
	UV = mix(caixa.xy, caixa.zw, UV);
}

void fragment() {
	// a textura não chega a 0 na borda da caixa (até 12/255 no GLOW, 40 na ponta
	// do SPIKE): somando várias lâmpadas aparecia o quadrado. Zera na borda (nosso)
	float borda = smoothstep(0.0, BORDA, min(min(q.x, 1.0 - q.x), min(q.y, 1.0 - q.y)));
	ALBEDO = cor.rgb * cor.a * texture(tex, UV).a * borda * aceso * ver;
}
"""

var car = null
var lampadas := []           # [{c, n, tam}] no frame do jogo
var aceso := 0.0
var aviso := ""
var _mats := []


## acha as lâmpadas na carroceria e monta os halos. false = carro sem farol
func montar(c) -> bool:
	car = c
	var mi: MeshInstance3D = car.body_mi
	if mi == null or not (mi.mesh is ArrayMesh):
		return false
	lampadas = achar_lampadas(mi)
	if lampadas.is_empty():
		return false
	var tex := _textura()
	var caixas = _caixas()
	var camadas := camadas_do_halo(PONTO)
	if tex == null or caixas == null or camadas.is_empty():
		aviso = "sem assets/fx/halo.png: rode o fx_jogo"
		return false
	var sh := Shader.new()
	sh.code = SHADER
	for l in lampadas:
		for cam in camadas:
			if not caixas.has(cam.caixa):
				continue
			var b: Array = caixas[cam.caixa]
			var mat := ShaderMaterial.new()
			mat.shader = sh
			mat.set_shader_parameter("tex", tex)
			mat.set_shader_parameter("caixa", Vector4(b[0], b[1], b[2], b[3]))
			mat.set_shader_parameter("tam", Vector2(cam.w, cam.h) * ESCALA)
			mat.set_shader_parameter("angulo", cam.angulo)
			mat.set_shader_parameter("cor", Vector4(cam.cor.r, cam.cor.g, cam.cor.b, cam.cor.a))
			mat.set_shader_parameter("frente", l.n)
			mat.set_shader_parameter("puxa", PUXA)
			var q := QuadMesh.new()
			q.material = mat
			var h := MeshInstance3D.new()
			h.name = "Farol"
			h.mesh = q
			h.position = l.c
			h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			h.extra_cull_margin = 1.0
			mi.add_child(h, true)
			_mats.append(mat)
	return not _mats.is_empty()


## liga: sobe SOBE/s até 1; desliga: apaga na hora (0x2260a0)
func atualizar(delta: float) -> void:
	var liga := ligado
	if OS.has_environment("FAROL"):              # print_tela: 1 aceso, 0 apagado
		liga = OS.get_environment("FAROL") == "1"
	aceso = minf(aceso + delta * SOBE, 1.0) if liga else 0.0
	for m in _mats:
		m.set_shader_parameter("aceso", aceso)


## faces com textura de farol, agrupadas pelas que se tocam (cada grupo é uma
## lâmpada); fica o grupo virado pra frente. Centro e normal pela área.
static func achar_lampadas(mi: MeshInstance3D) -> Array:
	var tris := []                 # [v0, v1, v2, normal da face]
	var mesh: ArrayMesh = mi.mesh
	for s in mesh.get_surface_count():
		var m := mi.get_active_material(s) as StandardMaterial3D
		if m == null or m.albedo_texture == null or m.albedo_color.a <= 0.0:
			continue
		var nome := m.albedo_texture.resource_path.get_file().to_lower()
		if not LAMPADAS.any(func(x): return nome.contains(x)):
			continue
		var a := mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var nrs = a[Mesh.ARRAY_NORMAL]
		var ix := PackedInt32Array(range(vs.size()))
		if a[Mesh.ARRAY_INDEX] != null:
			ix = a[Mesh.ARRAY_INDEX]
		for t in range(0, ix.size(), 3):
			var v0 := vs[ix[t]]
			var v1 := vs[ix[t + 1]]
			var v2 := vs[ix[t + 2]]
			# área pela face, lado pela normal do jogo (a ordem dos vértices não diz)
			var n := (v1 - v0).cross(v2 - v0)
			if nrs != null and n.dot(nrs[ix[t]] + nrs[ix[t + 1]] + nrs[ix[t + 2]]) < 0.0:
				n = -n
			tris.append([v0, v1, v2, n])
	# grupos: faces que dividem um vértice (a menos de JUNTA)
	var grupo := range(tris.size())
	var donos := {}
	for i in tris.size():
		for k in 3:
			var chave: Vector3i = Vector3i((tris[i][k] / JUNTA).round())
			if donos.has(chave):
				_une(grupo, i, donos[chave])
			else:
				donos[chave] = i
	var soma := {}
	for i in tris.size():
		var g: int = _raiz(grupo, i)
		var t: Array = tris[i]
		var area: float = t[3].length() * 0.5
		if not soma.has(g):
			soma[g] = {"c": Vector3.ZERO, "n": Vector3.ZERO, "a": 0.0, "lo": Vector3.INF, "hi": -Vector3.INF}
		var s: Dictionary = soma[g]
		s.c += (t[0] + t[1] + t[2]) / 3.0 * area
		s.n += t[3]
		s.a += area
		for k in 3:
			s.lo = s.lo.min(t[k])
			s.hi = s.hi.max(t[k])
	var out := []
	for g in soma:
		var s: Dictionary = soma[g]
		if s.a <= 0.0 or s.n.length() <= 0.0:
			continue
		var n: Vector3 = s.n.normalized()
		if OS.has_environment("FAROL_DIAG"):
			print("  lente %s n %s área %.4f" % [s.c / s.a, n, s.a])
		if n.z < FRENTE_MIN:
			continue
		out.append({"c": s.c / s.a + n * 0.01, "n": n, "tam": (s.hi - s.lo).length()})
	out.sort_custom(func(x, y): return x.c.x < y.c.x)
	return out


static func _raiz(g: Array, i: int) -> int:
	while g[i] != i:
		g[i] = g[g[i]]
		i = g[i]
	return i


static func _une(g: Array, a: int, b: int) -> void:
	g[_raiz(g, a)] = _raiz(g, b)


## camadas do halo do ponto (VehicleHaloMap -> HaloName -> VehicleHalos, NIVEL):
## [{caixa, w, h, angulo, cor}]
static func camadas_do_halo(ponto: String) -> Array:
	var nome := ""
	var x := XMLParser.new()
	if x.open(MAPA) != OK:
		return []
	while x.read() == OK:
		if x.get_node_type() == XMLParser.NODE_ELEMENT and x.get_node_name() == ponto:
			nome = x.get_named_attribute_value_safe("HaloName")
			break
	if nome == "" or x.open(HALOS) != OK:
		return []
	var out := []
	var dentro := 0                # 1 no halo, 2 no nível certo
	while x.read() == OK:
		var t := x.get_node_type()
		if t == XMLParser.NODE_ELEMENT:
			var n := x.get_node_name()
			if dentro == 0 and n == nome:
				dentro = 1
			elif dentro == 1 and n == NIVEL:
				dentro = 2
			elif dentro == 2 and n == "Layer":
				out.append({"caixa": x.get_named_attribute_value_safe("TextureBox"),
					"w": x.get_named_attribute_value_safe("Width").to_float(),
					"h": x.get_named_attribute_value_safe("Height").to_float(),
					"angulo": x.get_named_attribute_value_safe("Angle").to_float(),
					"cor": Color.WHITE})
			elif dentro == 2 and n == "Colour" and not out.is_empty():
				out[-1].cor = Color(x.get_named_attribute_value_safe("R").to_float(),
					x.get_named_attribute_value_safe("G").to_float(),
					x.get_named_attribute_value_safe("B").to_float(),
					x.get_named_attribute_value_safe("A").to_float())
		elif t == XMLParser.NODE_ELEMENT_END:
			var n := x.get_node_name()
			if dentro == 2 and n == NIVEL:
				break
	return out


static func _textura() -> Texture2D:
	if ResourceLoader.exists(TEXTURA):
		var t = load(TEXTURA)
		if t:
			return t
	if not FileAccess.file_exists(TEXTURA):
		return null
	var img := Image.load_from_file(ProjectSettings.globalize_path(TEXTURA))
	return ImageTexture.create_from_image(img) if img else null


static func _caixas():
	if not FileAccess.file_exists(CAIXAS):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(CAIXAS))
