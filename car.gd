extends RigidBody3D
## Carro com a física lida dos XMLs do próprio jogo (data/vehicles).
##
## O modelo de direção do ATV Offroad Fury 4 é "arcade de dados": em vez de
## simular pneu, ele trabalha com acelerações. O que foi reproduzido aqui:
##   - suspensão (portada): curso e velocidade próprios por roda, mola que
##     também puxa esticada, batente que empurra o carro, anti-pitch
##   - motor (portado do executável): curva de torque x rpm, atrito do motor,
##     inércia, limitador em rampa
##   - câmbio (portado): AutoManual troca por velocidade, Manual com E/Q,
##     embreagem com 4 estados (aberta, engatando, abrindo, travada)
##   - pneus: elipse de atrito por eixo (força máxima lateral e longitudinal)
##   - direção: ângulo x velocidade, subesterço, aceleração de guinada limitada
##   - derrapagem: ângulo máximo de sideslip e taxas de aumento/redução
##   - no ar (portado): gravidade maior subindo/descendo, guinada, arfagem,
##     empurrão lateral virando e torque de arfagem constante
## Unidades do jogo: massa em toneladas, torque/força em kN, velocidades em mph
## e desacelerações em mph/s. Tudo é convertido pra SI ao carregar.

const VehicleData := preload("res://vehicle_data.gd")
const MPH := 0.44704
const G := 9.81
const RPM2RAD := TAU / 60.0

var model_path := ""
var data_files := ["res://data/vehicles/buggy_base.xml", "res://data/vehicles/buggy_10.xml"]
# arquivo de pontos do modelo (POINT 1.00): posição das rodas no modelo do jogo
var points_file := "res://data/vehicles/buggy_10_points.bin"
var points := {}              # pontos lidos do arquivo acima
var points_rot := {}          # matriz 3x3 de cada ponto (Basis: colunas = linhas do jogo)
# pasta do carro em assets/ com o pecas.json do tools/gerar_buggies.py:
# Position do component map -> .obj (Body, FrontLeftFrame, ...), rodas, rally
var asset_dir := ""
var pecas := {}
var livery_file := "pintura.png"   # gerada pelo gerar_pintura.py, ao lado do modelo
var suspension := true        # desenha balanças, freios e amortecedores
var susp_vis    # suspension_visual.gd
# rodas do jogo (componente Wheel, TYRE_GENERIC_* nos buggies de fábrica):
# modelo da frente e de trás (Models_4K, o que o jogo carrega na corrida). Já
# vêm com o aro (ALLOY) e o pneu (TYRE). Sem escala: o tamanho é o do modelo
var wheel_front_file := ""
var wheel_rear_file := ""
var vehicle_name := "Renegade (Buggy)"

# peças de fábrica (DefaultConfig do jogo). Cada número diz quanto o valor
# anda de _non_tuned até _fully_tuned. Vêm de data/vehicles.xml (DefaultConfig
# do veículo) + data/upgrades.xml (efeito de cada peça), ver
# VehicleData.factory_tuning. Os valores abaixo são os do Renegade (BUGGY_10),
# conferidos no save state: torque 0.81, final 0.61, massa e embreagem no máximo.
var vehicle_id := "BUGGY_10"
var tune_override := {}       # ex.: {"engine": 0.3} pra simular peças compradas
var TUNE_ENGINE := 0.81       # Internals L3 + Management L2 + Header L2 + Intake L3 + Exhaust L3
var TUNE_BRAKE := 0.9         # Brake_Level2
var TUNE_SUSP := 1.0          # Suspension_Level3: curso máximo
var TUNE_UNDERSTEER := 1.0    # Suspension_Level3
var TUNE_FINAL := 0.61        # GearboxLevel_Level3 = relação final custom (CustomTunings FinalDrive)
var TUNE_SHIFT := 1.0         # Clutch_Level2
var TUNE_MASS := 1.0          # BodyMass_Level2
var TUNE_SPRING := 0.5        # Shocks_Medium
var TUNE_DAMPING := 0.91      # Shocks_Medium
var TUNE_GEARS := [0.5, 0.5, 0.5, 0.5, 0.5]   # CustomTunings/GearRatioTuning
const REAR_DRIVE := true      # tração só atrás (o XML não diz; buggy de motor traseiro)

# aderência do chão (TireBehaviour do jogo, nota 0-10): terra com pneu de fábrica
# (DIRT_BUDGET) = 8. Os XMLs trazem cada valor pra atrito máximo (1.0) e mínimo
# (0.1); o jogo interpola entre os dois conforme o chão.
var SURFACE_MU := 0.8          # pneu DIRT_BUDGET na terra (4 estrelas). DIRT_PREMIUM = 1.0
var TUNE_FRONT_BIAS := 0.5    # DefaultConfig/CustomTunings FrontBrakeBias

# geometria medida no modelo (o XML não traz a posição das rodas)
# posição das rodas no chute, só se faltar o arquivo de pontos do modelo
const WHEEL_X := 1.0
const WHEEL_Z := 1.75
const WHEEL_Y := 0.45         # altura do cubo com o carro parado

# volante: no jogo ele é parte da carroceria e NÃO gira. Girar é melhoria do
# remake (tools/volante.py acha o aro em cada carro e o gerar_buggies.py
# separa; centro e eixo vêm do pecas.json). VOLANTE_GIRA = false deixa igual
# ao jogo.
const VOLANTE_GIRA := true
var SW_CENTER := Vector3(-0.434, 1.351, 0.396)    # Renegade, se faltar no pecas.json
var SW_AXIS := Vector3(0.0, 0.684, -0.729)
const SW_TURNS := 2.6         # sem fonte no jogo (escolha do remake)
var rider_s := 0.0            # direção suavizada do piloto (rider+0x2d8)
var DRIVER_EYE := Vector3(-0.434, 1.78, -0.12)   # Renegade; nos outros vem do ponto ARSE
const EYE_FROM_ARSE := Vector3(0.047, 0.78, -0.169)   # medido no Renegade (ARSE -> olho)
const MAX_STEER := 1.0        # steer já é normalizado (-1..1)
# o pingu2obj acerta o giro dos triângulos pelas normais do jogo, então a face
# de trás pode ser descartada (painéis de duas faces não piscam mais).
# Modelos gerados com o pingu2obj antigo precisam de CULL_DISABLED.
const MODEL_CULL := BaseMaterial3D.CULL_BACK

var model_root: Node3D
var model_offset := Vector3.ZERO
var sw_pivot: Node3D

# ---- parâmetros carregados do XML ----
var P := {}
var wheels: Array = []
var drive_curve: Dictionary
var fric_curve: Dictionary
var steer_curve: Dictionary
var ss_inc_curve: Dictionary
var ss_dec_zero: Dictionary
var ss_dec_full: Dictionary
var ss_inc_min: Dictionary
var ss_dec_zero_min: Dictionary
var ss_dec_full_min: Dictionary
var rate_inc_max: Dictionary
var rate_inc_min: Dictionary
var rate_dec_max: Dictionary
var rate_dec_min: Dictionary
var ps_rate: Dictionary
var ps_scale: Dictionary
var mu_t := 1.0               # 0 = atrito mínimo do XML, 1 = máximo
var gears := PackedFloat32Array()

# ---- estado ----
var steer := 0.0              # direção (-1..1), + = esquerda
var throttle := 0.0
var brake_in := 0.0
var gear := 1                 # -1 = ré, 0 = neutro
var rpm := 1000.0
var clutch := 1.0
var shift_timer := 0.0
var shift_to := 1
var manual := false
var limiter := false
var cstate := 0               # embreagem (0x314): 0 aberta, 1 engatando, 2 abrindo, 3 travada
var shift_flag := false       # troca em andamento: acelerador cai junto com a embreagem
var slip_sign := 0.0          # sinal da diferença de giro quando começou a engatar
var lim_k := 1.0              # fator do limitador de giro (rampa)
var eng_torque := 0.0         # torque líquido do motor (N·m)
var clutch_t := 0.0           # torque passando pela embreagem (N·m)
var want_rev := false         # pedido de ré (o câmbio abre, engata a ré e fecha)
var reverse_hold := 0.0
var air_time := 0.0
var air_lat_state := 0        # empurrão lateral no ar (0x6f4): 0 nada, 1 direita, 2 esquerda
var air_lat_timer := 0.0
var air_lat_scale := 1.0
var sideslip := 0.0           # rad, + = bico à esquerda da trajetória
var grounded := 0

# tremida das rodas no chão (0x202760, só visual). A cada passo de física do
# jogo (50 Hz no PAL) cada roda no chão sorteia um deslocamento do curso:
# amp = min(1, WheelJitter * 0.06392613 * v) e tremida = amp * (U*0.075 - 0.0375),
# com v a velocidade no plano do chão (m/s) e U do gerador do piloto
# (x = x*31415821 + 1 mod 2^30). A traseira direita do jogo copia a esquerda.
# WheelJitter vem do Materials.xml da pista: 0.3 na terra do RX_01, 0 no asfalto.
const JIT_K := 0.06392613     # 2.2374146 / 35: amplitude cheia a 35 mph com WheelJitter 1
const JIT_HZ := 50.0          # passo de física do PAL (FUN_00172778)
var surface_jitter := 0.3     # o terreno do remake é todo terra (Material_1 DIRT/COMMON)
var jit_seed := 0
var jit_acc := 0.0
var spd_ground := 0.0         # corpo+0x440: velocidade no plano do chão (m/s)
var jit_order := []           # índices das rodas na ordem do jogo: FL, RL, FR, RR

var lateral_game := true     # L alterna: força lateral por eixo (jogo) x remendo antigo
var use_ported := true      # P alterna: física portada do jogo x modelo antigo
var stf_blend := 0.0          # 0x474: quanto da força pra frente veio da derrapagem
var drive_slip := 0.0         # patinada das rodas de tração (0x610 no jogo)
var test_input = null         # {thr, brk, steer} pra testes automáticos


func _ready() -> void:
	model_root = Node3D.new()
	add_child(model_root)
	_load_pecas()
	_load_model()                 # antes da física: define model_offset
	_load_physics()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.1, 0.8, 4.8)
	shape.shape = box
	shape.position = Vector3(0, 0.95, 0)
	add_child(shape)
	for w in wheels:
		_make_wheel_mesh(w)
	if suspension and not pecas.is_empty() and not points.is_empty():
		susp_vis = preload("res://suspension_visual.gd").new()
		add_child(susp_vis)
		var spare_mesh: Mesh = null
		if ResourceLoader.exists(wheel_rear_file):
			spare_mesh = load(wheel_rear_file) as Mesh
		susp_vis.build(self, points, points_rot, asset_dir, pecas.get("pecas", {}),
			pecas.get("rally", false), pecas.get("estepe", []), spare_mesh)


