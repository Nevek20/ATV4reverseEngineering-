extends Node3D
## Entrada de curva em terra plana (atrito MU, padrão 0.69, e Damping AMORT,
## padrão 0.2 = fora da pista do RX01; na pista 0.8 / 1.1 e 0): o Renegade acelera reto até VEL km/h, vira tudo (ST, padrão 1) com
## o acelerador no fundo e mede quando a derrapagem passa de 20°. Referência
## do jogo (Matheus, out/2026): a 110 km/h não derrapa; a 170 derrapa depois
## de 0.5 a 1 s. Com DET=1 imprime roda por roda a cada 0.1 s.
## Uso: VEL=110 godot --headless --path . res://tests/teste_entrada.tscn
const Car := preload("res://car.gd")
const Main := preload("res://main.gd")
var car
var t := 0.0
var t_vira := -1.0
var alvo := 110.0
var log_t := 0.0
var solto := -1.0
var kmh_solto := 0.0
func _ready():
	alvo = float(OS.get_environment("VEL"))
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8000, 2, 8000)
	cs.shape = box
	cs.position = Vector3(0, -1, 0)
	body.add_child(cs)
	add_child(body)
	var v: Dictionary = Main.VEHICLES[0]
	car = Car.new()
	car.asset_dir = v.dir
	car.data_files = ["res://data/vehicles/buggy_base.xml", v.data]
	car.points_file = v.points
	car.vehicle_id = v.id
	car.tune_override = v.get("tune", {})
	car.suspension = false
	car.SURFACE_MU = float(OS.get_environment("MU")) if OS.get_environment("MU") != "" else 0.69
	car.SURFACE_AMORT = float(OS.get_environment("AMORT")) if OS.get_environment("AMORT") != "" else 0.2
	add_child(car)
	car.reset_to(Vector3(0, 1.0, -3500), 0.0)
	car.test_input = {"thr": 0.0, "brk": 0.0, "steer": 0.0}
func _physics_process(d):
	t += d
	var ti = car.test_input
	ti.thr = 1.0 if t > 1.0 else 0.0
	var kmh: float = car.linear_velocity.length() * 3.6
	if t_vira < 0.0 and kmh >= alvo:
		t_vira = t
	var st := float(OS.get_environment("ST")) if OS.get_environment("ST") != "" else 1.0
	ti.steer = st if t_vira >= 0.0 else 0.0
	if t_vira >= 0.0:
		var tv := t - t_vira
		var ss := absf(rad_to_deg(car.sideslip))
		if solto < 0.0 and ss > 20.0:
			solto = tv
			kmh_solto = kmh
		log_t += d
		if log_t >= 0.1 and OS.get_environment("DET") != "1":
			log_t = 0.0
			# o velocímetro do jogo mostra ~1.06 x a velocidade pra frente (save
			# states: 93 com 87.2, 114 com 108.2, 97 com 91.6)
			var hud: float = car.linear_velocity.dot(car.global_transform.basis.z) * 3.6 * 1.06
			print("  %.1f s  %5.1f km/h (HUD do jogo ~%3.0f)  derrapagem %5.1f°  giro %6.1f°/s  marcha %s" % [tv, kmh, hud, ss, rad_to_deg(absf(car.angular_velocity.y)), car.gear_label()])
		if log_t >= 0.1 and OS.get_environment("DET") == "1":
			log_t = 0.0
			var t2 := []
			for w in car.wheels:
				t2.append("%5.1f %s g%.2f" % [-w.fx / 1000.0, "S" if w.sat else "-", w.grip])
			print("  %.1f s  %5.1f km/h  derrapagem %5.1f°  giro %6.1f  marcha %s rpm %d chão %d | %s" % [tv, kmh, ss, rad_to_deg(car.angular_velocity.y), car.gear_label(), int(car.rpm), car.grounded, " | ".join(t2)])
		if tv > 3.0:
			print("VEL %d: passa de 20° em %s" % [int(alvo), ("%.2f s, a %.0f km/h" % [solto, kmh_solto]) if solto >= 0.0 else "nunca (3 s)"])
			get_tree().quit()
	if t > 90.0:
		print("VEL %d: não chegou na velocidade" % int(alvo))
		get_tree().quit()
