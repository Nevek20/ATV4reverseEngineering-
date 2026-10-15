extends Node3D
## Cena principal do protótipo: monta mundo, chão, carro, câmera e HUD
## tudo por código, pra ficar fácil de ler e mexer.

# veículos do jogo: modelo, física (base + veículo), pontos, câmera, peças e
# rodas. "id" é o nome no vehicles.xml (posição na lista do jogo, contando do 1).
# Os 3 primeiros ficam fixos (os testes usam --veh 0/1/2).
const VEHICLES := [
	{"name": "Renegade", "id": "BUGGY_10", "cams": "BuggyCamSet_10",
		"model": "res://assets/renegade/21711_bloco.obj", "data": "res://data/vehicles/buggy_10.xml",
		"points": "res://data/vehicles/buggy_10_points.bin", "parts": "res://assets/renegade",
		"parts_ids": [21694, 21695, 21696, 21697, 21698, 21699, 21700, 21701, 21702, 21703, 21704], "brakes": 21713,
		"wheel_front": "res://assets/rodas/21968_bloco.obj", "wheel_rear": "res://assets/rodas/21969_bloco.obj"},
	{"name": "Sphinx", "id": "BUGGY_04", "cams": "BuggyCamSet_04",
		"model": "res://assets/sphinx/21531_bloco.obj", "data": "res://data/vehicles/buggy_04.xml",
		"points": "res://data/vehicles/buggy_04_points.bin", "parts": "res://assets/sphinx",
		"parts_ids": [21513, 21514, 21515, 21516, 21517, 21518, 21519, 21520, 21521, 21522, 21523], "brakes": 21533,
		"wheel_front": "res://assets/rodas/21968_bloco.obj", "wheel_rear": "res://assets/rodas/21969_bloco.obj"},
	# o Sphinx do speedrun tem peças compradas: com motor 0.81, BodyMass L2 e
	# Clutch L2 as trocas (38/57/75 mph) caem no mesmo tempo do vídeo
	{"name": "Sphinx speedrun", "id": "BUGGY_04", "cams": "BuggyCamSet_04",
		"model": "res://assets/sphinx/21531_bloco.obj", "data": "res://data/vehicles/buggy_04.xml",
		"points": "res://data/vehicles/buggy_04_points.bin", "parts": "res://assets/sphinx",
		"parts_ids": [21513, 21514, 21515, 21516, 21517, 21518, 21519, 21520, 21521, 21522, 21523], "brakes": 21533,
		"wheel_front": "res://assets/rodas/21968_bloco.obj", "wheel_rear": "res://assets/rodas/21969_bloco.obj",
		"livery": "pintura_speedrun.png", "tune": {"engine": 0.81, "mass": 1.0, "shift": 1.0}},
	# os outros buggies, na ordem da lista do jogo (tools/gerar_buggies.py)
	{"name": "Mosquito", "id": "BUGGY_01", "cams": "BuggyCamSet_01",
		"model": "res://assets/buggy_01/21447_bloco.obj", "data": "res://data/vehicles/buggy_01.xml",
		"points": "res://data/vehicles/buggy_01_points.bin", "parts": "res://assets/buggy_01",
		"parts_ids": [], "brakes": 21449,
		"wheel_front": "res://assets/rodas/21968_bloco.obj", "wheel_rear": "res://assets/rodas/21969_bloco.obj"},
	{"name": "Inferno", "id": "BUGGY_02", "cams": "BuggyCamSet_02",
		"model": "res://assets/buggy_02/21474_bloco.obj", "data": "res://data/vehicles/buggy_02.xml",
		"points": "res://data/vehicles/buggy_02_points.bin", "parts": "res://assets/buggy_02",
		"parts_ids": [21458, 21459, 21460, 21461, 21463, 21464, 21465, 21466, 21467, 21468, 21469], "brakes": 21476,
		"wheel_front": "res://assets/rodas/21973_bloco.obj", "wheel_rear": "res://assets/rodas/21974_bloco.obj"},
	{"name": "Trident", "id": "BUGGY_03", "cams": "BuggyCamSet_03",
		"model": "res://assets/buggy_03/21500_bloco.obj", "data": "res://data/vehicles/buggy_03.xml",
		"points": "res://data/vehicles/buggy_03_points.bin", "parts": "res://assets/buggy_03",
		"parts_ids": [21486, 21487, 21488, 21489, 21491, 21492, 21493, 21494, 21495, 21496, 21497], "brakes": 21502,
		"wheel_front": "res://assets/rodas/21973_bloco.obj", "wheel_rear": "res://assets/rodas/21974_bloco.obj"},
	{"name": "Bulldog", "id": "BUGGY_05", "cams": "BuggyCamSet_05",
		"model": "res://assets/buggy_05/21563_bloco.obj", "data": "res://data/vehicles/buggy_05.xml",
		"points": "res://data/vehicles/buggy_05_points.bin", "parts": "res://assets/buggy_05",
		"parts_ids": [21546, 21547, 21548, 21549, 21550, 21551, 21552, 21553, 21554, 21555, 21556], "brakes": 21565,
		"wheel_front": "res://assets/rodas/21978_bloco.obj", "wheel_rear": "res://assets/rodas/21979_bloco.obj"},
	{"name": "Phantom", "id": "BUGGY_06", "cams": "BuggyCamSet_06",
		"model": "res://assets/buggy_06/21589_bloco.obj", "data": "res://data/vehicles/buggy_06.xml",
		"points": "res://data/vehicles/buggy_06_points.bin", "parts": "res://assets/buggy_06",
		"parts_ids": [21574, 21575, 21576, 21577, 21579, 21580, 21581, 21582, 21583, 21584, 21585], "brakes": 21591,
		"wheel_front": "res://assets/rodas/21968_bloco.obj", "wheel_rear": "res://assets/rodas/21969_bloco.obj"},
	{"name": "Kraken V8", "id": "BUGGY_07", "cams": "BuggyCamSet_07",
		"model": "res://assets/buggy_07/21619_bloco.obj", "data": "res://data/vehicles/buggy_07.xml",
		"points": "res://data/vehicles/buggy_07_points.bin", "parts": "res://assets/buggy_07",
		"parts_ids": [21602, 21603, 21604, 21605, 21607, 21608, 21609, 21610, 21611, 21612, 21613], "brakes": 21621,
		"wheel_front": "res://assets/rodas/21963_bloco.obj", "wheel_rear": "res://assets/rodas/21964_bloco.obj"},
	{"name": "McKenzies", "id": "BUGGY_08", "cams": "BuggyCamSet_08",
		"model": "res://assets/buggy_08/21649_bloco.obj", "data": "res://data/vehicles/buggy_08.xml",
		"points": "res://data/vehicles/buggy_08_points.bin", "parts": "res://assets/buggy_08",
		"parts_ids": [21632, 21633, 21634, 21635, 21636, 21637, 21638, 21639, 21640, 21641, 21642], "brakes": 21651,
		"wheel_front": "res://assets/rodas/21963_bloco.obj", "wheel_rear": "res://assets/rodas/21964_bloco.obj"},
	{"name": "Viper", "id": "BUGGY_09", "cams": "BuggyCamSet_09",
		"model": "res://assets/buggy_09/21681_bloco.obj", "data": "res://data/vehicles/buggy_09.xml",
		"points": "res://data/vehicles/buggy_09_points.bin", "parts": "res://assets/buggy_09",
		"parts_ids": [21663, 21664, 21665, 21666, 21668, 21669, 21670, 21671, 21672, 21673, 21674], "brakes": 21683,
		"wheel_front": "res://assets/rodas/21968_bloco.obj", "wheel_rear": "res://assets/rodas/21969_bloco.obj"},
	{"name": "Hurricane", "id": "BUGGY_11", "cams": "BuggyCamSet_11",
		"model": "res://assets/buggy_11/21740_bloco.obj", "data": "res://data/vehicles/buggy_11.xml",
		"points": "res://data/vehicles/buggy_11_points.bin", "parts": "res://assets/buggy_11",
		"parts_ids": [21724, 21725, 21726, 21727, 21729, 21730, 21731, 21732, 21733, 21734, 21735], "brakes": 21742,
		"wheel_front": "res://assets/rodas/21968_bloco.obj", "wheel_rear": "res://assets/rodas/21969_bloco.obj"},
	{"name": "Storm", "id": "BUGGY_12", "cams": "LanciaCam",
		"model": "res://assets/buggy_12/21769_bloco.obj", "data": "res://data/vehicles/buggy_12.xml",
		"points": "res://data/vehicles/buggy_12_points.bin", "parts": "res://assets/buggy_12",
		"parts_ids": [21752, 21753, 21754, 21755, 21758, 21759, 21760, 21761, 21762, 21763, 21764], "brakes": 21776,
		"wheel_front": "res://assets/rodas/21267_bloco.obj", "wheel_rear": "res://assets/rodas/21268_bloco.obj"},
]
var veh_idx := 0
const SPAWN_XZ := Vector2(400.0, 340.0)   # em cima da reta de cima da pista

