extends RefCounted
## Tremida da câmera do jogo (componente com vtable 0x5b4fb8: update 0x380418,
## aplica 0x380170). Roda no passo de 1/60 da câmera, depois da mira.
##
## Parâmetros: só os do bloco GenericCameraData do cameras.xml, pelo tipo da
## câmera (FollowOrbitNear, MountOnHood...). Os Jitter* dos CameraSet são
## ignorados pelo jogo (conferido na RAM: os componentes vivos têm os valores
## genéricos). Construtor 0x380348 / 0x380090, loader 0x38cc48.
##
## Por velocidade (0x380418):
##   f = clamp((v - JitterSpeedStart) / (JitterSpeedMax - JitterSpeedStart)),
##   v = |velocidade| (corpo+0xe0), Start/Max em mph;
##   a = veículo+0xac0 * f², e veículo+0xac0 = média do WheelJitter do chão
##   embaixo das rodas FL, RL, FR (0x202760, car.gd jitter_chao): no asfalto
##   é 0 e a câmera não treme.
## Ruído (0x380170): duas ondas de Perlin 1D, (Amp/4, Freq) e (Amp, Freq*1.05),
##   fase inicial sorteada. Cada passo: n = tabela(fase) * amp_onda * a e
##   fase += dt * freq (mod 1). Tabela de 256 (+1) valores gerada pelo jogo
##   (RAM 0xd0e7f0, igual em todos os save states): data/ruido_camera.bin.
##   A direção da câmera vira dir + direita * n1 + cima * n2.
##
## Batida (não portada, falta o sistema de colisão): a última colisão do
##   corpo (corpo+0x7a0 + idx*0x40, idx em corpo+0x860) dá c = rampa da
##   velocidade (CollisionSpeedFor*Jitter) x rampa da massa do outro
##   (CollisionMassFor*Jitter) x CollisionJitterMagMax; amp = max(c, amp) *
##   CollisionJitterDecayFraction por passo, e soma um sorteio uniforme em
##   [-amp, amp) nas duas componentes (gerador x*31415821+1 mod 2^30).

const MPH_MS := 0.44694445         # mph -> m/s, constante do exe
const TABELA := "res://data/ruido_camera.bin"
# defaults do construtor quando o XML não traz (RAM: componentes sem dado)
const PADRAO := {"JitterSpeedStart": 0.0, "JitterSpeedMax": 1.0, "JitterPerlinAmp": 0.0,
	"JitterPerlinFreq": 0.0}

static var _tab := PackedFloat32Array()

var p := {}
var ondas := []                   # [amp, freq, fase] x 2
var n := Vector2.ZERO             # última tremida (direita, cima)


static func carregar(path: String, tipo: String):
	var j = new()
	j.p = PADRAO.duplicate()
	var x := XMLParser.new()
	if x.open(path) == OK:
		var no_generico := false
		while x.read() == OK:
			var t := x.get_node_type()
			if t == XMLParser.NODE_ELEMENT:
				var nome := x.get_node_name()
				if nome == "GenericCameraData":
					no_generico = true
				elif no_generico and nome == tipo:
					for k in PADRAO:
						if x.has_attribute(k):
							j.p[k] = x.get_named_attribute_value(k).to_float()
			elif t == XMLParser.NODE_ELEMENT_END and x.get_node_name() == "GenericCameraData":
				break
	var amp: float = j.p.JitterPerlinAmp
	var freq: float = j.p.JitterPerlinFreq
	j.ondas = [[amp * 0.25, freq, randf()], [amp, freq * 1.05, randf()]]
	if _tab.is_empty():
		_tab = FileAccess.get_file_as_bytes(TABELA).to_float32_array()
	return j


## 0x3aa6e0: tabela interpolada na fase (0..1)
static func ruido(fase: float) -> float:
	var x := fase * 256.0
	var i := int(x)
	var fr := x - i
	return _tab[i] * (1.0 - fr) + _tab[i + 1] * fr


## um passo da câmera (1/60 s). vel = |velocidade| (m/s), chao = média do
## WheelJitter embaixo das rodas (car.gd jitter_chao)
func passo(dt: float, vel: float, chao: float) -> Vector2:
	var s0: float = p.JitterSpeedStart * MPH_MS
	var s1: float = p.JitterSpeedMax * MPH_MS
	var f := clampf((vel - s0) / (s1 - s0), 0.0, 1.0) if s1 != s0 else 0.0
	var a := chao * f * f
	var out := Vector2.ZERO
	for k in 2:
		var o: Array = ondas[k]
		out[k] = ruido(o[2]) * o[0] * a
		o[2] = fmod(o[2] + dt * o[1], 1.0)
	n = out
	return out


## dir (normalizada) + direita * n.x + cima * n.y, com a direita e o cima da
## câmera (Godot: direita = dir x UP)
static func aplicar(dir: Vector3, t: Vector2) -> Vector3:
	if t == Vector2.ZERO:
		return dir
	var direita := dir.cross(Vector3.UP)
	if direita.length() < 1e-5:
		return dir
	direita = direita.normalized()
	var cima := direita.cross(dir)
	return (dir + direita * t.x + cima * t.y).normalized()
