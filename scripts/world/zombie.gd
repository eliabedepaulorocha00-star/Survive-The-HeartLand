extends CharacterBody3D
## Zumbi com IA sensorial: máquina de estados (parado, vagando, investigando um som,
## perseguindo, atacando, caído e rastejando). Sentidos:
##  - Visão: cone à frente, alcance reduzido por noite, chuva e neblina, precisa de linha de visão.
##  - Audição: passos do jogador e sons do mundo (tiros, etc.) pelo GameManager.
##  - Olfato: quem está sangrando é sentido de mais longe.
## Zumbis a mais de 40 m do jogador pensam só 2 vezes por segundo e não animam.

enum State { IDLE, WANDER, INVESTIGATE, CHASE, ATTACK, DOWN, CRAWL, DEAD }

const WANDER_SPEED := 0.9
const INVESTIGATE_SPEED := 1.5
const CHASE_SPEED := 2.1
const CRAWL_SPEED := 0.85
const SIGHT_RANGE := 18.0
const SIGHT_HALF_ANGLE := 55.0
const FORGET_RANGE := 34.0
const ATTACK_RANGE := 1.4
const CRAWL_ATTACK_RANGE := 1.1
const ATTACK_DAMAGE := 7.0
const ATTACK_WINDUP := 0.45  # tempo do bote até o golpe acertar
const ATTACK_COOLDOWN := 1.3
const GRAVITY := 22.0
const FAR_DISTANCE := 40.0
const FAR_TICK := 0.5
const HumanoidScript = preload("res://scripts/world/humanoid.gd")

var health: float = 100.0
var state: int = State.IDLE
var crawler: bool = false  # perdeu as pernas: rasteja

var _player
var _dir := Vector3.ZERO
var _timer: float = 1.0
var _attack_cd: float = 0.0
var _attack_t: float = -1.0  # >= 0 durante o bote
var _investigate_pos := Vector3.ZERO
var _model: Node3D
var _sway: float = 0.0
var _far_acc: float = 0.0
var _cs: CollisionShape3D
var _capsule: CapsuleShape3D


func _ready() -> void:
	add_to_group("zombies")
	collision_layer = 4
	collision_mask = 1 | 2 | 4

	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.35
	_capsule.height = 1.8
	_cs = CollisionShape3D.new()
	_cs.shape = _capsule
	_cs.position.y = 0.9
	add_child(_cs)

	_build_visual()
	_timer = randf_range(0.5, 3.0)
	_sway = randf() * TAU
	rotation.y = randf() * TAU
	GameManager.sound_emitted.connect(_on_sound)
	if crawler:
		_start_crawl()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	var to_player := Vector3.ZERO
	var dist := 9999.0
	if _player != null:
		to_player = _player.global_position - global_position
		to_player.y = 0.0
		dist = to_player.length()

	# Longe do jogador: pensa 2x por segundo e anda em linha reta, sem animação
	var far := dist > FAR_DISTANCE
	if far:
		_far_acc += delta
		if _far_acc < FAR_TICK:
			return
		delta = _far_acc
		_far_acc = 0.0
	else:
		_far_acc = 0.0

	_attack_cd = maxf(0.0, _attack_cd - delta)
	_perceive(dist, to_player)

	match state:
		State.IDLE:
			_move(Vector3.ZERO, delta, far)
			_timer -= delta
			if _timer <= 0.0:
				_set_wander()
		State.WANDER:
			_move(_dir * WANDER_SPEED, delta, far)
			_face(_dir, delta)
			_timer -= delta
			if _timer <= 0.0 or (is_on_wall() and not far):
				if randf() < 0.4:
					state = State.IDLE
					_timer = randf_range(1.0, 4.0)
				else:
					_set_wander()
		State.INVESTIGATE:
			var to_spot := _investigate_pos - global_position
			to_spot.y = 0.0
			_timer -= delta
			if to_spot.length() < 1.5 or _timer <= 0.0:
				state = State.IDLE  # chegou e não achou nada: olha em volta
				_timer = randf_range(2.0, 5.0)
			else:
				_move(to_spot.normalized() * INVESTIGATE_SPEED, delta, far)
				_face(to_spot, delta)
		State.CHASE:
			if _player == null or _player.dead:
				_set_wander()
			else:
				var dir := to_player.normalized()
				_face(dir, delta)
				if dist > ATTACK_RANGE * 0.8:
					_move(dir * CHASE_SPEED, delta, far)
				else:
					_move(Vector3.ZERO, delta, far)
				if dist <= ATTACK_RANGE and _attack_cd <= 0.0:
					_begin_attack()
		State.ATTACK:
			_move(Vector3.ZERO, delta, far)
			_face(to_player.normalized(), delta)
			_attack_t += delta
			if _attack_t >= ATTACK_WINDUP:
				_attack_t = -1.0
				_attack_cd = ATTACK_COOLDOWN
				if _player != null and not _player.dead and dist <= ATTACK_RANGE * 1.25:
					_player.zombie_hit(ATTACK_DAMAGE)
				state = State.CHASE
		State.DOWN:
			_move(Vector3.ZERO, delta, far)
			_timer -= delta
			if _timer <= 0.0:
				_stand_up()
		State.CRAWL:
			if _player != null and not _player.dead and dist < SIGHT_RANGE * 1.5:
				var d2 := to_player.normalized()
				_face(d2, delta)
				if dist > CRAWL_ATTACK_RANGE:
					_move(d2 * CRAWL_SPEED, delta, far)
				else:
					_move(Vector3.ZERO, delta, far)
					if _attack_cd <= 0.0:
						_attack_cd = ATTACK_COOLDOWN
						_model.play_attack("lunge", 0.5)
						_player.zombie_hit(ATTACK_DAMAGE * 0.7)
			else:
				_move(_dir * CRAWL_SPEED * 0.5, delta, far)
				_timer -= delta
				if _timer <= 0.0:
					_timer = randf_range(2.0, 5.0)
					var a := randf() * TAU
					_dir = Vector3(cos(a), 0.0, sin(a))

	if not far:
		_sway += delta * (3.0 if state == State.CHASE else 1.6)
		_model.rotation.z = sin(_sway) * (0.06 if state != State.CRAWL and state != State.DOWN else 0.0)
		_model.animate(Vector2(velocity.x, velocity.z).length(), delta)


