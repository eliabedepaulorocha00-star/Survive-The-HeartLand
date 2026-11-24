extends Node
## Mapa em chunks de 100x100 m: "Millbrook", cidade fictícia do interior (estilo Kentucky/Indiana).
## Só o chunk do jogador e os 8 vizinhos ficam carregados. A montagem é repartida entre os quadros
## (orçamento de ms por quadro) para não travar o celular. Ao descarregar, guardamos o estado:
## recipientes já revistados, itens que sobraram no chão e quantos zumbis vivos havia.
##
## Layout (x = leste, z = sul):
##   Rodovia leste-oeste em z=8 · Rua Principal em x=0 descendo para a cidade (z 8..330)
##   Comércio na Rua Principal, casas nas ruas transversais (z=110, 170, 230), igreja e caixa-d'água
##   Fazendas ao norte, nas estradinhas de terra x=-70 e x=90; casas isoladas ao longo da rodovia.

const MapBuilder = preload("res://scripts/world/map_builder.gd")
const ZombieScript = preload("res://scripts/world/zombie.gd")
const ContainerScript = preload("res://scripts/world/container.gd")
const GroundItemScript = preload("res://scripts/world/ground_item.gd")

const CHUNK := 100.0
const GRID := 3  # chunks de -3 a 3 em cada eixo = 700 x 700 m
const LOAD_RADIUS := 1
const KEEP_RADIUS := 2
const FRAME_BUDGET_MS := 5.0
const ASPHALT := Color(0.13, 0.13, 0.14)
const GRAVEL := Color(0.36, 0.30, 0.22)

var player
var builder
var _roads: Array = []
var _lots: Array = []
var _lots_by_chunk: Dictionary = {}
var _loaded: Dictionary = {}  # "i,j" -> Node3D
var _state: Dictionary = {}  # "i,j" -> estado guardado ao descarregar
var _queue: Array = []  # chaves de chunk esperando montagem
var _queued: Dictionary = {}
var _job: Dictionary = {}
var _cur_idx: int = 0
var _restoring: bool = false
var _last_center := Vector2i(9999, 9999)
var _check_t: float = 0.0


func setup(player_node) -> void:
	player = player_node
	builder = MapBuilder.new()
	builder.on_container = _on_container
	builder.on_pickup = _on_pickup
	_build_layout()
	_update_desired(true)
	# O chunk onde o jogador nasce sai pronto na hora; o resto vem aos poucos.
	var first: String = _queue[0] if not _queue.is_empty() else ""
	while first != "" and not _loaded.has(first):
		_run_jobs(1.0e9)


func key_of(i: int, j: int) -> String:
	return "%d,%d" % [i, j]


func is_loaded(i: int, j: int) -> bool:
	return _loaded.has(key_of(i, j))


func loaded_count() -> int:
	return _loaded.size()


func is_busy() -> bool:
	return not _job.is_empty() or not _queue.is_empty()


## Termina tudo que está na fila (usado nos testes).
func flush() -> void:
	_update_desired(true)
	while is_busy():
		_run_jobs(1.0e9)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 0.4
		_update_desired(false)
	if is_busy():
		_run_jobs(FRAME_BUDGET_MS)


# --- Layout fixo da cidade ---

