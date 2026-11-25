extends CharacterBody3D
## Jogador: movimento com posturas (em pé, agachado, correndo), stamina e exaustão,
## fome e sede, mochila com peso, arma equipada, pegar itens e câmera híbrida.

signal died
signal container_opened(container)
signal inventory_requested

const CameraRigScript = preload("res://scripts/player/camera_rig.gd")
const InventoryScript = preload("res://scripts/player/inventory.gd")
const BodyHealthScript = preload("res://scripts/player/body_health.gd")
const HumanoidScript = preload("res://scripts/world/humanoid.gd")
const KbmScript = preload("res://scripts/player/kbm_input.gd")
const SurvivorScript = preload("res://scripts/world/survivor_model.gd")
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
var body  # BodyHealth (scripts/player/body_health.gd)
var death_cause: String = ""
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
var randomizer := RandomNumberGenerator.new()
var _humanoid
var reload_left: float = 0.0
var _reload_total: float = 1.0
var panic: float = 0.0  # 0..1: sobe com zumbis perto, piora a pontaria
var smell_radius: float = 0.0  # sangramento aberto: zumbis sentem de mais longe
var _bloom: float = 0.0
var _aim_hold: float = 0.0
var _aim_yaw: float = 0.0
var _reload_uid: int = 0
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
	inventory.capacity = inventory.BASE_CAPACITY + CharacterData.add("carry")
	body = BodyHealthScript.new()
	body.bleed_mult = CharacterData.mult("bleed")
	body.wound_mult = CharacterData.mult("wound")
	_build_visual()
	_give_starting_items()
	inventory.changed.connect(_update_weapon_visual)
	_update_weapon_visual()

	rig = CameraRigScript.new()
	add_child(rig)
	var kbm = KbmScript.new()
	kbm.player = self
	add_child(kbm)


func bind_controls(c) -> void:
	controls = c
	c.camera_toggle_pressed.connect(func(): rig.toggle_view())
	c.crouch_pressed.connect(toggle_crouch)
	c.action_pressed.connect(_interact)
	c.attack_pressed.connect(_try_attack)
	c.bag_pressed.connect(func(): inventory_requested.emit())
	c.reload_pressed.connect(start_reload)


func _unhandled_input(event: InputEvent) -> void:
	# Atalhos de teclado (útil para testar no computador).
	if dead or ui_locked or GameManager.state != GameManager.State.IN_GAME:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if GameSettings.event_is(event, "crouch"):
			toggle_crouch()
		elif GameSettings.event_is(event, "reload"):
			start_reload()
		elif GameSettings.event_is(event, "view"):
			rig.toggle_view()
		elif GameSettings.event_is(event, "interact"):
			_interact()
		elif GameSettings.event_is(event, "inventory"):
			inventory_requested.emit()
		elif GameSettings.event_is(event, "attack"):
			_try_attack()
		elif GameSettings.event_is(event, "pause") or event.keycode == KEY_ESCAPE:
			GameManager.change_state(GameManager.State.PAUSED)


func _process(delta: float) -> void:
	_body.visible = rig.blend < 0.8
	_humanoid.animate(Vector2(velocity.x, velocity.z).length(), delta)


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
	var wants_sprint: bool = GameSettings.action_down("sprint")
	if controls != null and controls.sprinting:
		wants_sprint = true
	sprinting = wants_sprint and moving and not crouching and not exhausted and stamina > 0.0 and body.can_sprint()

	var speed := WALK_SPEED
	if crouching:
		speed = CROUCH_SPEED
	elif sprinting:
		speed = SPRINT_SPEED
	speed *= strength
	if exhausted:
		speed *= 0.6
	speed *= CharacterData.mult("speed")
	speed *= float(inventory.speed_factor()) * float(body.speed_factor())  # peso demais deixa lento

	# Stamina e exaustão
	if sprinting:
		stamina -= SPRINT_COST * CharacterData.mult("sprint_cost") * delta
		_regen_timer = REGEN_DELAY
	elif _regen_timer > 0.0:
		_regen_timer -= delta
	else:
		stamina += STAMINA_REGEN * CharacterData.mult("stamina_regen") * (1.0 - 0.4 * wetness) * delta  # roupa molhada cansa mais
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
	noise_radius *= GameManager.noise_factor * CharacterData.mult("noise")  # a chuva abafa os passos

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
	if _aim_hold > 0.0:
		face_yaw = _aim_yaw
	elif rig.is_first_person():
		face_yaw = rig.yaw
	elif hv.length() > 0.3:
		face_yaw = atan2(-hv.x, -hv.z)
	_body.rotation.y = lerp_angle(_body.rotation.y, face_yaw, clampf(12.0 * delta, 0.0, 1.0))
	_humanoid.pose = "down" if dead else ("crouch" if crouching else "stand")
	_humanoid.reloading = reload_left > 0.0
	_humanoid.reload_progress = 1.0 - reload_left / maxf(_reload_total, 0.01)
	_humanoid.sprinting = sprinting
	_update_combat(delta)

	_update_target()


