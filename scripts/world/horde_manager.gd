extends Node
## Hordas dinâmicas: barulho forte atrai zumbis distantes; de vez em quando um bando
## aparece fora da vista e vem em direção ao jogador. Limite de zumbis vivos para poupar o celular.

const ZombieScript = preload("res://scripts/world/zombie.gd")
const MAX_ZOMBIES := 40
const SPAWN_MIN := 45.0
const SPAWN_MAX := 70.0
const WORLD_LIMIT := 330.0

var player
var _timer: float = 90.0
var _noise_acc: float = 0.0  # barulho recente acumulado (decai)


func _ready() -> void:
	GameManager.sound_emitted.connect(_on_sound)


func _on_sound(_pos: Vector3, radius: float) -> void:
	if radius >= 80.0:
		_noise_acc += radius * 0.5


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.dead:
		return
	_noise_acc = maxf(0.0, _noise_acc - 8.0 * delta)
	_timer -= delta
	if _timer > 0.0:
		return
	# Mais barulho = horda mais cedo e maior
	var size := 4 + int(_noise_acc / 40.0) + randi_range(0, 3)
	size = mini(size, 14)
	_timer = randf_range(150.0, 240.0) - minf(_noise_acc, 100.0)
	_noise_acc *= 0.4
	_spawn_horde(size)


func _spawn_horde(n: int) -> void:
	var alive := get_tree().get_nodes_in_group("zombies").size()
	n = mini(n, MAX_ZOMBIES - alive)
	if n <= 0:
		return
	var a := randf() * TAU
	var d := randf_range(SPAWN_MIN, SPAWN_MAX)
	var center: Vector3 = player.global_position + Vector3(cos(a) * d, 0.0, sin(a) * d)
	center.x = clampf(center.x, -WORLD_LIMIT, WORLD_LIMIT)
	center.z = clampf(center.z, -WORLD_LIMIT, WORLD_LIMIT)
	for i in n:
		var z := ZombieScript.new()
		z.position = center + Vector3(randf_range(-5.0, 5.0), 0.2, randf_range(-5.0, 5.0))
		z.crawler = randf() < 0.1
		get_parent().add_child(z)
		z.investigate(player.global_position, 40.0)
