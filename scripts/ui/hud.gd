extends CanvasLayer
## HUD: barras de vida e stamina, FPS, abates, dica contextual,
## avisos rápidos e telas de pausa / morte. Também cria os controles touch.

const TouchControlsScript = preload("res://scripts/ui/touch_controls.gd")

var player
var controls

var _stamina_fill: ColorRect
var _health_fill: ColorRect
var _fps_label: Label
var _kills_label: Label
var _hint_label: Label
var _toast_label: Label
var _toast_tween: Tween
var _pause_panel: Control
var _dead_panel: Control
var _dead_info: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	controls = TouchControlsScript.new()
	controls.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(controls)

	_health_fill = _make_bar(24.0, Color(0.75, 0.12, 0.12))
	_stamina_fill = _make_bar(44.0, Color(0.90, 0.78, 0.20))
	_fps_label = _make_label(Vector2(24.0, 68.0), 15, Color(0.8, 0.85, 0.8, 0.8))
	_kills_label = _make_label(Vector2(24.0, 90.0), 18, Color(0.9, 0.9, 0.85))
	_hint_label = _make_label(Vector2(0.0, 0.0), 22, Color(1.0, 0.9, 0.6))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label = _make_label(Vector2(0.0, 0.0), 22, Color(0.95, 0.75, 0.35))
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.modulate.a = 0.0

	var pause_parts := _make_panel("PAUSADO", [
		["CONTINUAR", func(): GameManager.change_state(GameManager.State.IN_GAME)],
		["MENU PRINCIPAL", func(): GameManager.back_to_menu()],
	])
	_pause_panel = pause_parts["panel"]

	var dead_parts := _make_panel("VOCÊ MORREU", [
		["TENTAR DE NOVO", func(): GameManager.start_game()],
		["MENU PRINCIPAL", func(): GameManager.back_to_menu()],
	])
	_dead_panel = dead_parts["panel"]
	_dead_info = Label.new()
	_dead_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dead_info.add_theme_font_size_override("font_size", 22)
	dead_parts["box"].add_child(_dead_info)
	dead_parts["box"].move_child(_dead_info, 1)

	GameManager.state_changed.connect(_on_state_changed)
	GameManager.message.connect(_show_toast)
	get_viewport().size_changed.connect(_reposition)
	_reposition()


func _process(_delta: float) -> void:
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	_kills_label.text = "Zumbis abatidos: %d" % GameManager.kills
	if player == null or not is_instance_valid(player):
		return
	_health_fill.size.x = 236.0 * clampf(player.health / player.max_health, 0.0, 1.0)
	_stamina_fill.size.x = 236.0 * clampf(player.stamina / player.max_stamina, 0.0, 1.0)
	_stamina_fill.color = Color(0.85, 0.35, 0.15) if player.exhausted else Color(0.90, 0.78, 0.20)
	_hint_label.text = player.hint_text


func _reposition() -> void:
	var vp := get_viewport().get_visible_rect().size
	_hint_label.position = Vector2(0.0, vp.y * 0.62)
	_hint_label.size = Vector2(vp.x, 40.0)
	_toast_label.position = Vector2(0.0, vp.y * 0.18)
	_toast_label.size = Vector2(vp.x, 40.0)


func _make_bar(top: float, color: Color) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.position = Vector2(24.0, top)
	bg.size = Vector2(240.0, 14.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var fill := ColorRect.new()
	fill.color = color
	fill.position = Vector2(2.0, 2.0)
	fill.size = Vector2(236.0, 10.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(fill)
	return fill


func _make_label(pos: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _make_panel(title: String, entries: Array) -> Dictionary:
	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.68)
	panel.visible = false
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	panel.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var lbl := Label.new()
	lbl.text = title
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 52)
	box.add_child(lbl)

	for e in entries:
		var b := Button.new()
		b.text = e[0]
		b.custom_minimum_size = Vector2(340.0, 60.0)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(e[1])
		box.add_child(b)

	return {"panel": panel, "box": box}


func _on_state_changed(_old_state: int, new_state: int) -> void:
	_pause_panel.visible = (new_state == GameManager.State.PAUSED)
	_dead_panel.visible = (new_state == GameManager.State.PLAYER_DEAD)
	if new_state == GameManager.State.PLAYER_DEAD:
		_dead_info.text = "Zumbis abatidos: %d" % GameManager.kills


func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.5)