## Fome e sede caem com o tempo (mais rápido correndo). Zerar uma delas machuca; bem alimentado, a vida volta devagar.
func _update_needs(delta: float) -> void:
	var day_s: float = float(GameSettings.day_minutes()) * 60.0
	var hunger_rate: float = 100.0 / (day_s * HUNGER_DAYS) * CharacterData.mult("hunger_rate")
	var thirst_rate: float = 100.0 / (day_s * THIRST_DAYS) * CharacterData.mult("thirst_rate")
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
	var res: Dictionary = body.update(delta, day_s)
	if float(res["damage"]) > 0.0:
		death_cause = "Você sangrou até a morte." if body.bleeding_count() > 0 else "A infecção venceu."
		_vital_damage(float(res["damage"]))
	if bool(res["zombified"]):
		death_cause = "Você virou um deles..."
		_vital_damage(9999.0)
	if hunger > 50.0 and thirst > 50.0 and health < max_health and body.bleeding_count() == 0 and not dead:
		health = minf(max_health, health + 0.25 * CharacterData.mult("regen") * delta)


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
	if GameSettings.action_down("forward"):
		k.y += 1.0
	if GameSettings.action_down("back"):
		k.y -= 1.0
	if GameSettings.action_down("right"):
		k.x += 1.0
	if GameSettings.action_down("left"):
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

	if controls != null:
		var eq: Dictionary = inventory.equipped_entry()
		controls.reload_visible = (not eq.is_empty()) and ItemDB.is_firearm(str(eq["id"]))
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
	inventory.add("water_bottle", 1)
	inventory.add("canned_beans", 1)
	inventory.add("bandage", 2)
	var melee_uid := 0
	for it in CharacterData.start_items():
		inventory.add(str(it[0]), int(it[1]))
	for e in inventory.entries:
		var d := ItemDB.get_item(str(e["id"]))
		if melee_uid == 0 and bool(d.get("equip", false)) and not d.has("ammo"):
			melee_uid = int(e["uid"])
	if melee_uid == 0:
		inventory.add("bat", 1)
		melee_uid = int(inventory.entries[inventory.entries.size() - 1]["uid"])
	inventory.set_equipped(melee_uid)


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
	var treated := _treat(data)
	var is_treatment: bool = data.has("stop_bleed") or data.has("disinfect") or data.has("painkill") or data.has("antibiotic") or data.has("splint") or data.has("suture")
	if is_treatment and not treated and food == 0.0 and water == 0.0 and heal == 0.0:
		GameManager.notify("%s: não precisa agora." % nm)
		return
	if food == 0.0 and water == 0.0 and heal == 0.0 and not treated:
		GameManager.notify("%s não se usa assim. Serve para crafting ou desmontar." % nm)
		return
	if food > 0.0 and water == 0.0 and heal == 0.0 and hunger >= 99.0:
		GameManager.notify("Você não está com fome agora.")
		return
	if water > 0.0 and food == 0.0 and heal == 0.0 and thirst >= 99.0:
		GameManager.notify("Você não está com sede agora.")
		return
	if heal > 0.0 and food == 0.0 and water == 0.0 and health >= max_health - 0.5 and not treated:
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


## Aplica o efeito médico do item no corpo. true se serviu para algo.
func _treat(data: Dictionary) -> bool:
	var day_s: float = float(GameSettings.day_minutes()) * 60.0
	var used := false
	if data.has("stop_bleed") and body.stop_bleeding(str(data["stop_bleed"])):
		used = true
	if data.has("suture") and body.suture():
		used = true
	if data.has("disinfect") and body.disinfect():
		used = true
	if data.has("antibiotic") and body.antibiotic():
		used = true
	if data.has("painkill") and body.painkill(day_s * 0.15):
		used = true
	if data.has("splint") and body.splint(day_s):
		used = true
	return used


