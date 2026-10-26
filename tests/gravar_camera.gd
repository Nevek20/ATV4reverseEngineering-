extends SceneTree
## Prévia da câmera do piloto (camera_piloto.gd): acelera, freia forte, faz
## curva acelerando e olha pro lado com o "mouse". Grava com o Movie Maker:
##   godot --path . --write-movie camera.avi --fixed-fps 60 -s res://tests/gravar_camera.gd -- 0
## (na nuvem: xvfb-run -a ... --rendering-driver opengl3). O argumento é o
## índice em main.VEHICLES; EFEITOS=0 grava com os efeitos desligados (G).

const ROTEIRO := [               # [até (s), acelerador, freio, direção, olhar (px de mouse)]
	[1.5, 0.0, 0.0, 0.0, 0],      # assenta
	[6.5, 1.0, 0.0, 0.0, 0],      # acelera reto
	[8.5, 0.0, 1.0, 0.0, 0],      # freia forte
	[13.0, 1.0, 0.0, 0.6, 0],     # curva pra esquerda acelerando
	[14.5, 1.0, 0.0, 0.0, 350],   # olha pra direita
	[16.0, 1.0, 0.0, 0.0, 0],     # solta o olhar
]

var main
var veh := 0
var t := 0.0
var pronto := false
var olhando := false


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		veh = int(a[0])
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(dt: float) -> bool:
	if not pronto:
		if main.car == null:
			return false
		if main.veh_idx != veh:
			main.car.queue_free()
			main.spawn_vehicle(veh, main.spawn_point(), deg_to_rad(main.SPAWN_YAW))
			return false
		main.cam_mode = 4
		main.cam_piloto.ligado = OS.get_environment("EFEITOS") != "0"
		pronto = true
		return false
	t += dt
	var passo: Array = ROTEIRO[-1]
	for r in ROTEIRO:
		if t < r[0]:
			passo = r
			break
	main.car.test_input = {"thr": passo[1], "brk": passo[2], "steer": passo[3]}
	var olhar: int = passo[4]
	if olhar != 0 and not olhando:
		main.cam_piloto.mouse_botao(true)
		main.cam_piloto.mouse_arrasto(Vector2(olhar, 0))
		olhando = true
	elif olhar == 0 and olhando:
		main.cam_piloto.mouse_botao(false)
		olhando = false
	if int(t * 2.0) != int((t - dt) * 2.0):
		print("%.1f s  %3.0f km/h  cabeça (%.3f, %.3f, %.3f)  fov +%.1f  curva %.1f°  borrão %.2f" % [
			t, main.car.linear_velocity.length() * 3.6, main.cam_piloto.cabeca.x, main.cam_piloto.cabeca.y,
			main.cam_piloto.cabeca.z, main.cam_piloto.fov_extra, rad_to_deg(main.cam_piloto.curva),
			main.cam_piloto.borrao])
	return t > ROTEIRO[-1][0]
