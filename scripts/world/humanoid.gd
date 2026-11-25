extends Node3D
## Boneco articulado (cabeça, pescoço, tronco, braços com cotovelo, pernas com joelho,
## mãos e sapatos) com roupas do dia a dia. Serve para o jogador, a prévia da customização e os zumbis.
## Olha para -Z. Altura de ~1,75 m. Tudo feito de formas simples; modelos pintados entram depois.

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}

var zombie: bool = false
var _legs: Array = []  # [{hip, knee}, ...]
var _arms: Array = []  # [{shoulder, elbow}, ...]
var _head: Node3D
var _phase: float = 0.0
var _amount: float = 0.0
var _seed: float = 0.0


## `a`: dicionário de CharacterData.appearance(). `backpack`: desenha a mochila nas costas.
func build(a: Dictionary, backpack: bool = false) -> void:
	_seed = randf() * TAU
	var female: bool = bool(a.get("female", false))
	var skin: Color = a.get("skin_color", Color(0.87, 0.68, 0.53))
	var top: Color = a.get("top_color", Color(0.6, 0.12, 0.1))
	var bottom: Color = a.get("bottom_color", Color(0.2, 0.3, 0.5))
	var shoes: Color = a.get("shoe_color", Color(0.1, 0.1, 0.1))
	var top_style: int = int(a.get("top_style", 0))
	var bottom_style: int = int(a.get("bottom_style", 0))
	var long_sleeves: bool = top_style != 0
	var shorts: bool = bottom_style == 1

	var sw := 0.38 if female else 0.46  # largura dos ombros
	var hw := 0.36 if female else 0.33  # largura do quadril
	var s := 0.95 if female else 1.0
	scale = Vector3(s, s, s)

	# Pelve e tronco
	_box(self, Vector3(hw, 0.20, 0.22), Vector3(0.0, 0.93, 0.0), bottom)
	_box(self, Vector3(sw * 0.9, 0.54, 0.24), Vector3(0.0, 1.27, 0.0), top)
	if female:
		_box(self, Vector3(sw * 0.85, 0.12, 0.26), Vector3(0.0, 1.38, -0.01), top)  # busto
	if top_style == 1:  # xadrez: faixas mais escuras
		var dark := top.darkened(0.35)
		for x in [-0.12, 0.0, 0.12]:
			_box(self, Vector3(0.04, 0.50, 0.255), Vector3(x, 1.27, 0.0), dark)
		for y in [1.15, 1.30, 1.45]:
			_box(self, Vector3(sw * 0.9, 0.035, 0.255), Vector3(0.0, y, 0.0), dark)
	if top_style == 2:  # moletom: capuz e bolso
		_box(self, Vector3(0.26, 0.14, 0.12), Vector3(0.0, 1.58, 0.12), top.darkened(0.1))
		_box(self, Vector3(0.26, 0.10, 0.02), Vector3(0.0, 1.10, -0.125), top.darkened(0.2))
	_box(self, Vector3(0.09, 0.10, 0.09), Vector3(0.0, 1.58, 0.0), skin)  # pescoço
	if backpack:
		_box(self, Vector3(0.36, 0.46, 0.18), Vector3(0.0, 1.27, 0.21), Color(0.28, 0.32, 0.20))
		_box(self, Vector3(0.28, 0.16, 0.06), Vector3(0.0, 1.22, 0.31), Color(0.22, 0.26, 0.16))

	# Cabeça
	_head = Node3D.new()
	_head.position = Vector3(0.0, 1.68, 0.0)
	add_child(_head)
	var head := MeshInstance3D.new()
	head.mesh = _mesh("sphere", Vector3.ONE)
	head.scale = Vector3(0.22, 0.26, 0.24)
	head.material_override = _mat(skin)
	_head.add_child(head)
	_box(_head, Vector3(0.035, 0.05, 0.05), Vector3(0.0, -0.02, -0.125), skin.darkened(0.08))  # nariz
	var eye := Color(0.08, 0.08, 0.08) if not zombie else Color(0.85, 0.85, 0.7)
	for x in [-0.05, 0.05]:
		_box(_head, Vector3(0.035, 0.02, 0.01), Vector3(x, 0.03, -0.115), eye)
	_box(_head, Vector3(0.06, 0.012, 0.01), Vector3(0.0, -0.065, -0.115), skin.darkened(0.3))  # boca
	_build_hair(int(a.get("hair_style", 1)), a.get("hair_color", Color(0.3, 0.2, 0.1)), top)

	# Pernas (quadril -> joelho)
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * hw * 0.3, 0.88, 0.0)
		add_child(hip)
		if shorts:
			_box(hip, Vector3(0.16, 0.26, 0.17), Vector3(0.0, -0.13, 0.0), bottom)
			_box(hip, Vector3(0.14, 0.18, 0.15), Vector3(0.0, -0.35, 0.0), skin)
		else:
			_box(hip, Vector3(0.16, 0.44, 0.17), Vector3(0.0, -0.22, 0.0), bottom)
		var knee := Node3D.new()
		knee.position = Vector3(0.0, -0.44, 0.0)
		hip.add_child(knee)
		_box(knee, Vector3(0.14, 0.40, 0.15), Vector3(0.0, -0.20, 0.0), skin if shorts else bottom)
		_box(knee, Vector3(0.15, 0.09, 0.27), Vector3(0.0, -0.43, -0.04), shoes)
		_legs.append({"hip": hip, "knee": knee})

	# Braços (ombro -> cotovelo -> mão)
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * (sw * 0.5 + 0.045), 1.50, 0.0)
		add_child(shoulder)
		_box(shoulder, Vector3(0.12, 0.30, 0.12), Vector3(0.0, -0.14, 0.0), top)
		var elbow := Node3D.new()
		elbow.position = Vector3(0.0, -0.29, 0.0)
		shoulder.add_child(elbow)
		_box(elbow, Vector3(0.10, 0.27, 0.10), Vector3(0.0, -0.13, 0.0), top if long_sleeves else skin)
		_box(elbow, Vector3(0.09, 0.09, 0.10), Vector3(0.0, -0.30, 0.0), skin)  # mão
		_arms.append({"shoulder": shoulder, "elbow": elbow})
		if side > 0.0:
			hand = elbow

	if zombie:
		_make_zombie()


