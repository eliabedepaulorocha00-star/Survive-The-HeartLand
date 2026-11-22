extends Node
## Ciclo dia/noite de 24 horas e clima dinâmico.
## Controla sol, céu, névoa, chuva (partículas), raios e publica no GameManager
## os fatores de visão/ruído e o texto do relógio.

enum Weather { SUNNY, CLOUDY, RAIN, STORM, FOG }

# hora, céu (topo), céu (horizonte), cor do sol/lua, energia da luz, energia do ambiente, cor da névoa
const KEYS := [
	[0.0, Color(0.02, 0.03, 0.07), Color(0.05, 0.07, 0.12), Color(0.45, 0.55, 0.85), 0.10, 0.30, Color(0.05, 0.06, 0.09)],
	[5.5, Color(0.08, 0.10, 0.20), Color(0.30, 0.26, 0.32), Color(0.60, 0.60, 0.90), 0.15, 0.35, Color(0.15, 0.15, 0.20)],
	[7.0, Color(0.30, 0.42, 0.58), Color(0.95, 0.62, 0.40), Color(1.00, 0.70, 0.50), 0.70, 0.55, Color(0.70, 0.60, 0.55)],
	[12.0, Color(0.30, 0.50, 0.80), Color(0.70, 0.80, 0.90), Color(1.00, 0.97, 0.90), 1.20, 0.90, Color(0.70, 0.75, 0.80)],
	[17.5, Color(0.20, 0.27, 0.36), Color(0.85, 0.55, 0.35), Color(1.00, 0.72, 0.50), 1.10, 0.80, Color(0.55, 0.50, 0.50)],
	[19.5, Color(0.06, 0.08, 0.16), Color(0.35, 0.22, 0.25), Color(0.50, 0.45, 0.70), 0.15, 0.40, Color(0.20, 0.18, 0.22)],
	[24.0, Color(0.02, 0.03, 0.07), Color(0.05, 0.07, 0.12), Color(0.45, 0.55, 0.85), 0.10, 0.30, Color(0.05, 0.06, 0.09)],
]

# nuvens, densidade da névoa, chuva, visão dos zumbis, ruído dos passos, tempestade
const WEATHER_DATA := {
	Weather.SUNNY: {"name": "Ensolarado", "cloud": 0.0, "fog": 0.007, "rain": 0.0, "vis": 1.0, "noise": 1.0, "storm": false},
	Weather.CLOUDY: {"name": "Nublado", "cloud": 0.6, "fog": 0.012, "rain": 0.0, "vis": 0.9, "noise": 1.0, "storm": false},
	Weather.RAIN: {"name": "Chuva forte", "cloud": 0.85, "fog": 0.020, "rain": 1.0, "vis": 0.7, "noise": 0.65, "storm": false},
	Weather.STORM: {"name": "Tempestade", "cloud": 1.0, "fog": 0.026, "rain": 1.0, "vis": 0.6, "noise": 0.55, "storm": true},
	Weather.FOG: {"name": "Neblina densa", "cloud": 0.7, "fog": 0.060, "rain": 0.0, "vis": 0.35, "noise": 1.0, "storm": false},
}

var hour: float = 17.5
var day: int = 1
var weather: int = Weather.CLOUDY

var _sun: DirectionalLight3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _player
var _rain_node: GPUParticles3D

var _cloud: float = 0.6
var _fog: float = 0.012
var _rain: float = 0.0
var _vis: float = 0.9
var _noise: float = 1.0

var _weather_timer: float = 3.0  # horas de jogo até o próximo clima
var _thunder_timer: float = 8.0
var _flash: float = 0.0
var _last_minute: int = -1


func setup(sun: DirectionalLight3D, env: Environment, sky_mat: ProceduralSkyMaterial, player) -> void:
	_sun = sun
	_env = env
	_sky_mat = sky_mat
	_player = player
	_build_rain()
	GameManager.debug_command.connect(_on_debug_command)
	var d: Dictionary = WEATHER_DATA[weather]
	_cloud = d["cloud"]
	_fog = d["fog"]
	_vis = d["vis"]
	_noise = d["noise"]
	_update_sky()
	_update_clock_text()


func _process(delta: float) -> void:
	if _sun == null:
		return
	# Tempo do jogo
	hour += delta * 24.0 / (float(GameSettings.day_minutes()) * 60.0)
	_tick_day()

	# Clima
	if GameSettings.auto_weather:
		_weather_timer -= delta * 24.0 / (float(GameSettings.day_minutes()) * 60.0)
		if _weather_timer <= 0.0:
			_pick_next_weather()
	_blend_weather(delta)
	_update_thunder(delta)
	_update_sky()
	_update_rain()
	_update_clock_text()


func _tick_day() -> void:
	if hour >= 24.0:
		hour -= 24.0
		day += 1


# --- Clima ---

func set_weather(w: int) -> void:
	weather = w
	_weather_timer = randf_range(2.0, 5.0)
	_thunder_timer = randf_range(4.0, 10.0)


func _pick_next_weather() -> void:
	var options := [Weather.SUNNY, Weather.CLOUDY, Weather.RAIN, Weather.STORM, Weather.FOG]
	var weights := [0.30, 0.30, 0.20, 0.08, 0.12]
	var pick := randf()
	var acc := 0.0
	var chosen: int = Weather.CLOUDY
	for i in options.size():
		acc += weights[i]
		if pick <= acc:
			chosen = options[i]
			break
	if chosen == weather:
		chosen = (weather + 1) % 5
	set_weather(chosen)


