extends Control
## Tela da mochila. Quando há um armário/caixa por perto, mostra o conteúdo dele
## numa terceira coluna. Toque num item para ver os detalhes e as opções.

signal closed

var player
var container  # nó de container.gd, ou null se só a mochila estiver aberta

var _bag_list: VBoxContainer
var _box_list: VBoxContainer
var _detail: VBoxContainer
var _weight_label: Label
var _weight_bar: ProgressBar
var _status: Label
var _sel_source: String = ""  # "bag", "box" ou ""
var _sel_key: int = -1  # uid na mochila, posição no recipiente


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	player.inventory.changed.connect(_refresh)
	GameManager.message.connect(_say)
	_refresh()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_I or event.keycode == KEY_TAB:
			get_viewport().set_input_as_handled()
			close()


func close() -> void:
	closed.emit()
	queue_free()


# --- Montagem da tela ---

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.05, 0.95)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
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

	# Barra de cima: título, peso e botão de fechar
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	root.add_child(top)

	var title := Label.new()
	title.text = "MOCHILA"
	title.add_theme_font_size_override("font_size", 30)
	top.add_child(title)

	var weight_box := VBoxContainer.new()
	weight_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weight_box.add_theme_constant_override("separation", 2)
	top.add_child(weight_box)
	_weight_label = Label.new()
	_weight_label.add_theme_font_size_override("font_size", 18)
	weight_box.add_child(_weight_label)
	_weight_bar = ProgressBar.new()
	_weight_bar.show_percentage = false
	_weight_bar.custom_minimum_size = Vector2(0.0, 12.0)
	_weight_bar.add_theme_stylebox_override("background", _box_style(Color(0.0, 0.0, 0.0, 0.55), 2))
	weight_box.add_child(_weight_bar)

	var close_btn := _make_button("FECHAR", Vector2(170.0, 50.0), 20)
	close_btn.pressed.connect(close)
	top.add_child(close_btn)

	# Colunas
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 12)
	root.add_child(cols)

	var bag_col := _make_column("NA MOCHILA", 1.0)
	cols.add_child(bag_col["panel"])
	_bag_list = bag_col["list"]

	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_stretch_ratio = 0.9 if container != null else 1.0
	detail_panel.add_theme_stylebox_override("panel", _box_style(Color(0.13, 0.13, 0.12, 0.95), 10))
	cols.add_child(detail_panel)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_panel.add_child(detail_scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	detail_scroll.add_child(_detail)

	if container != null:
		var box_col := _make_column(str(container.title).to_upper(), 1.0)
		cols.add_child(box_col["panel"])
		_box_list = box_col["list"]
		var take_all := _make_button("PEGAR TUDO", Vector2(150.0, 40.0), 16)
		take_all.pressed.connect(_take_all)
		box_col["head"].add_child(take_all)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35))
	_status.custom_minimum_size = Vector2(0.0, 26.0)
	root.add_child(_status)


func _make_column(title: String, ratio: float) -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	panel.add_theme_stylebox_override("panel", _box_style(Color(0.10, 0.11, 0.11, 0.95), 10))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var head := HBoxContainer.new()
	vb.add_child(head)
	var lbl := Label.new()
	lbl.text = title
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55))
	head.add_child(lbl)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	return {"panel": panel, "head": head, "list": list}