## pecas.json (tools/gerar_buggies.py): modelo, peças e rodas do carro
func _load_pecas() -> void:
	var p := asset_dir.path_join("pecas.json")
	if asset_dir == "" or not FileAccess.file_exists(p):
		return
	pecas = JSON.parse_string(FileAccess.get_file_as_string(p))
	if pecas == null:
		pecas = {}
		return
	var pc: Dictionary = pecas.get("pecas", {})
	if model_path == "" and pc.has("Body"):
		model_path = asset_dir.path_join(pc.Body)
	var rd: Dictionary = pecas.get("rodas", {})
	if wheel_front_file == "" and rd.has("FrontWheel"):
		wheel_front_file = asset_dir.path_join(rd.FrontWheel).simplify_path()
	if wheel_rear_file == "" and rd.has("RearWheel"):
		wheel_rear_file = asset_dir.path_join(rd.RearWheel).simplify_path()


# ------------------------------------------------------------------ dados
func _load_tuning() -> void:
	if not FileAccess.file_exists("res://data/vehicles.xml"):
		return
	var t := VehicleData.factory_tuning("res://data/vehicles.xml", "res://data/upgrades.xml", vehicle_id)
	TUNE_ENGINE = t.engine
	TUNE_BRAKE = t.brake
	TUNE_SUSP = t.susp
	TUNE_UNDERSTEER = t.understeer
	TUNE_FINAL = t.final
	TUNE_SHIFT = t.shift
	TUNE_MASS = t.mass
	TUNE_SPRING = t.spring
	TUNE_DAMPING = t.damping
	TUNE_GEARS = t.gears
	TUNE_FRONT_BIAS = t.front_bias
	for k in tune_override:
		set("TUNE_" + String(k).to_upper(), tune_override[k])


