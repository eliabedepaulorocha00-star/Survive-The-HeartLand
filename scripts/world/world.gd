extends Node3D
## Mundo de teste (fatia jogável): chão, estrada, uma casa de dois lados,
## caminhonete, pinheiros, zumbis e o jogador. Tudo montado por código
## com formas simples; os modelos e texturas pintadas à mão entram depois.

const PlayerScript = preload("res://scripts/player/player.gd")
const ZombieScript = preload("res://scripts/world/zombie.gd")
const HordeScript = preload("res://scripts/world/horde_manager.gd")
const HudScript = preload("res://scripts/ui/hud.gd")
const ContainerScript = preload("res://scripts/world/container.gd")
const GroundItemScript = preload("res://scripts/world/ground_item.gd")
const TimeWeatherScript = preload("res://scripts/world/time_weather.gd")

const TREE_COUNT := 70
const WORLD_LIMIT := 95.0
const PLAYER_START := Vector3(0.0, 0.2, 14.0)

var _player
var _sun: DirectionalLight3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _time_weather


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_house(Vector3(0.0, 0.0, -6.0))
	_build_truck(Vector3(-12.0, 0.0, 11.5), 12.0)
	_build_trees()
	_build_outdoor_loot()
	_build_boundaries()
	_spawn_player()
	_spawn_zombies()
	_spawn_hud()
	_spawn_time_weather()
	GameSettings.changed.connect(_apply_settings)
	_apply_settings()
	GameManager.change_state(GameManager.State.IN_GAME)


func _on_pause_pressed() -> void:
	if GameManager.state == GameManager.State.IN_GAME:
		GameManager.change_state(GameManager.State.PAUSED)


func _on_player_died() -> void:
	GameManager.change_state(GameManager.State.PLAYER_DEAD)


# --- Ambiente e luz (entardecer nublado) ---

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.20, 0.27, 0.36)
	sky_mat.sky_horizon_color = Color(0.85, 0.55, 0.35)
	sky_mat.ground_horizon_color = Color(0.45, 0.35, 0.30)
	sky_mat.ground_bottom_color = Color(0.12, 0.12, 0.13)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# A cor do ambiente é atualizada pelo ciclo dia/noite (time_weather.gd)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.55)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.55, 0.50, 0.50)
	env.fog_density = 0.012
	env.glow_intensity = 0.8
	env.glow_hdr_threshold = 1.0

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.72, 0.5)
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-18.0, -50.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 50.0
	add_child(sun)

	_sun = sun
	_env = env
	_sky_mat = sky_mat


## Sombras e bloom seguem as configurações do jogador.
func _apply_settings() -> void:
	if _sun == null or _env == null:
		return
	var level := clampi(GameSettings.shadows, 0, 3)
	_sun.shadow_enabled = level > 0
	_sun.directional_shadow_max_distance = GameSettings.SHADOW_DISTANCE_M[level]
	_env.glow_enabled = GameSettings.bloom


func _spawn_time_weather() -> void:
	_time_weather = TimeWeatherScript.new()
	add_child(_time_weather)
	_time_weather.setup(_sun, _env, _sky_mat, _player)


# --- Terreno ---

func _build_ground() -> void:
	_add_box(self, Vector3(400.0, 1.0, 400.0), Vector3(0.0, -0.5, 0.0), Color(0.24, 0.29, 0.17))
	# Estrada de asfalto com faixa central
	_add_box(self, Vector3(400.0, 0.04, 6.0), Vector3(0.0, 0.02, 8.0), Color(0.13, 0.13, 0.14), false)
	for i in range(-20, 20):
		_add_box(self, Vector3(2.0, 0.045, 0.15), Vector3(i * 6.0, 0.03, 8.0), Color(0.75, 0.65, 0.25), false)
	# Caminho de terra até a casa
	_add_box(self, Vector3(2.0, 0.03, 8.0), Vector3(0.0, 0.015, 1.5), Color(0.35, 0.28, 0.18), false)


func _build_boundaries() -> void:
	# Paredes invisíveis para o jogador não sair do mapa de teste.
	var half := WORLD_LIMIT
	var specs := [
		[Vector3(half * 2.0, 6.0, 1.0), Vector3(0.0, 3.0, -half)],
		[Vector3(half * 2.0, 6.0, 1.0), Vector3(0.0, 3.0, half)],
		[Vector3(1.0, 6.0, half * 2.0), Vector3(-half, 3.0, 0.0)],
		[Vector3(1.0, 6.0, half * 2.0), Vector3(half, 3.0, 0.0)],
	]
	for s in specs:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = s[0]
		cs.shape = shape
		body.add_child(cs)
		body.position = s[1]
		add_child(body)


# --- Casa ---