func _build_hair(style: int, color: Color, cap_color: Color) -> void:
	if style == 0:
		return
	var h := _mat(color)
	if style == 5:  # boné
		var cap := MeshInstance3D.new()
		cap.mesh = _mesh("sphere", Vector3.ONE)
		cap.scale = Vector3(0.25, 0.20, 0.27)
		cap.material_override = _mat(cap_color.darkened(0.2))
		cap.position = Vector3(0.0, 0.07, 0.01)
		_head.add_child(cap)
		_box(_head, Vector3(0.20, 0.025, 0.12), Vector3(0.0, 0.07, -0.17), cap_color.darkened(0.3))
		return
	var top := MeshInstance3D.new()
	top.mesh = _mesh("sphere", Vector3.ONE)
	top.scale = Vector3(0.25, 0.16 if style == 2 else 0.20, 0.27)
	top.material_override = h
	top.position = Vector3(0.0, 0.08, 0.01)
	_head.add_child(top)
	if style == 3:  # longo
		_box(_head, Vector3(0.25, 0.30, 0.08), Vector3(0.0, -0.08, 0.12), color)
	elif style == 4:  # rabo de cavalo
		_box(_head, Vector3(0.07, 0.22, 0.07), Vector3(0.0, -0.06, 0.16), color)


# Zumbi: pele pálida, olhar vidrado, sangue e braços esticados à frente.
func _make_zombie() -> void:
	var blood := Color(0.35, 0.04, 0.04)
	for i in 3:
		_box(self, Vector3(randf_range(0.06, 0.16), randf_range(0.06, 0.2), 0.01), Vector3(randf_range(-0.15, 0.15), randf_range(1.1, 1.45), -0.126), blood)
	_box(_head, Vector3(0.08, 0.05, 0.01), Vector3(0.04, -0.07, -0.122), blood)
	_head.rotation.z = randf_range(-0.2, 0.2)


