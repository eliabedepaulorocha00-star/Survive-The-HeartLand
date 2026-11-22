extends Control
## Controles touch:
## - joystick dinâmico na metade esquerda (empurrar até a borda = correr)
## - arrastar na metade direita para olhar
## - botões contextuais (atacar, ação/pegar, agachar, câmera, pausa)

signal camera_toggle_pressed
signal crouch_pressed
signal action_pressed
signal attack_pressed
signal pause_pressed

const JOY_RADIUS := 100.0
const JOY_DEADZONE := 0.12
const SPRINT_THRESHOLD := 0.95

var move_vector := Vector2.ZERO  # x: direita, y: para baixo na tela (frente = -y)
var sprinting: bool = false
var look_delta := Vector2.ZERO

var action_label: String = "AÇÃO":
	set(value):
		if value != action_label:
			action_label = value
			queue_redraw()

var crouch_active: bool = false:
	set(value):
		if value != crouch_active:
			crouch_active = value
			queue_redraw()

var _move_touch: int = -1
var _look_touch: int = -1
var _move_origin := Vector2.ZERO
var _move_pos := Vector2.ZERO
var _buttons: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout_buttons)
	_layout_buttons()


func _layout_buttons() -> void:
	var w := size.x
	var h := size.y
	_buttons = {
		"attack": {"center": Vector2(w - 110.0, h - 120.0), "radius": 58.0, "touch": -1},
		"action": {"center": Vector2(w - 250.0, h - 85.0), "radius": 44.0, "touch": -1},
		"crouch": {"center": Vector2(w - 70.0, h - 250.0), "radius": 38.0, "touch": -1},
		"camera": {"center": Vector2(w - 190.0, h - 215.0), "radius": 36.0, "touch": -1},
		"pause": {"center": Vector2(w - 50.0, 50.0), "radius": 28.0, "touch": -1},
	}
	queue_redraw()


## Entrega (e zera) o quanto o dedo arrastou na área de olhar desde a última chamada.
func consume_look() -> Vector2:
	var d := look_delta
	look_delta = Vector2.ZERO
	return d


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag:
		_touch_drag(event.index, event.position, event.relative)


func _touch_down(index: int, pos: Vector2) -> void:
	for id in _buttons:
		var b: Dictionary = _buttons[id]
		var c: Vector2 = b["center"]
		var r: float = b["radius"]
		if b["touch"] == -1 and pos.distance_to(c) <= r * 1.15:
			b["touch"] = index
			_fire_button(id)
			queue_redraw()
			return
	if pos.x < size.x * 0.5:
		if _move_touch == -1:
			_move_touch = index
			_move_origin = pos
			_move_pos = pos
			move_vector = Vector2.ZERO
	elif _look_touch == -1:
		_look_touch = index
	queue_redraw()


func _touch_up(index: int) -> void:
	if index == _move_touch:
		_move_touch = -1
		move_vector = Vector2.ZERO
		sprinting = false
	elif index == _look_touch:
		_look_touch = -1
	for id in _buttons:
		if _buttons[id]["touch"] == index:
			_buttons[id]["touch"] = -1
	queue_redraw()


func _touch_drag(index: int, pos: Vector2, rel: Vector2) -> void:
	if index == _move_touch:
		_move_pos = pos
		var offset := pos - _move_origin
		sprinting = (offset.length() / JOY_RADIUS) >= SPRINT_THRESHOLD
		var v := offset / JOY_RADIUS
		if v.length() > 1.0:
			v = v.normalized()
		if v.length() < JOY_DEADZONE:
			v = Vector2.ZERO
		move_vector = v
		queue_redraw()
	elif index == _look_touch:
		look_delta += rel


func _fire_button(id: String) -> void:
	match id:
		"attack":
			attack_pressed.emit()
		"action":
			action_pressed.emit()
		"crouch":
			crouch_pressed.emit()
		"camera":
			camera_toggle_pressed.emit()
		"pause":
			pause_pressed.emit()


func _label_for(id: String) -> String:
	match id:
		"attack":
			return "ATACAR"
		"action":
			return action_label
		"crouch":
			return "AGACHAR"
		"camera":
			return "CÂMERA"
		"pause":
			return "II"
	return ""


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if _move_touch != -1:
		draw_circle(_move_origin, JOY_RADIUS, Color(1, 1, 1, 0.10))
		var ring := Color(1.0, 0.65, 0.2, 0.75) if sprinting else Color(1, 1, 1, 0.35)
		draw_arc(_move_origin, JOY_RADIUS, 0.0, TAU, 48, ring, 3.0)
		var knob := (_move_pos - _move_origin).limit_length(JOY_RADIUS)
		draw_circle(_move_origin + knob, 38.0, Color(1, 1, 1, 0.35))
	else:
		draw_arc(Vector2(150.0, size.y - 140.0), JOY_RADIUS * 0.8, 0.0, TAU, 40, Color(1, 1, 1, 0.12), 2.0)

	for id in _buttons:
		var b: Dictionary = _buttons[id]
		var c: Vector2 = b["center"]
		var r: float = b["radius"]
		var pressed: bool = b["touch"] != -1
		var active: bool = (id == "crouch" and crouch_active)
		var fill := Color(0.9, 0.6, 0.2, 0.45) if (pressed or active) else Color(0.05, 0.05, 0.05, 0.45)
		draw_circle(c, r, fill)
		draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.45), 2.0)
		var label := _label_for(id)
		var fs := 15 if label.length() > 4 else 20
		draw_string(font, Vector2(c.x - r, c.y + fs * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(1, 1, 1, 0.92))