const Car := preload("res://car.gd")
const Terrain := preload("res://terrain.gd")

var car  # instância de car.gd (sem tipo estático de propósito: métodos próprios do script)
var cam: Camera3D
var hud: Label
var cam_mode := 0                        # 0 perto, 1 longe, 2 capô, 3 para-choque, 4 piloto
var terrain


func _ready() -> void:
	_make_environment()
	terrain = Terrain.new()
	add_child(terrain)

	spawn_vehicle(0, spawn_point(), deg_to_rad(90.0))

	cam = Camera3D.new()
	cam.far = 4000.0
	cam.near = 0.1
	cam.fov = 70.0
	add_child(cam)
	cam.current = true
	# a câmera é posta no _process a partir do carro interpolado
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cam.global_position = spawn_point() + Vector3(-8, 4, 0)

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(16, 12)
	hud.add_theme_font_size_override("font_size", 18)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 6)
	layer.add_child(hud)
	_make_menu(layer)


func spawn_vehicle(i: int, pos: Vector3, yaw: float) -> void:
	var manual := false
	if car != null:
		manual = car.manual
		car.queue_free()
	veh_idx = i
	var v: Dictionary = VEHICLES[i]
	car = Car.new()
	car.model_path = v.model
	car.data_files = ["res://data/vehicles/buggy_base.xml", v.data]
	car.points_file = v.points
	car.vehicle_id = v.id
	car.tune_override = v.get("tune", {})
	car.livery_file = v.get("livery", "pintura.png")
	car.parts_dir = v.get("parts", "")
	car.parts_ids = v.get("parts_ids", [])
	car.brakes_base = v.get("brakes", -1)
	car.wheel_front_file = v.get("wheel_front", car.wheel_front_file)
	car.wheel_rear_file = v.get("wheel_rear", car.wheel_rear_file)
	car.wheel_dx = v.get("wheel_dx", 0.0)
	car.vehicle_name = "%s (%s)" % [v.name, v.id]
	add_child(car)
	car.manual = manual
	car.reset_to(pos, yaw)
	gcams.clear()
	cam_ready = false


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


