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
	var mi := MeshInstance3D.new()
	mi.mesh = ItemModels.ground_mesh(item_id)
	mi.rotation.y = randf() * TAU
	mi.position.y = 0.02
	mi.scale = Vector3.ONE * 1.3  # um pouco maior para ser fácil de ver no celular
	mi.visibility_range_end = 60.0
	add_child(mi)
