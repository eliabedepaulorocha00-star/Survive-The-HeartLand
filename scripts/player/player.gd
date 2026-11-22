extends CharacterBody3D
## Jogador: movimento com posturas (em pé, agachado, correndo), stamina e exaustão,
## ataque corpo a corpo, pegar itens e câmera híbrida.

signal died

const CameraRigScript = preload("res://scripts/player/camera_rig.gd")

const WALK_SPEED := 3.2
const SPRINT_SPEED := 6.0
const CROUCH_SPEED := 1.6
const GRAVITY := 22.0
const ACCEL := 16.0
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.2

const SPRINT_COST := 16.0  # stamina por segundo correndo
const ATTACK_COST := 12.0
const STAMINA_REGEN := 14.0
const REGEN_DELAY := 0.8
const EXHAUSTED_RECOVER := 25.0
const ATTACK_DAMAGE := 34.0
const ATTACK_RANGE := 2.3

var controls  # TouchControls, definido por bind_controls()
var rig  # CameraRig

var max_health: float = 100.0
var health: float = 100.0
var max_stamina: float = 100.0
var stamina: float = 100.0
var exhausted: bool = false
var crouching: bool = false
var sprinting: bool = false
var dead: bool = false
var noise_radius: float = 2.0  # raio em que os zumbis "ouvem" o jogador
var hint_text: String = ""

var _body: Node3D
var _weapon_pivot: Node3D
var _shape: CollisionShape3D
var _capsule: CapsuleShape3D
var _regen_timer: float = 0.0
var _attack_cd: float = 0.0
var _nearest_pickup: Node3D = null


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4

	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.35
	_capsule.height = STAND_HEIGHT
	_shape = CollisionShape3D.new()
	_shape.shape = _capsule
	_shape.position.y = STAND_HEIGHT * 0.5
	add_child(_shape)

	_build_visual()

	rig = CameraRigScript.new()
	add_child(rig)


func bind_controls(c) -> void:
	controls = c
	c.camera_toggle_pressed.connect(func(): rig.toggle_view())
	c.crouch_pressed.connect(toggle_crouch)
	c.action_pressed.connect(_interact)
	c.attack_pressed.connect(_try_attack)


func _unhandled_input(event: InputEvent) -> void:
	# Atalhos de teclado (útil para testar no computador).
	if dead or GameManager.state != GameManager.State.IN_GAME:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_C:
				toggle_crouch()
			KEY_V:
				rig.toggle_view()
			KEY_E:
				_interact()
			KEY_F, KEY_SPACE:
				_try_attack()
			KEY_ESCAPE:
				GameManager.change_state(GameManager.State.PAUSED)


func _process(_delta: float) -> void:
	_body.visible = rig.blend < 0.8