func _load_physics() -> void:
	_load_tuning()
	var d = VehicleData.new()
	d.load_files(data_files)

	mass = d.tuned("RigidBody", "Mass", TUNE_MASS) * 1000.0
	var bw := d.f("RigidBody", "Inertia_dimensions_width", 2.0)
	var bh := d.f("RigidBody", "Inertia_dimensions_height", 1.5)
	var bl := d.f("RigidBody", "Inertia_dimensions_length", 4.0)
	inertia = Vector3(bh * bh + bl * bl, bw * bw + bl * bl, bw * bw + bh * bh) * mass / 12.0
	P.ang_res = Vector3(d.f("RigidBody/Angular_resistance_3d", "X", 1.0),
		d.f("RigidBody/Angular_resistance_3d", "Y", 0.1),
		d.f("RigidBody/Angular_resistance_3d", "Z", 2.5))
	var pm := PhysicsMaterial.new()
	pm.friction = d.f("RigidBody", "Friction", 0.2)
	pm.bounce = d.f("RigidBody", "Restitution", 0.2)
	physics_material_override = pm
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.0
	continuous_cd = true

	var com := Vector3(d.f("Stability/General/Centre_of_mass", "X"),
		d.f("Stability/General/Centre_of_mass", "Y", 0.6),
		d.f("Stability/General/Centre_of_mass", "Z"))
	# o centro de massa do XML está nas coordenadas do modelo (no jogo, a origem
	# do modelo fica em corpo - CoM, 0x20ca88); aqui o modelo foi deslocado
	# por model_offset, então o CoM anda junto
	com += model_offset
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = com

	# motor
	P.idle = d.f("Engine", "Idle_rpm", 1000.0)
	P.lim_on = d.tuned("Engine", "Rev_limiter_engage_rpm", TUNE_ENGINE)
	P.lim_off = d.tuned("Engine", "Rev_limiter_disengage_rpm", TUNE_ENGINE)
	P.lim_rate_on = d.f("Engine", "Rev_limiter_engage_rate", 15.0)
	P.lim_rate_off = d.f("Engine", "Rev_limiter_disengage_rate", 15.0)
	P.eng_inertia = d.tuned("Engine", "Inertia", TUNE_ENGINE) * 1000.0   # N·m por (rpm/s)
	P.drive_scale = d.tuned("Engine", "Drive_torque", TUNE_ENGINE) * 1000.0
	P.fric_scale = d.tuned("Engine", "Friction_torque", TUNE_ENGINE) * 1000.0
	drive_curve = d.curve("Engine/Drive_torque_vs_rpm")
	fric_curve = d.curve("Engine/Friction_torque_vs_rpm")

	# câmbio
	var n := int(d.f("Gearbox", "Number_of_forward_gears", 5))
	gears.resize(n + 1)
	for g in range(1, n + 1):
		gears[g] = d.tuned("Gearbox/Ratios", "Gear_%d" % g, TUNE_GEARS[g - 1])
	P.gear_r = d.f("Gearbox/Ratios", "Gear_R", -15.0)
	P.final = d.tuned("Gearbox/Ratios", "Final_drive", TUNE_FINAL)
	P.up_rpm = d.f("Gearbox/AutoManual", "Change_up_rpm", 7000.0)
	var dd := PackedFloat32Array()
	dd.resize(n + 1)
	for g in range(2, n + 1):
		dd[g] = d.f("Gearbox/AutoManual", "Change_down_speed_difference_gear_%d" % g, 10.0)
	P.down_diff = dd
	P.clutch_dis_rate = d.f("Gearbox/AutoManual", "Clutch_disengagement_rate", 10.0)
	P.clutch_eng_rate = d.f("Gearbox/AutoManual", "Clutch_engagement_rate", 2.0)
	P.clutch_thr_mod = d.f("Gearbox/AutoManual", "Clutch_rate_throttle_modifier", 1.0)
	P.clutch_dis_rpm = d.f("Gearbox/AutoManual", "Clutch_disengagement_rpm", 1050.0)
	# ClutchTorque vem das peças de motor (mesma soma do torque), não do Clutch_Level:
	# no save state do Renegade a embreagem vale 0.6127 = lerp(0.445, 0.652, 0.81)
	P.clutch_max = d.tuned("Gearbox/AutoManual", "Maximum_clutch_torque", TUNE_ENGINE) * 1000.0
	P.clutch_rpm_lo = d.f("Gearbox/AutoManual", "Clutch_engagement_rpm_no_throttle", 1000.0)
	P.clutch_rpm_hi = d.f("Gearbox/AutoManual", "Clutch_engagement_rpm_full_throttle", 1000.0)
	P.clutch_lock_diff = d.f("Gearbox/AutoManual", "Clutch_lock_rpm_difference", 100.0)
	P.up_thr_mod = d.f("Gearbox/AutoManual", "Change_rpm_throttle_modifier", 1.0)
	P.auto_time = d.tuned("Gearbox/AutoManual", "Change_time", TUNE_SHIFT)
	P.manual_time = d.tuned("Gearbox/Manual", "Change_time", TUNE_SHIFT)

	# comandos (taxas de subida/descida do acelerador, freio e direção)
	P.thr_up = d.f("InputRates/Throttle", "Digital_increase_rate", 2.0)
	P.thr_down = d.f("InputRates/Throttle", "Digital_decrease_rate", 2.0)
	P.brk_up = d.f("InputRates/Footbrake", "Digital_increase_rate", 2.0)
	P.brk_down = d.f("InputRates/Footbrake", "Digital_decrease_rate", 2.0)
	P.st_up = d.f("InputRates/Steer", "Digital_increase_rate", 6.0)
	P.st_down = d.f("InputRates/Steer", "Digital_decrease_rate", 4.0)
	P.st_opp = d.f("InputRates/Steer", "Digital_opposite_rate", 6.0)

	# arrasto e freio
	P.air_drag = d.f("Misc", "Air_drag_coefficient", 1.0)
	P.ifd_lo_speed = d.f("Misc", "Internal_friction_drag_lower_speed", 5.0)
	P.ifd_hi_speed = d.f("Misc", "Internal_friction_drag_upper_speed", 80.0)
	P.ifd_lo = d.f("Misc", "Internal_friction_drag_lower_speed_decel", 3.0)
	P.ifd_hi = d.f("Misc", "Internal_friction_drag_upper_speed_decel", 5.0)
	P.brake_decel = d.tuned("Footbrake", "Maximum_deceleration", TUNE_BRAKE)
	P.rev_cut = d.f("ReverseSpeedLimit", "Drive_cut_speed_threshold", 25.0)
	P.rev_limit = d.f("ReverseSpeedLimit", "Speed_limit", 30.0)

	# elipse de atrito por eixo (kN -> N)
	var ws := d.tuned("FrictionEllipse", "Width_scale", 0.0)
	var hs := d.tuned("FrictionEllipse", "Height_scale", 0.0)
	P.ell_w_f = d.f("FrictionEllipse/FrontWheels/HalfWidth", "Maximum_friction_half_width", 10.0) * ws * 1000.0
	P.ell_w_r = d.f("FrictionEllipse/RearWheels/HalfWidth", "Maximum_friction_half_width", 10.0) * ws * 1000.0
	P.ell_h_f = d.f("FrictionEllipse/FrontWheels/HalfHeight", "Maximum_friction_half_height", 5.0) * hs * 1000.0
	P.ell_h_r = d.f("FrictionEllipse/RearWheels/HalfHeight", "Maximum_friction_half_height", 5.0) * hs * 1000.0

	# direção
	steer_curve = d.curve("BasicSteering/Angle_vs_speed")
	P.vis_steer = deg_to_rad(d.f("BasicSteering", "Maximum_visual_steer_angle_zero_speed", 30.0))
	P.understeer = deg_to_rad(d.tuned("BasicSteering", "Understeer_coefficient", TUNE_UNDERSTEER)) / G
	P.yaw_acc = deg_to_rad(d.f("BasicSteering/MaximumYawAcceleration", "Standard_value", 2000.0))

	# derrapagem
	P.ss_zero = d.f("Sideslip", "Speed_for_zero_sideslip", 5.0)
	P.ss_full = d.f("Sideslip", "Speed_for_maximum_sideslip", 100.0)
	P.ss_max = d.f("Sideslip", "Maximum_sideslip_angle", 10.0)
	P.side_to_fwd = d.f("Sideslip", "Side_deceleration_to_fwd_acceleration", 0.75)
	P.side_to_fwd_min = d.f("Sideslip", "Side_deceleration_to_fwd_acceleration_min_sideslip", 5.0)
	P.side_to_fwd_max = d.f("Sideslip", "Side_deceleration_to_fwd_acceleration_max_sideslip", 30.0)
	var fmax := d.f("Sideslip/SideVelocityDecelerationStandard", "Maximum_friction", 1.0)
	var fmin := d.f("Sideslip/SideVelocityDecelerationStandard", "Minimum_friction", 0.1)
	mu_t = clampf((SURFACE_MU - fmin) / maxf(fmax - fmin, 0.01), 0.0, 1.0)
	P.side_decel = lerpf(d.f("Sideslip/SideVelocityDecelerationStandard", "Minimum_friction_deceleration", 10.0),
		d.f("Sideslip/SideVelocityDecelerationStandard", "Maximum_friction_deceleration", 30.0), mu_t)
	P.tail_off = d.f("Sideslip", "Increase_tail_off_threshold", 10.0)
	P.legacy_side_decel = P.side_decel
	var sp := "Sideslip/SideslipIncreaseYawAcceleration/"
	ss_inc_curve = d.curve(sp + "Maximum_friction_acceleration_vs_speed")
	ss_inc_min = d.curve(sp + "Minimum_friction_acceleration_vs_speed")
	sp = "Sideslip/SideslipDecreaseYawAccelerationStandard/"
	ss_dec_zero = d.curve(sp + "ZeroThrottle/Maximum_friction_acceleration_vs_speed")
	ss_dec_zero_min = d.curve(sp + "ZeroThrottle/Minimum_friction_acceleration_vs_speed")
	ss_dec_full = d.curve(sp + "FullThrottle/Maximum_friction_acceleration_vs_speed")
	ss_dec_full_min = d.curve(sp + "FullThrottle/Minimum_friction_acceleration_vs_speed")
	sp = "Sideslip/MaximumRate/"
	rate_inc_max = d.curve(sp + "Maximum_increase_rate_vs_sideslip/Maximum_friction_rate_vs_sideslip")
	rate_inc_min = d.curve(sp + "Maximum_increase_rate_vs_sideslip/Minimum_friction_rate_vs_sideslip")
	rate_dec_max = d.curve(sp + "Maximum_decrease_rate_vs_sideslip/Maximum_friction_rate_vs_sideslip")
	rate_dec_min = d.curve(sp + "Maximum_decrease_rate_vs_sideslip/Minimum_friction_rate_vs_sideslip")
	ps_rate = d.curve("Powerslide/Maximum_sideslip_rate_vs_sideslip")
	ps_scale = d.curve("Powerslide/Scale_vs_speed")
	P.ps_ellipse = d.f("Powerslide", "Scale_of_min_friction_ellipse_scale", 0.8)

	# ---- parte 1: pneus e derrapagem, como no executável (funções 0x20ede8,
	# 0x20eb98, 0x20efa0 e 0x2101e0). Detalhes nos comentários do _tires().
	P.understeer_raw = d.tuned("BasicSteering", "Understeer_coefficient", TUNE_UNDERSTEER)
	P.width_scale = d.tuned("FrictionEllipse", "Width_scale", 0.0)
	P.height_scale = d.tuned("FrictionEllipse", "Height_scale", 0.0)
	for ax in ["FrontWheels", "RearWheels"]:
		var fe: String = "FrictionEllipse/" + ax
		P["ell_" + ax] = {"w": d.ftriple(fe + "/HalfWidth", "half_width"),
			"h": d.ftriple(fe + "/HalfHeight", "half_height"),
			"ms": d.ftriple(fe + "/MinimumScale", "minimum_scale"),
			"shrink": d.f(fe, "Shrink_rate", 1.0), "recover": d.f(fe, "Recovery_rate", 1.0)}
	P.front_bias = d.tuned("Footbrake", "Front_bias", TUNE_FRONT_BIAS)
	P.brake_fscale = d.ftriple("Footbrake", "scale")
	P.side_std = d.ftriple("Sideslip/SideVelocityDecelerationStandard", "deceleration")
	P.side_cs = d.ftriple("Sideslip/SideVelocityDecelerationCounterSteer", "deceleration")
	P.yaw_inc = d.fcurves("Sideslip/SideslipIncreaseYawAcceleration")
	P.yaw_dec_zero = d.fcurves("Sideslip/SideslipDecreaseYawAccelerationStandard/ZeroThrottle")
	P.yaw_dec_full = d.fcurves("Sideslip/SideslipDecreaseYawAccelerationStandard/FullThrottle")
	P.yaw_dec_cs = d.fcurves("Sideslip/SideslipDecreaseYawAccelerationCounterSteer")
	P.cs_scale = d.f("BasicSteering/MaximumYawAcceleration", "Counter_steer_maximum_scale", 1.0)
	P.cs_scale_ss = d.f("BasicSteering/MaximumYawAcceleration", "Counter_steer_maximum_scale_sideslip", 60.0)
	P.ps_side_to_fwd = d.f("Powerslide", "Side_deceleration_to_fwd_acceleration", 1.0)
	P.ss_rate_inc = d.fcurves("Sideslip/MaximumRate/Maximum_increase_rate_vs_sideslip", "rate_vs_sideslip")
	P.ss_rate_dec = d.fcurves("Sideslip/MaximumRate/Maximum_decrease_rate_vs_sideslip", "rate_vs_sideslip")
	P.slip_grow = d.f("SlipRatio", "Growth_rate_during_wheel_spin", 3.0)
	P.slip_recover = d.f("SlipRatio", "Recovery_rate_during_wheel_spin", 4.0)
	P.slip_max = d.f("SlipRatio", "Maximum", 10.0)

	# estabilidade e ar
	P.h_long = d.f("Stability/WheelForceHeightScales", "Longitudinal_scale_std", 0.5)
	P.h_long_stf = d.f("Stability/WheelForceHeightScales", "Longitudinal_scale_side_decel_to_fwd_accel", 0.5)
	P.h_lat = d.f("Stability/WheelForceHeightScales", "Lateral_scale_std", 0.1)
	P.grav_up = d.f("Stability/InAir", "Gravity_scale_moving_up", 1.0)
	P.grav_down = d.f("Stability/InAir", "Gravity_scale_moving_down", 1.0)
	P.air_yaw_time = d.f("Stability/InAir/Yaw_control", "Minimum_time", 0.3)
	P.air_yaw_acc = deg_to_rad(d.f("Stability/InAir/Yaw_control", "Yaw_acceleration", 60.0))
	P.air_yaw_max = deg_to_rad(d.f("Stability/InAir/Yaw_control", "Maximum_yaw_velocity", 30.0))
	P.air_brk_acc = deg_to_rad(d.f("Stability/InAir/Brake_pitch_control", "Acceleration", 0.0))
	P.air_brk_max = deg_to_rad(d.f("Stability/InAir/Brake_pitch_control", "Maximum_pitch_velocity", 0.0))
	P.air_nt_acc = deg_to_rad(d.f("Stability/InAir/No_throttle_pitch_control", "Acceleration", 0.0))
	P.air_nt_max = deg_to_rad(d.f("Stability/InAir/No_throttle_pitch_control", "Maximum_pitch_velocity", 0.0))
	P.air_pitch_torque = d.f("Stability/InAir", "Pitch_torque", 0.0) * 1000.0
	P.air_lat_time = d.f("Stability/InAir/Lateral_control", "Minimum_time", 0.3)
	P.air_lat_tail = d.f("Stability/InAir/Lateral_control", "Tail_off_time", 2.0)
	P.air_lat_thr = d.f("Stability/InAir/Lateral_control", "Steer_threshold", 0.3)
	P.air_lat_change = d.f("Stability/InAir/Lateral_control", "Steer_change_scale", 0.15)
	P.air_lat_force = d.f("Stability/InAir/Lateral_control", "Maximum_force", 0.0) * 1000.0
	P.ap_th = d.f("Stability/AntiPitch", "Sine_threshold_angle", 0.087)
	P.ap_max = d.f("Stability/AntiPitch", "Sine_maximum_angle", 0.174)
	P.ap_acc = d.f("Stability/AntiPitch", "Acceleration", 0.0)

	# rodas: esquerda = +X (o carro anda pra +Z). Com o arquivo de pontos do
	# jogo, a roda fica onde o jogo põe (WHEEL_FRONT_LEFT...); sem ele, no chute.
	# O modelo não é espelhado aqui, então o lado "esquerdo" do jogo (x < 0)
	# aparece no -X do Godot; a física só precisa saber de que lado cada roda fica.
	wheels.clear()
	var pts := _load_points(points_file)
	points = pts
	update_eye()
	var wpos := {}
	for k in ["FRONT_LEFT", "FRONT_RIGHT", "REAR_LEFT", "REAR_RIGHT"]:
		if pts.has("WHEEL_" + k):
			var pp: Vector3 = pts["WHEEL_" + k] + model_offset
			var side := "Left" if pp.x > 0.0 else "Right"
			var key: String = ("Front" if k.begins_with("FRONT") else "Rear") + side
			wpos[key] = pp
	var from_points := wpos.size() == 4
	var com_z := com.z
	var wb := WHEEL_Z * 2.0
	if from_points:
		wb = (wpos.FrontLeft.z + wpos.FrontRight.z - wpos.RearLeft.z - wpos.RearRight.z) * 0.5
	P.wheelbase = wb
	P.wheels_from_points = from_points
	for info in [["FrontLeft", 1, 1], ["FrontRight", -1, 1], ["RearLeft", 1, -1], ["RearRight", -1, -1]]:
		var path: String = "Wheels/" + info[0]
		var w := {}
		w.front = info[2] > 0
		w.px = WHEEL_X * info[1]
		w.pz = WHEEL_Z * info[2]
		if from_points:
			w.px = wpos[info[0]].x
			w.pz = wpos[info[0]].z
		w.r = d.f(path, "Radius", 0.45)
		w.k = d.tuned(path, "Spring_rate", TUNE_SPRING)
		w.c = d.tuned(path, "Damping_coefficient", TUNE_DAMPING)
		w.min = d.f(path, "Minimum_position", -0.2)
		w.max = d.tuned(path, "Maximum_position", TUNE_SUSP)
		w.vmax = d.f(path, "Maximum_velocity", 10.0)
		w.kc = d.curve(path + "/Normalised_spring_rate_vs_position")
		w.dc = d.curve(path + "/Normalised_damping_coeff_vs_velocity")
		w.mw = d.f(path, "Mass", 0.05) * 1000.0           # massa da roda (kg)
		w.cos_max = d.f(path, "Cosine_maximum_collision_angle", 0.643)
		# peso parado nessa roda -> quanto a mola afunda. y0 = cubo com a mola
		# solta (x = 0); assim o cubo fica em WHEEL_Y com o carro parado
		var share: float = (WHEEL_Z + com_z) / wb if w.front else (WHEEL_Z - com_z) / wb
		var x_static := _solve_static(w, mass * G * share * 0.5)
		w.y0 = WHEEL_Y - x_static
		if from_points:
			w.y0 = wpos[info[0]].y          # cubo com a mola solta = ponto do jogo
		w.x = 0.0                           # curso (0x0e8): + = comprimida, - = esticada
		w.v = 0.0                           # velocidade do curso (0x0f4)
		w.f = 0.0                           # força da mola no carro (N, 0x0fc)
		w.hit = false
		w.jit = 0.0                         # tremida visual do curso (m)
		w.point = Vector3.ZERO
		w.normal = Vector3.UP
		w.spin = 0.0
		w.grip = 1.0                        # escala da elipse (encolhe patinando)
		w.sat = false
		w.fx = 0.0                          # força lateral do passo (N, + = esquerda)
		w.fz = 0.0                          # força longitudinal do passo (N)
		wheels.append(w)
	P.wheel_r = wheels[2].r
	# ordem do jogo (corpo+0x254): FL, RL, FR, RR, com esquerda = x < 0 no modelo
	jit_order = []
	for fl in [[true, true], [false, true], [true, false], [false, false]]:
		for i in wheels.size():
			var w: Dictionary = wheels[i]
			if w.front == fl[0] and (w.px - model_offset.x < 0.0) == fl[1]:
				jit_order.append(i)
	jit_seed = Time.get_ticks_msec() & 0x3FFFFFFF   # o jogo semeia com o relógio
	# 0x20bf58: o jogo mede os eixos a partir da ORIGEM DO MODELO, não do CoM
	# (a média do z das rodas, antes de descontar o centro de massa). Esses
	# valores entram na curvatura, na divisão da força lateral entre os eixos e
	# no ponto onde ela é aplicada (CoM + frente x eixo).
	P.axle_f = (wheels[0].pz + wheels[1].pz) * 0.5 - model_offset.z
	P.axle_r = (wheels[2].pz + wheels[3].pz) * 0.5 - model_offset.z
	reset_drivetrain()


