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


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


var _dbg: Label
var _dbg_counts: Dictionary = {}
var _dbg_last: String = ""


func _debug(event: InputEvent) -> void:
	if _dbg == null:
		var layer := CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		_dbg = Label.new()
		_dbg.position = Vector2(12, 120)
		_dbg.add_theme_font_size_override("font_size", 18)
		_dbg.add_theme_color_override("font_color", Color(1, 1, 0.2))
		_dbg.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_dbg.add_theme_constant_override("outline_size", 6)
		_dbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_dbg)
	var cls := event.get_class()
	_dbg_counts[cls] = int(_dbg_counts.get(cls, 0)) + 1
	if event is InputEventMouseMotion:
		_dbg_last = "%s dev=%d rel=%s" % [cls, event.device, str(event.relative)]
	elif not (event is InputEventScreenDrag):
		_dbg_last = "%s dev=%d" % [cls, event.device]
	var t := "DIAG kbm  ativo=%s  finger=%s  jogando=%s  mouse_mode=%d\n" % [str(active), str(_finger_down), str(_can_play()), Input.mouse_mode]
	for k in _dbg_counts:
		t += "%s: %d\n" % [k, _dbg_counts[k]]
	_dbg.text = t + "ultimo: " + _dbg_last


func _input(event: InputEvent) -> void:
	_debug(event)
	if event is InputEventKey and event.pressed and not event.echo:
		_set_active(true)
	elif event is InputEventMouseMotion:
		# Tratado aqui (e não em _unhandled_input) para a interface nunca engolir o movimento do mouse.
		# Movimento gerado por um dedo na tela (emulação) é ignorado; qualquer outro vem do mouse.
		if not _finger_down and event.relative != Vector2.ZERO:
			_set_active(true)
			if _can_play():
				player.rig.apply_look(event.relative)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			_set_active(true)
	elif event is InputEventScreenTouch and event.device != InputEvent.DEVICE_ID_EMULATION:
		_finger_down = event.pressed
		if event.pressed:
			_set_active(false)


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
