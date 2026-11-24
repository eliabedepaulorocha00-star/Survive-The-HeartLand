extends Node3D
## Mundo de teste (fatia jogável): chão, estrada, uma casa de dois lados,
## caminhonete, pinheiros, zumbis e o jogador. Tudo montado por código
## com formas simples; os modelos e texturas pintadas à mão entram depois.

const PlayerScript = preload("res://scripts/player/player.gd")
const ZombieScript = preload("res://scripts/world/zombie.gd")
const HordeScript = preload("res://scripts/world/horde_manager.gd")
const ChunkManagerScript = preload("res://scripts/world/chunk_manager.gd")
const HudScript = preload("res://scripts/ui/hud.gd")
const ContainerScript = preload("res://scripts/world/container.gd")
const GroundItemScript = preload("res://scripts/world/ground_item.gd")
const TimeWeatherScript = preload("res://scripts/world/time_weather.gd")

const WORLD_LIMIT := 348.0
const PLAYER_START := Vector3(0.0, 0.2, 14.0)

var _player
var chunks
var _sun: DirectionalLight3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _time_weather


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_boundaries()
	_spawn_player()
	_spawn_map()
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
	# Chão único; estradas, prédios e árvores vêm dos chunks (chunk_manager.gd)
	_add_box(self, Vector3(760.0, 1.0, 760.0), Vector3(0.0, -0.5, 0.0), Color(0.24, 0.29, 0.17))


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


# --- Jogador, zumbis e HUD ---

func _spawn_player() -> void:
	_player = PlayerScript.new()
	_player.position = PLAYER_START
	_player.died.connect(_on_player_died)
	add_child(_player)


func _spawn_map() -> void:
	# Mapa por chunks + hordas dinâmicas
	chunks = ChunkManagerScript.new()
	chunks.name = "Chunks"
	add_child(chunks)
	chunks.setup(_player)
	# Dois rastejadores perto do início
	_add_zombie(Vector3(18.0, 0.2, 18.0), true)
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
