extends Node3D
## Cena principal do protótipo: monta mundo, chão, carro, câmera e HUD
## tudo por código, pra ficar fácil de ler e mexer.

const CAR_MODEL := "res://assets/renegade/21711_bloco.obj"
const SPAWN_XZ := Vector2(400.0, 340.0)   # em cima da reta de cima da pista

const Car := preload("res://car.gd")
const Terrain := preload("res://terrain.gd")

var car  # instância de car.gd (sem tipo estático de propósito: métodos próprios do script)
var cam: Camera3D
var hud: Label
var cam_mode := 0                        # 0 = atrás, 1 = longe, 2 = capô, 3 = piloto
var terrain


func _ready() -> void:
	_make_environment()
	terrain = Terrain.new()
	add_child(terrain)

	car = Car.new()
	car.model_path = CAR_MODEL
	add_child(car)
	car.reset_to(spawn_point(), deg_to_rad(90.0))

	cam = Camera3D.new()
	cam.far = 4000.0
	cam.near = 0.1
	cam.fov = 70.0
	add_child(cam)
	cam.current = true
	cam.global_position = spawn_point() + Vector3(-8, 4, 0)

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(16, 12)
	hud.add_theme_font_size_override("font_size", 18)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 6)
	layer.add_child(hud)


func _make_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.52, 0.74)
	sky_mat.sky_horizon_color = Color(0.78, 0.74, 0.66)
	sky_mat.ground_horizon_color = Color(0.62, 0.55, 0.45)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.68, 0.6)
	env.fog_density = 0.0012
	env.fog_sky_affect = 0.15   # sem isso a névoa pinta o céu inteiro de bege

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)   # mesma ideia do XML: sol vindo de +X, de cima
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	add_child(sun)


func spawn_point() -> Vector3:
	return Vector3(SPAWN_XZ.x, terrain.height_at(SPAWN_XZ.x, SPAWN_XZ.y) + 1.5, SPAWN_XZ.y)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_C:
				cam_mode = (cam_mode + 1) % 4
			KEY_R:
				var p: Vector3 = car.global_position
				car.reset_to(Vector3(p.x, terrain.height_at(p.x, p.z) + 1.5, p.z), car.global_rotation.y)
			KEY_T:
				car.reset_to(spawn_point(), deg_to_rad(90.0))
			KEY_F:
				car.flip_model()
			KEY_ESCAPE:
				get_tree().quit()


func _process(delta: float) -> void:
	if car == null:
		return
	_update_camera(delta)
	var kmh: float = car.linear_velocity.length() * 3.6
	hud.text = "%d km/h   %d mph\nmarcha %s   %d rpm   câmbio %s\nfísica: %s (%s)\n\nW/S ou setas: acelerar/frear (parado, segurar S = ré)   A/D: virar   Espaço: powerslide (freio de mão)\nP: pneus portados/antigos   L: lateral jogo/remendo   M: câmbio auto/manual   E/Q: sobe/desce marcha   R: desvirar   T: voltar pro início\nC: câmera (atrás/longe/capô/piloto)   F: girar o modelo   Esc: sair" % [
		int(kmh), int(kmh / 1.609), car.gear_label(), int(car.rpm), "MANUAL" if car.manual else "AUTO", car.vehicle_name, ("pneus portados do jogo" if car.use_ported else "pneus antigos") + (", lateral do jogo" if car.lateral_game else ", lateral remendo")]


var cam_dir := Vector3.FORWARD
var cam_h := 0.0          # altura suavizada da câmera
var cam_side := 0.0       # deslocamento lateral suavizado (balanço na curva)
var cam_ready := false


func _update_camera(delta: float) -> void:
	var cpos: Vector3 = car.global_position
	var vel: Vector3 = car.linear_velocity
	var fwd: Vector3 = car.forward()
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else cam_dir
	var flat_vel := Vector3(vel.x, 0.0, vel.z)
	var speed := flat_vel.length()
	var kmh := vel.length() * 3.6

	if not cam_ready:
		cam_dir = fwd
		cam_h = cpos.y
		cam_ready = true

	if cam_mode == 3:
		# primeira pessoa: nos olhos do piloto, olhando um pouco pra dentro da curva
		var eye: Vector3 = car.driver_eye()
		var b: Basis = car.global_transform.basis
		var turn: float = car.steer / car.MAX_STEER
		var look_dir: Vector3 = (b.z + b.x * turn * 0.25 - b.y * 0.08).normalized()
		cam.global_position = eye
		cam.look_at(eye + look_dir * 10.0, b.y)
		cam.fov = lerpf(cam.fov, 78.0, 1.0 - exp(-delta * 3.0))
		return

	if cam_mode == 2:
		# capô: preso no carro, só suaviza um pouco
		var pos: Vector3 = cpos + car.global_transform.basis * Vector3(0, 1.45, 0.6)
		cam.global_position = pos
		cam.look_at(pos + car.forward() * 10.0, Vector3.UP)
		cam.fov = lerpf(cam.fov, 72.0, 1.0 - exp(-delta * 3.0))
		return

	# a câmera mira pra onde o carro está INDO, misturado com pra onde ele aponta.
	# Assim, derrapando, ela mostra a derrapagem em vez de grudar na traseira.
	var want := fwd
	if speed > 4.0:
		want = fwd.lerp(flat_vel / speed, 0.35).normalized()
	# atraso na rotação: o carro vira primeiro, a câmera vem depois
	cam_dir = cam_dir.slerp(want, 1.0 - exp(-delta * 3.2)).normalized()

	# balanço lateral: na curva a câmera escorrega um pouco pra fora
	var right := cam_dir.cross(Vector3.UP).normalized()
	var lat := flat_vel.dot(right)
	cam_side = lerpf(cam_side, clampf(-lat * 0.12, -1.5, 1.5), 1.0 - exp(-delta * 2.5))

	# altura: segue o carro com mola, sem tremer nas pancadas da suspensão
	cam_h = lerpf(cam_h, cpos.y, 1.0 - exp(-delta * 5.0))

	var dist := 7.0 if cam_mode == 0 else 15.0
	var up := 2.4 if cam_mode == 0 else 6.5
	dist += clampf(speed * 0.03, 0.0, 1.2)     # afasta um pouquinho em alta
	var pos := Vector3(cpos.x, cam_h, cpos.z) - cam_dir * dist + Vector3.UP * up + right * cam_side
	# nunca entra no chão (morro atrás do carro)
	var ground: float = terrain.height_at(pos.x, pos.z) + 0.8
	pos.y = max(pos.y, ground)
	cam.global_position = pos

	# olha um pouco à frente do carro, na direção do movimento
	var look := Vector3(cpos.x, cam_h, cpos.z) + Vector3.UP * 1.0 + cam_dir * clampf(speed * 0.12, 0.0, 4.0)
	cam.look_at(look, Vector3.UP)

	# sensação de velocidade: o FOV abre conforme acelera
	var fov_target: float = lerpf(66.0, 82.0, clampf(kmh / 160.0, 0.0, 1.0))
	cam.fov = lerpf(cam.fov, fov_target, 1.0 - exp(-delta * 3.0))