func _input(event: InputEvent) -> void:
	# Tab antes da interface (senão a lista usa o Tab pra trocar de foco)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_TAB or (menu.visible and event.physical_keycode == KEY_ESCAPE):
			_toggle_menu()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_C:
				cam_mode = (cam_mode + 1) % 5
			KEY_R:
				var p: Vector3 = car.global_position
				car.reset_to(Vector3(p.x, terrain.height_at(p.x, p.z) + 1.5, p.z), car.global_rotation.y)
				reset_camera()
			KEY_T:
				car.reset_to(spawn_point(), deg_to_rad(90.0))
				reset_camera()
			KEY_V:
				_swap_vehicle((veh_idx + 1) % VEHICLES.size())
			KEY_F:
				car.flip_model()
			KEY_ESCAPE:
				get_tree().quit()


# ------------------------------------------------------------ menu de carros
var menu: ItemList
var menu_idx := []                       # linha do menu -> índice em VEHICLES


func _make_menu(layer: CanvasLayer) -> void:
	menu = ItemList.new()
	menu.anchor_left = 1.0
	menu.anchor_right = 1.0
	menu.offset_left = -300
	menu.offset_right = -16
	menu.offset_top = 12
	menu.auto_height = true
	menu.add_theme_font_size_override("font_size", 18)
	# ordem da lista do jogo (BUGGY_01..12), as variações logo depois
	var order := range(VEHICLES.size())
	order.sort_custom(func(a, b): return [VEHICLES[a].id, a] < [VEHICLES[b].id, b])
	for i in order:
		var v: Dictionary = VEHICLES[i]
		menu.add_item("%d. %s" % [v.id.to_int(), v.name])
		menu_idx.append(i)
	menu.item_activated.connect(func(row): _swap_vehicle(menu_idx[row]); _toggle_menu())
	menu.item_clicked.connect(func(row, _p, _b): _swap_vehicle(menu_idx[row]); _toggle_menu())
	menu.visible = false
	layer.add_child(menu)


func _toggle_menu() -> void:
	menu.visible = not menu.visible
	if menu.visible:
		var row := menu_idx.find(veh_idx)
		menu.select(row)
		menu.ensure_current_is_visible()
		menu.grab_focus()
	else:
		menu.release_focus()


func _swap_vehicle(i: int) -> void:
	var p: Vector3 = car.global_position
	spawn_vehicle(i, Vector3(p.x, terrain.height_at(p.x, p.z) + 1.5, p.z), car.global_rotation.y)


