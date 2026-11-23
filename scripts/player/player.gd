extends CharacterBody3D
## Jogador: movimento com posturas (em pé, agachado, correndo), stamina e exaustão,
## fome e sede, mochila com peso, arma equipada, pegar itens e câmera híbrida.

signal died
signal container_opened(container)
signal inventory_requested

const CameraRigScript = preload("res://scripts/player/camera_rig.gd")
const InventoryScript = preload("res://scripts/player/inventory.gd")
const GroundItemScript = preload("res://scripts/world/ground_item.gd")

const WALK_SPEED := 3.2
const SPRINT_SPEED := 6.0
const CROUCH_SPEED := 1.6
const GRAVITY := 22.0
const ACCEL := 16.0
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.2

const SPRINT_COST := 16.0  # stamina por segundo correndo
const STAMINA_REGEN := 14.0
const REGEN_DELAY := 0.8
const EXHAUSTED_RECOVER := 25.0

# Punhos (sem arma equipada)
const UNARMED_DAMAGE := 12.0
const UNARMED_RANGE := 1.9
const UNARMED_COST := 8.0
const UNARMED_COOLDOWN := 0.45

# Fome e sede: dias de jogo para chegar a zero (a duração do dia vem das configurações)
const HUNGER_DAYS := 3.0
const THIRST_DAYS := 1.5
const PICKUP_REACH := 2.0
const HUNGER_MSGS := ["", "Você está com fome.", "Fome forte! Coma alguma coisa.", "Você está morrendo de fome!"]
const THIRST_MSGS := ["", "Você está com sede.", "Sede forte! Beba alguma coisa.", "Você está morrendo de sede!"]

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
var hunger: float = 100.0  # 100 = saciado, 0 = faminto
var thirst: float = 100.0
var inventory  # Inventory (scripts/player/inventory.gd)
var ui_locked: bool = false  # true enquanto a mochila está aberta
var wetness: float = 0.0  # 0 = seco, 1 = encharcado (a chuva molha, o abrigo seca)
var sheltered: bool = false  # tem teto por cima?
var _shelter_timer: float = 0.0

var _body: Node3D
var _weapon_pivot: Node3D
var _shape: CollisionShape3D
var _capsule: CapsuleShape3D
var _regen_timer: float = 0.0
var _attack_cd: float = 0.0
var _target = null  # item no chão ou recipiente mais próximo
var _hunger_level: int = 0
var _thirst_level: int = 0
var _shown_weapon: String = "?"


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

	inventory = InventoryScript.new()
	_build_visual()
	_give_starting_items()
	inventory.changed.connect(_update_weapon_visual)
	_update_weapon_visual()

	rig = CameraRigScript.new()
	add_child(rig)


func bind_controls(c) -> void:
	controls = c
	c.camera_toggle_pressed.connect(func(): rig.toggle_view())
	c.crouch_pressed.connect(toggle_crouch)
	c.action_pressed.connect(_interact)
	c.attack_pressed.connect(_try_attack)
	c.bag_pressed.connect(func(): inventory_requested.emit())


func _unhandled_input(event: InputEvent) -> void:
	# Atalhos de teclado (útil para testar no computador).
	if dead or ui_locked or GameManager.state != GameManager.State.IN_GAME:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_C:
				toggle_crouch()
			KEY_V:
				rig.toggle_view()
			KEY_E:
				_interact()
			KEY_I, KEY_TAB:
				inventory_requested.emit()
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
	speed *= float(inventory.speed_factor())  # peso demais deixa lento

	# Stamina e exaustão
	if sprinting:
		stamina -= SPRINT_COST * delta
		_regen_timer = REGEN_DELAY
	elif _regen_timer > 0.0:
		_regen_timer -= delta
	else:
		stamina += STAMINA_REGEN * (1.0 - 0.4 * wetness) * delta  # roupa molhada cansa mais
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
	noise_radius *= GameManager.noise_factor  # a chuva abafa os passos

	_update_exposure(delta)
	_update_needs(delta)

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

	_update_target()