func _box_style(color: Color, margin: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(4)
	s.set_content_margin_all(margin)
	return s


func _plate(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = Color(0.08, 0.08, 0.08)
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	s.content_margin_left = 12.0
	s.content_margin_right = 12.0
	return s


func _make_button(text: String, min_size: Vector2, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", _plate(Color(0.30, 0.29, 0.27)))
	b.add_theme_stylebox_override("hover", _plate(Color(0.38, 0.36, 0.33)))
	b.add_theme_stylebox_override("pressed", _plate(Color(0.20, 0.19, 0.18)))
	b.add_theme_stylebox_override("focus", _plate(Color(0.30, 0.29, 0.27)))
	return b


# --- Atualização ---

func _refresh() -> void:
	var inv = player.inventory
	_validate_selection()

	_clear(_bag_list)
	if inv.entries.is_empty():
		_add_hint(_bag_list, "Mochila vazia.")
	for e in inv.entries:
		var id := str(e["id"])
		var uid := int(e["uid"])
		var txt := ItemDB.name_of(id)
		if int(e["n"]) > 1:
			txt += "  x%d" % int(e["n"])
		if uid == inv.equipped_uid:
			txt += "  (equipado)"
		var wtxt := ItemDB.fmt_weight(ItemDB.weight_of(id) * int(e["n"]))
		_add_row(_bag_list, id, txt, wtxt, _sel_source == "bag" and _sel_key == uid, "bag", uid)

	if container != null:
		_clear(_box_list)
		if container.contents.is_empty():
			_add_hint(_box_list, "Vazio.")
		for i in container.contents.size():
			var c: Dictionary = container.contents[i]
			var cid := str(c["id"])
			var ctxt := ItemDB.name_of(cid)
			if int(c["n"]) > 1:
				ctxt += "  x%d" % int(c["n"])
			var cw := ItemDB.fmt_weight(ItemDB.weight_of(cid) * int(c["n"]))
			_add_row(_box_list, cid, ctxt, cw, _sel_source == "box" and _sel_key == i, "box", i)

	var total: float = inv.total_weight()
	_weight_label.text = "Peso: %.1f / %.0f kg" % [total, inv.capacity]
	if total > inv.capacity:
		_weight_label.text += "   (sobrecarregado: você anda mais devagar)"
	_weight_bar.max_value = inv.hard_limit()
	_weight_bar.value = total
	var fill_color := Color(0.45, 0.70, 0.30) if total <= inv.capacity else Color(0.90, 0.45, 0.15)
	_weight_bar.add_theme_stylebox_override("fill", _box_style(fill_color, 2))

	_refresh_detail()


func _validate_selection() -> void:
	if _sel_source == "bag":
		if player.inventory.find_uid(_sel_key).is_empty():
			_sel_source = ""
	elif _sel_source == "box":
		if container == null or _sel_key < 0 or _sel_key >= container.contents.size():
			_sel_source = ""


func _clear(list: Control) -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()


func _add_hint(list: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(0.6, 0.6, 0.58))
	list.add_child(l)


func _add_row(list: Control, id: String, text: String, right_text: String, selected: bool, source: String, key: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	list.add_child(row)

	var swatch := ColorRect.new()
	swatch.color = ItemDB.color_of(id)
	swatch.custom_minimum_size = Vector2(10.0, 0.0)
	row.add_child(swatch)

	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.custom_minimum_size = Vector2(0.0, 52.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 18)
	var base := Color(0.36, 0.31, 0.16) if selected else Color(0.19, 0.20, 0.20)
	b.add_theme_stylebox_override("normal", _plate(base))
	b.add_theme_stylebox_override("hover", _plate(base.lightened(0.08)))
	b.add_theme_stylebox_override("pressed", _plate(base.lightened(0.18)))
	b.add_theme_stylebox_override("focus", _plate(base))
	b.pressed.connect(_select.bind(source, key))
	row.add_child(b)

	var rl := Label.new()
	rl.text = right_text
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rl.add_theme_font_size_override("font_size", 16)
	rl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.72))
	b.add_child(rl)
	rl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rl.offset_right = -12.0


func _select(source: String, key: int) -> void:
	_sel_source = source
	_sel_key = key
	_refresh()


func _refresh_detail() -> void:
	_clear(_detail)
	if _sel_source == "":
		var hint := "Toque num item para ver os detalhes e as opções."
		if container != null:
			hint += "\nToque num item do recipiente para pegar."
		_add_wrapped(_detail, hint, 18, Color(0.65, 0.65, 0.62))
		return

	var e: Dictionary
	if _sel_source == "bag":
		e = player.inventory.find_uid(_sel_key)
	else:
		e = container.contents[_sel_key]
	var id := str(e["id"])
	var n := int(e["n"])
	var uid := int(e.get("uid", 0))

	_add_wrapped(_detail, ItemDB.name_of(id), 26, Color(1.0, 0.95, 0.8))
	var info := "%s  |  %s" % [ItemDB.cat_name(id), ItemDB.fmt_weight(ItemDB.weight_of(id) * n)]
	if n > 1:
		info += "  (%s cada)" % ItemDB.fmt_weight(ItemDB.weight_of(id))
	_add_wrapped(_detail, info, 16, Color(0.7, 0.72, 0.7))
	var max_dur := ItemDB.max_durability_of(id)
	if max_dur > 0.0:
		_add_wrapped(_detail, "Durabilidade: %d%%" % int(100.0 * float(e["dur"]) / max_dur), 16, Color(0.7, 0.72, 0.7))
	_add_wrapped(_detail, ItemDB.describe(id), 17, Color(0.85, 0.85, 0.82))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 6.0)
	_detail.add_child(spacer)

	var data := ItemDB.get_item(id)
	if _sel_source == "bag":
		if ItemDB.is_weapon(id):
			var equipped: bool = player.inventory.equipped_uid == uid
			_add_action(_detail, "DESEQUIPAR" if equipped else "EQUIPAR", func(): player.equip_item(uid))
		elif data.has("food") or data.has("water") or data.has("heal"):
			var verb := "USAR"
			if data["cat"] == "food":
				verb = "COMER"
			elif data["cat"] == "drink":
				verb = "BEBER"
			_add_action(_detail, verb, func(): player.use_item(uid))
		if container != null:
			_add_action(_detail, "GUARDAR NO RECIPIENTE", func(): _put(uid, n))
			if n > 1:
				_add_action(_detail, "GUARDAR 1", func(): _put(uid, 1))
		_add_action(_detail, "LARGAR NO CHÃO", func(): player.drop_item(uid, n))
		if n > 1:
			_add_action(_detail, "LARGAR 1", func(): player.drop_item(uid, 1))
		if data.has("dismantle"):
			_add_action(_detail, "DESMONTAR", func(): player.dismantle_item(uid))
	else:
		var idx := _sel_key
		_add_action(_detail, "PEGAR", func(): _take(idx, n))
		if n > 1:
			_add_action(_detail, "PEGAR 1", func(): _take(idx, 1))


func _add_wrapped(parent: Control, text: String, font_size: int, color: Color) -> void:
	if text == "":
		return
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)


