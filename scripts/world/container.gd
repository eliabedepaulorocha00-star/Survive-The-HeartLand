extends Node3D
## Armário, caixa de ferramentas, mala de carro... O conteúdo só é sorteado
## na primeira vez que o jogador abre (assim o mapa não gasta nada antes disso).

var title: String = "Caixa"
var loot_table: String = "generic"
var reach: float = 2.4  # distância máxima do jogador para poder abrir
var opened: bool = false
var contents: Array = []  # entradas {"id", "n", "dur"}

var _marker: MeshInstance3D


func _ready() -> void:
	add_to_group("containers")
	# Bolinha âmbar flutuando: some depois da primeira abertura (ainda não revistado)
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.7, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.2)
	mat.emission_energy_multiplier = 1.5
	_marker = MeshInstance3D.new()
	_marker.mesh = sphere
	_marker.material_override = mat
	_marker.position = Vector3(0.0, 0.3, 0.0)
	add_child(_marker)


func open_loot() -> void:
	if opened:
		return
	opened = true
	contents = ItemDB.roll_loot(loot_table)
	if _marker != null:
		_marker.queue_free()
		_marker = null


## Move até `n` unidades da posição `index` para a mochila `inv`. Devolve quantas passaram.
func take_to(inv, index: int, n: int) -> int:
	if index < 0 or index >= contents.size():
		return 0
	var e: Dictionary = contents[index]
	var want := mini(n, int(e["n"]))
	var moved: int = inv.add(str(e["id"]), want, float(e["dur"]))
	if moved <= 0:
		return 0
	e["n"] = int(e["n"]) - moved
	if int(e["n"]) <= 0:
		contents.remove_at(index)
	return moved


## Guarda até `n` unidades do item `uid` da mochila `inv` neste recipiente.
func put_from(inv, uid: int, n: int) -> int:
	var e: Dictionary = inv.find_uid(uid)
	if e.is_empty():
		return 0
	var id := str(e["id"])
	var dur := float(e["dur"])
	var moved: int = inv.remove_uid(uid, n)
	if moved <= 0:
		return 0
	if ItemDB.is_stackable(id):
		var merged := false
		for c in contents:
			if c["id"] == id:
				c["n"] = int(c["n"]) + moved
				merged = true
				break
		if not merged:
			contents.append({"id": id, "n": moved, "dur": 0.0})
	else:
		for i in moved:
			contents.append({"id": id, "n": 1, "dur": dur})
	return moved