## Fome e sede caem com o tempo (mais rápido correndo). Zerar uma delas machuca; bem alimentado, a vida volta devagar.
func _update_needs(delta: float) -> void:
	var day_s: float = float(GameSettings.day_minutes()) * 60.0
	var hunger_rate: float = 100.0 / (day_s * HUNGER_DAYS)
	var thirst_rate: float = 100.0 / (day_s * THIRST_DAYS)
	if sprinting:
		hunger_rate *= 1.4
		thirst_rate *= 1.8
	hunger = maxf(0.0, hunger - hunger_rate * delta)
	thirst = maxf(0.0, thirst - thirst_rate * delta)

	var h_level := _need_level(hunger)
	if h_level > _hunger_level:
		GameManager.notify(HUNGER_MSGS[h_level])
	_hunger_level = h_level
	var t_level := _need_level(thirst)
	if t_level > _thirst_level:
		GameManager.notify(THIRST_MSGS[t_level])
	_thirst_level = t_level

	if hunger <= 0.0:
		_vital_damage(0.15 * delta)
	if thirst <= 0.0:
		_vital_damage(0.35 * delta)
	if hunger > 50.0 and thirst > 50.0 and health < max_health and not dead:
		health = minf(max_health, health + 0.25 * delta)


func _need_level(value: float) -> int:
	if value <= 0.0:
		return 3
	if value < 12.0:
		return 2
	if value < 30.0:
		return 1
	return 0


## Detecta se há teto por cima (abrigo) e atualiza o quanto o jogador está molhado.
func _update_exposure(delta: float) -> void:
	_shelter_timer -= delta
	if _shelter_timer <= 0.0:
		_shelter_timer = 0.25
		var from := global_position + Vector3(0.0, 1.8, 0.0)
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, 12.0, 0.0), 1)
		sheltered = not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	if GameManager.rain_amount > 0.1 and not sheltered:
		wetness += 0.012 * GameManager.rain_amount * delta
	elif sheltered:
		wetness -= 0.010 * delta
	else:
		wetness -= 0.004 * delta
	wetness = clampf(wetness, 0.0, 1.0)


func _read_move_input() -> Vector2:
	if ui_locked:
		return Vector2.ZERO
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


## Acha o item no chão ou o recipiente mais perto, e atualiza a dica e o botão de ação.
func _update_target() -> void:
	_target = null
	var best := 9999.0
	for p in get_tree().get_nodes_in_group("pickups"):
		var d: float = global_position.distance_to(p.global_position)
		if d < PICKUP_REACH and d < best:
			best = d
			_target = p
	for c in get_tree().get_nodes_in_group("containers"):
		var off: Vector3 = c.global_position - global_position
		off.y = 0.0  # só a distância no chão conta
		var d2: float = off.length()
		if d2 < float(c.reach) and d2 < best:
			best = d2
			_target = c

	if _target == null:
		hint_text = ""
		if controls != null:
			controls.action_label = "AÇÃO"
	elif _target.is_in_group("containers"):
		hint_text = "%s - toque em ABRIR" % _target.title
		if controls != null:
			controls.action_label = "ABRIR"
	else:
		hint_text = "%s - toque em PEGAR" % _target.display_name()
		if controls != null:
			controls.action_label = "PEGAR"


func _interact() -> void:
	if dead or ui_locked:
		return
	if _target == null or not is_instance_valid(_target):
		GameManager.notify("Nada para usar aqui")
	elif _target.is_in_group("containers"):
		container_opened.emit(_target)
	else:
		_pickup(_target)


func _pickup(g) -> void:
	var id: String = g.item_id
	var want: int = g.count
	var added: int = inventory.add(id, want, g.durability)
	var label: String = ItemDB.name_of(id)
	if added <= 0:
		GameManager.notify("Pesado demais! Largue alguma coisa antes.")
	elif added < want:
		g.count = want - added
		GameManager.notify("Mochila cheia: pegou só %d de %s" % [added, label])
	else:
		_target = null
		g.remove_from_group("pickups")
		g.queue_free()
		if want > 1:
			GameManager.notify("Pegou: %s x%d" % [label, want])
		else:
			GameManager.notify("Pegou: %s" % label)


# --- Mochila: usar, equipar, largar e desmontar (chamados pela tela da mochila) ---

func _give_starting_items() -> void:
	inventory.add("bat", 1)
	inventory.set_equipped(int(inventory.entries[0]["uid"]))
	inventory.add("water_bottle", 1)
	inventory.add("canned_beans", 1)
	inventory.add("bandage", 2)


