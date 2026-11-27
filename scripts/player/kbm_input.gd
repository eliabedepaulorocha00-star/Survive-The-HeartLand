extends Node
## Suporte a teclado e mouse (celular com mouse/teclado Bluetooth ou USB, ou computador).
##  Mouse: mover = olhar | botão esquerdo = atacar/atirar | direito (segurar) = mira em 1ª pessoa | roda = câmera
##  Teclado: WASD/setas = andar | Shift = correr | Ctrl ou C = agachar | E = ação | R = recarregar
##           Tab/I = mochila | V = câmera | Espaço/F = atacar | Esc = pausa
## Ao usar teclado/mouse os botões de toque somem; tocar na tela traz eles de volta.

var player
var active: bool = false
var _rmb_prev_blend: float = 0.0
var _rmb_down: bool = false
var _finger_down: bool = false
var _last_touch_ms: int = -10000
var _motion_acc: float = 0.0


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


var _dbg: Label
var _dbg_counts: Dictionary = {}
var _dbg_last: String = ""
var _dbg_layer: CanvasLayer


## Painel de diagnóstico (Configurações > Teclas): mostra o que o aparelho realmente envia.
func _debug_event(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		return
	var key := event.get_class() + " dev=" + str(event.device)
	if event is InputEventMouseMotion:
		key += " botao=" + ("sim" if event.button_mask != 0 else "nao")
		_dbg_last = "motion rel=%s pos=%s mask=%d" % [str(event.relative), str(event.position), event.button_mask]
	elif event is InputEventMouseButton:
		_dbg_last = "botao %d %s" % [event.button_index, "apertou" if event.pressed else "soltou"]
	elif event is InputEventScreenTouch:
		_dbg_last = "toque %s idx=%d" % ["apertou" if event.pressed else "soltou", event.index]
	elif event is InputEventKey:
		_dbg_last = "tecla %s" % event.as_text_keycode()
	_dbg_counts[key] = int(_dbg_counts.get(key, 0)) + 1


func _update_debug_panel() -> void:
	if not GameSettings.debug_input:
		if _dbg_layer != null:
			_dbg_layer.queue_free()
			_dbg_layer = null
			_dbg = null
		return
	if _dbg == null:
		_dbg_layer = CanvasLayer.new()
		_dbg_layer.layer = 100
		add_child(_dbg_layer)
		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, 0.7)
		bg.position = Vector2(8, 90)
		bg.size = Vector2(720, 520)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dbg_layer.add_child(bg)
		_dbg = Label.new()
		_dbg.position = Vector2(16, 96)
		_dbg.add_theme_font_size_override("font_size", 17)
		_dbg.add_theme_color_override("font_color", Color(1, 1, 0.3))
		_dbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dbg_layer.add_child(_dbg)
	var t := "DIAGNOSTICO  %s | %s | Godot %s\n" % [OS.get_model_name(), OS.get_name(), Engine.get_version_info().get("string", "?")]
	t += "kbm ativo=%s  dedo=%s  jogando=%s  mouse_mode=%d\n" % [str(active), str(_finger_down), str(_can_play()), Input.mouse_mode]
	t += "pos mouse=%s  velocidade=%s\n" % [str(get_viewport().get_mouse_position()), str(Input.get_last_mouse_velocity())]
	for k in _dbg_counts:
		t += "%s: %d\n" % [k, _dbg_counts[k]]
	_dbg.text = t + "ultimo: " + _dbg_last