func can_craft(r: Dictionary) -> bool:
	for i in r["inputs"]:
		if int(inventory.count(str(i[0]))) < int(i[1]):
			return false
	for t in r["tools"]:
		var ok := false
		for alt in str(t).split("|"):
			if inventory.has_item(alt):
				ok = true
		if not ok:
			return false
	return true


func craft(recipe_id: String) -> void:
	if dead:
		return
	for r in ItemDB.RECIPES:
		if r["id"] != recipe_id:
			continue
		if not can_craft(r):
			GameManager.notify("Faltam ingredientes ou ferramentas.")
			return
		for i in r["inputs"]:
			for k in int(i[1]):
				inventory.consume_one(str(i[0]))
		for o in r["outputs"]:
			_give_or_drop(str(o[0]), int(o[1]))
		GameManager.notify("Criou: %s" % ItemDB.recipe_title(r))
		return


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
	unload_gun(uid)
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

## Golpe corpo a corpo da arma equipada (ou dos punhos; arma de fogo vira coronhada).
func _weapon_stats() -> Dictionary:
	var e: Dictionary = inventory.equipped_entry()
	if e.is_empty():
		return {"dmg": UNARMED_DAMAGE, "range": UNARMED_RANGE, "cost": UNARMED_COST, "cd": UNARMED_COOLDOWN, "arc": 90.0, "knock": 0.1}
	var data := ItemDB.get_item(str(e["id"]))
	if data.has("ammo"):
		return {"dmg": 10.0, "range": 1.8, "cost": 10.0, "cd": 0.6, "arc": 70.0, "knock": 0.2}
	return {
		"dmg": float(data.get("dmg", UNARMED_DAMAGE)),
		"range": float(data.get("range", 2.0)),
		"cost": float(data.get("cost", 12.0)),
		"cd": float(data.get("cd", 0.55)),
		"arc": float(data.get("arc", 90.0)),
		"knock": float(data.get("knock", 0.2)),
	}


func _try_attack() -> void:
	if dead or ui_locked or _attack_cd > 0.0:
		return
	var e: Dictionary = inventory.equipped_entry()
	if not e.is_empty() and ItemDB.is_firearm(str(e["id"])):
		_fire(e)
		return
	if stamina < 1.0:
		return
	var stats := _weapon_stats()
	var stomp_target = _find_stomp_target()
	var cost := float(stats["cost"]) * (0.6 if stomp_target != null else 1.0)
	stamina = maxf(0.0, stamina - cost)
	_regen_timer = REGEN_DELAY
	var cd := float(stats["cd"]) * (1.6 if exhausted else 1.0)
	_attack_cd = cd
	_aim_hold = 0.8
	if stomp_target != null:
		var to: Vector3 = stomp_target.global_position - global_position
		_aim_yaw = atan2(-to.x, -to.z)
		_body.rotation.y = _aim_yaw
		_attack_cd = 0.7
		_humanoid.play_attack("stomp", 0.6)
		get_tree().create_timer(0.3).timeout.connect(_resolve_stomp.bind(stomp_target))
	else:
		_aim_yaw = rig.yaw
		_body.rotation.y = rig.yaw
		_humanoid.play_attack("swing", cd)
		get_tree().create_timer(cd * 0.5).timeout.connect(_resolve_melee.bind(stats))


## Acerta quem está dentro do arco da arma, na hora em que o golpe desce.
func _resolve_melee(stats: Dictionary) -> void:
	if dead or not is_inside_tree():
		return
	var fwd := -_body.global_transform.basis.z
	var power := float(stats["dmg"]) * (0.6 if exhausted else 1.0) * float(body.attack_factor()) * CharacterData.mult("melee")
	var reach := float(stats["range"])
	var cos_arc := cos(deg_to_rad(float(stats["arc"]) * 0.5))
	var hit := false
	for z in get_tree().get_nodes_in_group("zombies"):
		var to: Vector3 = z.hit_point() - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > 0.01 and dist < reach and fwd.dot(to / dist) > cos_arc:
			z.take_damage(power, global_position, float(stats["knock"]))
			_blood_puff(z.hit_point() + Vector3(0.0, 0.9, 0.0))
			hit = true
	GameManager.emit_sound(global_position, 14.0)
	if hit:
		rig.shake(0.25)
		_wear_weapon()