func _process(delta: float) -> void:
	if car == null:
		return
	_update_camera(delta)
	var kmh: float = car.linear_velocity.length() * 3.6
	hud.text = "%d km/h   %d mph\nmarcha %s   %d rpm   câmbio %s\nfísica: %s (%s)\n\nW/S ou setas: acelerar/frear (parado, segurar S = ré)   A/D: virar   Espaço: powerslide (freio de mão)\nP: pneus portados/antigos   L: lateral jogo/remendo   M: câmbio auto/manual   E/Q: sobe/desce marcha   R: desvirar   T: voltar pro início\nC: câmera (%s)   V: próximo carro   Tab: menu de carros   F: girar o modelo   Esc: sair" % [
		int(kmh), int(kmh / 1.609), car.gear_label(), int(car.rpm), "MANUAL" if car.manual else "AUTO", car.vehicle_name, ("pneus portados do jogo" if car.use_ported else "pneus antigos") + (", lateral do jogo" if car.lateral_game else ", lateral remendo"), CAM_NAMES[cam_mode]]


const GameCamera := preload("res://game_camera.gd")
const CAM_XML := "res://data/cameras.xml"
const CAM_NAMES := ["perto", "longe", "capô", "para-choque", "piloto"]
var gcams := []                           # câmeras do jogo, uma por modo (0..3)
var cam_ready := false


func _make_cameras() -> void:
	var cs: String = VEHICLES[veh_idx].cams
	gcams = [
		GameCamera.load_set(CAM_XML, cs, "FollowOrbitNear"),
		GameCamera.load_set(CAM_XML, cs, "FollowOrbitFar"),
		GameCamera.load_set(CAM_XML, cs, "MountOnHood"),
		GameCamera.load_set(CAM_XML, cs, "MountOnFront"),
	]


func cam_state() -> Dictionary:
	# transform interpolado: é o que aparece na tela (física roda a 120 Hz)
	var xf: Transform3D = car.get_global_transform_interpolated()
	var b := xf.basis.orthonormalized()
	var tp: Vector3 = xf * car.model_offset
	var v: Vector3 = car.linear_velocity
	return {
		"tp": tp, "basis": b, "vel": v, "v_f": v.dot(b.z),
		"air_time": car.air_time, "grounded": car.grounded,
		"ground_n": ground_normal(tp.x, tp.z),
	}


func ground_normal(x: float, z: float) -> Vector3:
	var e := 0.5
	return Vector3(terrain.height_at(x - e, z) - terrain.height_at(x + e, z), 2.0 * e,
		terrain.height_at(x, z - e) - terrain.height_at(x, z + e)).normalized()


func reset_camera() -> void:
	if gcams.is_empty():
		_make_cameras()
	var s := cam_state()
	for g in gcams:
		if not g.mount:
			g.reset(s, terrain)
	cam_ready = true


func _update_camera(delta: float) -> void:
	if not cam_ready:
		reset_camera()
	var s := cam_state()
	# as câmeras de órbita rodam sempre (como no jogo, trocar não dá tranco)
	for i in 2:
		gcams[i].update(delta, s, terrain)

	# MountOnFront fica dentro da carroceria (no ATV também: Z -0.2), então o
	# jogo não desenha o veículo nela. As rodas continuam.
	car.model_root.visible = cam_mode != 3
	if car.susp_vis:
		car.susp_vis.visible = cam_mode != 3

	if cam_mode <= 1:
		gcams[cam_mode].apply(cam, s.tp)
		return

	if cam_mode == 4:
		# primeira pessoa (não é do jogo): nos olhos do piloto
		var eye: Vector3 = car.driver_eye()
		var b: Basis = car.get_global_transform_interpolated().basis
		var turn: float = car.steer / car.MAX_STEER
		var look_dir: Vector3 = (b.z + b.x * turn * 0.25 - b.y * 0.08).normalized()
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.global_position = eye
		cam.look_at(eye + look_dir * 10.0, b.y)
		cam.fov = 70.0
		return

	# MountOnHood / MountOnFront: presa no carro, PosOffset no frame do modelo,
	# Orientation.X = inclinação em graus, FOV = zoom fixo
	var g = gcams[cam_mode]
	var xf: Transform3D = car.get_global_transform_interpolated()
	var bb := xf.basis.orthonormalized()
	var pos: Vector3 = xf * (car.model_offset + g.pos_off)
	var o: Vector3 = g.p.get("orient", Vector3.ZERO)
	var fwd := bb.z.rotated(bb.x, deg_to_rad(-o.x))
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.global_position = pos
	cam.look_at(pos + fwd * 10.0, bb.y)
	cam.fov = g.fov_deg(g.p.FOV)
