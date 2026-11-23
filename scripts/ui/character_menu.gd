extends Control
## Customização do sobrevivente: aparência, profissão e traços (estilo Project Zomboid).
## À esquerda, uma prévia 3D que gira; à direita, as opções. Salva ao voltar.

signal closed

const HumanoidScript = preload("res://scripts/world/humanoid.gd")

var _tab: String = "look"
var _preview_root: Node3D
var _humanoid: Node3D
var _content: VBoxContainer
var _points_label: Label
var _status: Label
var _name_edit: LineEdit
var _dragging: bool = false
var _spin: float = 0.4


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_rebuild_model()
	_refresh()


func _process(delta: float) -> void:
	if _preview_root != null and not _dragging:
		_preview_root.rotation.y += _spin * delta


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.08, 1.0)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	# Topo: título, nome e pontos
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	root.add_child(top)
	var title := Label.new()
	title.text = "SOBREVIVENTE"
	title.add_theme_font_size_override("font_size", 28)
	top.add_child(title)
	_name_edit = LineEdit.new()
	_name_edit.text = CharacterData.char_name
	_name_edit.max_length = 18
	_name_edit.placeholder_text = "Nome"
	_name_edit.custom_minimum_size = Vector2(240.0, 46.0)
	_name_edit.add_theme_font_size_override("font_size", 20)
	_name_edit.text_changed.connect(func(t: String): CharacterData.char_name = t)
	top.add_child(_name_edit)
	_points_label = Label.new()
	_points_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_points_label.add_theme_font_size_override("font_size", 24)
	top.add_child(_points_label)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 12)
	root.add_child(cols)

	# Prévia 3D
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vpc.size_flags_stretch_ratio = 0.8
	vpc.gui_input.connect(_on_preview_input)
	cols.add_child(vpc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_2X
	vpc.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.15, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.75)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	light.light_energy = 1.1
	vp.add_child(light)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.95, 3.7)
	cam.fov = 38.0
	vp.add_child(cam)
	_preview_root = Node3D.new()
	vp.add_child(_preview_root)

	# Painel de opções
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.2
	right.add_theme_constant_override("separation", 8)
	cols.add_child(right)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	right.add_child(tabs)
	for t in [["look", "APARÊNCIA"], ["prof", "PROFISSÃO"], ["traits", "TRAÇOS"]]:
		var b := _button(t[1], Vector2(0.0, 48.0), 19)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_tab.bind(t[0]))
		tabs.add_child(b)

	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(Color(0.10, 0.11, 0.11), 10))
	right.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	scroll.add_child(_content)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 17)
	_status.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0.0, 48.0)
	right.add_child(_status)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	root.add_child(bottom)
	var rnd := _button("ALEATÓRIO", Vector2(200.0, 50.0), 20)
	rnd.pressed.connect(_on_random)
	bottom.add_child(rnd)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	var back := _button("SALVAR E VOLTAR", Vector2(260.0, 50.0), 20)
	back.pressed.connect(close)
	bottom.add_child(back)


func close() -> void:
	CharacterData.save_character()
	closed.emit()
	queue_free()


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask != 0):
		_dragging = true
		_preview_root.rotation.y += event.relative.x * 0.012
	elif (event is InputEventMouseButton or event is InputEventScreenTouch) and not event.pressed:
		_dragging = false


func _on_random() -> void:
	CharacterData.randomize_look()
	_status.text = ""
	_rebuild_model()
	_refresh()


func _set_tab(tab: String) -> void:
	_tab = tab
	_status.text = ""
	_refresh()


func _rebuild_model() -> void:
	if _humanoid != null:
		_humanoid.queue_free()
	_humanoid = HumanoidScript.new()
	_preview_root.add_child(_humanoid)
	_humanoid.build(CharacterData.appearance(), false)


# --- Conteúdo das abas ---

func _refresh() -> void:
	var left := CharacterData.points_left()
	_points_label.text = "Pontos: %d" % left
	_points_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.5) if left > 0 else Color(0.95, 0.75, 0.35))
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	match _tab:
		"look":
			_build_look()
		"prof":
			_build_professions()
		"traits":
			_build_traits()


func _build_look() -> void:
	_stepper("Gênero", ["Masculino", "Feminino"], int(CharacterData.female), func(v): CharacterData.female = (v == 1))
	_stepper("Pele", [], CharacterData.skin, func(v): CharacterData.skin = v, CharacterData.SKIN_TONES)
	_stepper("Cabelo", CharacterData.HAIR_STYLES, CharacterData.hair_style, func(v): CharacterData.hair_style = v)
	_stepper("Cor do cabelo", [], CharacterData.hair_color, func(v): CharacterData.hair_color = v, CharacterData.HAIR_COLORS)
	_stepper("Parte de cima", CharacterData.TOP_STYLES, CharacterData.top_style, func(v): CharacterData.top_style = v)
	_stepper("Cor de cima", [], CharacterData.top_color, func(v): CharacterData.top_color = v, CharacterData.CLOTH_COLORS)
	_stepper("Parte de baixo", CharacterData.BOTTOM_STYLES, CharacterData.bottom_style, func(v): CharacterData.bottom_style = v)
	_stepper("Cor de baixo", [], CharacterData.bottom_color, func(v): CharacterData.bottom_color = v, CharacterData.CLOTH_COLORS)
	_stepper("Calçado", [], CharacterData.shoe_color, func(v): CharacterData.shoe_color = v, CharacterData.CLOTH_COLORS)


