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
var debug_input: bool = false  # mostra na tela o que o teclado/mouse enviam (diagnóstico)
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


# --- Teclas (teclado e mouse) ---
# Cada ação tem 2 espaços. Teclado = código da tecla (>0); botão do mouse = -índice do botão.
const ACTIONS := [
	["forward", "Andar para frente", [KEY_W, KEY_UP]],
	["back", "Andar para trás", [KEY_S, KEY_DOWN]],
	["left", "Andar para a esquerda", [KEY_A, KEY_LEFT]],
	["right", "Andar para a direita", [KEY_D, KEY_RIGHT]],
	["sprint", "Correr (segurar)", [KEY_SHIFT, 0]],
	["crouch", "Agachar", [KEY_C, KEY_CTRL]],
	["interact", "Ação / pegar / abrir", [KEY_E, 0]],
	["attack", "Atacar / atirar", [-MOUSE_BUTTON_LEFT, KEY_F]],
	["aim", "Mirar em 1ª pessoa (segurar)", [-MOUSE_BUTTON_RIGHT, 0]],
	["reload", "Recarregar", [KEY_R, 0]],
	["inventory", "Mochila", [KEY_TAB, KEY_I]],
	["view", "Trocar câmera 1ª/3ª pessoa", [KEY_V, 0]],
	["pause", "Pausar", [KEY_ESCAPE, 0]],
]
var keybinds: Dictionary = {}


func reset_keybinds() -> void:
	keybinds = {}
	for a in ACTIONS:
		keybinds[a[0]] = (a[2] as Array).duplicate()


func binds_of(id: String) -> Array:
	return keybinds.get(id, [0, 0])


## Quer dizer: algum botão desta ação está pressionado agora?
func action_down(id: String) -> bool:
	for code in binds_of(id):
		var c: int = int(code)
		if c > 0 and Input.is_key_pressed(c as Key):
			return true
		if c < 0 and Input.is_mouse_button_pressed((-c) as MouseButton):
			return true
	return false


## O evento é o apertar (ou soltar, se `pressed` = false) desta ação?
func event_is(event: InputEvent, id: String, pressed: bool = true) -> bool:
	var code := 0
	if event is InputEventKey:
		if event.echo or event.pressed != pressed:
			return false
		code = int(event.keycode)
	elif event is InputEventMouseButton:
		if event.pressed != pressed:
			return false
		code = -int(event.button_index)
	else:
		return false
	return code != 0 and binds_of(id).has(code)


func bind_name(code: int) -> String:
	if code == 0:
		return "—"
	if code > 0:
		return OS.get_keycode_string(code as Key)
	match -code:
		MOUSE_BUTTON_LEFT:
			return "Mouse esquerdo"
		MOUSE_BUTTON_RIGHT:
			return "Mouse direito"
		MOUSE_BUTTON_MIDDLE:
			return "Mouse meio"
		_:
			return "Mouse botão %d" % (-code)


## Define o botão de uma ação; se ele já era de outra ação, tira de lá.
func set_bind(id: String, slot: int, code: int) -> void:
	if code != 0:
		for k in keybinds:
			var arr: Array = keybinds[k]
			for i in arr.size():
				if int(arr[i]) == code:
					arr[i] = 0
	var mine: Array = keybinds[id]
	mine[slot] = code
	save_settings()
	changed.emit()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_keybinds()
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
	for a in keybinds:
		cfg.set_value("keybinds", a, keybinds[a])
	cfg.save(SAVE_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for k in SAVED_KEYS:
		if cfg.has_section_key("settings", k):
			set(k, cfg.get_value("settings", k))
	for a in ACTIONS:
		if cfg.has_section_key("keybinds", a[0]):
			var v = cfg.get_value("keybinds", a[0])
			if v is Array and v.size() == 2:
				keybinds[a[0]] = [int(v[0]), int(v[1])]