## Mola do jogo (0x248a80): F = k x curva(x normalizado) x x, em kN.
## Normaliza por Maximum_position comprimindo e por Minimum_position esticando;
## esticada (x < 0) com a roda no chão, ela puxa o carro pra baixo.
func _spring(w: Dictionary, x: float) -> float:
	var u := 0.0
	if x >= 0.0 and w.max > 0.0:
		u = x / w.max
	elif x < 0.0 and w.min < 0.0:
		u = x / w.min
	return w.k * VehicleData.sample(w.kc, u) * x * 1000.0


func _damper(w: Dictionary, v: float) -> float:
	return w.c * VehicleData.sample(w.dc, absf(v)) * v * 1000.0


## Arquivo de pontos do modelo: "POINT 1.00", contagem em 0x10, entradas de
## 0x50 bytes a partir de 0x14: nome (0x00..0x20), posição x, y, z (0x20) e
## matriz 3x3 em linhas (0x2c, escala 0.01; o jogo usa normalizada). A linha
## 2 da matriz do A_FRAME_* é o eixo da balança (suspension_visual.gd).
func _load_points(path: String) -> Dictionary:
	var out := {}
	points_rot = {}
	if path == "" or not FileAccess.file_exists(path):
		return out
	var buf := FileAccess.get_file_as_bytes(path)
	if buf.size() < 0x60 or buf.slice(0, 5).get_string_from_ascii() != "POINT":
		push_warning("%s não é um arquivo de pontos" % path)
		return out
	var off := 0x14
	while off + 0x50 <= buf.size():
		var nm := buf.slice(off, off + 0x20).get_string_from_ascii()
		out[nm] = Vector3(buf.decode_float(off + 0x20), buf.decode_float(off + 0x24), buf.decode_float(off + 0x28))
		var rows := []
		for r in 3:
			var o := off + 0x2c + r * 12
			rows.append(Vector3(buf.decode_float(o), buf.decode_float(o + 4), buf.decode_float(o + 8)).normalized())
		points_rot[nm] = Basis(rows[0], rows[1], rows[2])
		off += 0x50
	return out


## 0x23f6c0: soma correções de posição; no mesmo sentido fica a maior
func _add_corr(c: Vector3, d: Vector3) -> Vector3:
	for i in 3:
		if signf(c[i]) == signf(d[i]) or c[i] == 0.0:
			if absf(d[i]) > absf(c[i]):
				c[i] = d[i]
		else:
			c[i] += d[i]
	return c


func _solve_static(w: Dictionary, f_load: float) -> float:
	var lo := 0.0
	var hi: float = w.max
	for i in 40:
		var mid := (lo + hi) * 0.5
		if _spring(w, mid) < f_load:
			lo = mid
		else:
			hi = mid
	return lo


# ------------------------------------------------------------------ visual
func _make_wheel_mesh(w: Dictionary) -> void:
	var pivot := Node3D.new()
	add_child(pivot)
	var spin := Node3D.new()
	pivot.add_child(spin)
	w.pivot = pivot
	w.spin_node = spin
	var path: String = wheel_front_file if w.front else wheel_rear_file
	if path != "" and ResourceLoader.exists(path):
		var mesh: Mesh = load(path) as Mesh
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m is StandardMaterial3D:
				var m2: StandardMaterial3D = m.duplicate()
				m2.cull_mode = MODEL_CULL
				mi.set_surface_override_material(i, m2)
		# component map (14881): Mirror="1" nas rodas da esquerda do jogo,
		# que é o x < 0 do modelo (aqui o modelo não é espelhado)
		if w.px < 0.0:
			mi.scale.x = -1.0
		# centro do modelo = centro da roda (sem deslocamento: matriz da RAM)
		spin.add_child(mi)
		return
	push_warning("Roda não encontrada em %s. Veja docs/assets.md (rodas)." % path)
	var cyl := CylinderMesh.new()
	cyl.top_radius = w.r
	cyl.bottom_radius = w.r
	cyl.height = 0.34
	cyl.radial_segments = 20
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.08, 0.08)
	mat.roughness = 0.9
	cyl.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.rotation_degrees = Vector3(0, 0, 90)
	spin.add_child(mi)
	# um risco claro pra dar pra ver a roda girando
	var mark := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.36, 0.08, w.r * 1.6)
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.35, 0.35, 0.35)
	bm.material = mm
	mark.mesh = bm
	spin.add_child(mark)


func _load_model() -> void:
	var mi := MeshInstance3D.new()
	var mesh: Mesh = null
	if model_path != "" and ResourceLoader.exists(model_path):
		mesh = load(model_path) as Mesh
	if mesh == null:
		push_warning("Modelo não encontrado em %s. Copie a pasta renegade pra assets/renegade." % model_path)
		var bm := BoxMesh.new()
		bm.size = Vector3(2.2, 1.0, 4.6)
		mi.mesh = bm
		mi.position = Vector3(0, 1.0, 0)
		model_root.add_child(mi)
		return
	mi.mesh = mesh
	# pintura: a carroceria usa a textura "white", que o jogo gera em tempo
	# real juntando camadas (Base/Primary/Secondary/Detail + cores do XML).
	# O gerar_pintura.py faz isso e salva pintura.png do lado do modelo.
	var livery: Texture2D = null
	var lp := model_path.get_base_dir().path_join(livery_file)
	if ResourceLoader.exists(lp):
		livery = load(lp)
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		var m2: StandardMaterial3D
		if m is StandardMaterial3D:
			m2 = m.duplicate()
		else:
			m2 = StandardMaterial3D.new()
			m2.albedo_color = Color(0.85, 0.85, 0.85)
		if livery and m and m.resource_name.ends_with("_white"):
			m2.albedo_texture = livery
		m2.cull_mode = MODEL_CULL
		mi.set_surface_override_material(i, m2)
	var aabb := mesh.get_aabb()
	var c := aabb.get_center()
	model_offset = Vector3(-c.x, -aabb.position.y + 0.12, -c.z)
	mi.position = model_offset
	model_root.add_child(mi)
	_load_steering_wheel()


func _load_steering_wheel() -> void:
	var path := model_path.get_basename() + "_volante.obj"
	if not ResourceLoader.exists(path):
		return
	var vol: Dictionary = pecas.get("volante", {})
	if vol.has("centro"):
		SW_CENTER = Vector3(vol.centro[0], vol.centro[1], vol.centro[2])
		SW_AXIS = Vector3(vol.eixo[0], vol.eixo[1], vol.eixo[2])
	var mesh := load(path) as Mesh
	if mesh == null:
		return
	sw_pivot = Node3D.new()
	sw_pivot.position = model_offset + SW_CENTER
	model_root.add_child(sw_pivot)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = -SW_CENTER
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		var m2: StandardMaterial3D = m.duplicate() if m is StandardMaterial3D else StandardMaterial3D.new()
		m2.cull_mode = MODEL_CULL
		mi.set_surface_override_material(i, m2)
	sw_pivot.add_child(mi)


func driver_eye() -> Vector3:
	return model_root.get_global_transform_interpolated() * (model_offset + DRIVER_EYE)


# câmera de primeira pessoa (não existe no jogo; é do remake). O olho fica
# centralizado atrás do volante de cada carro (pecas.json, tools/volante.py):
# FP_UP acima e FP_BACK atrás do centro do aro. Sem volante, usa o banco
# (ponto ARSE + EYE_FROM_ARSE, medido no Renegade).
# Calibrado pelos prints dos 12 carros contra a referência do Matheus (cockpit
# de rally: volante grande embaixo, painel e pista pelo para-brisa)
var FP_FOV := 65.0            # graus na vertical (KEEP_HEIGHT)
var FP_PITCH := 0.25          # quanto olha pra baixo (componente -y da direção, ~14°)
var FP_NEAR := 0.05
var FP_UP := 0.25             # olho acima do centro do volante (m)
var FP_BACK := 0.50           # olho atrás do centro do volante (m)
var FP_VOLANTE := true        # olho pelo volante (false = pelo banco)


## posição do olho no frame do modelo (chame de novo se mudar FP_*)
func update_eye() -> void:
	var vol: Dictionary = pecas.get("volante", {})
	if FP_VOLANTE and vol.has("centro"):
		var c := Vector3(vol.centro[0], vol.centro[1], vol.centro[2])
		DRIVER_EYE = c + Vector3(0.0, FP_UP, -FP_BACK)
	elif points.has("ARSE"):
		DRIVER_EYE = points["ARSE"] + EYE_FROM_ARSE


## transform da câmera de primeira pessoa (mundo, interpolado)
func first_person_xf() -> Transform3D:
	var eye: Vector3 = driver_eye()
	var b: Basis = get_global_transform_interpolated().basis
	var turn: float = steer / MAX_STEER
	var look_dir: Vector3 = (b.z + b.x * turn * 0.25 - b.y * FP_PITCH).normalized()
	return Transform3D(Basis.looking_at(look_dir, b.y), eye)


func flip_model() -> void:
	model_root.rotation.y = PI - model_root.rotation.y


func forward() -> Vector3:
	return global_transform.basis.z


func reset_to(pos: Vector3, yaw: float) -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	reset_physics_interpolation()   # teleporte: não interpolar do lugar antigo
	reset_drivetrain()


func reset_drivetrain() -> void:
	drive_slip = 0.0
	gear = 1
	shift_to = 1
	rpm = P.get("idle", 1000.0)
	clutch = 0.0
	cstate = 0
	shift_flag = false
	shift_timer = 0.0
	lim_k = 1.0
	eng_torque = 0.0
	clutch_t = 0.0
	want_rev = false
	limiter = false
	throttle = 0.0
	brake_in = 0.0


