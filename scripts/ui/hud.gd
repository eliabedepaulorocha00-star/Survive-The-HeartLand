extends CanvasLayer
## HUD: barras de vida, stamina, fome e sede, arma equipada, FPS, abates, dica
## contextual, avisos rápidos e telas de pausa / morte / mochila.
## Também cria os controles touch.

const TouchControlsScript = preload("res://scripts/ui/touch_controls.gd")
const SettingsMenuScript = preload("res://scripts/ui/settings_menu.gd")
const InventoryScreenScript = preload("res://scripts/ui/inventory_screen.gd")

var player
var controls

var _stamina_fill: ColorRect
var _health_fill: ColorRect
var _hunger_fill: ColorRect
var _thirst_fill: ColorRect
var _weapon_label: Label
var _inv_screen
var _moodle_box: HBoxContainer
var _moodle_key: String = ""
var _fps_label: Label
var _kills_label: Label
var _wet_label: Label
var _clock_label: Label
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

	_health_fill = _make_bar(24.0, Color(0.75, 0.12, 0.12), "Vida")
	_stamina_fill = _make_bar(44.0, Color(0.90, 0.78, 0.20), "Fôlego")
	_hunger_fill = _make_bar(64.0, Color(0.80, 0.52, 0.18), "Fome")
	_thirst_fill = _make_bar(84.0, Color(0.28, 0.58, 0.92), "Sede")
	_fps_label = _make_label(Vector2(24.0, 108.0), 15, Color(0.8, 0.85, 0.8, 0.8))
	_kills_label = _make_label(Vector2(24.0, 130.0), 18, Color(0.9, 0.9, 0.85))
	_wet_label = _make_label(Vector2(24.0, 156.0), 16, Color(0.6, 0.8, 1.0))
	_weapon_label = _make_label(Vector2(24.0, 180.0), 16, Color(0.92, 0.90, 0.80))
	_moodle_box = HBoxContainer.new()
	_moodle_box.position = Vector2(24.0, 208.0)
	_moodle_box.add_theme_constant_override("separation", 6)
	_moodle_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_moodle_box)
	_clock_label = _make_label(Vector2(0.0, 16.0), 20, Color(0.92, 0.90, 0.80))
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label = _make_label(Vector2(0.0, 0.0), 22, Color(1.0, 0.9, 0.6))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label = _make_label(Vector2(0.0, 0.0), 22, Color(0.95, 0.75, 0.35))
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.modulate.a = 0.0

	var pause_parts := _make_panel("PAUSADO", [
		["CONTINUAR", func(): GameManager.change_state(GameManager.State.IN_GAME)],
		["CONFIGURAÇÕES", func(): _open_settings()],
		["[TESTE] MUDAR CLIMA", func(): GameManager.debug_command.emit("next_weather")],
		["[TESTE] AVANÇAR 3 HORAS", func(): GameManager.debug_command.emit("advance_3h")],
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
	_fps_label.visible = GameSettings.show_stats
	if GameSettings.show_stats:
		var ram_mb := int(OS.get_static_memory_usage() / 1048576.0)
		var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_fps_label.text = "FPS %d  |  RAM %d MB  |  Draw %d" % [Engine.get_frames_per_second(), ram_mb, draws]
	_kills_label.text = "Zumbis abatidos: %d" % GameManager.kills
	_clock_label.text = GameManager.clock_text
	if player == null or not is_instance_valid(player):
		return
	_wet_label.text = ("Molhado: %d%%" % int(player.wetness * 100.0)) if player.wetness > 0.05 else ""
	_health_fill.size.x = 236.0 * clampf(player.health / player.max_health, 0.0, 1.0)
	_stamina_fill.size.x = 236.0 * clampf(player.stamina / player.max_stamina, 0.0, 1.0)
	_stamina_fill.color = Color(0.85, 0.35, 0.15) if player.exhausted else Color(0.90, 0.78, 0.20)
	_hunger_fill.size.x = 236.0 * clampf(player.hunger / 100.0, 0.0, 1.0)
	_thirst_fill.size.x = 236.0 * clampf(player.thirst / 100.0, 0.0, 1.0)
	_hunger_fill.color = Color(0.85, 0.20, 0.15) if player.hunger < 12.0 else Color(0.80, 0.52, 0.18)
	_thirst_fill.color = Color(0.85, 0.20, 0.15) if player.thirst < 12.0 else Color(0.28, 0.58, 0.92)
	_weapon_label.text = "%s  |  Mochila %.1f/%.0f kg" % [player.weapon_status(), player.inventory.total_weight(), player.inventory.capacity]
	_hint_label.text = player.hint_text
	_update_moodles()


## Moodles: avisos de estado (fome, dor, sangramento...). Gravidade 1 = amarelo, 2 = vermelho.
func _update_moodles() -> void:
	var list: Array = []
	if player.hunger < 12.0:
		list.append(["Faminto", 2])
	elif player.hunger < 30.0:
		list.append(["Fome", 1])
	if player.thirst < 12.0:
		list.append(["Sedento", 2])
	elif player.thirst < 30.0:
		list.append(["Sede", 1])
	if player.exhausted:
		list.append(["Exausto", 2])
	elif player.stamina < 25.0:
		list.append(["Cansado", 1])
	var b = player.body
	if b.has_bite():
		list.append(["Mordido", 2])
	if b.bleeding_count() > 0:
		list.append(["Sangrando x%d" % b.bleeding_count(), 2])
	if b.infection > 0.5:
		list.append(["Infecção", 2])
	elif b.infection > 0.05:
		list.append(["Infecção leve", 1])
	if int(b.fractures["legs"]) != 0 or int(b.fractures["arms"]) != 0:
		list.append(["Fratura", 2 if (int(b.fractures["legs"]) == 1 or int(b.fractures["arms"]) == 1) else 1])
	if b.pain() > 0.5:
		list.append(["Dor forte", 2])
	elif b.pain() > 0.05:
		list.append(["Dor", 1])
	if player.wetness > 0.5:
		list.append(["Molhado", 1])
	var key := str(list)
	if key == _moodle_key:
		return
	_moodle_key = key
	for c in _moodle_box.get_children():
		_moodle_box.remove_child(c)
		c.queue_free()
	for m in list:
		var l := Label.new()
		l.text = " %s " % m[0]
		l.add_theme_font_size_override("font_size", 14)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.65, 0.12, 0.10, 0.85) if int(m[1]) == 2 else Color(0.70, 0.55, 0.12, 0.85)
		sb.set_corner_radius_all(3)
		l.add_theme_stylebox_override("normal", sb)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_moodle_box.add_child(l)


func _reposition() -> void:
	var vp := get_viewport().get_visible_rect().size
	_hint_label.position = Vector2(0.0, vp.y * 0.62)
	_hint_label.size = Vector2(vp.x, 40.0)
	_toast_label.position = Vector2(0.0, vp.y * 0.18)
	_toast_label.size = Vector2(vp.x, 40.0)
	_clock_label.position = Vector2(0.0, 16.0)
	_clock_label.size = Vector2(vp.x, 30.0)


func _make_bar(top: float, color: Color, caption: String = "") -> ColorRect:
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
	if caption != "":
		var cap := Label.new()
		cap.text = caption
		cap.position = Vector2(248.0, -4.0)
		cap.add_theme_font_size_override("font_size", 14)
		cap.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85, 0.85))
		cap.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		cap.add_theme_constant_override("shadow_offset_x", 1)
		cap.add_theme_constant_override("shadow_offset_y", 1)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(cap)
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
	if new_state != GameManager.State.IN_GAME and _inv_screen != null:
		_inv_screen.close()  # pausou ou morreu com a mochila aberta
	_pause_panel.visible = (new_state == GameManager.State.PAUSED)
	_dead_panel.visible = (new_state == GameManager.State.PLAYER_DEAD)
	if new_state == GameManager.State.PLAYER_DEAD:
		_dead_info.text = "%s\nZumbis abatidos: %d" % [player.death_cause, GameManager.kills]


func _open_settings() -> void:
	var s = SettingsMenuScript.new()
	add_child(s)


## Abre a mochila; se `cont` (nó de container.gd) vier, mostra também o conteúdo dele.
func open_inventory(cont = null) -> void:
	if _inv_screen != null or player == null or not is_instance_valid(player) or player.dead:
		return
	if GameManager.state != GameManager.State.IN_GAME:
		return
	if cont != null:
		cont.open_loot()  # o loot só é sorteado na primeira abertura
	_inv_screen = InventoryScreenScript.new()
	_inv_screen.player = player
	_inv_screen.container = cont
	_inv_screen.closed.connect(_on_inventory_closed)
	add_child(_inv_screen)
	controls.blocked = true
	player.ui_locked = true


func _on_inventory_closed() -> void:
	_inv_screen = null
	controls.blocked = false
	if player != null and is_instance_valid(player):
		player.ui_locked = false


func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.5)
