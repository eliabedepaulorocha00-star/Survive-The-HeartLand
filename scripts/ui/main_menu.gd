extends Control
## Menu principal (versão inicial): fundo em gradiente com silhueta de casa,
## título e botões estilo placa de metal à esquerda.

var _toast: Label
var _toast_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_silhouettes()
	_build_title()
	_build_buttons()
	_build_footer()


func _build_background() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.07, 0.09, 0.11))
	grad.set_color(1, Color(0.27, 0.31, 0.34))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 8
	tex.height = 256
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_silhouettes() -> void:
	var vp := get_viewport_rect().size
	var base_y := vp.y * 0.74
	var dark := Color(0.03, 0.04, 0.05)

	# Chão escuro
	var ground := ColorRect.new()
	ground.color = Color(0.05, 0.06, 0.07)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.position = Vector2(0.0, base_y)
	ground.size = Vector2(vp.x, vp.y - base_y)
	add_child(ground)

	# Casa
	var house := Node2D.new()
	house.position = Vector2(vp.x * 0.66, base_y)
	add_child(house)
	var body := Polygon2D.new()
	body.color = dark
	body.polygon = PackedVector2Array([Vector2(0, 0), Vector2(300, 0), Vector2(300, -150), Vector2(0, -150)])
	house.add_child(body)
	var roof := Polygon2D.new()
	roof.color = dark
	roof.polygon = PackedVector2Array([Vector2(-24, -150), Vector2(324, -150), Vector2(150, -250)])
	house.add_child(roof)
	var chimney := Polygon2D.new()
	chimney.color = dark
	chimney.polygon = PackedVector2Array([Vector2(230, -215), Vector2(262, -215), Vector2(262, -165), Vector2(230, -180)])
	house.add_child(chimney)
	var window_lit := Polygon2D.new()
	window_lit.color = Color(0.95, 0.68, 0.28, 0.9)
	window_lit.polygon = PackedVector2Array([Vector2(60, -105), Vector2(110, -105), Vector2(110, -60), Vector2(60, -60)])
	house.add_child(window_lit)

	# Névoa no horizonte
	var fog_grad := Gradient.new()
	fog_grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	fog_grad.colors = PackedColorArray([Color(0.6, 0.66, 0.7, 0.0), Color(0.6, 0.66, 0.7, 0.28), Color(0.6, 0.66, 0.7, 0.0)])
	var fog_tex := GradientTexture2D.new()
	fog_tex.gradient = fog_grad
	fog_tex.fill_from = Vector2(0.5, 0.0)
	fog_tex.fill_to = Vector2(0.5, 1.0)
	fog_tex.width = 8
	fog_tex.height = 128
	var fog := TextureRect.new()
	fog.texture = fog_tex
	fog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fog.stretch_mode = TextureRect.STRETCH_SCALE
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog.position = Vector2(0.0, base_y - vp.y * 0.22)
	fog.size = Vector2(vp.x, vp.y * 0.3)
	add_child(fog)


func _build_title() -> void:
	var title := Label.new()
	title.text = "SURVIVE THE\nHEARTLAND"
	title.position = Vector2(48.0, 36.0)
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", Color(0.82, 0.84, 0.82))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)


func _build_buttons() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(48.0, 220.0)
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	_add_button(box, "JOGAR", func(): GameManager.start_game())
	_add_button(box, "MULTIPLAYER", func(): _show_toast("Multiplayer: em breve (Fase 8)"))
	_add_button(box, "CUSTOMIZAR SOBREVIVENTE", func(): _show_toast("Customização: em breve"))
	_add_button(box, "CONFIGURAÇÕES", func(): _show_toast("Configurações: em breve (Fase 4)"))
	_add_button(box, "SAIR", func(): get_tree().quit())


func _add_button(parent: Control, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380.0, 56.0)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color(0.92, 0.92, 0.88))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_stylebox_override("normal", _plate(Color(0.34, 0.33, 0.31)))
	b.add_theme_stylebox_override("hover", _plate(Color(0.43, 0.41, 0.38)))
	b.add_theme_stylebox_override("pressed", _plate(Color(0.22, 0.21, 0.20)))
	b.add_theme_stylebox_override("focus", _plate(Color(0.34, 0.33, 0.31)))
	b.pressed.connect(action)
	parent.add_child(b)


func _plate(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = Color(0.13, 0.12, 0.11)
	s.set_border_width_all(3)
	s.set_corner_radius_all(3)
	s.content_margin_left = 16.0
	s.content_margin_right = 16.0
	return s


func _build_footer() -> void:
	var vp := get_viewport_rect().size
	var version := Label.new()
	version.text = "v0.1.0 — fatia jogável"
	version.position = Vector2(48.0, vp.y - 36.0)
	version.add_theme_font_size_override("font_size", 16)
	version.add_theme_color_override("font_color", Color(0.6, 0.62, 0.62))
	version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(version)

	var help := Label.new()
	help.text = "Esquerda: andar (até o fim = correr)  |  Direita: olhar  |  Botões: atacar, ação, agachar, câmera"
	help.position = Vector2(48.0, vp.y - 66.0)
	help.add_theme_font_size_override("font_size", 15)
	help.add_theme_color_override("font_color", Color(0.7, 0.72, 0.72))
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(help)

	_toast = Label.new()
	_toast.position = Vector2(48.0, vp.y - 110.0)
	_toast.add_theme_font_size_override("font_size", 20)
	_toast.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35))
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