## Zumbi caído (ou rastejando) perto da frente do jogador: dá para pisar na cabeça.
func _find_stomp_target():
	var fwd := -_body.global_transform.basis.z
	var best = null
	var best_d := 1.9
	for z in get_tree().get_nodes_in_group("zombies"):
		if not z.is_grounded():
			continue
		var to: Vector3 = Vector3.ZERO
		var near_len := 1000.0
		for p in [z.head_position(), z.hit_point(), z.global_position]:
			var cand: Vector3 = p - global_position
			cand.y = 0.0
			if cand.length() < near_len:
				near_len = cand.length()
				to = cand
		to.y = 0.0
		var d := to.length()
		if near_len >= 1000.0 or d < 0.001:
			continue
		if d < best_d and (d < 0.6 or fwd.dot(to / d) > 0.3):
			best_d = d
			best = z
	return best


func _resolve_stomp(z) -> void:
	if dead or z == null or not is_instance_valid(z):
		return
	z.take_damage(200.0, global_position, 0.0, true)
	_blood_puff(z.head_position() + Vector3(0.0, 0.1, 0.0))
	rig.shake(0.35)
	GameManager.emit_sound(global_position, 10.0)


# --- Armas de fogo ---

func _fire(e: Dictionary) -> void:
	var id := str(e["id"])
	var data := ItemDB.get_item(id)
	if reload_left > 0.0:
		return
	if int(e["mag"]) <= 0:
		_attack_cd = 0.35
		if inventory.count(str(data["ammo"])) > 0:
			start_reload()
		else:
			GameManager.notify("Sem munição (%s)." % ItemDB.name_of(str(data["ammo"])))
		return
	e["mag"] = int(e["mag"]) - 1
	_attack_cd = float(data["cd"])
	_aim_hold = 1.6
	var origin := global_position + Vector3(0.0, 1.4, 0.0)
	var range_m := float(data["range"])
	var aim := _aim_direction(origin, range_m)
	_aim_yaw = atan2(-aim.x, -aim.z)
	_body.rotation.y = _aim_yaw

	# Dispersão: base da arma + coice acumulado + pânico + correndo/andando; agachado ajuda
	var moving := clampf(Vector2(velocity.x, velocity.z).length() / 3.0, 0.0, 1.0)
	var spread := float(data["spread"]) + _bloom + panic * 3.0 + moving * 1.5 - (0.6 if crouching else 0.0)
	spread = maxf(0.2, spread)
	var pellets := int(data["pellets"])
	var pierce := int(data["pierce"]) if pellets == 1 else 1
	for i in pellets:
		_shoot_ray(origin, _spread_dir(aim, spread), range_m, float(data["dmg"]), pierce)

	_bloom = minf(10.0, _bloom + float(data["recoil"]) * 0.3)
	rig.kick(float(data["recoil"]) * 0.35)
	rig.shake(0.2 + float(data["recoil"]) * 0.03)
	if GameSettings.vibration:
		Input.vibrate_handheld(40)
	GameManager.emit_sound(global_position, float(data["noise"]))
	_humanoid.play_attack("shoot", 0.25)
	_muzzle_flash(origin + aim * 0.9)


## Direção da mira: para onde a câmera olha; com um pouco de ajuda (auto-mira) no zumbi mais próximo do centro.
func _aim_direction(origin: Vector3, range_m: float) -> Vector3:
	var yaw: float = rig.yaw
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var pitch_part := 0.0
	if rig.is_first_person():
		pitch_part = float(rig.pitch)
	var base := (fwd * cos(pitch_part) + Vector3.UP * sin(pitch_part)).normalized()
	var best = null
	var best_ang := deg_to_rad(11.0)
	for z in get_tree().get_nodes_in_group("zombies"):
		var p: Vector3 = z.hit_point() + Vector3(0.0, 0.9 if not z.is_grounded() else 0.1, 0.0)
		var to := p - origin
		var d := to.length()
		if d < 0.5 or d > range_m:
			continue
		var flat := Vector3(to.x, 0.0, to.z).normalized()
		var ang := fwd.angle_to(flat)
		if ang < best_ang:
			best_ang = ang
			best = to.normalized()
	if best != null:
		return best
	return base