func _input(event: InputEvent) -> void:
	if GameSettings.debug_input:
		_debug_event(event)
	if event is InputEventScreenDrag and event.device != InputEvent.DEVICE_ID_EMULATION:
		_last_touch_ms = Time.get_ticks_msec()
		_motion_acc = 0.0
	elif event is InputEventKey and event.pressed and not event.echo:
		# Só teclas de teclado de verdade ativam (botões do Android como voltar/volume não).
		if event.device != InputEvent.DEVICE_ID_EMULATION and _is_real_key(event.keycode):
			_set_active(true)
	elif event is InputEventMouseMotion:
		# Tratado aqui (e não em _unhandled_input) para a interface nunca engolir o movimento do mouse.
		if _finger_down or event.relative == Vector2.ZERO:
			return
		if not active:
			# Ativa só com movimento de mouse de verdade: não vindo de toque/emulação e com um bom deslocamento.
			if event.device == InputEvent.DEVICE_ID_EMULATION or Time.get_ticks_msec() - _last_touch_ms < 800:
				return
			_motion_acc += event.relative.length()
			if _motion_acc > 40.0:
				_motion_acc = 0.0
				_set_active(true)
			return
		if _can_play():
			player.rig.apply_look(event.relative)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.device != InputEvent.DEVICE_ID_EMULATION and Time.get_ticks_msec() - _last_touch_ms >= 800:
			_set_active(true)
			# No Android a captura do mouse só pega depois de um toque/clique do usuário:
			# pedir de novo a cada clique faz o mouse passar a girar a câmera sem segurar o botão.
			if event.pressed and _can_play():
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventScreenTouch and event.device != InputEvent.DEVICE_ID_EMULATION:
		_finger_down = event.pressed
		_last_touch_ms = Time.get_ticks_msec()
		_motion_acc = 0.0
		if event.pressed:
			_set_active(false)


static func _is_real_key(code: int) -> bool:
	if code >= KEY_SPACE and code <= KEY_ASCIITILDE:
		return true
	return code in [KEY_TAB, KEY_ENTER, KEY_ESCAPE, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_F9, KEY_F10, KEY_F11, KEY_F12]


func _set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	var c = player.controls
	if c != null:
		c.kbm_mode = on
	if on:
		GameManager.notify("Teclado e mouse ativados. Toque na tela para voltar aos controles de toque.")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _can_play() -> bool:
	return active and not player.dead and not player.ui_locked and GameManager.state == GameManager.State.IN_GAME


func _process(_delta: float) -> void:
	_update_debug_panel()
	var want := Input.MOUSE_MODE_CAPTURED if _can_play() else Input.MOUSE_MODE_VISIBLE
	if active and Input.mouse_mode != want:
		Input.mouse_mode = want
	# Segurar o botão esquerdo repete golpes de arma branca
	if _can_play() and GameSettings.action_down("attack"):
		var e: Dictionary = player.inventory.equipped_entry()
		if e.is_empty() or not ItemDB.is_firearm(str(e["id"])):
			player._try_attack()


## Ações ligadas a botões do mouse (quando o jogador remapeia, por exemplo, "Ação" para o botão lateral).
func _mouse_action(event: InputEvent) -> void:
	if GameSettings.event_is(event, "crouch"):
		player.toggle_crouch()
	elif GameSettings.event_is(event, "reload"):
		player.start_reload()
	elif GameSettings.event_is(event, "view"):
		player.rig.toggle_view()
	elif GameSettings.event_is(event, "interact"):
		player._interact()
	elif GameSettings.event_is(event, "inventory"):
		player.inventory_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _can_play():
		return
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if GameSettings.event_is(event, "attack"):
			player._try_attack()
		elif GameSettings.event_is(event, "aim"):
			if not _rmb_down:
				_rmb_down = true
				_rmb_prev_blend = player.rig.target_blend
				player.rig.target_blend = 1.0
		elif GameSettings.event_is(event, "aim", false):
			if _rmb_down:
				_rmb_down = false
				player.rig.target_blend = _rmb_prev_blend
		elif GameSettings.event_is(event, "inventory") or GameSettings.event_is(event, "interact") or GameSettings.event_is(event, "reload") or GameSettings.event_is(event, "crouch") or GameSettings.event_is(event, "view"):
			_mouse_action(event)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			player.rig.target_blend = 1.0
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			player.rig.target_blend = 0.0