# --- Animação ---
# Tudo procedural: ciclo de marcha dirigido pela velocidade real (os pés não "patinam"),
# corrida com inclinação e passada longa, ombro/quadril com contra-rotação, respiração e olhar
# no parado, transições suaves entre estados e ataques com antecipação, golpe e recuperação.
# pose: "stand", "crouch", "crawl" (rastejando), "down" (caído de costas)
# armed: "none", "melee" (arma branca na mão) ou "gun" (mira com as duas mãos)

var pose: String = "stand"
var armed: String = "none"
var sprinting: bool = false
var reloading: bool = false
var reload_progress: float = 0.0  # 0..1 durante a recarga
var hand: Node3D  # cotovelo direito: a arma é filha deste nó
var _pelvis: Node3D  # opcionais: só o modelo 3D tem tronco articulado
var _chest: Node3D

var _w: Dictionary = {"crouch": 0.0, "prone": 0.0, "down": 0.0, "gun": 0.0, "melee": 0.0, "reload": 0.0, "run": 0.0, "move": 0.0}
var _cur: Dictionary = {}
var _spd: float = 0.0
var _prev_spd: float = 0.0
var _accel: float = 0.0
var _yaw_prev: float = 0.0
var _turn: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _have_last: bool = false
var _local_vel: Vector3 = Vector3.ZERO
var _time: float = 0.0
var _attack_kind: String = ""
var _attack_t: float = 0.0
var _attack_dur: float = 0.4
var _flinch: float = 0.0
var _flinch_dir: float = 1.0
var _gun_kick: float = 0.0
var _land: float = 0.0


## Toca uma animação de ataque: "swing" (golpe), "stomp" (pisão), "shoot" (disparo) ou "lunge" (bote do zumbi).
func play_attack(kind: String, dur: float) -> void:
	_attack_kind = kind
	_attack_dur = maxf(dur, 0.05)
	_attack_t = 0.0
	if kind == "shoot":
		_gun_kick = 1.0


## Reação a um golpe recebido.
func flinch() -> void:
	_flinch = 1.0
	_flinch_dir = -1.0 if randf() < 0.5 else 1.0


func is_attacking() -> bool:
	return _attack_kind != ""


# Funções de suavização
static func _ease_out(t: float) -> float:
	var u := 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - u * u * u


static func _ease_in(t: float) -> float:
	var u := clampf(t, 0.0, 1.0)
	return u * u * u


