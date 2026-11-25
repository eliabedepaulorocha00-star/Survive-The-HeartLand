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


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_set_active(true)
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			_set_active(true)
	elif event is InputEventScreenTouch and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
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
	if _can_play() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var e: Dictionary = player.inventory.equipped_entry()
		if e.is_empty() or not ItemDB.is_firearm(str(e["id"])):
			player._try_attack()


func _unhandled_input(event: InputEvent) -> void:
	if not _can_play():
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and captured and event.device != InputEvent.DEVICE_ID_EMULATION:
		player.rig.apply_look(event.relative)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if captured:
				player._try_attack()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed and not _rmb_down:
				_rmb_down = true
				_rmb_prev_blend = player.rig.target_blend
				player.rig.target_blend = 1.0
			elif not event.pressed and _rmb_down:
				_rmb_down = false
				player.rig.target_blend = _rmb_prev_blend
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			player.rig.target_blend = 1.0
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			player.rig.target_blend = 0.0
