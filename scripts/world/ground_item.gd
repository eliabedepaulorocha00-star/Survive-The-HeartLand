extends Node3D
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


# Caixinha colorida pela categoria; o tamanho acompanha o peso. Os modelos entram depois.
func _build_visual() -> void:
	var weight: float = ItemDB.weight_of(item_id)
	var s := clampf(0.10 + weight * 0.06, 0.10, 0.40)
	var color: Color = ItemDB.color_of(item_id)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(s * 1.3, s * 0.6, s)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.25  # brilho fraquinho ajuda a achar o item no escuro
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position.y = s * 0.3
	mi.rotation.y = randf() * TAU
	add_child(mi)