func gear_label() -> String:
	if shift_to != gear:
		return "-"
	if gear == -1:
		return "R"
	if gear == 0:
		return "N"
	return str(gear)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_M:
				manual = not manual
			KEY_P:
				use_ported = not use_ported
			KEY_L:
				lateral_game = not lateral_game
			KEY_E, KEY_PAGEUP:
				if manual:
					if gear == -1:
						want_rev = false
						_start_shift(1)
					elif gear < gears.size() - 1:
						_start_shift(gear + 1)
			KEY_Q, KEY_PAGEDOWN:
				if manual:
					if gear > 1:
						_start_shift(gear - 1)
					elif gear == 1:
						want_rev = true       # no jogo, abaixo da 1ª vem a ré
						_start_shift(-1)


# ------------------------------------------------------------------ física
func _physics_process(dt: float) -> void:
	# ---- comandos
	var thr_raw := 0.0
	var brk_raw := 0.0
	var st_raw := 0.0
	var handbrake := false
	if test_input != null:
		thr_raw = test_input.get("thr", 0.0)
		brk_raw = test_input.get("brk", 0.0)
		st_raw = test_input.get("steer", 0.0)
		handbrake = test_input.get("hb", false)
	else:
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			thr_raw = 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			brk_raw = 1.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			st_raw += 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			st_raw -= 1.0
		handbrake = Input.is_physical_key_pressed(KEY_SPACE)
		if Input.get_connected_joypads().size() > 0:
			thr_raw = maxf(thr_raw, Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT))
			brk_raw = maxf(brk_raw, Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT))
			var ax := -Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
			if absf(ax) > 0.12:
				st_raw = ax

	var b := global_transform.basis
	var up := b.y
	var fwd_body := b.z
	var v_body_f := linear_velocity.dot(fwd_body)

	# ré: segurando freio parado engata a ré; na ré os pedais se invertem
	if want_rev:
		if thr_raw > 0.1 and v_body_f > -0.5:
			want_rev = false
			if manual:
				_start_shift(1)
		else:
			var t := thr_raw
			thr_raw = brk_raw
			brk_raw = t
	elif brk_raw > 0.5 and thr_raw < 0.1 and absf(v_body_f) < 0.6:
		reverse_hold += dt
		if reverse_hold > 0.25:
			want_rev = true
			if manual:
				_start_shift(-1)
			reverse_hold = 0.0
	else:
		reverse_hold = 0.0

	throttle = move_toward(throttle, thr_raw, dt * (P.thr_up if thr_raw > throttle else P.thr_down))
	brake_in = move_toward(brake_in, brk_raw, dt * (P.brk_up if brk_raw > brake_in else P.brk_down))
	var st_rate: float = P.st_up
	if st_raw == 0.0 or absf(st_raw) < absf(steer):
		st_rate = P.st_down
	if st_raw != 0.0 and steer != 0.0 and signf(st_raw) != signf(steer):
		st_rate = P.st_opp
	steer = move_toward(steer, st_raw, dt * st_rate)

	# ---- suspensão portada (0x248768 contato, 0x248a80 mola, 0x2484c8 roda)
	# Cada roda tem curso x e velocidade v próprios. A roda só "pega" no chão se
	# na posição atual dela ela encosta; aí o curso sobe até a superfície, a
	# velocidade vem do carro no ponto da roda e a força sai ao longo da normal
	# do chão, no ponto de fixação da roda.
	var space := get_world_3d().direct_space_state
	var com_w := global_transform * center_of_mass
	grounded = 0
	var n_sum := Vector3.ZERO
	var rear_g := 0
	var h_sum := 0.0
	var corr := Vector3.ZERO                # correção de posição (batente), 0x23f6c0
	for w in wheels:
		var attach: Vector3 = global_transform * Vector3(w.px, w.y0, w.pz)
		var top: Vector3 = global_transform * Vector3(w.px, w.y0 + w.max, w.pz)
		var reach: float = (w.max - w.min) + w.r + 0.05
		var q := PhysicsRayQueryParameters3D.create(top, top - up * reach)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		w.hit = false
		var pen := 0.0
		if not hit.is_empty():
			var hn0: Vector3 = hit.normal
			# distância do ponto de fixação até o chão, e quanto a roda (no
			# curso atual) entra nele
			var d0: float = top.distance_to(hit.position) - w.max
			pen = (w.r - w.x) - d0
			w.hit = pen > 0.0 and hn0.dot(up) >= w.cos_max
		if not w.hit:
			w.f = 0.0
			continue
		var hp: Vector3 = hit.position
		var hn: Vector3 = hit.normal
		w.point = hp
		w.normal = hn
		grounded += 1
		n_sum += hn
		if not w.front:
			rear_g += 1
		h_sum += (com_w - hp).dot(up)
		w.x += pen
		if w.x > w.max:
			# batente: o jogo empurra o carro pra fora, sem mexer na velocidade
			corr = _add_corr(corr, hn * (w.x - w.max))
			w.x = w.max
		var vp: Vector3 = linear_velocity + angular_velocity.cross(attach - com_w)
		w.v = clampf(-hn.dot(vp) * hn.dot(up), -w.vmax, w.vmax)
		var f_s: float = _spring(w, w.x) + _damper(w, w.v)
		w.f = f_s
		apply_force(hn * f_s, attach - global_position)

	var ground_n := up if grounded == 0 else n_sum.normalized()
	var fwd := (fwd_body - ground_n * fwd_body.dot(ground_n)).normalized()
	var left := ground_n.cross(fwd)
	var v := linear_velocity
	var v_f := v.dot(fwd)
	var spd := v.length()
	if grounded > 0:
		spd_ground = (v - ground_n * v.dot(ground_n)).length()   # no ar fica o último

	# ---- motor e câmbio
	var driven_g := rear_g if REAR_DRIVE else grounded
	var drive := _drivetrain(dt, v_f, driven_g > 0, handbrake)

	if grounded > 0:
		air_time = 0.0
		air_lat_state = 0
		air_lat_scale = 1.0
		gravity_scale = 1.0
		if use_ported:
			_tires(dt, v, fwd, left, ground_n, com_w, h_sum / grounded, drive, handbrake)
		else:
			_tires_legacy(dt, v, fwd, left, ground_n, com_w, h_sum / grounded, drive, handbrake)
		# 0x20e160: no chão o jogo anula a parte da gravidade que puxa o carro
		# de lado num barranco, aplicada na altura do chão (vira rolagem)
		var g_side: float = mass * G * Vector3.DOWN.dot(left)
		apply_force(-left * g_side, com_w - ground_n * (h_sum / grounded) - global_position)
		# 0x2100a0 anti-pitch: passou de ~5° de arfagem em relação ao chão,
		# acelera de volta (cheio a ~10°)
		var s_p: float = -up.dot(fwd)
		if P.ap_acc != 0.0 and absf(s_p) > P.ap_th:
			var a_p: float = P.ap_acc
			if absf(s_p) < P.ap_max:
				a_p *= (absf(s_p) - P.ap_th) / (P.ap_max - P.ap_th)
			apply_torque(b.x * inertia.x * a_p * signf(s_p))
	else:
		# no ar (0x20e160 gravidade, 0x2100a0 torque de arfagem, 0x2129c0 controles)
		air_time += dt
		gravity_scale = P.grav_up if v.dot(Vector3.UP) > 0.0 else P.grav_down
		apply_torque(b.x * P.air_pitch_torque)
		var wl := b.transposed() * angular_velocity
		# guinada: só depois de um tempo no ar, proporcional à direção
		if air_time > P.air_yaw_time and steer != 0.0:
			var tgt: float = steer * P.air_yaw_max
			var acc_y: float = steer * P.air_yaw_acc * dt
			if not (signf(wl.y) == signf(tgt) and absf(tgt) < absf(wl.y)):
				if (tgt > 0.0 and wl.y + acc_y > tgt) or (tgt < 0.0 and wl.y + acc_y < tgt):
					acc_y = tgt - wl.y
				apply_torque(b.y * inertia.y * acc_y / dt)
		# empurrão lateral: virando forte no ar, uma força de lado que some em 2 s
		if air_time > P.air_lat_time:
			if air_lat_state == 0:
				if absf(steer) >= P.air_lat_thr:
					air_lat_state = 1 if steer < 0.0 else 2
					air_lat_timer = P.air_lat_tail
			elif air_lat_timer > 0.0:
				air_lat_timer -= dt
				var old_state := air_lat_state
				if steer < 0.0:
					air_lat_state = 1
				elif steer > 0.0:
					air_lat_state = 2
				if old_state != air_lat_state:
					air_lat_scale *= P.air_lat_change
				apply_central_force(left * steer * P.air_lat_force * (air_lat_timer / P.air_lat_tail) * air_lat_scale)
		# arfagem: freando o bico desce; sem acelerar também (mais devagar)
		var tgt_p := 0.0
		var acc_p := 0.0
		if brake_in > 0.0:
			tgt_p = P.air_brk_max
			acc_p = brake_in * P.air_brk_acc * dt
		if throttle == 0.0:
			tgt_p = maxf(tgt_p, P.air_nt_max)
			acc_p = maxf(acc_p, P.air_nt_acc * dt)
		if acc_p != 0.0 and not (signf(wl.x) == signf(tgt_p) and absf(tgt_p) < absf(wl.x)):
			if tgt_p > 0.0 and wl.x > 0.0 and wl.x + acc_p > tgt_p:
				acc_p = tgt_p - wl.x
			apply_torque(b.x * inertia.x * acc_p / dt)

	# resistência angular do jogo (amortece rolagem e arfagem)
	var w_loc := b.transposed() * angular_velocity
	var res_loc: Vector3 = -Vector3(inertia.x * P.ang_res.x * w_loc.x, inertia.y * P.ang_res.y * w_loc.y, inertia.z * P.ang_res.z * w_loc.z)
	apply_torque(b * res_loc)

	# arrasto do ar
	apply_central_force(-v * spd * P.air_drag * 0.65)

	# 0x2484c8: curso de cada roda anda com a massa dela. No ar a mola e o
	# amortecedor levam a roda de volta pro meio (x = 0)
	for w in wheels:
		var fw: float
		if w.hit:
			fw = -w.f
		else:
			var damp: float = -_damper(w, w.v)
			var dv: float = damp / w.mw * dt
			if absf(dv) > absf(w.v) and absf(dv) > 1e-6:
				damp *= absf(w.v / dv)
			fw = -_spring(w, w.x) + damp
		w.v = clampf(w.v + fw / w.mw * dt, -w.vmax, w.vmax)
		w.x = clampf(w.x + w.v * dt, w.min, w.max)
	if corr != Vector3.ZERO:
		global_position += corr
	# 0x20c278: de ré no chão, a velocidade para no limite do jogo
	if grounded > 0 and v_f < -P.rev_limit * MPH:
		linear_velocity -= fwd * (v_f + P.rev_limit * MPH)

	jit_acc += dt
	while jit_acc >= 1.0 / JIT_HZ:
		jit_acc -= 1.0 / JIT_HZ
		_wheel_jitter()
	_update_visuals(dt, v_f)