func use_item(uid: int) -> void:
	if dead:
		return
	var e: Dictionary = inventory.find_uid(uid)
	if e.is_empty():
		return
	var id := str(e["id"])
	var nm: String = ItemDB.name_of(id)
	if ItemDB.is_weapon(id):
		equip_item(uid)
		return
	var data := ItemDB.get_item(id)
	var food := float(data.get("food", 0.0))
	var water := float(data.get("water", 0.0))
	var heal := float(data.get("heal", 0.0))
	var harm := float(data.get("harm", 0.0))
	if food == 0.0 and water == 0.0 and heal == 0.0:
		if bool(data.get("later", false)):
			GameManager.notify("%s: ainda sem efeito (chega com a saúde por partes do corpo)." % nm)
		else:
			GameManager.notify("%s não se usa assim. Serve para crafting ou desmontar." % nm)
		return
	if food > 0.0 and water == 0.0 and heal == 0.0 and hunger >= 99.0:
		GameManager.notify("Você não está com fome agora.")
		return
	if water > 0.0 and food == 0.0 and heal == 0.0 and thirst >= 99.0:
		GameManager.notify("Você não está com sede agora.")
		return
	if heal > 0.0 and food == 0.0 and water == 0.0 and health >= max_health - 0.5:
		GameManager.notify("Você não está ferido.")
		return

	hunger = clampf(hunger + food, 0.0, 100.0)
	thirst = clampf(thirst + water, 0.0, 100.0)
	health = minf(max_health, health + heal)
	inventory.remove_uid(uid, 1)
	var back := str(data.get("returns", ""))
	if back != "":
		_give_or_drop(back, 1)
	var verb := "Usou"
	if str(data["cat"]) == "food":
		verb = "Comeu"
	elif str(data["cat"]) == "drink":
		verb = "Bebeu"
	GameManager.notify("%s: %s" % [verb, nm])
	if harm > 0.0:
		_vital_damage(harm)
		GameManager.notify("%s fez mal! (-%d de vida)" % [nm, int(harm)])


func equip_item(uid: int) -> void:
	var e: Dictionary = inventory.find_uid(uid)
	if e.is_empty() or not ItemDB.is_weapon(str(e["id"])):
		return
	var nm: String = ItemDB.name_of(str(e["id"]))
	if inventory.equipped_uid == uid:
		inventory.set_equipped(0)
		GameManager.notify("Guardou: %s" % nm)
	else:
		inventory.set_equipped(uid)
		GameManager.notify("Equipou: %s" % nm)


func drop_item(uid: int, n: int = 1) -> void:
	var e: Dictionary = inventory.find_uid(uid)
	if e.is_empty():
		return
	var id := str(e["id"])
	var dur := float(e["dur"])
	var moved: int = inventory.remove_uid(uid, n)
	if moved <= 0:
		return
	_spawn_ground(id, moved, dur)
	if moved > 1:
		GameManager.notify("Largou: %s x%d" % [ItemDB.name_of(id), moved])
	else:
		GameManager.notify("Largou: %s" % ItemDB.name_of(id))


func dismantle_item(uid: int) -> void:
	var e: Dictionary = inventory.find_uid(uid)
	if e.is_empty():
		return
	var id := str(e["id"])
	var data := ItemDB.get_item(id)
	if not data.has("dismantle"):
		return
	var needs := str(data.get("needs", ""))
	if needs != "" and not inventory.has_item(needs):
		GameManager.notify("Precisa de: %s" % ItemDB.name_of(needs))
		return
	inventory.remove_uid(uid, 1)
	var parts: Array[String] = []
	for p in data["dismantle"]:
		_give_or_drop(str(p[0]), int(p[1]))
		parts.append("%dx %s" % [int(p[1]), ItemDB.name_of(str(p[0]))])
	GameManager.notify("Desmontou %s: %s" % [ItemDB.name_of(id), ", ".join(PackedStringArray(parts))])


## Põe na mochila; o que não couber cai no chão.
func _give_or_drop(id: String, n: int) -> void:
	var added: int = inventory.add(id, n)
	if added < n:
		_spawn_ground(id, n - added, -1.0)


func _spawn_ground(id: String, n: int, dur: float) -> void:
	var g = GroundItemScript.new()
	var d := dur
	if d < 0.0:
		d = ItemDB.max_durability_of(id)
	g.setup(id, n, d)
	get_parent().add_child(g)
	var fwd := -_body.global_transform.basis.z
	g.global_position = global_position + fwd * 0.9 + Vector3(randf_range(-0.2, 0.2), 0.05, randf_range(-0.2, 0.2))


func weapon_name() -> String:
	var e: Dictionary = inventory.equipped_entry()
	if e.is_empty():
		return "Punhos"
	return ItemDB.name_of(str(e["id"]))