# --- Sentidos ---

func _perceive(dist: float, to_player: Vector3) -> void:
	if _player == null or _player.dead:
		return
	if state == State.DOWN or state == State.ATTACK:
		return

	# Audição: os passos dentro do alcance chamam atenção (muito perto = já vira perseguição)
	var radius: float = _player.noise_radius
	if dist < radius:
		if dist < radius * 0.6 or state == State.CHASE:
			_aggro()
		else:
			investigate(_player.global_position)

	# Olfato: sangramento aberto denuncia de longe
	if dist < _player.smell_radius and state != State.CHASE:
		investigate(_player.global_position)
		if dist < _player.smell_radius * 0.5:
			_aggro()

	# Visão: cone à frente; noite, chuva e neblina encurtam o alcance
	var sight := SIGHT_RANGE * GameManager.visibility_factor
	if state != State.CRAWL and dist < sight and dist > 0.01:
		var fwd := -global_transform.basis.z
		var angle := rad_to_deg(fwd.angle_to(to_player / dist))
		if angle < SIGHT_HALF_ANGLE and _has_line_of_sight():
			_aggro()

	if state == State.CHASE and dist > FORGET_RANGE:
		_set_wander()


func _aggro() -> void:
	if state == State.CRAWL or state == State.DOWN or state == State.ATTACK:
		return
	state = State.CHASE


## Vai até um ponto (som, horda). Não interrompe quem já está perseguindo.
func investigate(pos: Vector3, seconds: float = 25.0) -> void:
	if state == State.DEAD or state == State.CHASE or state == State.ATTACK or state == State.DOWN:
		return
	_investigate_pos = pos
	_timer = seconds
	if state != State.CRAWL:
		state = State.INVESTIGATE
	else:
		_dir = (pos - global_position).normalized()


func _on_sound(pos: Vector3, radius: float) -> void:
	if state == State.DEAD:
		return
	if global_position.distance_to(pos) <= radius:
		investigate(pos, 40.0)


func _has_line_of_sight() -> bool:
	var from := global_position + Vector3(0.0, 1.5, 0.0)
	var to: Vector3 = _player.global_position + Vector3(0.0, 1.2, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)  # só cenário
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()


# --- Movimento ---

func _set_wander() -> void:
	state = State.CRAWL if crawler else State.WANDER
	_timer = randf_range(2.0, 6.0)
	var a := randf() * TAU
	_dir = Vector3(cos(a), 0.0, sin(a))