func _build_layout() -> void:
	_roads = [
		{"h": true, "c": 8.0, "a": -350.0, "b": 350.0, "w": 7.0, "col": ASPHALT, "t": 0.04, "dash": true},
		{"h": false, "c": 0.0, "a": 8.0, "b": 330.0, "w": 7.0, "col": ASPHALT, "t": 0.04, "dash": true},
		{"h": true, "c": 110.0, "a": -140.0, "b": 140.0, "w": 6.0, "col": ASPHALT, "t": 0.04, "dash": true},
		{"h": true, "c": 170.0, "a": -140.0, "b": 140.0, "w": 6.0, "col": ASPHALT, "t": 0.04, "dash": true},
		{"h": true, "c": 230.0, "a": -140.0, "b": 140.0, "w": 6.0, "col": ASPHALT, "t": 0.04, "dash": true},
		{"h": false, "c": -70.0, "a": -350.0, "b": 8.0, "w": 4.0, "col": GRAVEL, "t": 0.03, "dash": false},
		{"h": false, "c": 90.0, "a": -350.0, "b": 8.0, "w": 4.0, "col": GRAVEL, "t": 0.03, "dash": false},
	]
	# Casa onde o jogador nasce e a caminhonete na estrada
	_lot("start", 0.0, -6.0, 0.0, 10.0)
	_lot("truck", -12.0, 11.5, 12.0, 4.0)
	# Rua Principal: comércio (leste de frente para oeste e vice-versa)
	_lot("gas", 24.0, 34.0, -90.0, 14.0)
	_lot("diner", 18.0, 64.0, -90.0, 11.0)
	_lot("pharmacy", 17.0, 90.0, -90.0, 9.0)
	_lot("store", -17.0, 36.0, 90.0, 10.0)
	_lot("police", -18.0, 64.0, 90.0, 11.0)
	_lot("hardware", -18.0, 92.0, 90.0, 11.0)
	_lot("church", 22.0, 140.0, -90.0, 15.0)
	_lot("watertower", -26.0, 140.0, 0.0, 6.0)
	# Casas da cidade
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for z0 in [110.0, 170.0, 230.0]:
		var skip := 40.0 if z0 < 120.0 else 22.0
		for k in range(-5, 6):
			var x := float(k) * 26.0
			if absf(x) < skip:
				continue
			if rng.randf() < 0.9:
				_lot("house", x, z0 - 14.0, 0.0, 8.0)
			if rng.randf() < 0.9:
				_lot("house", x, z0 + 14.0, 180.0, 8.0)
	for z in [262.0, 288.0, 314.0]:
		_lot("house", 17.0, z, -90.0, 8.0)
		_lot("house", -17.0, z, 90.0, 8.0)
	# Fazenda oeste (estradinha x=-70)
	_lot("farmhouse", -86.0, -60.0, 90.0, 9.0)
	_lot("barn", -100.0, -86.0, 90.0, 12.0)
	_lot("silo", -112.0, -100.0, 0.0, 4.0)
	_lot("field", -125.0, -170.0, 0.0, 34.0, {"w": 60.0, "d": 70.0, "col": Color(0.42, 0.40, 0.18)})
	# Fazenda leste (estradinha x=90)
	_lot("farmhouse", 106.0, -110.0, -90.0, 9.0)
	_lot("barn", 124.0, -136.0, -90.0, 12.0)
	_lot("silo", 136.0, -154.0, 0.0, 4.0)
	_lot("field", 150.0, -60.0, 0.0, 30.0, {"w": 50.0, "d": 60.0, "col": Color(0.30, 0.38, 0.16)})
	# Casas isoladas ao longo da rodovia e uma cabana
	for x in [-150.0, 130.0, -220.0, 210.0, 290.0]:
		_lot("house", x, -8.0, 0.0, 8.0)
	for x in [-250.0, 260.0]:
		_lot("house", x, 28.0, 180.0, 8.0)
	_lot("farmhouse", -210.0, 100.0, 90.0, 9.0)
	_lot("barn", -230.0, 76.0, 90.0, 12.0)
	_lot("house", 180.0, -230.0, 0.0, 8.0)
	_lot("house", -250.0, -250.0, 0.0, 8.0)
	for lot in _lots:
		var ci := roundi(float(lot["x"]) / CHUNK)
		var cj := roundi(float(lot["z"]) / CHUNK)
		var k := key_of(clampi(ci, -GRID, GRID), clampi(cj, -GRID, GRID))
		if not _lots_by_chunk.has(k):
			_lots_by_chunk[k] = []
		_lots_by_chunk[k].append(lot)


func _lot(type: String, x: float, z: float, yaw: float, r: float, extra: Dictionary = {}) -> void:
	_lots.append({"type": type, "x": x, "z": z, "yaw": yaw, "r": r, "extra": extra, "seed": hash("%s%d%d" % [type, int(x), int(z)])})


# --- Quais chunks ficam carregados ---

func _chunk_of(pos: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi(pos.x / CHUNK), -GRID, GRID), clampi(roundi(pos.z / CHUNK), -GRID, GRID))