## 0x202760: sorteia a tremida das rodas no chão (FL, RL, FR; RR = RL)
func _wheel_jitter() -> void:
	for w in wheels:
		w.jit = 0.0
	if jit_order.size() != 4:
		return
	for k in 3:
		var w: Dictionary = wheels[jit_order[k]]
		if not w.hit:
			continue
		var amp := minf(surface_jitter * JIT_K * spd_ground, 1.0)
		jit_seed = (jit_seed * 31415821 + 1) & 0x3FFFFFFF
		w.jit = amp * (float(jit_seed) * 0.075 / 1073741824.0 - 0.0375)
	wheels[jit_order[3]].jit = wheels[jit_order[1]].jit


# ------------------------------------------------------------------ pneus
## Parte 1 portada do executável do jogo. Ordem igual à do jogo:
##   0x20ede8  curvatura pedida pela direção (com subesterço)
##   0x20e8d8  força de tração por roda
##   0x20eb98  força de freio por roda (com divisão frente/trás)
##   0x20efa0  derrapagem: força lateral total + torque de guinada, divididos
##             entre eixo dianteiro e traseiro
##   0x2101e0  elipse de atrito por roda, com a aderência que encolhe quando
##             a roda satura e volta quando ela para de saturar
## Unidades do jogo: mph (x 0.44694445 = 1609/3600) e graus.
const MPH_G := 0.44694445
const DEG := 0.017453294

func _tires(dt: float, v: Vector3, fwd: Vector3, left: Vector3, n: Vector3, com_w: Vector3,
		h: float, drive: float, handbrake: bool) -> void:
	var v_f := v.dot(fwd)                   # 0x418
	var v_l := v.dot(left)                  # 0x410 (+ = esquerda)
	var v_p := sqrt(v_f * v_f + v_l * v_l)  # 0x440 velocidade no plano do chão
	var mph := v_p / MPH_G
	var mu := SURFACE_MU                    # 0x780 atrito médio das rodas no chão
	var yaw := angular_velocity.dot(n)      # + = virando pra esquerda
	var sgn_v := -1.0 if v_f < 0.0 else 1.0
	stf_blend = 0.0

	# ângulo de derrapagem atual (0x6c0): direção da velocidade em relação ao bico
	sideslip = asin(clampf(v_l / v_p, -1.0, 1.0)) if v_p >= 0.316 else 0.0

	# ---- 0x20ede8: curvatura. Subesterço entra como U * v² * 0.001
	var delta: float = steer * VehicleData.sample(steer_curve, mph) * DEG
	var kappa: float = delta / ((P.axle_f - P.axle_r) + v_p * v_p * P.understeer_raw * 0.001)
	if absf(v_f) < 0.223472:
		kappa *= absf(v_f) / 0.223472

	# rodas no chão por eixo
	var nf := 0
	var nr := 0
	for w in wheels:
		w.fx = 0.0
		w.fz = 0.0
		if w.hit:
			if w.front:
				nf += 1
			else:
				nr += 1

	# O jogo divide as forças pelo número FIXO de rodas de cada eixo (0x3a0,
	# 0x3a4, 0x3a8), não pelas que estão no chão. Tração e freio só vão pras
	# rodas no chão (a parte da roda no ar some); a força da derrapagem vai pras
	# 4 rodas sempre, no chão ou não.
	var nf_s := 0
	var nr_s := 0
	for w in wheels:
		if w.front:
			nf_s += 1
		else:
			nr_s += 1

	# ---- 0x20e8d8: tração (só rodas motrizes no chão)
	var n_drive := nr_s if REAR_DRIVE else nf_s + nr_s
	if n_drive > 0:
		for w in wheels:
			if w.hit and (not w.front or not REAR_DRIVE):
				w.fz += drive / n_drive

	# ---- 0x20eb98: freio. Desaceleração máxima (mph/s) x escala do chão,
	# nunca mais do que o necessário pra parar neste passo
	var brk := brake_in if not handbrake else maxf(brake_in, 0.4)
	if brk > 0.0 and (nf + nr) > 0:
		var dmax: float = brk * MPH_G * P.brake_decel * VehicleData.triple(P.brake_fscale, mu)
		var dec: float = -v_f / dt if absf(v_f) < dmax * dt else dmax * -sgn_v
		var dec_front: float = P.front_bias * dec
		if handbrake:
			dec_front = 0.0                 # freio de mão só atrás
		for w in wheels:
			if not w.hit:
				continue
			if w.front:
				w.fz += mass * dec_front / nf_s
			else:
				w.fz += mass * (dec - dec_front) / nr_s

	# ---- 0x20efa0: derrapagem
	var f_cent: float = mass * v_p * v_p * kappa          # força centrípeta pedida
	var ss_deg := absf(sideslip) / DEG
	# alvo de derrapagem: acima de Speed_for_zero_sideslip o bico aponta pra dentro
	# (proporcional à direção); abaixo disso é a geometria do eixo traseiro
	var target := 0.0
	if mph > P.ss_full:
		target = P.ss_max * DEG * -steer
	elif mph > P.ss_zero:
		target = (mph - P.ss_zero) / (P.ss_full - P.ss_zero) * P.ss_max * DEG * -steer
	else:
		if v_p > 1e-6:
			target = asin(clampf(absf(P.axle_r) * kappa, -1.0, 1.0))
		target *= 1.0 - mph / P.ss_zero
		if v_f < 0.0:
			target = -target
	if mph < 5.0:
		target *= mph / 5.0
	var err := target - sideslip
	var w_err := sgn_v * v_p * kappa - yaw                 # falta de giro pra seguir a curva
	var low: bool = mph <= P.ss_zero
	var f_lat := 0.0
	var torque := 0.0
	var f_fwd := 0.0
	# forças externas no plano (gravidade na rampa + tração/freio já somados)
	var g_vec := Vector3.DOWN * 9.81 * gravity_scale * mass
	var sum_x: float = g_vec.dot(left)
	var sum_z: float = g_vec.dot(fwd)
	for w in wheels:
		sum_z += w.fz

	if sideslip * target >= 0.0 or low:
		if absf(sideslip) < absf(target):
			# A) derrapagem crescendo até o alvo
			f_lat = f_cent
			var path := 0.0
			if v_p > 1e-6:
				path = sgn_v * ((v_f * (f_cent + sum_x) - v_l * sum_z) / mass / (v_p * v_p) - yaw)
			var rate: float = VehicleData.fcurve_eval(P.yaw_inc, mu, mph) * DEG
			var acc: float = rate * signf(err) * sgn_v
			var err_deg := absf(err) / DEG
			if signf(path) == signf(err) and err_deg < P.tail_off:
				# chegando no alvo: rampa em cosseno (Increase_tail_off_threshold)
				acc *= (cos((P.tail_off - err_deg) / P.tail_off * PI) + 1.0) * 0.5
				if steer != 0.0:
					var k := maxf((10.0 - err_deg) / 10.0, 0.0)
					acc = (1.0 - k) * acc + k * (-w_err / dt)
			var step := -acc * dt
			if low:
				var s1 := signf(step + yaw)
				var s2 := signf(steer * sgn_v)
				if s1 == -s2:
					step = w_err
					if absf(yaw) >= 0.5 * DEG:
						step = -0.25 * yaw
			var cap: float = P.yaw_acc * dt
			step = clampf(step, -cap, cap)
			torque = inertia.y * step / dt
		else:
			# B) passou do alvo: segura a velocidade lateral no ângulo alvo
			var decel: float = VehicleData.triple(P.side_std, mu) * MPH_G
			var vt := tan(target) * absf(v_f)
			var a: float = (vt - v_l) / dt if absf(vt - v_l) < decel * dt else decel * -signf(v_l)
			var f_side := mass * a
			f_fwd = _side_to_fwd(f_side, ss_deg)
			f_lat = f_cent + f_side
			var lim: float = dt * lerpf(VehicleData.fcurve_eval(P.yaw_dec_zero, mu, mph),
				VehicleData.fcurve_eval(P.yaw_dec_full, mu, mph), throttle) * DEG
			torque = inertia.y * clampf(w_err, -lim, lim) / dt
	else:
		# C) derrapando pro lado contrário (contra-esterço)
		var fc := f_cent
		fc = 0.0 if ss_deg > 5.0 else fc * (5.0 - ss_deg) / 5.0
		var decel: float = VehicleData.triple(P.side_cs, mu) * MPH_G
		var vv := v_l + fc / mass * dt
		var a: float = -vv / dt if absf(vv) < decel * dt else decel * -signf(vv)
		var f_side := mass * a
		f_fwd = _side_to_fwd(f_side, ss_deg)
		f_lat = fc + f_side
		var rate: float = signf(err) * VehicleData.fcurve_eval(P.yaw_dec_cs, mu, mph) * DEG
		var s := 1.0
		if ss_deg < P.cs_scale_ss:
			s = (ss_deg / P.cs_scale_ss) * (ss_deg / P.cs_scale_ss)
		s *= throttle
		var cap: float = P.yaw_acc * ((1.0 - s) + s * P.cs_scale)
		rate = clampf(rate, -cap, cap)
		if v_f < 0.0:
			rate = -rate
		torque = inertia.y * -rate

	# divide força lateral e torque entre os eixos (estática de bicicleta)
	var a_f: float = P.axle_f
	var b_r: float = P.axle_r
	var span := a_f - b_r
	if v_f < 0.0:
		f_fwd = 0.0
	var n_all := nf_s + nr_s
	for w in wheels:
		if w.front:
			w.fx += (-b_r / span) * (f_lat + torque / -b_r) / nf_s
		else:
			w.fx += (a_f / span) * (f_lat - torque / a_f) / nr_s
		w.fz += f_fwd / n_all

	# ---- 0x2101e0: elipse de atrito por roda
	var lat_dem := 0.0
	var lat_got := 0.0
	for w in wheels:
		var e: Dictionary = P.ell_FrontWheels if w.front else P.ell_RearWheels
		var W: float = w.grip * VehicleData.triple(e.w, mu) * P.width_scale * 1000.0
		var H: float = w.grip * VehicleData.triple(e.h, mu) * P.height_scale * 1000.0
		var fx: float = w.fx
		var fz: float = w.fz
		var clamped := false
		if absf(fx) < 0.01:
			if absf(fz) > H:
				w.fz = fz * H / absf(fz)
				clamped = true
		elif absf(fz) < 0.01:
			if absf(fx) > W:
				w.fx = fx * W / absf(fx)
				clamped = true
		else:
			var t := fz / fx
			var lim := 1.0 / sqrt(1.0 / (W * W) + t * t / (H * H))
			if lim < absf(fx):
				var k := lim / absf(fx)
				w.fx = fx * k
				w.fz = fz * k
				clamped = true
		var min_scale: float = VehicleData.triple(e.ms, mu)
		if handbrake and not w.front:
			min_scale *= P.ps_ellipse
			clamped = true                    # powerslide: traseira escorrega
		w.sat = clamped
		lat_dem += absf(fx)
		lat_got += absf(w.fx)
		if clamped:
			w.grip = maxf(w.grip - e.shrink * dt, min_scale)
		else:
			w.grip = minf(w.grip + e.recover * dt, 1.0)


	# ---- 0x2101e0: patinada. Roda de tração saturada acelerando: a patinada cresce
	# (Growth_rate_during_wheel_spin) até onde o motor consegue girar; roda dentro
	# da elipse: volta (Recovery_rate_during_wheel_spin)
	var spin_sat := false
	for w in wheels:
		if w.hit and (not w.front or not REAR_DRIVE) and w.sat and w.fz * v_f > 0.0 and throttle > 0.05:
			spin_sat = true
	if spin_sat and gear >= 1 and absf(v_f) > 0.5:
		# giro de referência do jogo: o máximo da curva do motor (9000); virando
		# forte abaixo de 40 mph, 95% do limitador
		var ref_rpm: float = drive_curve["max"]
		if absf(steer) > 0.5 and absf(v_f) < 40.0 * MPH:
			ref_rpm = P.lim_on * 0.95
		var lim_slip: float = ref_rpm * RPM2RAD * P.wheel_r / (absf(_ratio(gear)) * absf(v_f)) - 1.0
		drive_slip = minf(drive_slip + P.slip_grow * dt, minf(lim_slip, P.slip_max))
	else:
		drive_slip = maxf(drive_slip - P.slip_recover * dt, 0.0)
	drive_slip = maxf(drive_slip, 0.0)

	# ---- 0x210ce0: limite da velocidade de derrapagem. Com as forças que
	# sobraram depois da elipse, calcula quão rápido o ângulo de derrapagem vai
	# mudar (curva da trajetória - giro do carro). Se passar do máximo do XML
	# (MaximumRate), o jogo mexe direto no giro do carro. É isso que segura o
	# carro de rodar quando a traseira solta.
	if grounded > 0:
		var sx := 0.0
		var sz := 0.0
		for w in wheels:
			sx += w.fx
			sz += w.fz
		var yaw_now := angular_velocity.dot(n)
		var beta_rate: float = -yaw_now * sgn_v
		if v_p > 1e-6:
			beta_rate = ((v_f * sx - v_l * sz) / mass / (v_p * v_p) - yaw_now) * sgn_v
		# baixa velocidade: o giro não passa de v / distância até a roda da frente
		if v_f > 0.0 and v_p < 30.0 * MPH_G and steer != 0.0 and yaw_now * steer > 0.0:
			var fw: Dictionary = wheels[0] if steer > 0.0 else wheels[1]
			var r_fw := Vector3(fw.px, 0.0, fw.pz) - Vector3(center_of_mass.x, 0.0, center_of_mass.z)
			var dir_loc := Vector3(v_l, 0.0, v_f).normalized()
			if dir_loc.dot(r_fw.normalized()) < 0.8660254:
				var cap_w: float = v_p / r_fw.length()
				if absf(yaw_now) > cap_w:
					angular_velocity += n * (signf(steer) * cap_w - yaw_now)
					yaw_now = signf(steer) * cap_w
		if absf(v_f) > 2.0:
			var ss_d: float = absf(sideslip) / DEG
			var growing: bool = beta_rate * sideslip > 0.0
			var mr: float = VehicleData.fcurve_eval(P.ss_rate_inc if growing else P.ss_rate_dec, mu, ss_d)
			if handbrake and growing:
				mr = VehicleData.sample(ps_rate, ss_d)     # powerslide: curva própria
			if absf(beta_rate) > mr * DEG:
				var ex: float = beta_rate - signf(beta_rate) * mr * DEG
				if ex * yaw_now > 0.0:
					ex = 0.0
				elif absf(yaw_now) < absf(ex):
					ex = -yaw_now
				if absf(v_f) < 20.0:
					ex *= (absf(v_f) - 2.0) / 18.0
				if ex != 0.0:
					angular_velocity += n * (sgn_v * ex)

	# ---- 0x211b58: aplica as forças de cada roda. O jogo põe a força no meio
	# do eixo dela (na linha do carro), numa altura = soma das alturas do contato
	# das rodas desse eixo (em relação ao CoM) x a escala do XML. É daí que sai a
	# guinada (eixo da frente x eixo de trás) e o quanto o carro afunda/agacha.
	var sum_f := 0.0
	var sum_r := 0.0
	for w in wheels:
		var hy: float = w.y0 + w.x - w.r - center_of_mass.y
		if w.front:
			sum_f += hy
		else:
			sum_r += hy
	var hl: float = stf_blend * P.h_long_stf + (1.0 - stf_blend) * P.h_long
	var base := com_w - global_position
	var lat_sum := 0.0
	for w in wheels:
		var az: float = P.axle_f if w.front else P.axle_r
		var sy: float = sum_f if w.front else sum_r
		if w.fx != 0.0:
			if lateral_game:
				apply_force(left * w.fx, base + n * (sy * P.h_lat) + fwd * az)
			else:
				lat_sum += w.fx
		if w.fz != 0.0:
			apply_force(fwd * w.fz, base + n * (sy * hl) + fwd * az)
	if not lateral_game:
		# modo antigo (remendo da parte 1): lateral toda no CoM e a guinada que o
		# jogo pediu aplicada direto, cortada na proporção que a elipse cortou
		var keep := 1.0 if lat_dem < 1.0 else lat_got / lat_dem
		apply_force(left * lat_sum, base + n * (sum_r * P.h_lat))
		apply_torque(n * torque * keep)

	# atrito interno (só sem acelerar): o carro perde velocidade sozinho
	if throttle < 0.05 and absf(v_f) > 0.1:
		# 0x20e5e8: abaixo da velocidade mínima vale a desaceleração mínima
		var k2 := clampf((absf(mph) - P.ifd_lo_speed) / (P.ifd_hi_speed - P.ifd_lo_speed), 0.0, 1.0)
		var dec2: float = lerpf(P.ifd_lo, P.ifd_hi, k2) * MPH
		apply_central_force(-fwd * sgn_v * minf(dec2 * mass, mass * absf(v_f) / dt))


