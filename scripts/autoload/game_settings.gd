extends Node
## Autoload "GameSettings": opções do jogador (gráficos, controles, áudio, jogo).
## Salva em user://settings.cfg e aplica na hora. Emite "changed" a cada mudança.

signal changed

const SAVE_PATH := "user://settings.cfg"

const PRESET_ORDER := ["batata", "baixo", "medio", "alto", "ultra"]
const PRESET_NAMES := ["Batata (ultra baixo)", "Baixo", "Médio", "Alto", "Ultra", "Personalizado"]

# Escala de resolução (%), índice do limite de FPS, distância, sombras, antialiasing, bloom
const PRESETS := {
	"batata": {"render_scale": 60, "fps_index": 0, "draw_distance": 0, "shadows": 0, "aa": 0, "bloom": false},
	"baixo": {"render_scale": 75, "fps_index": 1, "draw_distance": 0, "shadows": 1, "aa": 0, "bloom": false},
	"medio": {"render_scale": 85, "fps_index": 2, "draw_distance": 1, "shadows": 2, "aa": 0, "bloom": false},
	"alto": {"render_scale": 100, "fps_index": 2, "draw_distance": 2, "shadows": 2, "aa": 1, "bloom": true},
	"ultra": {"render_scale": 100, "fps_index": 3, "draw_distance": 2, "shadows": 3, "aa": 2, "bloom": true},
}

const FPS_OPTIONS := [30, 45, 60, 90, 120]
const DISTANCE_M := [80.0, 130.0, 200.0]
const SHADOW_DISTANCE_M := [0.0, 30.0, 50.0, 80.0]
const SHADOW_ATLAS := [1024, 1024, 2048, 4096]
const DAY_MINUTES := [15, 30, 60, 120]

# Gráficos
var preset: String = "medio"  # ou "custom"
var render_scale: int = 85
var fps_index: int = 2
var draw_distance: int = 1
var shadows: int = 2
var aa: int = 0
var bloom: bool = false
var ssao: bool = false
var reflections: bool = false
var show_stats: bool = true
# Controles
var look_sensitivity: float = 0.16
var look_accel: float = 0.8
var invert_y: bool = false
var button_scale: float = 1.0
var vibration: bool = true
# Áudio
var master_volume: float = 1.0
# Jogo
var day_index: int = 2
var auto_weather: bool = true

const SAVED_KEYS := [
	"preset", "render_scale", "fps_index", "draw_distance", "shadows", "aa", "bloom",
	"ssao", "reflections", "show_stats", "look_sensitivity", "look_accel", "invert_y",
	"button_scale", "vibration", "master_volume", "day_index", "auto_weather",
]
const PRESET_KEYS := ["render_scale", "fps_index", "draw_distance", "shadows", "aa", "bloom"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply()


func distance_m() -> float:
	return DISTANCE_M[clampi(draw_distance, 0, DISTANCE_M.size() - 1)]


func day_minutes() -> int:
	return DAY_MINUTES[clampi(day_index, 0, DAY_MINUTES.size() - 1)]


## Troca uma opção. Mexer numa opção de gráficos vira o preset "Personalizado".
func set_setting(key: String, value) -> void:
	set(key, value)
	if key in PRESET_KEYS:
		preset = "custom"
	apply()
	save_settings()


func apply_preset(preset_name: String) -> void:
	if not PRESETS.has(preset_name):
		return
	var p: Dictionary = PRESETS[preset_name]
	for k in p:
		set(k, p[k])
	preset = preset_name
	apply()
	save_settings()


func preset_index() -> int:
	var i := PRESET_ORDER.find(preset)
	return i if i >= 0 else PRESET_ORDER.size()


func apply() -> void:
	Engine.max_fps = FPS_OPTIONS[clampi(fps_index, 0, FPS_OPTIONS.size() - 1)]

	var root := get_tree().root
	root.scaling_3d_scale = clampf(render_scale / 100.0, 0.5, 1.0)
	match aa:
		1:
			root.msaa_3d = Viewport.MSAA_2X
		2:
			root.msaa_3d = Viewport.MSAA_4X
		_:
			root.msaa_3d = Viewport.MSAA_DISABLED

	var atlas: int = SHADOW_ATLAS[clampi(shadows, 0, SHADOW_ATLAS.size() - 1)]
	RenderingServer.directional_shadow_atlas_set_size(atlas, true)

	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	changed.emit()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in SAVED_KEYS:
		cfg.set_value("settings", k, get(k))
	cfg.save(SAVE_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for k in SAVED_KEYS:
		if cfg.has_section_key("settings", k):
			set(k, cfg.get_value("settings", k))