# --- Combate ---

## Dano, alcance, custo de stamina e recarga da arma equipada (ou dos punhos).
func _weapon_stats() -> Dictionary:
	var e: Dictionary = inventory.equipped_entry()
	if e.is_empty():
		return {"dmg": UNARMED_DAMAGE, "range": UNARMED_RANGE, "cost": UNARMED_COST, "cd": UNARMED_COOLDOWN}
	var data := ItemDB.get_item(str(e["id"]))
	if data.has("ammo"):  # arma de fogo: o tiro chega na Fase 6, por enquanto é coronhada
		return {"dmg": 10.0, "range": 1.8, "cost": 10.0, "cd": 0.6}
	return {
		"dmg": float(data.get("dmg", UNARMED_DAMAGE)),
		"range": float(data.get("range", 2.0)),
		"cost": float(data.get("cost", 12.0)),
		"cd": float(data.get("cd", 0.55)),
	}


func _try_attack() -> void:
	if dead or ui_locked or _attack_cd > 0.0 or stamina < 1.0:
		return
	var stats := _weapon_stats()
	stamina = maxf(0.0, stamina - float(stats["cost"]))
	_regen_timer = REGEN_DELAY
	_attack_cd = float(stats["cd"]) * (1.6 if exhausted else 1.0)
	_body.rotation.y = rig.yaw
	_swing_weapon()

	var fwd := -_body.global_transform.basis.z
	var power := float(stats["dmg"]) * (0.6 if exhausted else 1.0)
	var reach := float(stats["range"])
	var hit := false
	for z in get_tree().get_nodes_in_group("zombies"):
		var to: Vector3 = z.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > 0.01 and dist < reach and fwd.dot(to / dist) > 0.25:
			z.take_damage(power, global_position)
			hit = true
	if hit:
		rig.shake(0.25)
		_wear_weapon()


## Cada golpe que acerta desgasta a arma; durabilidade zerada = quebra.
func _wear_weapon() -> void:
	var e: Dictionary = inventory.equipped_entry()
	if e.is_empty():
		return
	var id := str(e["id"])
	if ItemDB.max_durability_of(id) <= 0.0:
		return
	e["dur"] = float(e["dur"]) - 1.0
	if float(e["dur"]) <= 0.0:
		GameManager.notify("%s quebrou!" % ItemDB.name_of(id))
		inventory.remove_uid(int(e["uid"]), 1)


func _swing_weapon() -> void:
	var tw := create_tween()
	tw.tween_property(_weapon_pivot, "rotation_degrees:x", -125.0, 0.12)
	tw.tween_property(_weapon_pivot, "rotation_degrees:x", -15.0, 0.25)


## Troca o modelo provisório na mão conforme a arma equipada.
func _update_weapon_visual() -> void:
	if _weapon_pivot == null:
		return
	var e: Dictionary = inventory.equipped_entry()
	var id := ""
	if not e.is_empty():
		id = str(e["id"])
	if id == _shown_weapon:
		return
	_shown_weapon = id
	for c in _weapon_pivot.get_children():
		_weapon_pivot.remove_child(c)
		c.queue_free()
	if id == "":
		_mesh_node(_weapon_pivot, _sphere_mesh(0.09), Vector3(0.0, 0.3, 0.0), Color(0.85, 0.68, 0.55))  # punho
		return
	var data := ItemDB.get_item(id)
	var length := float(data.get("len", 0.6))
	var color: Color = ItemDB.color_of(id)
	_mesh_node(_weapon_pivot, _box_mesh(Vector3(0.07, length, 0.07)), Vector3(0.0, length * 0.5, 0.0), color)
	if bool(data.get("head", false)):
		_mesh_node(_weapon_pivot, _box_mesh(Vector3(0.26, 0.14, 0.06)), Vector3(0.0, length - 0.07, 0.0), Color(0.62, 0.62, 0.66))


func take_damage(amount: float) -> void:
	if dead:
		return
	health -= amount
	rig.shake(0.5)
	if GameSettings.vibration:
		Input.vibrate_handheld(60)
	_check_death()


## Dano que não vem de golpe (fome, sede, água suja): sem tremor de câmera.
func _vital_damage(amount: float) -> void:
	if dead:
		return
	health -= amount
	_check_death()


func _check_death() -> void:
	if health <= 0.0 and not dead:
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
	# O modelo da arma é montado por _update_weapon_visual()


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