func _physics_process(delta: float) -> void:
	if dead:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)

	var look := Vector2.ZERO
	if controls != null:
		look = controls.consume_look()
	if look != Vector2.ZERO:
		rig.apply_look(look)

	var input := _read_move_input()
	var strength := minf(input.length(), 1.0)
	var moving := strength > 0.1

	# Postura e velocidade
	var wants_sprint: bool = Input.is_key_pressed(KEY_SHIFT)
	if controls != null and controls.sprinting:
		wants_sprint = true
	sprinting = wants_sprint and moving and not crouching and not exhausted and stamina > 0.0

	var speed := WALK_SPEED
	if crouching:
		speed = CROUCH_SPEED
	elif sprinting:
		speed = SPRINT_SPEED
	speed *= strength
	if exhausted:
		speed *= 0.6

	# Stamina e exaustão
	if sprinting:
		stamina -= SPRINT_COST * delta
		_regen_timer = REGEN_DELAY
	elif _regen_timer > 0.0:
		_regen_timer -= delta
	else:
		stamina += STAMINA_REGEN * delta
	stamina = clampf(stamina, 0.0, max_stamina)
	if stamina <= 0.0 and not exhausted:
		exhausted = true
		_regen_timer = 1.5
	elif exhausted and stamina >= EXHAUSTED_RECOVER:
		exhausted = false

	# Ruído que os zumbis podem ouvir
	if not moving:
		noise_radius = 2.0
	elif crouching:
		noise_radius = 3.0
	elif sprinting:
		noise_radius = 22.0
	else:
		noise_radius = 8.0

	# Movimento relativo à direção da câmera
	var yaw_basis := Basis(Vector3.UP, rig.yaw)
	var dir := yaw_basis * Vector3(input.x, 0.0, -input.y)
	var target := dir.normalized() * speed
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	hv = hv.move_toward(target, ACCEL * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	# Corpo vira para onde anda (3ª pessoa) ou para onde a câmera olha (1ª pessoa)
	var face_yaw := _body.rotation.y
	if rig.is_first_person():
		face_yaw = rig.yaw
	elif hv.length() > 0.3:
		face_yaw = atan2(-hv.x, -hv.z)
	_body.rotation.y = lerp_angle(_body.rotation.y, face_yaw, clampf(12.0 * delta, 0.0, 1.0))
	var squash := 0.72 if crouching else 1.0
	_body.scale.y = lerpf(_body.scale.y, squash, clampf(10.0 * delta, 0.0, 1.0))

	_update_pickup_hint()


func _read_move_input() -> Vector2:
	var v := Vector2.ZERO
	if controls != null:
		v = Vector2(controls.move_vector.x, -controls.move_vector.y)
	var k := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		k.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		k.y -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		k.x += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		k.x -= 1.0
	if k != Vector2.ZERO:
		v = k.normalized()
	return v


func toggle_crouch() -> void:
	if dead:
		return
	crouching = not crouching
	var h := CROUCH_HEIGHT if crouching else STAND_HEIGHT
	_capsule.height = h
	_shape.position.y = h * 0.5
	rig.target_height = 1.0 if crouching else 1.55
	if controls != null:
		controls.crouch_active = crouching


func _update_pickup_hint() -> void:
	_nearest_pickup = null
	var best := 2.0
	for p in get_tree().get_nodes_in_group("pickups"):
		var d: float = global_position.distance_to(p.global_position)
		if d < best:
			best = d
			_nearest_pickup = p
	if _nearest_pickup != null:
		var item_name: String = _nearest_pickup.get_meta("item_name", "Item")
		hint_text = "%s - toque em PEGAR" % item_name
		if controls != null:
			controls.action_label = "PEGAR"
	else:
		hint_text = ""
		if controls != null:
			controls.action_label = "AÇÃO"


func _interact() -> void:
	if dead:
		return
	if _nearest_pickup != null and is_instance_valid(_nearest_pickup):
		var item_name: String = _nearest_pickup.get_meta("item_name", "Item")
		var heal: float = _nearest_pickup.get_meta("heal", 0.0)
		_nearest_pickup.queue_free()
		_nearest_pickup = null
		health = minf(max_health, health + heal)
		GameManager.notify("Pegou: %s (+%d vida)" % [item_name, int(heal)])
	else:
		GameManager.notify("Nada para usar aqui")


func _try_attack() -> void:
	if dead or _attack_cd > 0.0 or stamina < 1.0:
		return
	stamina = maxf(0.0, stamina - ATTACK_COST)
	_regen_timer = REGEN_DELAY
	_attack_cd = 0.55 * (1.6 if exhausted else 1.0)
	_body.rotation.y = rig.yaw
	_swing_weapon()

	var fwd := -_body.global_transform.basis.z
	var power := ATTACK_DAMAGE * (0.6 if exhausted else 1.0)
	var hit := false
	for z in get_tree().get_nodes_in_group("zombies"):
		var to: Vector3 = z.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > 0.01 and dist < ATTACK_RANGE and fwd.dot(to / dist) > 0.25:
			z.take_damage(power, global_position)
			hit = true
	if hit:
		rig.shake(0.25)


func _swing_weapon() -> void:
	var tw := create_tween()
	tw.tween_property(_weapon_pivot, "rotation_degrees:x", -125.0, 0.12)
	tw.tween_property(_weapon_pivot, "rotation_degrees:x", -15.0, 0.25)


func take_damage(amount: float) -> void:
	if dead:
		return
	health -= amount
	rig.shake(0.5)
	if health <= 0.0:
		health = 0.0
		dead = true
		velocity = Vector3.ZERO
		died.emit()


# --- Visual provisório (boneco de formas simples, no estilo da arte de referência) ---

func _build_visual() -> void:
	_body = Node3D.new()
	add_child(_body)
	_mesh_node(_body, _capsule_mesh(0.30, 0.95), Vector3(0.0, 0.48, 0.0), Color(0.25, 0.32, 0.45))  # calça jeans
	_mesh_node(_body, _capsule_mesh(0.34, 0.90), Vector3(0.0, 1.22, 0.0), Color(0.62, 0.12, 0.10))  # camisa xadrez
	_mesh_node(_body, _sphere_mesh(0.20), Vector3(0.0, 1.68, 0.0), Color(0.85, 0.68, 0.55))  # cabeça
	var hair := _mesh_node(_body, _sphere_mesh(0.205), Vector3(0.0, 1.76, 0.02), Color(0.35, 0.25, 0.15))
	hair.scale = Vector3(1.0, 0.6, 1.0)
	_mesh_node(_body, _box_mesh(Vector3(0.45, 0.6, 0.25)), Vector3(0.0, 1.25, 0.32), Color(0.33, 0.36, 0.22))  # mochila

	_weapon_pivot = Node3D.new()
	_weapon_pivot.position = Vector3(0.38, 1.2, -0.1)
	_weapon_pivot.rotation_degrees.x = -15.0
	_body.add_child(_weapon_pivot)
	_mesh_node(_weapon_pivot, _box_mesh(Vector3(0.07, 0.8, 0.07)), Vector3(0.0, 0.4, 0.0), Color(0.55, 0.38, 0.2))  # taco


func _mesh_node(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _capsule_mesh(radius: float, height: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = height
	return c


func _sphere_mesh(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	return s


func _box_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b