static func _smooth(a: float, b: float, v: float) -> float:
	var t := clampf((v - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Aproxima o valor guardado de `target` (filtro exponencial; `rate` maior = mais rápido).
func _sm(key: String, target: float, rate: float, delta: float) -> float:
	var v: float = _cur.get(key, target)
	v = lerpf(v, target, 1.0 - exp(-rate * delta))
	_cur[key] = v
	return v


func _blend_w(key: String, target: float, rate: float, delta: float) -> float:
	var v: float = lerpf(float(_w[key]), target, 1.0 - exp(-rate * delta))
	_w[key] = v
	return v


## `speed`: velocidade horizontal em m/s.
func animate(speed: float, delta: float) -> void:
	if delta <= 0.0:
		return
	_time += delta
	# Velocidade no referencial do boneco (para andar de costas / de lado)
	var gp := global_position
	if _have_last:
		var v := (gp - _last_pos) / delta
		v.y = 0.0
		var yaw := global_transform.basis.get_euler().y
		_local_vel = Basis(Vector3.UP, yaw).inverse() * v
		_turn = lerpf(_turn, angle_difference(_yaw_prev, yaw) / delta, 1.0 - exp(-10.0 * delta))
		_yaw_prev = yaw
	else:
		_yaw_prev = global_transform.basis.get_euler().y
	_last_pos = gp
	_have_last = true
	_spd = lerpf(_spd, speed, 1.0 - exp(-14.0 * delta))
	_accel = lerpf(_accel, (_spd - _prev_spd) / delta, 1.0 - exp(-8.0 * delta))
	_prev_spd = _spd

	var crouch := _blend_w("crouch", 1.0 if pose == "crouch" else 0.0, 10.0, delta)
	var prone := _blend_w("prone", 1.0 if pose == "crawl" else 0.0, 8.0, delta)
	var down := _blend_w("down", 1.0 if pose == "down" else 0.0, 7.0, delta)
	var gun := _blend_w("gun", 1.0 if armed == "gun" and not zombie else 0.0, 9.0, delta)
	var melee := _blend_w("melee", 1.0 if armed == "melee" and not zombie else 0.0, 9.0, delta)
	var rel := _blend_w("reload", 1.0 if reloading else 0.0, 12.0, delta)
	var run := _blend_w("run", _smooth(3.7, 5.3, _spd) if not zombie else 0.0, 7.0, delta)
	var move := _blend_w("move", _smooth(0.12, 0.9, _spd), 9.0, delta)
	var up := 1.0 - maxf(prone, down)  # 1 = em pé/agachado
	var idle := (1.0 - move) * up

	_flinch = maxf(0.0, _flinch - 3.2 * delta)
	_gun_kick = maxf(0.0, _gun_kick - 6.0 * delta)
	var at := 0.0
	if _attack_kind != "":
		_attack_t += delta / _attack_dur
		at = clampf(_attack_t, 0.0, 1.0)
		if _attack_t >= 1.0:
			_attack_kind = ""
			at = 0.0
	# Quanto o ataque assume o controle (sobe rápido, solta no fim)
	var aw := 0.0
	if _attack_kind != "":
		aw = minf(_smooth(0.0, 0.10, at), 1.0 - _smooth(0.82, 1.0, at))

	# --- Ciclo de marcha ---
	var dir := 1.0
	if _local_vel.z > 0.4 and absf(_local_vel.z) > absf(_local_vel.x):
		dir = -1.0  # andando de costas
	var stride := lerpf(1.55, 2.5, run) * lerpf(1.0, 0.75, crouch)
	_phase += dir * TAU * _spd / stride * delta
	var strafe := clampf(_local_vel.x / maxf(_spd, 0.5), -1.0, 1.0) if absf(_local_vel.x) > absf(_local_vel.z) else 0.0
	var sy := sin(_phase)
	var cy := cos(_phase)
	var amp := lerpf(0.52, 0.95, run) * move * lerpf(1.0, 0.55, crouch) * up

	# --- Pernas ---
	var hip_val: Array = [0.0, 0.0]
	var knee_val: Array = [0.0, 0.0]
	var hipz_val: Array = [0.0, 0.0]
	for i in 2:
		var sd := -1.0 if i == 0 else 1.0
		var ph := _phase + (PI if i == 1 else 0.0)
		var hs := sin(ph)
		var hc := cos(ph)
		var hip_x: float = amp * hs
		var knee_x: float = -(0.10 * move + (0.55 + 0.85 * run) * maxf(0.0, hc - 0.1) * move) * up
		var hip_z: float = 0.0
		if zombie:
			# Zumbi: perna esquerda arrasta, passada curta e dura
			hip_x *= 0.7 if i == 0 else 0.55
			knee_x *= 0.5
			if i == 1:
				hip_x -= 0.1 * move
		hip_x += 0.9 * crouch
		knee_x -= 1.8 * crouch
		hip_z = sd * -0.05 * move + strafe * 0.25 * sd * -hs * move
		hip_x += idle * 0.03 * sin(_time * 0.5 + _seed) * (1.0 if i == 0 else -1.0)  # transfere o peso
		if prone > 0.01:  # rastejando: pernas arrastam
			hip_x = lerpf(hip_x, 0.15 * sin(_phase * 0.8 + float(i) * PI), prone)
			knee_x = lerpf(knee_x, -0.1, prone)
		if down > 0.01:
			hip_x = lerpf(hip_x, 0.4 + 0.3 * float(i), down)
			knee_x = lerpf(knee_x, -0.9, down)
		if _attack_kind == "stomp":
			if i == 1:  # pisão com a perna direita: levanta, segura, desce rápido
				var lift := _smooth(0.0, 0.35, at) * (1.0 - _smooth(0.42, 0.56, at))
				hip_x = lerpf(hip_x, 1.45, lift * aw)
				knee_x = lerpf(knee_x, -1.0, lift * aw)
				var hit := _smooth(0.45, 0.56, at) * (1.0 - _smooth(0.56, 0.9, at))
				hip_x = lerpf(hip_x, 0.35, hit * aw)
				knee_x = lerpf(knee_x, -0.05, hit * aw)
			else:  # perna de apoio dobra
				hip_x = lerpf(hip_x, 0.25, aw)
				knee_x = lerpf(knee_x, -0.45, aw)
		elif _attack_kind == "swing" and not zombie:
			# Passo à frente com a perna esquerda ao golpear (destro)
			var step := _smooth(0.25, 0.5, at) * (1.0 - _smooth(0.7, 1.0, at))
			if i == 0:
				hip_x = lerpf(hip_x, 0.65, step * aw)
				knee_x = lerpf(knee_x, -0.3, step * aw)
			else:
				hip_x = lerpf(hip_x, -0.35, step * aw)
				knee_x = lerpf(knee_x, -0.25, step * aw)
		if gun > 0.01 and _attack_kind != "stomp":
			hip_x += (0.12 if i == 0 else -0.12) * gun  # pé direito atrás, base firme
		hip_x += -_flinch * 0.25 * (1.0 if i == 0 else -0.4)
		knee_x -= _flinch * 0.35
		hip_val[i] = hip_x
		knee_val[i] = knee_x
		hipz_val[i] = hip_z

	# --- Tronco, quadril e cabeça ---
	var sway_roll := 0.045 * sy * move * (1.0 - 0.5 * run)  # queda do quadril
	var pelvis_yaw := -0.20 * sy * move * (1.0 + 0.6 * run)
	var chest_yaw := 0.30 * sy * move * (1.0 + 0.8 * run)  # contra-rotação dos ombros
	var chest_roll := -0.5 * sway_roll
	var chest_pitch := 0.015 * sin(_time * 1.7 + _seed) * (1.0 + 2.0 * idle)  # respiração
	var pelvis_pitch := 0.0
	var head_yaw := 0.0
	var head_pitch := 0.0
	var head_roll := 0.0
	# Olhar em volta quando parado
	head_yaw += idle * 0.45 * sin(_time * 0.37 + _seed) * sin(_time * 0.11 + _seed * 2.0)
	head_pitch += idle * 0.06 * sin(_time * 0.53 + _seed)
	pelvis_yaw *= 1.0
	# Inclinação do corpo: corrida, aceleração, curvas
	var lean := 0.04 * move + 0.17 * run + clampf(_accel * 0.012, -0.08, 0.14)
	if sprinting:
		lean += 0.04
	var roll_body := clampf(_turn * 0.035 * clampf(_spd / 3.0, 0.0, 1.5), -0.13, 0.13)
	if zombie:
		lean += 0.12
		head_roll += 0.18 * sin(_phase * 0.5 + _seed) * move + 0.12
		chest_roll += 0.12 * sin(_phase * 0.5 + _seed)
		roll_body += 0.05 * sin(_phase * 0.5 + _seed) * move
		chest_yaw += 0.18 * sin(_phase * 0.5)
		head_pitch += 0.15 + 0.1 * sin(_phase * 0.25)
	# Posições de combate
	var gun_stance := gun * (1.0 - rel * 0.4)
	chest_yaw += 0.28 * gun_stance + 0.12 * melee
	pelvis_yaw += 0.12 * gun_stance
	head_yaw += -0.18 * gun_stance
	head_roll += -0.06 * gun_stance
	chest_pitch += -0.05 * gun_stance - _gun_kick * 0.10
	lean += 0.05 * gun_stance + 0.03 * melee

	# Ataques: antecipação, golpe, recuperação
	if _attack_kind == "swing" and not zombie:
		var wind := _smooth(0.0, 0.34, at) * (1.0 - _smooth(0.34, 0.40, at))
		var strike := _smooth(0.34, 0.54, at) * (1.0 - _smooth(0.6, 1.0, at))
		var tw := (0.75 * _ease_out(minf(at / 0.34, 1.0)) if at < 0.36 else lerpf(0.75, -0.8, _ease_out((at - 0.36) / 0.2))) if at < 0.56 else lerpf(-0.8, 0.0, _smooth(0.6, 1.0, at))
		chest_yaw += -tw * aw
		pelvis_yaw += -tw * 0.4 * aw
		chest_pitch += (-0.15 * wind + 0.35 * strike) * aw
		lean += 0.25 * strike * aw
		head_yaw += tw * 0.5 * aw
	elif _attack_kind == "stomp":
		var down_s := _smooth(0.0, 0.5, at) * (1.0 - _smooth(0.7, 1.0, at))
		chest_pitch += 0.30 * down_s * aw
		lean += 0.1 * down_s * aw
		head_pitch += 0.35 * down_s * aw
	elif _attack_kind == "lunge":
		var lg := sin(at * PI)
		lean += 0.4 * lg * aw
		chest_pitch += 0.25 * lg * aw
		head_pitch += 0.3 * lg * aw
	elif _attack_kind == "shoot":
		chest_pitch += -0.1 * (1.0 - at) * aw
	elif _attack_kind == "swing" and zombie:
		pass
	if armed == "none" and _attack_kind == "swing" and not zombie:
		var punch := sin(clampf(at, 0.0, 1.0) * PI)
		chest_yaw += 0.45 * punch * aw
		pelvis_yaw += 0.2 * punch * aw
	# Susto de golpe recebido
	chest_pitch += -_flinch * 0.28
	chest_yaw += _flinch * 0.4 * _flinch_dir
	chest_roll += _flinch * 0.15 * _flinch_dir
	head_pitch += -_flinch * 0.35
	head_yaw += -_flinch * 0.3 * _flinch_dir
	# Rastejando / caído
	chest_pitch += prone * (-0.45 + 0.1 * sin(_phase * 0.8)) + down * 0.15
	chest_yaw += prone * 0.25 * sin(_phase * 0.8)
	head_pitch += prone * -0.7

	# --- Braços ---
	var arm_sh: Array = [0.0, 0.0]
	var arm_sz: Array = [0.0, 0.0]
	var arm_el: Array = [0.0, 0.0]
	for i in 2:
		var sd := -1.0 if i == 0 else 1.0  # lado do corpo (+X = direita)
		var ph := _phase + (PI if i == 1 else 0.0)
		# Braço do mesmo lado balança contrário à perna
		var swing := -sin(ph) * amp * (0.75 + 0.35 * run)
		var sh: float = swing
		var el: float = 0.12 + 0.22 * move + (0.35 + 1.0 * run) * (0.5 - 0.5 * sin(ph)) * move
		var sz: float = sd * (0.05 + 0.03 * run)
		el += 0.04 * sin(_time * 1.7 + _seed + float(i)) * idle  # respiração
		sh += 0.03 * sin(_time * 1.7 + _seed + float(i)) * idle
		if zombie:
			sh = 1.35 + sin(_phase * 0.5 + _seed + float(i) * 1.7) * 0.12
			el = 0.15 + 0.1 * sin(_time * 1.3 + float(i))
			sz = sd * (0.10 + 0.08 * sin(_time * 0.9 + float(i) * 2.0))
			if _attack_kind == "lunge":
				sh = lerpf(sh, 2.25, sin(at * PI) * aw)
				el = lerpf(el, 0.1, sin(at * PI) * aw)
				sz = lerpf(sz, 0.0, aw)
		else:
			# Arma branca: braço direito segura a arma
			if i == 1:
				var msh := 0.55 - _spd * 0.03
				var mel := 1.05
				sh = lerpf(sh, msh + swing * 0.3, melee)
				el = lerpf(el, mel, melee)
				sz = lerpf(sz, 0.1, melee)
			else:
				sh = lerpf(sh, sh * 0.6 + 0.2, melee)
				el = lerpf(el, 0.55, melee)
			# Arma de fogo: duas mãos, cotovelo direito junto ao corpo, esquerdo apoiando
			if gun > 0.001:
				var gsh := 1.38 + 0.015 * sin(_time * 1.7 + _seed) + 0.04 * sin(_phase) * move + _gun_kick * 0.22
				var gel := 0.12 if i == 1 else 0.75
				var gz := 0.0 if i == 1 else -0.28
				if i == 1:
					gz = 0.05
				if rel > 0.001:
					var u := reload_progress
					var out_h := _smooth(0.0, 0.2, u) * (1.0 - _smooth(0.55, 0.7, u))  # mão esquerda vai à cartucheira
					var ins := _smooth(0.52, 0.72, u) * (1.0 - _smooth(0.82, 0.95, u))  # mão traz o carregador
					if i == 0:
						gsh = lerpf(gsh, 0.55, out_h)
						gel = lerpf(gel, 1.35, out_h)
						gz = lerpf(gz, -0.2, out_h)
						gsh = lerpf(gsh, 1.15, ins)
						gel = lerpf(gel, 1.0, ins)
						gz = lerpf(gz, -0.1, ins)
					else:
						gsh = lerpf(gsh, 0.95 + 0.1 * sin(u * 30.0) * ins, rel * 0.7)  # inclina a arma para o carregador
						gel = lerpf(gel, 0.95, rel * 0.7)
				sh = lerpf(sh, gsh, gun)
				el = lerpf(el, gel, gun)
				sz = lerpf(sz, gz, gun)
			# Ataques
			if _attack_kind == "swing" and i == 1 and armed == "melee":
				if at < 0.34:  # levanta a arma atrás da cabeça
					var w1 := _ease_out(at / 0.34)
					sh = lerpf(sh, 2.95, w1)
					el = lerpf(el, 0.45, w1)
				elif at < 0.56:  # desce com força
					var w2 := _ease_out((at - 0.34) / 0.22)
					sh = lerpf(2.95, 0.25, w2)
					el = lerpf(0.45, 0.2, w2)
					sz = lerpf(sz, -0.1, w2)
				else:  # recupera
					var w3 := _smooth(0.56, 1.0, at)
					sh = lerpf(0.25, 0.55, w3)
					el = lerpf(0.2, 1.05, w3)
			elif _attack_kind == "swing" and i == 0 and armed == "melee":
				var bal := sin(at * PI)
				sh = lerpf(sh, 0.4, bal * 0.6)
				sz = lerpf(sz, -0.55, bal * 0.7)  # braço de trás abre para equilibrar
			elif _attack_kind == "swing" and armed == "none":
				if i == 1:  # soco: recolhe, estica, volta
					var pw := _smooth(0.0, 0.3, at) * (1.0 - _smooth(0.55, 1.0, at))
					sh = lerpf(sh, 1.6, pw)
					el = lerpf(el, 0.1, pw)
					sz = lerpf(sz, -0.1, pw)
				else:  # guarda levantada
					sh = lerpf(sh, 1.1, aw)
					el = lerpf(el, 1.5, aw)
			elif _attack_kind == "shoot" and gun > 0.5:
				sh += 0.25 * pow(1.0 - at, 2.0)
			elif _attack_kind == "stomp":
				sz = lerpf(sz, sd * 0.7, aw * 0.8)  # braços abertos para equilibrar
				sh = lerpf(sh, 0.2, aw)
			# Corrida: cotovelos dobrados para bombear
			if run > 0.01 and gun < 0.5 and melee < 0.5:
				el = lerpf(el, 1.35 + 0.35 * sin(ph), run * 0.8)
		# Susto
		sh += _flinch * (-0.5 if i == 0 else 0.3)
		sz += sd * _flinch * 0.45
		if prone > 0.01:  # engatinhando: braços puxam à frente
			sh = lerpf(sh, 2.6 + 0.5 * sin(_phase * 0.8 + float(i) * PI), prone)
			el = lerpf(el, 0.3 + 0.2 * sin(_phase * 0.8 + float(i) * PI), prone)
		if down > 0.01:
			sh = lerpf(sh, 2.0 + 0.4 * sin(_phase * 0.5 + float(i)), down)
		arm_sh[i] = sh
		arm_sz[i] = sz
		arm_el[i] = el

	# --- Aplica tudo com suavização ---
	for i in 2:
		var leg: Dictionary = _legs[i]
		leg["hip"].rotation.x = _sm("hx%d" % i, hip_val[i], 40.0, delta)
		leg["hip"].rotation.z = _sm("hz%d" % i, hipz_val[i], 20.0, delta)
		leg["knee"].rotation.x = _sm("kx%d" % i, knee_val[i], 40.0, delta)
		var arm: Dictionary = _arms[i]
		var fast := 34.0 if aw > 0.05 else 20.0
		arm["shoulder"].rotation.x = _sm("sx%d" % i, arm_sh[i], fast, delta)
		arm["shoulder"].rotation.z = _sm("sz%d" % i, arm_sz[i], fast, delta)
		arm["elbow"].rotation.x = _sm("ex%d" % i, arm_el[i], fast, delta)

	var tr := 14.0
	var c_yaw := _sm("cy", chest_yaw, tr, delta)
	var c_pitch := _sm("cp", chest_pitch, tr, delta)
	var c_roll := _sm("cr", chest_roll, tr, delta)
	var p_yaw := _sm("py", pelvis_yaw, tr, delta)
	var p_roll := _sm("pr", sway_roll, tr, delta)
	var p_pitch := _sm("pp", pelvis_pitch, tr, delta)
	var h_yaw := _sm("hy", head_yaw, 9.0, delta)
	var h_pitch := _sm("hp", head_pitch - lean * 0.5, 9.0, delta)
	var h_roll := _sm("hr", head_roll, 9.0, delta)
	if _pelvis != null:
		_pelvis.rotation = Vector3(-p_pitch, p_yaw, p_roll)
		_chest.rotation = Vector3(-c_pitch, c_yaw, c_roll)
		if _head != null:
			_head.rotation = Vector3(-h_pitch, h_yaw, h_roll)
	elif _head != null:
		# Boneco de caixas: o tronco não articula; só a cabeça e a inclinação do corpo todo
		_head.rotation = Vector3(-h_pitch, h_yaw + c_yaw * 0.5, h_roll)

	# Corpo todo: inclinação, altura (agachar, quique da passada) e deitado
	var bob := (0.012 + 0.022 * run) * cos(2.0 * _phase) * move * up
	var breathe_y := 0.004 * sin(_time * 1.7 + _seed) * idle
	rotation.x = _sm("rx", -lean + (-1.35 * prone) + (1.45 * down), 12.0, delta)
	rotation.z = _sm("rz", roll_body, 8.0, delta)
	position.y = _sm("py_root", -0.32 * crouch + 0.18 * prone + 0.12 * down + bob + breathe_y - 0.03 * _flinch - 0.03 * _gun_kick, 30.0, delta)
	_apply_extra()


## Gancho para o modelo 3D copiar as juntas para os ossos.
func _apply_extra() -> void:
	pass


# --- Auxiliares ---

func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.9
		_mats[key] = m
	return _mats[key]


func _mesh(kind: String, size: Vector3) -> Mesh:
	var key := "sphere" if kind == "sphere" else "box%s" % size
	if not _meshes.has(key):
		if kind == "sphere":
			var sm := SphereMesh.new()
			sm.radius = 0.5
			sm.height = 1.0
			sm.radial_segments = 12
			sm.rings = 6
			# esfera unitária: quem usa ajusta o tamanho com a escala do nó
			_meshes[key] = sm
		else:
			var bm := BoxMesh.new()
			bm.size = size
			_meshes[key] = bm
	return _meshes[key]


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh("box", size)
	mi.material_override = _mat(color)
	mi.position = pos
	if zombie:
		mi.visibility_range_end = 90.0  # longe demais: nem desenha
	parent.add_child(mi)
	return mi
