extends RefCounted
## Mochila do jogador: pilhas de itens, peso total e limite de carga.
## Cada entrada é um Dictionary {"uid", "id", "n", "dur"}.
## Passou da capacidade confortável: anda mais devagar. Passou do limite duro: não cabe mais nada.

signal changed

const BASE_CAPACITY := 20.0  # kg carregados sem penalidade
const HARD_LIMIT_FACTOR := 1.5  # acima de capacidade x 1,5 não cabe nada
const MIN_SPEED_FACTOR := 0.55  # velocidade no limite duro

var entries: Array = []
var capacity: float = BASE_CAPACITY
var equipped_uid: int = 0  # 0 = punhos

var _next_uid: int = 1


func total_weight() -> float:
	var t := 0.0
	for e in entries:
		t += ItemDB.weight_of(e["id"]) * float(e["n"])
	return t


func hard_limit() -> float:
	return capacity * HARD_LIMIT_FACTOR


func is_overweight() -> bool:
	return total_weight() > capacity


## 1.0 = sem penalidade; cai até MIN_SPEED_FACTOR no limite duro.
func speed_factor() -> float:
	var w := total_weight()
	if w <= capacity:
		return 1.0
	var t := clampf((w - capacity) / (hard_limit() - capacity), 0.0, 1.0)
	return lerpf(1.0, MIN_SPEED_FACTOR, t)


## Quantas unidades de `id` ainda cabem (até `want`).
func can_carry(id: String, want: int) -> int:
	var w := ItemDB.weight_of(id)
	if w <= 0.0:
		return want
	var room := hard_limit() - total_weight()
	if room <= 0.0:
		return 0
	return clampi(floori(room / w), 0, want)


## Põe na mochila o que couber. Devolve quantas unidades entraram.
## `dur` < 0 usa a durabilidade máxima do item.
func add(id: String, n: int = 1, dur: float = -1.0) -> int:
	if not ItemDB.has_item(id) or n <= 0:
		return 0
	var fit := can_carry(id, n)
	if fit <= 0:
		return 0
	if ItemDB.is_stackable(id):
		var stack := _find_stack(id)
		if stack.is_empty():
			entries.append(_make(id, fit, 0.0))
		else:
			stack["n"] = int(stack["n"]) + fit
	else:
		var d: float = dur if dur >= 0.0 else ItemDB.max_durability_of(id)
		for i in fit:
			entries.append(_make(id, 1, d))
	changed.emit()
	return fit


func find_uid(uid: int) -> Dictionary:
	for e in entries:
		if int(e["uid"]) == uid:
			return e
	return {}


func count(id: String) -> int:
	var c := 0
	for e in entries:
		if e["id"] == id:
			c += int(e["n"])
	return c


func has_item(id: String) -> bool:
	return count(id) > 0


## Tira `n` unidades (ou a pilha toda se n for maior). Devolve quantas saíram.
func remove_uid(uid: int, n: int = 1) -> int:
	for i in entries.size():
		var e: Dictionary = entries[i]
		if int(e["uid"]) != uid:
			continue
		var taken := mini(n, int(e["n"]))
		e["n"] = int(e["n"]) - taken
		if int(e["n"]) <= 0:
			entries.remove_at(i)
			if equipped_uid == uid:
				equipped_uid = 0
		changed.emit()
		return taken
	return 0


## Tira uma unidade do primeiro item com esse id. Devolve true se havia.
func consume_one(id: String) -> bool:
	for e in entries:
		if e["id"] == id:
			return remove_uid(int(e["uid"]), 1) > 0
	return false


func equipped_entry() -> Dictionary:
	if equipped_uid == 0:
		return {}
	return find_uid(equipped_uid)


func set_equipped(uid: int) -> void:
	equipped_uid = uid
	changed.emit()


func _find_stack(id: String) -> Dictionary:
	for e in entries:
		if e["id"] == id:
			return e
	return {}


func _make(id: String, n: int, dur: float) -> Dictionary:
	var e := {"uid": _next_uid, "id": id, "n": n, "dur": dur}
	_next_uid += 1
	return e