func _move(target: Vector3, delta: float, far: bool) -> void:
	if far:
		# Longe do jogador: anda direto, sem colisão fina (ninguém está olhando)
		global_position += Vector3(target.x, 0.0, target.z) * delta
		velocity = Vector3.ZERO
		return
	velocity.x = move_toward(velocity.x, target.x, 10.0 * delta)
	velocity.z = move_toward(velocity.z, target.z, 10.0 * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()


func _face(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.01:
		return
	var want := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, want, clampf(6.0 * delta, 0.0, 1.0))


# --- Ataque, dano, queda ---

func _begin_attack() -> void:
	state = State.ATTACK
	_attack_t = 0.0
	_model.play_attack("lunge", ATTACK_WINDUP + 0.35)


## Ponto central do corpo (em pé: peito; caído/rastejando: meio do corpo deitado).
func hit_point() -> Vector3:
	if state == State.DOWN:
		return global_transform * Vector3(0.0, 0.0, 0.85)
	if state == State.CRAWL:
		return global_transform * Vector3(0.0, 0.0, -0.85)
	return global_position


func head_position() -> Vector3:
	if state == State.DOWN:
		return global_transform * Vector3(0.0, 0.0, 1.6)
	if state == State.CRAWL:
		return global_transform * Vector3(0.0, 0.0, -1.55)
	return global_position + Vector3(0.0, 1.7, 0.0)


func is_grounded() -> bool:
	return state == State.DOWN or state == State.CRAWL


func is_chasing() -> bool:
	return state == State.CHASE or state == State.ATTACK


## `knock`: chance de derrubar. `finisher`: pisão na cabeça (mata quem está no chão).
func take_damage(amount: float, from_pos: Vector3, knock: float = 0.0, finisher: bool = false) -> void:
	if state == State.DEAD:
		return
	health -= amount
	var push := global_position - from_pos
	push.y = 0.0
	if state != State.DOWN:
		velocity += push.normalized() * 4.0
	if health <= 0.0 or (finisher and is_grounded()):
		_die()
		return
	_model.flinch()
	if state == State.DOWN:
		return
	_attack_t = -1.0
	if health < 35.0 and not crawler and randf() < 0.3:
		crawler = true  # perna destruída: cai e passa a rastejar
		_knock_down(2.0)
		return
	if knock > 0.0 and randf() < knock and state != State.CRAWL:
		_knock_down(randf_range(2.5, 4.0))
		return
	if state != State.CRAWL:
		state = State.CHASE


func _knock_down(seconds: float) -> void:
	state = State.DOWN
	_timer = seconds
	_model.pose = "down"
	_set_collision_pose("down")


func _stand_up() -> void:
	if crawler:
		_start_crawl()
	else:
		state = State.CHASE
		_model.pose = "stand"
		_set_collision_pose("stand")


func _start_crawl() -> void:
	crawler = true
	state = State.CRAWL
	_model.pose = "crawl"
	_set_collision_pose("crawl")
	_timer = randf_range(1.0, 3.0)


## Corpo deitado precisa de uma cápsula deitada (para tiros e pisões acertarem onde ele está).
func _set_collision_pose(mode: String) -> void:
	if mode == "stand":
		_capsule.radius = 0.35
		_capsule.height = 1.8
		_cs.rotation.x = 0.0
		_cs.position = Vector3(0.0, 0.9, 0.0)
	else:
		_capsule.radius = 0.28
		_capsule.height = 1.7
		_cs.rotation.x = PI * 0.5
		_cs.position = Vector3(0.0, 0.28, 0.85 if mode == "down" else -0.85)


func _die() -> void:
	state = State.DEAD
	GameManager.kills += 1
	remove_from_group("zombies")
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	_model.rotation.z = 0.0
	_model.pose = "down"
	var tw := create_tween()
	tw.tween_interval(10.0)
	tw.tween_callback(queue_free)


# --- Visual: boneco articulado com roupas comuns, pele pálida e sangue ---

func _build_visual() -> void:
	var cloth := [Color(0.12, 0.15, 0.30), Color(0.45, 0.72, 0.62), Color(0.30, 0.36, 0.45), Color(0.40, 0.40, 0.42),
		Color(0.55, 0.22, 0.18), Color(0.75, 0.72, 0.65), Color(0.20, 0.30, 0.22), Color(0.30, 0.22, 0.15)]
	var hairs := [Color(0.1, 0.08, 0.07), Color(0.3, 0.2, 0.12), Color(0.6, 0.5, 0.3), Color(0.5, 0.5, 0.5)]
	var look := {
		"female": randf() < 0.5,
		"skin_color": Color(0.55, 0.65, 0.58).lerp(Color(0.8, 0.7, 0.6), randf() * 0.35),
		"hair_style": randi() % 6,
		"hair_color": hairs[randi() % hairs.size()],
		"top_style": randi() % 3,
		"top_color": cloth[randi() % cloth.size()],
		"bottom_style": 0 if randf() < 0.8 else 1,
		"bottom_color": cloth[randi() % cloth.size()].darkened(0.2),
		"shoe_color": Color(0.12, 0.1, 0.09),
	}
	_model = HumanoidScript.new()
	_model.zombie = true
	add_child(_model)
	_model.build(look)