func _update_desired(force: bool) -> void:
	var c := _chunk_of(player.global_position)
	if c == _last_center and not force:
		return
	_last_center = c
	var wanted: Array = []
	for di in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dj in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var i := c.x + di
			var j := c.y + dj
			if absi(i) > GRID or absi(j) > GRID:
				continue
			var k := key_of(i, j)
			if not _loaded.has(k) and not _queued.has(k) and not (not _job.is_empty() and _job["key"] == k):
				wanted.append(Vector3i(i, j, absi(di) + absi(dj)))
	wanted.sort_custom(func(a, b): return a.z < b.z)
	for w in wanted:
		var k2 := key_of(w.x, w.y)
		_queue.append(k2)
		_queued[k2] = Vector2i(w.x, w.y)
	for k3 in _loaded.keys():
		var parts: PackedStringArray = k3.split(",")
		if maxi(absi(int(parts[0]) - c.x), absi(int(parts[1]) - c.y)) > KEEP_RADIUS:
			_unload(k3)


func _unload(k: String) -> void:
	var node: Node3D = _loaded[k]
	var st := {"cont": {}, "pick": [], "zom": 0}
	for ch in node.get_children():
		if ch.has_meta("idx") and ch.get("opened") == true:
			st["cont"][int(ch.get_meta("idx"))] = {"opened": true, "contents": ch.contents.duplicate(true)}
		elif ch.is_in_group("pickups"):
			st["pick"].append({"id": ch.item_id, "n": ch.count, "dur": ch.durability, "pos": ch.position})
		elif ch.is_in_group("zombies") and ch.state != ch.State.DEAD:
			st["zom"] = int(st["zom"]) + 1
	_state[k] = st
	_loaded.erase(k)
	node.queue_free()


# --- Montagem em etapas ---

func _run_jobs(budget_ms: float) -> void:
	var t0 := Time.get_ticks_usec()
	while true:
		if _job.is_empty():
			if _queue.is_empty():
				return
			_start_job(_queue.pop_front())
		var steps: Array = _job["steps"]
		while _job["n"] < steps.size():
			var s: Callable = steps[_job["n"]]
			_job["n"] = int(_job["n"]) + 1
			s.call()
			if float(Time.get_ticks_usec() - t0) / 1000.0 > budget_ms:
				return
		_job = {}
		if float(Time.get_ticks_usec() - t0) / 1000.0 > budget_ms:
			return


func _start_job(k: String) -> void:
	var c: Vector2i = _queued[k]
	_queued.erase(k)
	var node := Node3D.new()
	node.name = "Chunk_%d_%d" % [c.x, c.y]
	add_child(node)
	builder.begin(node)
	var st: Dictionary = _state.get(k, {})
	_restoring = st.has("pick")
	_cur_idx = 0
	_job = {"key": k, "i": c.x, "j": c.y, "node": node, "n": 0, "steps": [], "state": st}
	var steps: Array = _job["steps"]
	steps.append(_step_roads)
	for lot in _lots_by_chunk.get(k, []):
		steps.append(_step_lot.bind(lot))
	var trees := _tree_count(c.x, c.y)
	var tree_rng := RandomNumberGenerator.new()
	tree_rng.seed = hash(k)
	while trees > 0:
		var n := mini(10, trees)
		steps.append(_step_trees.bind(n, tree_rng.randi()))
		trees -= n
	steps.append(_step_cars.bind(hash(k) + 7))
	steps.append(_step_loot.bind(hash(k) + 13))
	steps.append(_step_zombies)
	steps.append(_step_finish)


func _bounds() -> Rect2:
	return Rect2(float(_job["i"]) * CHUNK - 50.0, float(_job["j"]) * CHUNK - 50.0, CHUNK, CHUNK)


func _step_roads() -> void:
	var rect := _bounds()
	var x0 := rect.position.x
	var z0 := rect.position.y
	var x1 := rect.end.x
	var z1 := rect.end.y
	for r in _roads:
		var horiz: bool = r["h"]
		var c: float = r["c"]
		var half: float = float(r["w"]) * 0.5
		var lo := z0 if horiz else x0
		var hi := z1 if horiz else x1
		if c + half < lo or c - half > hi:
			continue
		var a := maxf(float(r["a"]), x0 if horiz else z0)
		var b := minf(float(r["b"]), x1 if horiz else z1)
		if b <= a:
			continue
		var pl := maxf(c - half, lo)
		var ph := minf(c + half, hi)
		var t: float = r["t"]
		if horiz:
			builder.ground_patch(Vector2(a, pl), Vector2(b, ph), r["col"], t * 0.5, t)
		else:
			builder.ground_patch(Vector2(pl, a), Vector2(ph, b), r["col"], t * 0.5, t)
		if r["dash"]:
			var p := ceilf(a / 6.0) * 6.0
			while p < b:
				if horiz:
					builder.dash(p, c, true)
				else:
					builder.dash(c, p, false)
				p += 6.0


