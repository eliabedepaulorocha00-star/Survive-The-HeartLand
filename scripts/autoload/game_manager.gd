extends Node
## Autoload "GameManager": máquina de estados global do jogo.
## Estados: MainMenu, LobbySetup, LoadingWorld, InGame, Paused, PlayerDead.

enum State { MAIN_MENU, LOBBY_SETUP, LOADING_WORLD, IN_GAME, PAUSED, PLAYER_DEAD }

signal state_changed(old_state: int, new_state: int)
signal message(text: String)
signal debug_command(cmd: String)
signal sound_emitted(pos: Vector3, radius: float)

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const GAME_SCENE := "res://scenes/game.tscn"

var state: int = State.MAIN_MENU
var kills: int = 0

# Publicados pelo sistema de dia/noite e clima (time_weather.gd)
var visibility_factor: float = 1.0  # multiplica o alcance de visão dos zumbis
var noise_factor: float = 1.0  # multiplica o ruído dos passos (chuva abafa)
var rain_amount: float = 0.0
var weather_name: String = "Nublado"
var clock_text: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := get_tree().root
	if root.has_signal("go_back_requested"):
		root.connect("go_back_requested", _on_go_back)


## Troca de estado. As cenas antigas são liberadas pelo próprio Godot ao trocar de cena.
func change_state(new_state: int) -> void:
	if new_state == state:
		return
	var old: int = state
	state = new_state
	match new_state:
		State.MAIN_MENU:
			get_tree().paused = false
			get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		State.LOADING_WORLD:
			get_tree().paused = false
			kills = 0
			visibility_factor = 1.0
			noise_factor = 1.0
			rain_amount = 0.0
			get_tree().change_scene_to_file(GAME_SCENE)
		State.IN_GAME:
			get_tree().paused = false
		State.PAUSED:
			get_tree().paused = true
		_:
			pass
	state_changed.emit(old, new_state)


func start_game() -> void:
	change_state(State.LOADING_WORLD)


func back_to_menu() -> void:
	change_state(State.MAIN_MENU)


## Barulho no mundo (tiro, vidro quebrando, alarme): os zumbis dentro do raio vão investigar.
func emit_sound(pos: Vector3, radius: float) -> void:
	sound_emitted.emit(pos, radius)


func notify(text: String) -> void:
	message.emit(text)


## Botão "voltar" do Android.
func _on_go_back() -> void:
	match state:
		State.IN_GAME:
			change_state(State.PAUSED)
		State.PAUSED:
			change_state(State.IN_GAME)
		State.PLAYER_DEAD:
			change_state(State.MAIN_MENU)
		State.MAIN_MENU:
			get_tree().quit()