## Linha "< valor >". `names` vazio + `colors` = mostra um quadradinho de cor.
func _stepper(label: String, names: Array, value: int, setter: Callable, colors: Array = []) -> void:
	var count: int = colors.size() if names.is_empty() else names.size()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_content.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(170.0, 0.0)
	l.add_theme_font_size_override("font_size", 19)
	row.add_child(l)
	var prev := _button("<", Vector2(56.0, 50.0), 22)
	prev.pressed.connect(_step.bind(setter, (value - 1 + count) % count))
	row.add_child(prev)
	if names.is_empty():
		var sw := ColorRect.new()
		sw.color = colors[value]
		sw.custom_minimum_size = Vector2(0.0, 50.0)
		sw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sw)
	else:
		var v := Label.new()
		v.text = str(names[value])
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_font_size_override("font_size", 19)
		row.add_child(v)
	var next := _button(">", Vector2(56.0, 50.0), 22)
	next.pressed.connect(_step.bind(setter, (value + 1) % count))
	row.add_child(next)


func _step(setter: Callable, new_value: int) -> void:
	setter.call(new_value)
	_rebuild_model()
	_refresh()


func _build_professions() -> void:
	for p in CharacterData.PROFESSIONS:
		var id: String = p["id"]
		var cost := int(p["cost"])
		var txt := "%s   (%s)" % [p["name"], "grátis" if cost == 0 else "%d pts" % cost]
		_choice(txt, id == CharacterData.profession, _pick_profession.bind(id))
	var cur := CharacterData.profession_data()
	var d := Label.new()
	d.text = str(cur["desc"])
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_font_size_override("font_size", 17)
	d.add_theme_color_override("font_color", Color(0.8, 0.85, 0.75))
	_content.add_child(d)
	if not cur["items"].is_empty():
		var parts: Array[String] = []
		for it in cur["items"]:
			parts.append("%dx %s" % [int(it[1]), ItemDB.name_of(str(it[0]))])
		var il := Label.new()
		il.text = "Começa com: " + ", ".join(PackedStringArray(parts))
		il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		il.add_theme_font_size_override("font_size", 16)
		il.add_theme_color_override("font_color", Color(0.7, 0.72, 0.7))
		_content.add_child(il)


func _pick_profession(id: String) -> void:
	_status.text = CharacterData.set_profession(id)
	_refresh()


func _build_traits() -> void:
	for t in CharacterData.TRAITS:
		var id: String = t["id"]
		var cost := int(t["cost"])
		var on: bool = CharacterData.traits.has(id)
		var price := ("custa %d" % cost) if cost > 0 else ("dá %d pts" % absi(cost))
		var txt := "%s   (%s)  -  %s" % [t["name"], price, t["desc"]]
		_choice(txt, on, _pick_trait.bind(id))


func _pick_trait(id: String) -> void:
	_status.text = CharacterData.toggle_trait(id)
	_refresh()


## Botão de escolha (selecionado = destacado).
func _choice(text: String, selected: bool, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0.0, 52.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 17)
	var base := Color(0.36, 0.31, 0.16) if selected else Color(0.19, 0.20, 0.20)
	b.add_theme_stylebox_override("normal", _style(base, 10, true))
	b.add_theme_stylebox_override("hover", _style(base.lightened(0.08), 10, true))
	b.add_theme_stylebox_override("pressed", _style(base.lightened(0.18), 10, true))
	b.add_theme_stylebox_override("focus", _style(base, 10, true))
	b.pressed.connect(action)
	_content.add_child(b)


func _button(text: String, min_size: Vector2, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", _style(Color(0.30, 0.29, 0.27), 8, true))
	b.add_theme_stylebox_override("hover", _style(Color(0.38, 0.36, 0.33), 8, true))
	b.add_theme_stylebox_override("pressed", _style(Color(0.20, 0.19, 0.18), 8, true))
	b.add_theme_stylebox_override("focus", _style(Color(0.30, 0.29, 0.27), 8, true))
	return b


func _style(color: Color, margin: float, border: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(4)
	s.set_content_margin_all(margin)
	if border:
		s.border_color = Color(0.08, 0.08, 0.08)
		s.set_border_width_all(2)
	return s