func _build_house(pos: Vector3) -> void:
	var house := Node3D.new()
	house.position = pos
	add_child(house)

	var wall := Color(0.78, 0.76, 0.70)
	var roof := Color(0.22, 0.20, 0.19)
	var wood := Color(0.42, 0.30, 0.18)

	# Piso (só visual)
	_add_box(house, Vector3(10.0, 0.06, 8.0), Vector3(0.0, 0.03, 0.0), Color(0.36, 0.28, 0.20), false)
	# Paredes: fundo, laterais e frente com porta
	_add_box(house, Vector3(10.0, 3.0, 0.3), Vector3(0.0, 1.5, -4.0), wall)
	_add_box(house, Vector3(0.3, 3.0, 8.0), Vector3(-5.0, 1.5, 0.0), wall)
	_add_box(house, Vector3(0.3, 3.0, 8.0), Vector3(5.0, 1.5, 0.0), wall)
	_add_box(house, Vector3(4.2, 3.0, 0.3), Vector3(-2.9, 1.5, 4.0), wall)
	_add_box(house, Vector3(4.2, 3.0, 0.3), Vector3(2.9, 1.5, 4.0), wall)
	_add_box(house, Vector3(1.6, 0.8, 0.3), Vector3(0.0, 2.6, 4.0), wall)
	# Tábuas pregadas nas "janelas" da frente
	for i in 3:
		_add_box(house, Vector3(1.6, 0.18, 0.08), Vector3(-2.9, 1.2 + i * 0.4, 4.18), wood, false, Vector3(0.0, 0.0, 4.0 - i * 4.0))
		_add_box(house, Vector3(1.6, 0.18, 0.08), Vector3(2.9, 1.2 + i * 0.4, 4.18), wood, false, Vector3(0.0, 0.0, -4.0 + i * 4.0))
	# Telhado de duas águas (visual) e empenas
	_add_box(house, Vector3(10.8, 0.2, 5.2), Vector3(0.0, 4.3, 2.25), roof, true, Vector3(30.0, 0.0, 0.0))
	_add_box(house, Vector3(10.8, 0.2, 5.2), Vector3(0.0, 4.3, -2.25), roof, true, Vector3(-30.0, 0.0, 0.0))
	for sx in [-5.0, 5.0]:
		var gable := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(8.9, 1.8, 0.3)
		gable.mesh = prism
		gable.material_override = _mat(wall)
		gable.position = Vector3(sx, 3.9, 0.0)
		gable.rotation_degrees = Vector3(0.0, 90.0, 0.0)
		house.add_child(gable)

	# Móveis (cada um é um recipiente com loot sorteado na primeira abertura)
	_add_box(house, Vector3(1.6, 0.8, 0.8), Vector3(-2.5, 0.4, -2.8), Color(0.40, 0.30, 0.20))
	_add_container(house, "Armário da cozinha", "kitchen", Vector3(-2.5, 0.8, -2.8))
	_add_box(house, Vector3(0.8, 0.8, 0.8), Vector3(3.2, 0.4, -3.0), Color(0.45, 0.32, 0.22))
	_add_container(house, "Cômoda do quarto", "bedroom", Vector3(3.2, 0.8, -3.0))
	_add_box(house, Vector3(0.3, 0.9, 0.8), Vector3(4.65, 1.5, 0.8), Color(0.82, 0.82, 0.78))
	_add_container(house, "Armário de remédios", "bathroom", Vector3(4.65, 1.95, 0.8))

	# Lampião aceso
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.75, 0.4)
	lamp.light_energy = 1.6
	lamp.omni_range = 9.0
	lamp.position = Vector3(0.0, 2.3, 0.0)
	house.add_child(lamp)

	# Um item solto no chão para testar o PEGAR
	_add_ground(house, "canned_beans", 1, Vector3(1.0, 0.07, 1.5))


func _add_container(parent: Node3D, title: String, table: String, pos: Vector3, reach: float = 2.4) -> void:
	var c = ContainerScript.new()
	c.title = title
	c.loot_table = table
	c.reach = reach
	c.position = pos
	parent.add_child(c)


func _add_ground(parent: Node3D, id: String, n: int, pos: Vector3) -> void:
	var g = GroundItemScript.new()
	g.setup(id, n, ItemDB.max_durability_of(id))
	parent.add_child(g)
	g.position = pos


## Caixa de ferramentas no quintal e itens espalhados pelo mapa (sorteio fixo, igual em toda partida).
func _build_outdoor_loot() -> void:
	_add_box(self, Vector3(0.9, 0.5, 0.45), Vector3(7.5, 0.25, -2.0), Color(0.70, 0.15, 0.12))
	_add_container(self, "Caixa de ferramentas", "garage", Vector3(7.5, 0.5, -2.0))
	_add_ground(self, "water_bottle", 1, Vector3(2.5, 0.07, 11.8))

	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var spots := 0
	var tries := 0
	while spots < 14 and tries < 400:
		tries += 1
		var x := rng.randf_range(-35.0, 35.0)
		var z := rng.randf_range(-8.0, 38.0)
		if absf(x) < 8.0 and z > -13.0 and z < 1.0:
			continue  # dentro da casa
		for e in ItemDB.roll_loot("roadside", rng):
			_add_ground(self, str(e["id"]), int(e["n"]), Vector3(x, 0.07, z))
		spots += 1


