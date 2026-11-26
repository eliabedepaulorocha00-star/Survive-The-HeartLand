extends Control
## Tela de configurações com 4 abas: Gráficos, Controles, Áudio e Jogo.
## Funciona no menu principal e na pausa. Fecha sozinha ao tocar em VOLTAR.

signal closed

var _controls: Dictionary = {}  # nome da configuração -> controle da tela
var _preset_option: OptionButton
var _key_buttons: Dictionary = {}  # ação -> [botão1, botão2]
var _listening: Array = []  # [ação, espaço] enquanto espera uma tecla


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()
	GameSettings.changed.connect(_refresh)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.07, 0.98)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "CONFIGURAÇÕES"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 36)
	header.add_child(title)
	var back := Button.new()
	back.text = "VOLTAR"
	back.custom_minimum_size = Vector2(170.0, 54.0)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(_close)
	header.add_child(back)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 22)
	root.add_child(tabs)

	_build_graphics(_new_tab(tabs, "Gráficos"))
	_build_controls(_new_tab(tabs, "Controles"))
	_build_keys(_new_tab(tabs, "Teclas"))
	_build_audio(_new_tab(tabs, "Áudio"))
	_build_game(_new_tab(tabs, "Jogo"))


func _close() -> void:
	closed.emit()
	queue_free()


# --- Abas ---

func _build_graphics(tab: VBoxContainer) -> void:
	var row := _new_row(tab, "Preset de qualidade")
	_preset_option = OptionButton.new()
	_style_option(_preset_option)
	for n in GameSettings.PRESET_NAMES:
		_preset_option.add_item(n)
	_preset_option.item_selected.connect(_on_preset_selected)
	row.add_child(_preset_option)

	_add_slider(tab, "render_scale", "Escala de resolução (pode não ter efeito em alguns aparelhos)", 50.0, 100.0, 5.0, "%d%%")
	_add_option(tab, "fps_index", "Limite de FPS", ["30 FPS", "45 FPS", "60 FPS", "90 FPS", "120 FPS"])
	_add_option(tab, "draw_distance", "Distância de renderização", ["Curta", "Média", "Longa"])
	_add_option(tab, "shadows", "Qualidade das sombras", ["Desligadas", "Baixa", "Média", "Alta"])
	_add_option(tab, "aa", "Anti-aliasing", ["Desligado", "MSAA 2x", "MSAA 4x"])
	_add_check(tab, "bloom", "Bloom (brilho)")
	_add_check(tab, "ssao", "Oclusão ambiental (SSAO) - indisponível neste modo", true)
	_add_check(tab, "reflections", "Reflexos na água - em breve", true)
	_add_check(tab, "show_stats", "Mostrar FPS, memória e draw calls na tela")


func _build_controls(tab: VBoxContainer) -> void:
	_add_slider(tab, "look_sensitivity", "Sensibilidade de olhar", 0.05, 0.40, 0.01, "%.2f")
	_add_slider(tab, "look_accel", "Aceleração do arrasto", 0.0, 2.0, 0.1, "%.1f")
	_add_check(tab, "invert_y", "Inverter eixo vertical")
	_add_slider(tab, "button_scale", "Tamanho dos botões na tela", 0.8, 1.4, 0.1, "%.1fx")
	_add_check(tab, "vibration", "Vibração ao levar dano")


func _build_keys(tab: VBoxContainer) -> void:
	var info := Label.new()
	info.text = "Toque em uma tecla para trocar e aperte o novo botão (teclado ou mouse). Esc cancela, Delete limpa."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 18)
	tab.add_child(info)
	_add_check(tab, "debug_input", "Diagnóstico de entrada (mostra na tela o que o mouse/teclado enviam)")
	for a in GameSettings.ACTIONS:
		var row := _new_row(tab, a[1])
		var pair: Array = []
		for slot in 2:
			var b := Button.new()
			b.custom_minimum_size = Vector2(190.0, 48.0)
			b.add_theme_font_size_override("font_size", 18)
			b.pressed.connect(_start_listen.bind(a[0], slot))
			row.add_child(b)
			pair.append(b)
		_key_buttons[a[0]] = pair
	var reset := Button.new()
	reset.text = "Restaurar teclas padrão"
	reset.custom_minimum_size = Vector2(0.0, 54.0)
	reset.add_theme_font_size_override("font_size", 20)
	reset.pressed.connect(func():
		GameSettings.reset_keybinds()
		GameSettings.save_settings()
		GameSettings.changed.emit())
	tab.add_child(reset)


func _start_listen(id: String, slot: int) -> void:
	_listening = [id, slot]
	(_key_buttons[id][slot] as Button).text = "Aperte um botão..."