func _spread_dir(aim: Vector3, spread_deg: float) -> Vector3:
	var up := Vector3.UP if absf(aim.y) < 0.95 else Vector3.RIGHT
	var basis := Basis.looking_at(aim, up)
	var ang := randf() * TAU
	var r := deg_to_rad(spread_deg) * sqrt(randf())
	return (basis * Vector3(sin(r) * cos(ang), sin(r) * sin(ang), -cos(r))).normalized()


## Raio do tiro. Acerta zumbis (camada 4) e para no cenário; `pierce` = quantos atravessa.
func _shoot_ray(origin: Vector3, dir: Vector3, range_m: float, dmg: float, pierce: int) -> void:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [get_rid()]
	var pos := origin
	var end := origin + dir * range_m
	var left := pierce
	var guard := 0
	while guard < 6:
		guard += 1
		var q := PhysicsRayQueryParameters3D.create(pos, origin + dir * range_m, 1 | 4)
		q.exclude = exclude
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		end = hit["position"]
		var col = hit["collider"]
		if col != null and col.is_in_group("zombies"):
			var dist := origin.distance_to(end)
			var power := dmg * (1.0 - 0.5 * dist / range_m)
			var head: bool = (not col.is_grounded()) and (end.y - col.global_position.y) > 1.5
			if head:
				power *= 2.5
			col.take_damage(power, global_position, 0.3)
			_blood_puff(end)
			exclude.append(col.get_rid())
			left -= 1
			pos = end + dir * 0.05
			if left <= 0:
				break
		else:
			_spark(end)
			break
	_tracer(origin + dir * 0.9, end)


func start_reload() -> void:
	var e: Dictionary = inventory.equipped_entry()
	if e.is_empty() or not ItemDB.is_firearm(str(e["id"])):
		return
	if reload_left > 0.0:
		return
	var data := ItemDB.get_item(str(e["id"]))
	var size := int(data["mag"])
	var need := size - int(e["mag"])
	if need <= 0:
		GameManager.notify("O pente já está cheio.")
		return
	if inventory.count(str(data["ammo"])) <= 0:
		GameManager.notify("Sem munição (%s)." % ItemDB.name_of(str(data["ammo"])))
		return
	reload_left = float(data["reload"]) * (0.5 + 0.5 * float(need) / float(size))
	_reload_total = reload_left
	_reload_uid = int(e["uid"])
	GameManager.notify("Recarregando...")


func _finish_reload() -> void:
	var e: Dictionary = inventory.equipped_entry()
	if e.is_empty() or int(e["uid"]) != _reload_uid:
		return
	var data := ItemDB.get_item(str(e["id"]))
	var need := int(data["mag"]) - int(e["mag"])
	var got: int = inventory.consume_n(str(data["ammo"]), need)
	e["mag"] = int(e["mag"]) + got
	GameManager.notify("Recarregou (%d/%d)." % [int(e["mag"]), int(data["mag"])])


## Descarrega a arma: as balas do pente voltam para a mochila (ou caem no chão).
func unload_gun(uid: int) -> void:
	var e: Dictionary = inventory.find_uid(uid)
	if e.is_empty() or int(e["mag"]) <= 0:
		return
	var data := ItemDB.get_item(str(e["id"]))
	_give_or_drop(str(data["ammo"]), int(e["mag"]))
	e["mag"] = 0
	if reload_left > 0.0 and _reload_uid == uid:
		reload_left = 0.0


## Texto do HUD para a arma equipada.
func weapon_status() -> String:
	var e: Dictionary = inventory.equipped_entry()
	if e.is_empty():
		return "Punhos"
	var id := str(e["id"])
	if not ItemDB.is_firearm(id):
		return ItemDB.name_of(id)
	var data := ItemDB.get_item(id)
	var txt := "%s  %d/%d  (+%d)" % [ItemDB.name_of(id), int(e["mag"]), int(data["mag"]), inventory.count(str(data["ammo"]))]
	if reload_left > 0.0:
		txt += "  recarregando..."
	return txt