# --- Caminhonete abandonada ---

func _build_truck(pos: Vector3, yaw_deg: float) -> void:
	var truck := Node3D.new()
	truck.position = pos
	truck.rotation_degrees.y = yaw_deg
	add_child(truck)
	var paint := Color(0.25, 0.48, 0.46)
	_add_box(truck, Vector3(2.0, 0.9, 4.6), Vector3(0.0, 0.85, 0.0), paint)
	_add_box(truck, Vector3(1.9, 0.8, 1.8), Vector3(0.0, 1.7, -0.5), paint.darkened(0.1), false)
	_add_container(truck, "Caçamba da caminhonete", "vehicle", Vector3(0.0, 1.35, 1.7), 2.8)
	for x in [-1.0, 1.0]:
		for z in [-1.5, 1.5]:
			var wheel := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.42
			cyl.bottom_radius = 0.42
			cyl.height = 0.3
			wheel.mesh = cyl
			wheel.material_override = _mat(Color(0.06, 0.06, 0.06))
			wheel.position = Vector3(x, 0.42, z)
			wheel.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			truck.add_child(wheel)


# --- Pinheiros ---

func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261122
	var placed := 0
	var tries := 0
	while placed < TREE_COUNT and tries < 3000:
		tries += 1
		var x := rng.randf_range(-WORLD_LIMIT + 4.0, WORLD_LIMIT - 4.0)
		var z := rng.randf_range(-WORLD_LIMIT + 4.0, WORLD_LIMIT - 4.0)
		if absf(x) < 16.0 and z > -18.0 and z < 18.0:
			continue  # área da casa e do início
		if z > 3.0 and z < 13.0:
			continue  # estrada
		_add_tree(Vector3(x, 0.0, z), rng)
		placed += 1


func _add_tree(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var tree := StaticBody3D.new()
	tree.position = pos
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.3
	shape.height = 4.0
	cs.shape = shape
	cs.position.y = 2.0
	tree.add_child(cs)

	var s := rng.randf_range(0.8, 1.35)
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.2
	tm.bottom_radius = 0.3
	tm.height = 4.0
	trunk.mesh = tm
	trunk.material_override = _mat(Color(0.28, 0.2, 0.13))
	trunk.position.y = 2.0
	tree.add_child(trunk)

	var green := Color(0.10, 0.25 + rng.randf() * 0.08, 0.14)
	for i in 2:
		var crown := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 2.0 - i * 0.6
		cm.height = 3.2
		crown.mesh = cm
		crown.material_override = _mat(green)
		crown.position.y = 3.6 + i * 1.8
		tree.add_child(crown)

	tree.scale = Vector3(s, s, s)
	add_child(tree)


# --- Jogador, zumbis e HUD ---

func _spawn_player() -> void:
	_player = PlayerScript.new()
	_player.position = PLAYER_START
	_player.died.connect(_on_player_died)
	add_child(_player)


func _spawn_zombies() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var count := 0
	var tries := 0
	while count < 8 and tries < 200:
		tries += 1
		var a := rng.randf() * TAU
		var d := rng.randf_range(22.0, 55.0)
		var p := Vector3(cos(a) * d, 0.2, PLAYER_START.z + sin(a) * d)
		if absf(p.x) > WORLD_LIMIT - 6.0 or absf(p.z) > WORLD_LIMIT - 6.0:
			continue
		if absf(p.x) < 8.0 and p.z > -13.0 and p.z < 1.0:
			continue  # dentro da casa
		_add_zombie(p)
		count += 1
	# Dois dentro da casa
	_add_zombie(Vector3(-3.0, 0.2, -8.0))
	_add_zombie(Vector3(3.0, 0.2, -7.5))
	# Alguns rastejadores e hordas dinâmicas
	_add_zombie(Vector3(18.0, 0.2, 14.0), true)
	_add_zombie(Vector3(-22.0, 0.2, 6.0), true)
	var hm := HordeScript.new()
	hm.player = _player
	add_child(hm)


func _add_zombie(pos: Vector3, crawl: bool = false) -> void:
	var z := ZombieScript.new()
	z.crawler = crawl
	z.position = pos
	add_child(z)


func _spawn_hud() -> void:
	var hud = HudScript.new()
	add_child(hud)
	hud.player = _player
	_player.bind_controls(hud.controls)
	hud.controls.pause_pressed.connect(_on_pause_pressed)
	_player.container_opened.connect(hud.open_inventory)
	_player.inventory_requested.connect(hud.open_inventory)


# --- Auxiliares ---

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	return m


func _add_box(parent: Node, size: Vector3, pos: Vector3, color: Color, collide: bool = true, rot_deg: Vector3 = Vector3.ZERO) -> Node3D:
	var holder: Node3D
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		holder = body
	else:
		holder = Node3D.new()
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _mat(color)
	holder.add_child(mi)
	holder.position = pos
	holder.rotation_degrees = rot_deg
	parent.add_child(holder)
	return holder