func _step_lot(lot: Dictionary) -> void:
	builder.rng.seed = int(lot["seed"])
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(float(lot["yaw"]))), Vector3(float(lot["x"]), 0.0, float(lot["z"])))
	match str(lot["type"]):
		"start":
			builder.house(xf, 10.0, 8.0, Color(0.78, 0.76, 0.70))
			builder.ground_patch(Vector2(-1.0, -2.0), Vector2(1.0, 5.0), Color(0.35, 0.28, 0.18), 0.015, 0.03)
			builder.box(Transform3D.IDENTITY, Vector3(0.9, 0.5, 0.45), Vector3(7.5, 0.25, -2.0), Color(0.70, 0.15, 0.12))
			builder.container(Transform3D.IDENTITY, "Caixa de ferramentas", "garage", Vector3(7.5, 0.5, -2.0))
			builder.pickup("water_bottle", 1, Vector3(2.5, 0.07, 11.8))
		"truck":
			builder.car(xf, Color(0.25, 0.48, 0.46), "", true)
		"house":
			builder.house(xf)
		"farmhouse":
			builder.house(xf, 0.0, 0.0, Color(0.88, 0.87, 0.82))
		"gas":
			builder.gas_station(xf)
		"diner":
			builder.diner(xf)
		"pharmacy":
			builder.pharmacy(xf)
		"police":
			builder.police_station(xf)
		"hardware":
			builder.hardware_store(xf)
		"store":
			builder.general_store(xf)
		"church":
			builder.church(xf)
		"barn":
			builder.barn(xf)
		"silo":
			builder.silo(xf)
		"watertower":
			builder.water_tower(xf)
		"field":
			var ex: Dictionary = lot["extra"]
			builder.field(xf, float(ex["w"]), float(ex["d"]), ex["col"])


func _tree_count(i: int, j: int) -> int:
	var cx := float(i) * CHUNK
	var cz := float(j) * CHUNK
	if absf(cx) <= 100.0 and cz >= 100.0 and cz <= 300.0:
		return 6  # cidade
	if (cx < -100.0 and cz < 0.0) or (cx > 100.0 and cz < -50.0) or cz >= 250.0:
		return 38  # mata
	return 16


## Livre de estradas e de terrenos de prédios (com folga `margin`)?
func _is_free(x: float, z: float, margin: float, near: Array) -> bool:
	for r in _roads:
		var half: float = float(r["w"]) * 0.5 + margin
		if r["h"]:
			if absf(z - float(r["c"])) < half and x > float(r["a"]) - margin and x < float(r["b"]) + margin:
				return false
		else:
			if absf(x - float(r["c"])) < half and z > float(r["a"]) - margin and z < float(r["b"]) + margin:
				return false
	for lot in near:
		var dx := x - float(lot["x"])
		var dz := z - float(lot["z"])
		var rr := float(lot["r"]) + margin
		if dx * dx + dz * dz < rr * rr:
			return false
	return true


func _near_lots() -> Array:
	var rect := _bounds().grow(40.0)
	var out: Array = []
	for lot in _lots:
		if rect.has_point(Vector2(float(lot["x"]), float(lot["z"]))):
			out.append(lot)
	return out


func _step_trees(n: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	builder.rng.seed = seed_value
	var rect := _bounds()
	var near := _near_lots()
	var placed := 0
	var tries := 0
	while placed < n and tries < n * 6:
		tries += 1
		var x := rng.randf_range(rect.position.x + 2.0, rect.end.x - 2.0)
		var z := rng.randf_range(rect.position.y + 2.0, rect.end.y - 2.0)
		if not _is_free(x, z, 3.0, near):
			continue
		builder.tree(Vector3(x, 0.0, z), rng.randf_range(0.8, 1.35))
		placed += 1


func _step_cars(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rect := _bounds()
	builder.rng.seed = seed_value
	for r in _roads:
		if float(r["w"]) < 6.0 or rng.randf() > 0.55:
			continue
		var horiz: bool = r["h"]
		var c: float = r["c"]
		var lo := maxf(float(r["a"]), (rect.position.x if horiz else rect.position.y) + 6.0)
		var hi := minf(float(r["b"]), (rect.end.x if horiz else rect.end.y) - 6.0)
		var perp_lo := rect.position.y if horiz else rect.position.x
		var perp_hi := rect.end.y if horiz else rect.end.x
		if hi <= lo or c < perp_lo or c > perp_hi:
			continue
		var along := rng.randf_range(lo, hi)
		var lateral := c + rng.randf_range(-1.6, 1.6)
		var yaw := (90.0 if horiz else 0.0) + (180.0 if rng.randf() < 0.5 else 0.0) + rng.randf_range(-12.0, 12.0)
		var pos := Vector3(along, 0.0, lateral) if horiz else Vector3(lateral, 0.0, along)
		var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), pos)
		builder.car(xf, MapBuilder.CAR_COLORS[rng.randi() % MapBuilder.CAR_COLORS.size()])


