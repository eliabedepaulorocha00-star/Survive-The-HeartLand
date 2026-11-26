extends Node3D

const ItemModels = preload("res://scripts/world/item_models.gd")
## Item solto no chão: espalhado pelo mapa ou largado pelo jogador.
## Fica no grupo "pickups"; o jogador pega com o botão de ação.

var item_id: String = ""
var count: int = 1
var durability: float = 0.0


func setup(id: String, n: int, dur: float) -> void:
	item_id = id
	count = n
	durability = dur


func _ready() -> void:
	add_to_group("pickups")
	_build_visual()


func display_name() -> String:
	var nm: String = ItemDB.name_of(item_id)
	if count > 1:
		return "%s x%d" % [nm, count]
	return nm


# Modelo low-poly do item (scripts/world/item_models.gd); o brilho fraquinho ajuda a achar no escuro.
func _build_visual() -> void:
	var node: Node3D = ItemModels.ground_node(item_id)
	node.rotation.y = randf() * TAU
	add_child(node)