## Modelo anterior (palpites meus), mantido pra comparar com o portado.
## Tecla P alterna entre os dois.
func _tires_legacy(dt: float, v: Vector3, fwd: Vector3, left: Vector3, ground_n: Vector3,
		com_w: Vector3, h: float, drive: float, handbrake: bool) -> void:
	var v_f := v.dot(fwd)
	var v_l := v.dot(left)
	var spd := v.length()
	var spd_mph := spd / MPH
	var front_g := 0
	var rear_g := 0
	for w in wheels:
		if w.hit:
			if w.front:
				front_g += 1
			else:
				rear_g += 1
	var frac_f := front_g * 0.5
	var frac_r := rear_g * 0.5
	var cap_long: float = P.ell_h_f * frac_f + P.ell_h_r * frac_r
	var cap_drive: float = P.ell_h_r * frac_r if REAR_DRIVE else cap_long
	var cap_lat: float = P.ell_w_f * frac_f + P.ell_w_r * frac_r * (P.ps_ellipse * 0.6 if handbrake else 1.0)
	var f_long := clampf(drive, -cap_drive, cap_drive)
	var brk := brake_in if not handbrake else maxf(brake_in, 0.4)
	if brk > 0.0:
		var fb: float = P.brake_decel * MPH * mass * brk
		fb = minf(fb, mass * absf(v_f) / dt)
		f_long -= signf(v_f) * fb
	var f_lat := -mass * v_l / dt
	var lat_max: float = P.legacy_side_decel * mass * (grounded / 4.0)
	f_lat = clampf(f_lat, -lat_max, lat_max)
	var ex := f_long / maxf(cap_long, 1.0)
	var ey := f_lat / maxf(cap_lat, 1.0)
	var e := sqrt(ex * ex + ey * ey)
	if e > 1.0:
		f_long /= e
		f_lat /= e
	var ss_l := atan2(-v_l, absf(v_f)) if spd > 1.0 else 0.0
	sideslip = -ss_l
	var ss := absf(ss_l)
	var stf_min := deg_to_rad(P.side_to_fwd_min)
	var stf_max := deg_to_rad(P.side_to_fwd_max)
	if throttle > 0.0 and ss > stf_min and v_f > 0.0:
		var k := clampf((ss - stf_min) / (stf_max - stf_min), 0.0, 1.0)
		f_long += absf(f_lat) * P.side_to_fwd * k * throttle
	if throttle < 0.05 and absf(v_f) > 0.1:
		var k2 := clampf((spd_mph - P.ifd_lo_speed) / (P.ifd_hi_speed - P.ifd_lo_speed), 0.0, 1.0)
		var dec: float = lerpf(P.ifd_lo, P.ifd_hi, k2) * MPH
		dec *= clampf(spd_mph / P.ifd_lo_speed, 0.3, 1.0)
		f_long -= signf(v_f) * minf(dec * mass, mass * absf(v_f) / dt)
	apply_force(fwd * f_long, com_w - ground_n * h * P.h_long - global_position)
	apply_force(left * f_lat, com_w - ground_n * h * P.h_lat - global_position)

	var ang: float = deg_to_rad(VehicleData.sample(steer_curve, spd_mph)) * steer
	var yaw_target: float = v_f * ang / (P.wheelbase + P.understeer * v_f * v_f)
	var yaw_rate := angular_velocity.dot(ground_n)
	var acc_max: float = P.yaw_acc
	if spd > 2.0 and v_f > 0.0:
		var ss_lim: float = deg_to_rad(P.ss_max) * clampf((spd_mph - P.ss_zero) / (P.ss_full - P.ss_zero), 0.0, 1.0)
		var w_path := (f_lat / mass) / maxf(v_f, 1.0)
		var s_deg := rad_to_deg(ss)
		var dir := signf(yaw_target)
		if dir != 0.0:
			var into := ss_l * dir
			var into_deg := rad_to_deg(maxf(into, 0.0))
			var rate: float
			if handbrake:
				rate = deg_to_rad(VehicleData.sample(ps_rate, into_deg) * VehicleData.sample(ps_scale, spd_mph))
			else:
				rate = deg_to_rad(lerpf(VehicleData.sample(rate_inc_min, into_deg), VehicleData.sample(rate_inc_max, into_deg), mu_t)) * lerpf(1.0, 0.65, 0.5)
				if into > ss_lim:
					rate *= clampf(1.0 - (into - ss_lim) / (deg_to_rad(P.tail_off) * 0.65), 0.0, 1.0)
			var allowed := maxf(0.0, w_path * dir + rate)
			yaw_target = dir * minf(absf(yaw_target), allowed)
		if ss > 0.01:
			var sg := signf(ss_l)
			var dec_rate := deg_to_rad(lerpf(VehicleData.sample(rate_dec_min, s_deg), VehicleData.sample(rate_dec_max, s_deg), mu_t))
			if sg * yaw_target < sg * w_path - dec_rate:
				yaw_target = w_path - sg * dec_rate
		var dw0 := yaw_target - yaw_rate
		if signf(dw0) == signf(ss_l) and ss > 0.01:
			acc_max = minf(acc_max, deg_to_rad(lerpf(VehicleData.sample(ss_inc_min, spd_mph), VehicleData.sample(ss_inc_curve, spd_mph), mu_t)))
		elif ss > 0.01:
			var dz := lerpf(VehicleData.sample(ss_dec_zero_min, spd_mph), VehicleData.sample(ss_dec_zero, spd_mph), mu_t)
			var df := lerpf(VehicleData.sample(ss_dec_full_min, spd_mph), VehicleData.sample(ss_dec_full, spd_mph), mu_t)
			acc_max = minf(acc_max, deg_to_rad(lerpf(dz, df, throttle)))
	var step := clampf(yaw_target - yaw_rate, -acc_max * dt, acc_max * dt)
	apply_torque(ground_n * inertia.y * step / dt * (grounded / 4.0))