func _input(event: InputEvent) -> void:
	if _listening.is_empty():
		return
	var id: String = _listening[0]
	var slot: int = _listening[1]
	var code := 0
	var done := false
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		done = true
		if event.keycode == KEY_ESCAPE:
			code = -9999  # cancelar
		elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			code = 0
		else:
			code = int(event.keycode)
	elif event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		get_viewport().set_input_as_handled()
		done = true
		code = -int(event.button_index)
	elif event is InputEventScreenTouch and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		done = true
		code = -9999
	if not done:
		return
	_listening = []
	if code != -9999:
		GameSettings.set_bind(id, slot, code)
	else:
		_refresh()


func _build_audio(tab: VBoxContainer) -> void:
	_add_slider(tab, "master_volume", "Volume geral", 0.0, 1.0, 0.05, "%.2f")
	var note := Label.new()
	note.text = "Música e efeitos sonoros: em breve."
	note.add_theme_font_size_override("font_size", 18)
	note.add_theme_color_override("font_color", Color(0.65, 0.68, 0.68))
	tab.add_child(note)


func _build_game(tab: VBoxContainer) -> void:
	_add_option(tab, "day_index", "Duração de um dia no jogo", ["15 min reais", "30 min reais", "1 hora real", "2 horas reais"])
	_add_check(tab, "auto_weather", "Clima muda sozinho")


# --- Peças de interface ---

func _new_tab(tabs: TabContainer, tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	return box


func _new_row(parent: Control, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 54.0)
	row.add_theme_constant_override("separation", 12)
	var lbl := Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 20)
	row.add_child(lbl)
	parent.add_child(row)
	return row


func _style_option(ob: OptionButton) -> void:
	ob.custom_minimum_size = Vector2(280.0, 48.0)
	ob.add_theme_font_size_override("font_size", 20)
	var popup := ob.get_popup()
	popup.add_theme_font_size_override("font_size", 22)
	popup.add_theme_constant_override("v_separation", 14)


func _add_option(parent: Control, key: String, text: String, items: Array) -> void:
	var row := _new_row(parent, text)
	var ob := OptionButton.new()
	_style_option(ob)
	for it in items:
		ob.add_item(it)
	ob.item_selected.connect(func(i: int): GameSettings.set_setting(key, i))
	row.add_child(ob)
	_controls[key] = ob


func _add_slider(parent: Control, key: String, text: String, min_v: float, max_v: float, step: float, fmt: String) -> void:
	var row := _new_row(parent, text)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.custom_minimum_size = Vector2(240.0, 40.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(70.0, 0.0)
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value_label.add_theme_font_size_override("font_size", 20)
	slider.set_meta("fmt", fmt)
	slider.set_meta("value_label", value_label)
	slider.value_changed.connect(func(v: float):
		value_label.text = fmt % v
		GameSettings.set_setting(key, v))
	row.add_child(slider)
	row.add_child(value_label)
	_controls[key] = slider


func _add_check(parent: Control, key: String, text: String, disabled: bool = false) -> void:
	var cb := CheckButton.new()
	cb.text = text
	cb.disabled = disabled
	cb.custom_minimum_size = Vector2(0.0, 54.0)
	cb.add_theme_font_size_override("font_size", 20)
	cb.toggled.connect(func(pressed: bool): GameSettings.set_setting(key, pressed))
	parent.add_child(cb)
	_controls[key] = cb


# --- Sincronizar a tela com os valores atuais ---

func _on_preset_selected(index: int) -> void:
	if index < GameSettings.PRESET_ORDER.size():
		GameSettings.apply_preset(GameSettings.PRESET_ORDER[index])
	else:
		GameSettings.preset = "custom"
		GameSettings.save_settings()


func _refresh() -> void:
	for id in _key_buttons:
		var codes: Array = GameSettings.binds_of(id)
		for slot in 2:
			if not (not _listening.is_empty() and _listening[0] == id and _listening[1] == slot):
				(_key_buttons[id][slot] as Button).text = GameSettings.bind_name(int(codes[slot]))
	if _preset_option != null:
		_preset_option.select(GameSettings.preset_index())
	for key in _controls:
		var c = _controls[key]
		var v = GameSettings.get(key)
		if c is OptionButton:
			c.select(int(v))
		elif c is HSlider:
			c.set_value_no_signal(float(v))
			var lbl: Label = c.get_meta("value_label")
			lbl.text = String(c.get_meta("fmt")) % float(v)
		elif c is CheckButton:
			c.set_pressed_no_signal(bool(v))