func _update_combat(delta: float) -> void:
	_bloom = maxf(0.0, _bloom - 5.0 * delta)
	_aim_hold = maxf(0.0, _aim_hold - delta)
	if reload_left > 0.0:
		var e: Dictionary = inventory.equipped_entry()
		if e.is_empty() or int(e["uid"]) != _reload_uid:
			reload_left = 0.0  # trocou de arma: cancela
		else:
			reload_left -= delta
			if reload_left <= 0.0:
				reload_left = 0.0
				_finish_reload()
	# Pânico sobe com zumbis perseguindo por perto e desce com calma
	var near := 0
	for z in get_tree().get_nodes_in_group("zombies"):
		if z.is_chasing() and z.global_position.distance_to(global_position) < 8.0:
			near += 1
	panic = clampf(panic + (0.12 * float(mini(near, 4)) - 0.10) * delta, 0.0, 1.0)
	# Cheiro de sangue
	var bleeding: int = body.bleeding_count()
	smell_radius = minf(20.0, 5.0 + 4.0 * float(bleeding)) if bleeding > 0 else 0.0


# --- Efeitos ---

func _muzzle_flash(pos: Vector3) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.45)
	l.light_energy = 3.0
	l.omni_range = 7.0
	get_parent().add_child(l)
	l.global_position = pos
	get_tree().create_timer(0.06).timeout.connect(l.queue_free)


func _tracer(from: Vector3, to: Vector3) -> void:
	var len := from.distance_to(to)
	if len < 0.2:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.025, len)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.9, 0.5)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	get_parent().add_child(mi)
	mi.look_at_from_position((from + to) * 0.5, to, Vector3.UP)
	get_tree().create_timer(0.05).timeout.connect(mi.queue_free)


func _blood_puff(pos: Vector3) -> void:
	_particles(pos, Color(0.55, 0.03, 0.03), 10)


func _spark(pos: Vector3) -> void:
	_particles(pos, Color(0.9, 0.8, 0.5), 5)


func _particles(pos: Vector3, color: Color, amount: int) -> void:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.45
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0.0, -9.0, 0.0)
	var sm := SphereMesh.new()
	sm.radius = 0.025
	sm.height = 0.05
	sm.radial_segments = 4
	sm.rings = 2
	p.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = m
	get_parent().add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


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


## Troca o modelo provisório na mão conforme a arma equipada. A arma é filha da mão do boneco.
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
		_humanoid.armed = "none"
		return
	var data := ItemDB.get_item(id)
	var is_gun := data.has("ammo")
	_humanoid.armed = "gun" if is_gun else "melee"
	_weapon_pivot.rotation_degrees.x = 180.0 if is_gun else -134.0  # arma aponta à frente (arma de fogo) ou para cima (corpo a corpo)
	var length := float(data.get("len", 0.6))
	var color: Color = ItemDB.color_of(id)
	_mesh_node(_weapon_pivot, _box_mesh(Vector3(0.07, length, 0.07)), Vector3(0.0, length * 0.5, 0.0), color)
	if bool(data.get("head", false)):
		_mesh_node(_weapon_pivot, _box_mesh(Vector3(0.26, 0.14, 0.06)), Vector3(0.0, length - 0.07, 0.0), Color(0.62, 0.62, 0.66))
	if is_gun:
		_mesh_node(_weapon_pivot, _box_mesh(Vector3(0.06, 0.16, 0.09)), Vector3(0.0, -0.04, 0.05), color.darkened(0.2))  # empunhadura


func take_damage(amount: float) -> void:
	if dead:
		return
	health -= amount
	rig.shake(0.5)
	if GameSettings.vibration:
		Input.vibrate_handheld(60)
	_check_death()


## Golpe de zumbi: dano direto e um ferimento por partes do corpo.
func zombie_hit(amount: float) -> void:
	if dead:
		return
	death_cause = "Os zumbis pegaram você."
	panic = minf(1.0, panic + 0.25)
	_humanoid.flinch()
	take_damage(amount)
	GameManager.notify(body.hit(randomizer))


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
	var look := CharacterData.appearance()
	_humanoid = SurvivorScript.new() if look["use_model"] else HumanoidScript.new()
	_body.add_child(_humanoid)
	_humanoid.build(look, true)

	_weapon_pivot = Node3D.new()
	_weapon_pivot.position = Vector3(0.0, -0.30, 0.0)  # na mão direita
	_humanoid.hand.add_child(_weapon_pivot)
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