func _step_loot(seed_value: int) -> void:
	if _restoring:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rect := _bounds()
	var near := _near_lots()
	var spots := 0
	var tries := 0
	var want := 3 if _tree_count(int(_job["i"]), int(_job["j"])) <= 6 else 2
	while spots < want and tries < 40:
		tries += 1
		var x := rng.randf_range(rect.position.x + 3.0, rect.end.x - 3.0)
		var z := rng.randf_range(rect.position.y + 3.0, rect.end.y - 3.0)
		if not _is_free(x, z, 1.0, near):
			continue
		for e in ItemDB.roll_loot("roadside", rng):
			builder.pickup(str(e["id"]), int(e["n"]), Vector3(x, 0.07, z))
		spots += 1


func _step_zombies() -> void:
	var node: Node3D = _job["node"]
	var st: Dictionary = _job["state"]
	var i: int = _job["i"]
	var j: int = _job["j"]
	var count := 0
	if st.has("zom"):
		count = int(st["zom"])
	else:
		count = 5 if _tree_count(i, j) <= 6 else 2
		if i == 0 and j == 0:
			# Dois zumbis dentro da casa inicial
			_spawn_zombie(node, Vector3(-3.0, 0.2, -7.5), false)
			_spawn_zombie(node, Vector3(3.0, 0.2, -7.0), false)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(_job["key"])) + 99
	var rect := _bounds()
	var near := _near_lots()
	var tries := 0
	while count > 0 and tries < 80:
		tries += 1
		var x := rng.randf_range(rect.position.x + 4.0, rect.end.x - 4.0)
		var z := rng.randf_range(rect.position.y + 4.0, rect.end.y - 4.0)
		if not _is_free(x, z, 1.5, near):
			continue
		if player != null and Vector2(x, z).distance_to(Vector2(player.global_position.x, player.global_position.z)) < 35.0:
			continue
		_spawn_zombie(node, Vector3(x, 0.2, z), rng.randf() < 0.08)
		count -= 1


func _spawn_zombie(node: Node3D, pos: Vector3, crawl: bool) -> void:
	var z = ZombieScript.new()
	z.crawler = crawl
	z.position = pos
	node.add_child(z)


func _step_finish() -> void:
	builder.finish()
	var k: String = _job["key"]
	_loaded[k] = _job["node"]
	if _restoring:
		for p in _job["state"]["pick"]:
			_spawn_pickup(str(p["id"]), int(p["n"]), float(p["dur"]), p["pos"])


# --- Chamadas do construtor ---

func _on_container(title: String, table: String, pos: Vector3, reach: float) -> void:
	var node: Node3D = _job["node"]
	var c = ContainerScript.new()
	c.title = title
	c.loot_table = table
	c.reach = reach
	c.position = pos
	var idx := _cur_idx
	_cur_idx += 1
	c.set_meta("idx", idx)
	node.add_child(c)
	var st: Dictionary = _job["state"]
	if st.has("cont") and st["cont"].has(idx):
		var saved: Dictionary = st["cont"][idx]
		c.opened = true
		c.contents = saved["contents"]
		if c._marker != null:
			c._marker.queue_free()
			c._marker = null


func _on_pickup(id: String, n: int, pos: Vector3) -> void:
	if _restoring:
		return
	_spawn_pickup(id, n, ItemDB.max_durability_of(id), pos)


func _spawn_pickup(id: String, n: int, dur: float, pos: Vector3) -> void:
	var node: Node3D = _job["node"] if not _job.is_empty() else null
	if node == null:
		return
	var g = GroundItemScript.new()
	g.setup(id, n, dur)
	node.add_child(g)
	g.position = pos