func _side_to_fwd(f_side: float, ss_deg: float) -> float:
	# parte da desaceleração lateral vira aceleração pra frente (com acelerador)
	var frac := 0.0
	if ss_deg > P.side_to_fwd_max:
		frac = 1.0
	elif ss_deg > P.side_to_fwd_min:
		frac = (ss_deg - P.side_to_fwd_min) / (P.side_to_fwd_max - P.side_to_fwd_min)
	if frac <= 0.0:
		return 0.0
	stf_blend = throttle * frac * P.side_to_fwd     # 0x474: muda a altura da força longitudinal
	return throttle * absf(f_side) * frac * P.side_to_fwd



func _engine_torque(r: float, thr: float) -> float:
	return thr * VehicleData.sample(drive_curve, r) * P.drive_scale - VehicleData.sample(fric_curve, r) * P.fric_scale


func _ratio(g: int) -> float:
	if g == -1:
		return P.gear_r * P.final
	if g <= 0:
		return 0.0
	return gears[g] * P.final


func _speed_at(g: int, r: float) -> float:
	return r * RPM2RAD / absf(_ratio(g)) * P.wheel_r


func _start_shift(to: int) -> void:
	# 0x247aa0: pedido de troca (manual). Só aceita sem outra troca em andamento
	if shift_timer > 0.0 or to == gear:
		return
	shift_to = to
	cstate = 2
	shift_flag = true


## Motor e câmbio portados do executável:
##   0x20c558  giro vem das rodas quando a embreagem está travada e no chão;
##             durante a troca o acelerador cai junto com a embreagem
##   0x2474a0  câmbio AutoManual (embreagem com 4 estados, troca por velocidade)
##   0x2470c0  câmbio Manual (mesma embreagem, sem troca sozinho)
##   0x20c808  carga que a embreagem põe no motor
##   0x246858  motor: torque = acelerador x limitador x curva - atrito; giro
##             integra pela inércia; limitador é uma rampa (15/s), não corte seco
## Marchas aqui: -1 = ré (0 no jogo), 0 = neutro (6 no jogo), 1..5.
func _drivetrain(dt: float, v_f: float, driven_on_ground: bool, forced_open: bool) -> float:
	var ratio := _ratio(gear)
	# giro das rodas de tração (com a patinada) e do lado de fora da embreagem
	var wheel_rpm: float = v_f * (1.0 + drive_slip) / P.wheel_r / RPM2RAD
	var out_rpm: float = wheel_rpm * ratio

	# ---- 0x20c558
	var integrate := true
	if cstate == 3 and driven_on_ground:
		rpm = maxf(out_rpm, P.idle)
		integrate = false
	var thr_eng := throttle
	if cstate != 3 and shift_flag:
		thr_eng *= clutch

	# ---- câmbio (usa o torque do motor do passo anterior, como o jogo)
	var ct := _gearbox(dt, v_f, out_rpm, driven_on_ground, forced_open)

	# ---- 0x20c808 + 0x246858
	var e_load := 0.0 if cstate == 3 else ct
	if rpm > P.lim_on:
		lim_k = maxf(lim_k - P.lim_rate_on * dt, 0.0)
	elif rpm < P.lim_off:
		lim_k = minf(lim_k + P.lim_rate_off * dt, 1.0)
	limiter = lim_k < 0.999
	eng_torque = thr_eng * lim_k * VehicleData.sample(drive_curve, rpm) * P.drive_scale \
		- VehicleData.sample(fric_curve, rpm) * P.fric_scale
	if integrate:
		rpm += (eng_torque - e_load) * dt / P.eng_inertia
	if rpm < P.idle:
		rpm = P.idle
	if rpm <= P.idle and eng_torque < 0.0:
		eng_torque = 0.0

	# torque na roda -> força (0x20e8d8), com o corte de velocidade da ré
	var f: float = ct * _ratio(gear) / P.wheel_r
	var v_mph := v_f / MPH
	if v_mph < -P.rev_limit:
		f = 0.0
	elif v_mph < -P.rev_cut:
		f *= (v_mph + P.rev_limit) / (P.rev_limit - P.rev_cut)
	return f


## Devolve o torque que passa pela embreagem (lado do motor).
func _gearbox(dt: float, v_f: float, out_rpm: float, auto_ok: bool, forced: bool) -> float:
	var n_g := gears.size() - 1
	var rev_now := gear == -1
	var t2 := throttle * throttle
	var dis: float = P.clutch_dis_rate
	var eng: float = P.clutch_eng_rate
	var rpm_thr: float = P.clutch_rpm_lo
	var plain := (want_rev if not manual else rev_now)
	if not plain:
		dis *= 1.0 + t2 * (P.clutch_thr_mod - 1.0)
		eng *= 1.0 + t2 * (P.clutch_thr_mod - 1.0)
		rpm_thr = lerpf(P.clutch_rpm_lo, P.clutch_rpm_hi, t2)
	var diff := rpm - out_rpm
	var change_time: float = P.manual_time if manual else P.auto_time

	var open_path := false
	var engage := false
	if not manual:
		# 0x2474a0 (AutoManual)
		if P.clutch_dis_rpm < rpm or gear > 1:
			if absf(v_f) < _down_speed(2) and gear > 1:
				open_path = true
			elif want_rev and gear != -1 and shift_to != -1:
				open_path = true
			elif not want_rev and gear == -1 and shift_to == -1:
				open_path = true
			elif forced:
				open_path = true
			elif shift_to != gear:
				_shift_step(dt, dis, change_time, diff)
			elif rpm > rpm_thr:
				engage = true
			elif cstate == 1 or cstate == 3:
				engage = true
			elif throttle < 0.01 and absf(v_f) > 5.0 * MPH:
				engage = true
		else:
			open_path = true
	else:
		# 0x2470c0 (Manual)
		if P.clutch_dis_rpm <= rpm and not forced:
			if shift_to != gear:
				_shift_step(dt, dis, change_time, diff)
			elif rpm > rpm_thr or cstate == 1 or cstate == 3:
				engage = true
		else:
			open_path = true

	if open_path:
		cstate = 2
		clutch = maxf(clutch - dis * dt, 0.0)
		if clutch <= 0.0:
			cstate = 0
			if not forced:
				shift_timer = 0.0
				if manual:
					gear = shift_to
				else:
					gear = -1 if want_rev else 1
					shift_to = gear
			shift_flag = false
	elif engage:
		if clutch < 1.0:
			if cstate != 1:
				slip_sign = diff
			cstate = 1
			clutch = minf(clutch + eng * dt, 1.0)
		if clutch > 0.0 and cstate != 3:
			if absf(diff) < P.clutch_lock_diff or signf(diff) != signf(slip_sign):
				cstate = 3
				clutch = 1.0
				shift_flag = false
		# troca automática por velocidade (só com as rodas de tração no chão)
		if cstate == 3 and not manual and not want_rev and auto_ok and gear >= 1:
			var k: float = 1.0 + throttle * (P.up_thr_mod - 1.0)
			if v_f > k * _up_speed(gear) and gear < n_g:
				shift_to = gear + 1
				cstate = 2
				shift_flag = true
			elif gear > 1 and v_f < k * _down_speed(gear):
				shift_to = gear - 1
				cstate = 2
				shift_flag = true

	# torque que a embreagem passa
	if clutch <= 0.0 or gear == 0:
		clutch_t = 0.0
	elif cstate == 3:
		clutch_t = eng_torque
	elif cstate == 2:
		var cap: float = clutch * P.clutch_max
		clutch_t = 0.0 if eng_torque <= 0.0 else minf(cap, eng_torque)
	elif cstate == 1:
		clutch_t = signf(diff) * clutch * P.clutch_max
	return clutch_t


func _shift_step(dt: float, dis: float, change_time: float, diff: float) -> void:
	# embreagem abre; aberta, conta o tempo da troca; aí engata a marcha nova
	if clutch > 0.0:
		clutch -= dis * dt
		if clutch < 0.0:
			clutch = 0.0
			cstate = 0
	else:
		shift_timer += dt
		if shift_timer >= change_time:
			shift_timer = 0.0
			cstate = 1
			slip_sign = diff
			gear = shift_to


## velocidades de troca do jogo (0x246d88), em m/s
func _up_speed(g: int) -> float:
	return P.up_rpm * P.wheel_r * RPM2RAD / (gears[g] * P.final)


func _down_speed(g: int) -> float:
	if g <= 1:
		return 0.0
	if g == 2:
		return maxf(_up_speed(1) * 0.1, _up_speed(1) - P.down_diff[2] * MPH)
	var a := _up_speed(g - 2)
	var b := _up_speed(g - 1)
	return maxf(a + (b - a) * 0.1, b - P.down_diff[g] * MPH)


func _update_visuals(dt: float, v_f: float) -> void:
	for w in wheels:
		var x: float = clampf(w.x, w.min, w.max) + w.jit   # 0x222078: sem clamp depois
		w.pivot.position = Vector3(w.px, w.y0 + x, w.pz)
		w.pivot.rotation.y = steer * P.vis_steer if w.front else 0.0
		w.spin += v_f / w.r * dt
		w.spin_node.rotation.x = w.spin
	# direção suavizada do piloto (0x187060: s += min(1/dt, 30)·(direção - s)·dt):
	# é o que move os braços dele no jogo, então o volante anda junto
	if dt > 0.0:
		rider_s = clampf(rider_s + minf(1.0 / dt, 30.0) * (steer - rider_s) * dt, -1.0, 1.0)
	if sw_pivot and VOLANTE_GIRA:
		sw_pivot.basis = Basis(SW_AXIS.normalized(), rider_s * SW_TURNS)
	if susp_vis:
		susp_vis.update(steer * P.vis_steer)
