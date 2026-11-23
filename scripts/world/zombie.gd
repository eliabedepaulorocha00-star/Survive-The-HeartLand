extends CharacterBody3D
## Zumbi simples (clássico/lento): vaga, vê ou ouve o jogador e persegue.
## A IA completa (olfato, hordas, rastejar, etc.) fica para a Fase 6.

enum State { IDLE, WANDER, CHASE, DEAD }

const WANDER_SPEED := 0.9
const CHASE_SPEED := 2.1
const SIGHT_RANGE := 18.0
const SIGHT_HALF_ANGLE := 55.0
const FORGET_RANGE := 34.0
const ATTACK_RANGE := 1.4
const ATTACK_DAMAGE := 7.0
const ATTACK_COOLDOWN := 1.2
const GRAVITY := 22.0

const OUTFITS := [
	Color(0.12, 0.15, 0.30),  # policial
	Color(0.45, 0.72, 0.62),  # enfermeira
	Color(0.30, 0.36, 0.45),  # macacão
	Color(0.40, 0.40, 0.42),  # moletom
]

var health: float = 100.0
var state: int = State.IDLE

var _player
var _dir := Vector3.ZERO
var _timer: float = 1.0
var _attack_cd: float = 0.0
var _model: Node3D
var _sway: float = 0.0


func _ready() -> void:
	add_to_group("zombies")
	collision_layer = 4
	collision_mask = 1 | 2 | 4

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var cs := CollisionShape3D.new()
	cs.shape = capsule
	cs.position.y = 0.9
	add_child(cs)

	_build_visual()
	_timer = randf_range(0.5, 3.0)
	_sway = randf() * TAU
	rotation.y = randf() * TAU


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	_attack_cd = maxf(0.0, _attack_cd - delta)

	var to_player := Vector3.ZERO
	var dist := 9999.0
	if _player != null:
		to_player = _player.global_position - global_position
		to_player.y = 0.0
		dist = to_player.length()

	_perceive(dist, to_player)

	match state:
		State.IDLE:
			_move(Vector3.ZERO, delta)
			_timer -= delta
			if _timer <= 0.0:
				_set_wander()
		State.WANDER:
			_move(_dir * WANDER_SPEED, delta)
			_face(_dir, delta)
			_timer -= delta
			if _timer <= 0.0 or is_on_wall():
				if randf() < 0.4:
					state = State.IDLE
					_timer = randf_range(1.0, 4.0)
				else:
					_set_wander()
		State.CHASE:
			var dir := to_player.normalized()
			_face(dir, delta)
			if dist > ATTACK_RANGE * 0.8:
				_move(dir * CHASE_SPEED, delta)
			else:
				_move(Vector3.ZERO, delta)
			if dist <= ATTACK_RANGE and _attack_cd <= 0.0 and not _player.dead:
				_attack_cd = ATTACK_COOLDOWN
				_player.zombie_hit(ATTACK_DAMAGE)

	# Balanço do corpo (andar cambaleante) e passos
	_sway += delta * (3.0 if state == State.CHASE else 1.6)
	_model.rotation.z = sin(_sway) * 0.06
	_model.animate(Vector2(velocity.x, velocity.z).length(), delta)


func _perceive(dist: float, to_player: Vector3) -> void:
	if _player == null or _player.dead:
		if state == State.CHASE:
			_set_wander()
		return

	var heard: bool = dist < _player.noise_radius
	var seen: bool = false
	# Neblina, chuva e noite diminuem o alcance de visão
	var sight := SIGHT_RANGE * GameManager.visibility_factor
	if dist < sight and dist > 0.01:
		var fwd := -global_transform.basis.z
		var angle := rad_to_deg(fwd.angle_to(to_player / dist))
		if angle < SIGHT_HALF_ANGLE:
			seen = _has_line_of_sight()

	if heard or seen:
		state = State.CHASE
	elif state == State.CHASE and dist > FORGET_RANGE:
		_set_wander()


func _has_line_of_sight() -> bool:
	var from := global_position + Vector3(0.0, 1.5, 0.0)
	var to: Vector3 = _player.global_position + Vector3(0.0, 1.2, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)  # só cenário
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()


func _set_wander() -> void:
	state = State.WANDER
	_timer = randf_range(2.0, 6.0)
	var a := randf() * TAU
	_dir = Vector3(cos(a), 0.0, sin(a))


func _move(target: Vector3, delta: float) -> void:
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


func take_damage(amount: float, from_pos: Vector3) -> void:
	if state == State.DEAD:
		return
	health -= amount
	var push := global_position - from_pos
	push.y = 0.0
	velocity += push.normalized() * 4.0
	if health <= 0.0:
		_die()
	else:
		state = State.CHASE


func _die() -> void:
	state = State.DEAD
	GameManager.kills += 1
	remove_from_group("zombies")
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	_model.rotation.z = 0.0
	var tw := create_tween()
	tw.tween_property(self, "rotation_degrees:x", -90.0, 0.5)
	tw.parallel().tween_property(self, "position:y", position.y + 0.25, 0.5)
	tw.tween_interval(10.0)
	tw.tween_callback(queue_free)


# --- Visual: boneco articulado com roupas comuns, pele pálida e sangue ---

const HumanoidScript = preload("res://scripts/world/humanoid.gd")

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