func _add_action(parent: Control, text: String, action: Callable) -> void:
	var b := _make_button(text, Vector2(0.0, 52.0), 20)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(action)
	parent.add_child(b)


# --- Ações com o recipiente ---

func _take(index: int, n: int) -> void:
	if container == null or index < 0 or index >= container.contents.size():
		return
	var before: int = container.contents.size()
	var nm := ItemDB.name_of(str(container.contents[index]["id"]))
	var moved: int = container.take_to(player.inventory, index, n)
	if moved <= 0:
		_say("Pesado demais: não cabe %s na mochila." % nm)
	else:
		_say("Pegou: %s x%d" % [nm, moved])
	if container.contents.size() < before:
		_sel_source = ""
	_refresh()


func _take_all() -> void:
	if container == null:
		return
	var total := 0
	for i in range(container.contents.size() - 1, -1, -1):
		total += container.take_to(player.inventory, i, 9999)
	_sel_source = ""
	if not container.contents.is_empty():
		_say("Mochila cheia: sobrou coisa no recipiente.")
	elif total > 0:
		_say("Pegou tudo.")
	_refresh()


func _put(uid: int, n: int) -> void:
	if container == null:
		return
	var e: Dictionary = player.inventory.find_uid(uid)
	if e.is_empty():
		return
	var nm := ItemDB.name_of(str(e["id"]))
	var moved: int = container.put_from(player.inventory, uid, n)
	if moved > 0:
		_say("Guardou: %s x%d" % [nm, moved])
	_refresh()


func _say(text: String) -> void:
	if _status != null:
		_status.text = text