func _blend_weather(delta: float) -> void:
	var d: Dictionary = WEATHER_DATA[weather]
	_cloud = move_toward(_cloud, d["cloud"], delta * 0.12)
	_fog = move_toward(_fog, d["fog"], delta * 0.004)
	_rain = move_toward(_rain, d["rain"], delta * 0.15)
	_vis = move_toward(_vis, d["vis"], delta * 0.1)
	_noise = move_toward(_noise, d["noise"], delta * 0.1)


func _update_thunder(delta: float) -> void:
	var d: Dictionary = WEATHER_DATA[weather]
	if d["storm"]:
		_thunder_timer -= delta
		if _thunder_timer <= 0.0:
			_thunder_timer = randf_range(7.0, 18.0)
			_flash = 1.0
			# trovão chega um pouco depois do clarão
			var rig = _player.rig if _player != null and is_instance_valid(_player) else null
			if rig != null:
				get_tree().create_timer(randf_range(0.8, 2.4)).timeout.connect(_thunder_rumble.bind(rig))
	_flash = move_toward(_flash, 0.0, delta * 3.5)


func _thunder_rumble(rig_ref) -> void:
	if is_instance_valid(rig_ref):
		rig_ref.shake(0.2)


# --- Céu e luz ---

func _sample(h: float) -> Dictionary:
	var i := 0
	while i < KEYS.size() - 2 and h >= KEYS[i + 1][0]:
		i += 1
	var a: Array = KEYS[i]
	var b: Array = KEYS[i + 1]
	var f := clampf((h - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
	return {
		"top": (a[1] as Color).lerp(b[1], f),
		"horizon": (a[2] as Color).lerp(b[2], f),
		"sun_color": (a[3] as Color).lerp(b[3], f),
		"sun_energy": lerpf(float(a[4]), float(b[4]), f),
		"ambient": lerpf(float(a[5]), float(b[5]), f),
		"fog": (a[6] as Color).lerp(b[6], f),
	}


func _update_sky() -> void:
	var s := _sample(hour)
	var light_level := clampf(float(s["ambient"]) / 0.9, 0.0, 1.0)
	var overcast := Color(0.30, 0.32, 0.35) * (0.25 + 0.75 * light_level)
	overcast.a = 1.0

	var top: Color = (s["top"] as Color).lerp(overcast, _cloud * 0.75)
	var horizon: Color = (s["horizon"] as Color).lerp(overcast * 1.1, _cloud * 0.8)
	horizon.a = 1.0
	_sky_mat.sky_top_color = top
	_sky_mat.sky_horizon_color = horizon
	_sky_mat.ground_horizon_color = horizon.darkened(0.4)
	_sky_mat.ground_bottom_color = top.darkened(0.6)

	# Posição do sol: sobe das 6h às 18h; de noite a "lua" fica baixa no mesmo caminho.
	var elevation := sin((hour - 6.0) / 24.0 * TAU) * 62.0
	elevation = maxf(elevation, 10.0)
	var azimuth := -110.0 + 220.0 * clampf((hour - 6.0) / 12.0, 0.0, 1.0)
	_sun.rotation_degrees = Vector3(-elevation, azimuth, 0.0)
	_sun.light_color = s["sun_color"]
	_sun.light_energy = float(s["sun_energy"]) * (1.0 - 0.65 * _cloud) + _flash * 2.5

	_env.ambient_light_color = top.lerp(horizon, 0.5).lightened(0.15)
	_env.ambient_light_energy = float(s["ambient"]) * (1.0 - 0.15 * _cloud) + _flash * 1.5
	_env.fog_light_color = (s["fog"] as Color).lerp(overcast, _cloud * 0.5)
	_env.fog_density = _fog

	# Publica fatores para zumbis e jogador
	GameManager.visibility_factor = _vis * lerpf(0.55, 1.0, light_level)
	GameManager.noise_factor = _noise
	GameManager.rain_amount = _rain
	GameManager.weather_name = String(WEATHER_DATA[weather]["name"])


func _update_clock_text() -> void:
	var minute_of_day := int(hour * 60.0)
	if minute_of_day == _last_minute:
		return
	_last_minute = minute_of_day
	GameManager.clock_text = "Dia %d  %02d:%02d  -  %s" % [day, int(hour), int(fmod(hour, 1.0) * 60.0), GameManager.weather_name]


# --- Chuva ---

func _build_rain() -> void:
	_rain_node = GPUParticles3D.new()
	_rain_node.amount = 700
	_rain_node.lifetime = 0.8
	_rain_node.local_coords = false
	_rain_node.emitting = false
	_rain_node.visibility_aabb = AABB(Vector3(-20.0, -14.0, -20.0), Vector3(40.0, 16.0, 40.0))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16.0, 0.2, 16.0)
	pm.direction = Vector3(0.0, -1.0, 0.0)
	pm.spread = 3.0
	pm.initial_velocity_min = 18.0
	pm.initial_velocity_max = 22.0
	pm.gravity = Vector3(0.0, -6.0, 0.0)
	_rain_node.process_material = pm

	var drop := BoxMesh.new()
	drop.size = Vector3(0.012, 0.55, 0.012)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.75, 0.82, 0.90, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.material = mat
	_rain_node.draw_pass_1 = drop
	add_child(_rain_node)


func _update_rain() -> void:
	if _player == null or not is_instance_valid(_player):
		_rain_node.emitting = false
		return
	_rain_node.global_position = _player.global_position + Vector3(0.0, 9.0, 0.0)
	_rain_node.set("amount_ratio", clampf(_rain, 0.05, 1.0))
	_rain_node.emitting = _rain > 0.05 and not _player.sheltered


# --- Comandos de teste (menu de pausa) ---

func _on_debug_command(cmd: String) -> void:
	match cmd:
		"next_weather":
			set_weather((weather + 1) % 5)
		"advance_3h":
			hour += 3.0
			_tick_day()
