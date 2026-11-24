extends RefCounted
## Monta os pedaços do mapa (estradas, casas, comércio, fazendas, árvores, carros).
## Toda a parte visual de um chunk é fundida em poucas malhas (uma por cor) e toda a
## colisão fica num único corpo estático: isso mantém a contagem de draw calls baixa no celular.
## Convenção dos prédios: origem no centro do terreno, porta na frente (+Z local).

const HOUSE_WALLS := [
	Color(0.78, 0.76, 0.70), Color(0.72, 0.68, 0.58), Color(0.60, 0.68, 0.74),
	Color(0.62, 0.72, 0.62), Color(0.85, 0.84, 0.80), Color(0.55, 0.40, 0.30),
]
const ROOFS := [Color(0.22, 0.20, 0.19), Color(0.30, 0.16, 0.14), Color(0.18, 0.22, 0.28), Color(0.28, 0.26, 0.22)]
const WOOD := Color(0.42, 0.30, 0.18)
const DARK_GLASS := Color(0.07, 0.09, 0.11)
const FLOOR := Color(0.36, 0.28, 0.20)
const CAR_COLORS := [
	Color(0.55, 0.10, 0.10), Color(0.20, 0.30, 0.50), Color(0.75, 0.75, 0.72),
	Color(0.15, 0.15, 0.16), Color(0.25, 0.48, 0.46), Color(0.70, 0.55, 0.15),
]

var chunk: Node3D
var body: StaticBody3D
var rng := RandomNumberGenerator.new()
var on_container: Callable  # (title, table, pos, reach)
var on_pickup: Callable  # (id, n, pos)

var _batches: Dictionary = {}
var _mats: Dictionary = {}
var _shapes: Dictionary = {}
var _arrays: Dictionary = {}


func begin(chunk_node: Node3D) -> void:
	chunk = chunk_node
	_batches = {}
	body = StaticBody3D.new()
	body.collision_layer = 1
	chunk.add_child(body)


## Cria as malhas fundidas do chunk. Chamar uma vez, depois de montar tudo.
func finish() -> void:
	for key in _batches:
		var b: Dictionary = _batches[key]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = b["v"]
		arr[Mesh.ARRAY_NORMAL] = b["n"]
		arr[Mesh.ARRAY_INDEX] = b["i"]
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.material_override = _mat(b["c"])
		mi.visibility_range_end = 330.0
		chunk.add_child(mi)
	_batches = {}


# --- Primitivas ---

func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html(false)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	_mats[key] = m
	return m


func _push(color: Color, arrays: Array, t: Transform3D) -> void:
	var key := color.to_html(false)
	if not _batches.has(key):
		_batches[key] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "i": PackedInt32Array(), "c": color}
	var b: Dictionary = _batches[key]
	var bv: PackedVector3Array = b["v"]
	var bn: PackedVector3Array = b["n"]
	var bi: PackedInt32Array = b["i"]
	var base := bv.size()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for k in verts.size():
		bv.append(t * verts[k])
		bn.append(t.basis * norms[k])
	for k in idx.size():
		bi.append(base + idx[k])
	b["v"] = bv
	b["n"] = bn
	b["i"] = bi


func _box_arrays(size: Vector3) -> Array:
	var key := "b%s" % str(size)
	if not _arrays.has(key):
		var m := BoxMesh.new()
		m.size = size
		_arrays[key] = m.get_mesh_arrays()
	return _arrays[key]


func _xf(xf: Transform3D, pos: Vector3, rot_deg: Vector3) -> Transform3D:
	return xf * Transform3D(Basis.from_euler(rot_deg * (PI / 180.0)), pos)


func box(xf: Transform3D, size: Vector3, pos: Vector3, color: Color, collide: bool = true, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var t := _xf(xf, pos, rot_deg)
	_push(color, _box_arrays(size), t)
	if collide:
		var key := "s%s" % str(size)
		if not _shapes.has(key):
			var sh := BoxShape3D.new()
			sh.size = size
			_shapes[key] = sh
		var cs := CollisionShape3D.new()
		cs.shape = _shapes[key]
		cs.transform = t
		body.add_child(cs)


func cyl(xf: Transform3D, r_top: float, r_bot: float, h: float, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO, segs: int = 8) -> void:
	var key := "c%.2f_%.2f_%.2f_%d" % [r_top, r_bot, h, segs]
	if not _arrays.has(key):
		var m := CylinderMesh.new()
		m.top_radius = r_top
		m.bottom_radius = r_bot
		m.height = h
		m.radial_segments = segs
		m.rings = 1
		_arrays[key] = m.get_mesh_arrays()
	_push(color, _arrays[key], _xf(xf, pos, rot_deg))


func prism(xf: Transform3D, size: Vector3, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var key := "p%s" % str(size)
	if not _arrays.has(key):
		var m := PrismMesh.new()
		m.size = size
		_arrays[key] = m.get_mesh_arrays()
	_push(color, _arrays[key], _xf(xf, pos, rot_deg))


func container(xf: Transform3D, title: String, table: String, local_pos: Vector3, reach: float = 2.4) -> void:
	if on_container.is_valid():
		on_container.call(title, table, xf * local_pos, reach)


func pickup(id: String, n: int, pos: Vector3) -> void:
	if on_pickup.is_valid():
		on_pickup.call(id, n, pos)


func lamp(xf: Transform3D, local_pos: Vector3, energy: float = 1.3, range_m: float = 9.0) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.4)
	l.light_energy = energy
	l.omni_range = range_m
	l.distance_fade_enabled = true
	l.distance_fade_begin = 45.0
	l.distance_fade_length = 25.0
	chunk.add_child(l)
	l.position = xf * local_pos


func sign_text(xf: Transform3D, local_pos: Vector3, text: String, color: Color = Color(0.95, 0.9, 0.7)) -> void:
	var lb := Label3D.new()
	lb.text = text
	lb.font_size = 72
	lb.pixel_size = 0.014
	lb.modulate = color
	lb.outline_size = 10
	lb.outline_modulate = Color(0.05, 0.05, 0.05)
	lb.visibility_range_end = 90.0
	chunk.add_child(lb)
	lb.transform = xf * Transform3D(Basis(), local_pos)


func _pick(arr: Array) -> Color:
	return arr[rng.randi() % arr.size()]


# --- Terreno ---

func ground_patch(rect_min: Vector2, rect_max: Vector2, color: Color, y: float = 0.02, height: float = 0.04) -> void:
	var size := Vector3(rect_max.x - rect_min.x, height, rect_max.y - rect_min.y)
	var center := Vector3((rect_min.x + rect_max.x) * 0.5, y, (rect_min.y + rect_max.y) * 0.5)
	box(Transform3D.IDENTITY, size, center, color, false)


func dash(x: float, z: float, along_x: bool) -> void:
	var size := Vector3(2.0, 0.045, 0.15) if along_x else Vector3(0.15, 0.045, 2.0)
	box(Transform3D.IDENTITY, size, Vector3(x, 0.03, z), Color(0.75, 0.65, 0.25), false)


func tree(pos: Vector3, s: float) -> void:
	var t := Transform3D(Basis().scaled(Vector3(s, s, s)), pos)
	cyl(t, 0.2, 0.3, 4.0, Vector3(0.0, 2.0, 0.0), Color(0.28, 0.20, 0.13), Vector3.ZERO, 6)
	var tone := rng.randi() % 3
	var green := Color(0.10, 0.25 + 0.04 * float(tone), 0.14)
	cyl(t, 0.0, 2.0, 3.2, Vector3(0.0, 3.6, 0.0), green, Vector3.ZERO, 7)
	cyl(t, 0.0, 1.4, 3.2, Vector3(0.0, 5.4, 0.0), green, Vector3.ZERO, 7)
	if not _shapes.has("tree"):
		var sh := CylinderShape3D.new()
		sh.radius = 0.3
		sh.height = 4.0
		_shapes["tree"] = sh
	var cs := CollisionShape3D.new()
	cs.shape = _shapes["tree"]
	cs.transform = Transform3D(Basis().scaled(Vector3(s, s, s)), pos + Vector3(0.0, 2.0 * s, 0.0))
	body.add_child(cs)


func field(xf: Transform3D, w: float, d: float, color: Color) -> void:
	box(xf, Vector3(w, 0.04, d), Vector3(0.0, 0.02, 0.0), color, false)
	var rows := int(w / 3.0)
	for r in rows:
		box(xf, Vector3(0.5, 0.05, d - 1.0), Vector3(-w * 0.5 + 1.5 + float(r) * 3.0, 0.03, 0.0), color.darkened(0.25), false)


# --- Prédios genéricos ---

## Quatro paredes com porta (vão de 1,8 m) na frente, chão e janelas.
func shell(xf: Transform3D, w: float, d: float, h: float, wall: Color, door_w: float = 1.8) -> void:
	box(xf, Vector3(w, 0.06, d), Vector3(0.0, 0.03, 0.0), FLOOR, false)
	box(xf, Vector3(w, h, 0.3), Vector3(0.0, h * 0.5, -d * 0.5), wall)
	box(xf, Vector3(0.3, h, d), Vector3(-w * 0.5, h * 0.5, 0.0), wall)
	box(xf, Vector3(0.3, h, d), Vector3(w * 0.5, h * 0.5, 0.0), wall)
	var side := (w - door_w) * 0.5
	box(xf, Vector3(side, h, 0.3), Vector3(-(door_w + side) * 0.5, h * 0.5, d * 0.5), wall)
	box(xf, Vector3(side, h, 0.3), Vector3((door_w + side) * 0.5, h * 0.5, d * 0.5), wall)
	box(xf, Vector3(door_w, h - 2.3, 0.3), Vector3(0.0, 2.3 + (h - 2.3) * 0.5, d * 0.5), wall)
	# Janelas escuras na frente e nas laterais; algumas com tábuas
	var wx := (w - door_w) * 0.25 + door_w * 0.5
	for sx in [-1.0, 1.0]:
		box(xf, Vector3(1.2, 1.0, 0.06), Vector3(sx * wx, 1.7, d * 0.5 + 0.17), DARK_GLASS, false)
		if rng.randf() < 0.55:
			boards(xf, Vector3(sx * wx, 1.7, d * 0.5 + 0.22))
	for sz in [-1.0, 1.0]:
		box(xf, Vector3(0.06, 1.0, 1.2), Vector3(sz * (w * 0.5 + 0.17), 1.7, d * 0.2), DARK_GLASS, false)


func boards(xf: Transform3D, pos: Vector3) -> void:
	for i in 3:
		var a := 4.0 - float(i) * 4.0
		box(xf, Vector3(1.4, 0.16, 0.06), pos + Vector3(0.0, -0.3 + float(i) * 0.3, 0.0), WOOD, false, Vector3(0.0, 0.0, a))


func gable_roof(xf: Transform3D, w: float, d: float, h: float, color: Color, wall: Color) -> void:
	var half := d * 0.5
	var rise := half * tan(deg_to_rad(28.0))
	var slab := half / cos(deg_to_rad(28.0)) + 0.4
	box(xf, Vector3(w + 0.8, 0.2, slab), Vector3(0.0, h + rise * 0.5 + 0.1, half * 0.5), color, false, Vector3(28.0, 0.0, 0.0))
	box(xf, Vector3(w + 0.8, 0.2, slab), Vector3(0.0, h + rise * 0.5 + 0.1, -half * 0.5), color, false, Vector3(-28.0, 0.0, 0.0))
	for sx in [-1.0, 1.0]:
		prism(xf, Vector3(d, rise, 0.3), Vector3(sx * (w * 0.5 - 0.05), h + rise * 0.5, 0.0), wall, Vector3(0.0, 90.0, 0.0))


func flat_roof(xf: Transform3D, w: float, d: float, h: float, color: Color) -> void:
	box(xf, Vector3(w + 0.4, 0.3, d + 0.4), Vector3(0.0, h + 0.15, 0.0), color, false)
	box(xf, Vector3(w + 0.4, 0.5, 0.2), Vector3(0.0, h + 0.55, d * 0.5 + 0.2), color.lightened(0.1), false)


func furniture(xf: Transform3D, size: Vector3, pos: Vector3, color: Color) -> void:
	box(xf, size, pos + Vector3(0.0, size.y * 0.5, 0.0), color)


# --- Casas ---

func house(xf: Transform3D, w: float = 0.0, d: float = 0.0, wall_override: Color = Color(0, 0, 0, 0)) -> void:
	if w <= 0.0:
		w = rng.randf_range(8.5, 11.0)
	if d <= 0.0:
		d = rng.randf_range(7.0, 9.0)
	var wall: Color = wall_override if wall_override.a > 0.0 else _pick(HOUSE_WALLS)
	shell(xf, w, d, 3.0, wall)
	gable_roof(xf, w, d, 3.0, _pick(ROOFS), wall)
	furniture(xf, Vector3(1.6, 0.8, 0.8), Vector3(-w * 0.25, 0.0, -d * 0.5 + 0.7), Color(0.40, 0.30, 0.20))
	container(xf, "Armário da cozinha", "kitchen", Vector3(-w * 0.25, 0.8, -d * 0.5 + 0.7))
	furniture(xf, Vector3(0.8, 0.8, 0.8), Vector3(w * 0.3, 0.0, -d * 0.5 + 0.7), Color(0.45, 0.32, 0.22))
	container(xf, "Cômoda do quarto", "bedroom", Vector3(w * 0.3, 0.8, -d * 0.5 + 0.7))
	box(xf, Vector3(0.3, 0.9, 0.8), Vector3(w * 0.5 - 0.35, 1.5, d * 0.1), Color(0.82, 0.82, 0.78))
	container(xf, "Armário de remédios", "bathroom", Vector3(w * 0.5 - 0.35, 1.95, d * 0.1))
	furniture(xf, Vector3(2.0, 0.5, 1.0), Vector3(-w * 0.25, 0.0, d * 0.05), Color(0.35, 0.32, 0.40))  # sofá
	furniture(xf, Vector3(1.9, 0.45, 1.5), Vector3(w * 0.28, 0.0, -d * 0.1), Color(0.55, 0.50, 0.45))  # cama
	if rng.randf() < 0.5:
		lamp(xf, Vector3(0.0, 2.3, 0.0))
	if rng.randf() < 0.45:
		# Caixa de ferramentas no quintal
		box(xf, Vector3(0.9, 0.5, 0.45), Vector3(w * 0.5 + 2.0, 0.25, 0.0), Color(0.70, 0.15, 0.12))
		container(xf, "Caixa de ferramentas", "garage", Vector3(w * 0.5 + 2.0, 0.5, 0.0))
	if rng.randf() < 0.3:
		pickup("canned_beans", 1, xf * Vector3(1.0, 0.07, 1.5))


# --- Comércio ---

func diner(xf: Transform3D) -> void:
	var w := 14.0
	var d := 10.0
	var wall := Color(0.70, 0.22, 0.20)
	shell(xf, w, d, 3.6, wall, 2.4)
	flat_roof(xf, w, d, 3.6, Color(0.25, 0.24, 0.24))
	sign_text(xf, Vector3(0.0, 4.6, d * 0.5 + 0.3), "DINER", Color(1.0, 0.85, 0.4))
	furniture(xf, Vector3(7.0, 1.0, 0.9), Vector3(0.0, 0.0, 0.5), Color(0.45, 0.32, 0.22))  # balcão
	for tx in [-4.0, 4.0]:
		furniture(xf, Vector3(1.4, 0.8, 1.4), Vector3(tx, 0.0, 3.0), Color(0.55, 0.45, 0.35))
	furniture(xf, Vector3(2.4, 0.9, 0.8), Vector3(-3.0, 0.0, -d * 0.5 + 0.7), Color(0.75, 0.75, 0.75))
	container(xf, "Cozinha do restaurante", "kitchen", Vector3(-3.0, 0.9, -d * 0.5 + 0.7), 2.8)
	furniture(xf, Vector3(1.0, 1.9, 0.9), Vector3(1.2, 0.0, -d * 0.5 + 0.7), Color(0.85, 0.85, 0.85))
	container(xf, "Geladeira", "kitchen", Vector3(1.2, 1.9, -d * 0.5 + 0.7))
	container(xf, "Balcão", "kitchen", Vector3(2.8, 1.0, 0.5))
	lamp(xf, Vector3(0.0, 3.0, 0.0), 1.5, 11.0)


func gas_station(xf: Transform3D) -> void:
	var w := 8.0
	var d := 6.0
	shell(xf, w, d, 3.2, Color(0.85, 0.82, 0.72), 2.0)
	flat_roof(xf, w, d, 3.2, Color(0.60, 0.15, 0.12))
	sign_text(xf, Vector3(0.0, 4.2, d * 0.5 + 0.3), "POSTO", Color(1.0, 0.5, 0.3))
	furniture(xf, Vector3(3.0, 1.0, 0.8), Vector3(0.0, 0.0, 1.0), Color(0.45, 0.32, 0.22))
	furniture(xf, Vector3(2.0, 1.8, 0.7), Vector3(-w * 0.5 + 1.4, 0.0, -d * 0.5 + 0.6), Color(0.35, 0.35, 0.40))
	container(xf, "Prateleira da loja", "roadside", Vector3(-w * 0.5 + 1.4, 1.8, -d * 0.5 + 0.6))
	furniture(xf, Vector3(1.6, 1.0, 0.8), Vector3(w * 0.5 - 1.4, 0.0, -d * 0.5 + 0.6), Color(0.35, 0.30, 0.25))
	container(xf, "Oficina do posto", "garage", Vector3(w * 0.5 - 1.4, 1.0, -d * 0.5 + 0.6))
	# Cobertura das bombas
	for sx in [-5.0, 5.0]:
		for sz in [d * 0.5 + 3.0, d * 0.5 + 9.0]:
			box(xf, Vector3(0.4, 4.2, 0.4), Vector3(sx, 2.1, sz), Color(0.8, 0.8, 0.8))
	box(xf, Vector3(12.0, 0.3, 8.0), Vector3(0.0, 4.35, d * 0.5 + 6.0), Color(0.60, 0.15, 0.12), false)
	for sx in [-2.5, 2.5]:
		box(xf, Vector3(0.7, 1.5, 0.5), Vector3(sx, 0.75, d * 0.5 + 6.0), Color(0.85, 0.2, 0.15))
	lamp(xf, Vector3(0.0, 2.8, 0.0))


func pharmacy(xf: Transform3D) -> void:
	var w := 12.0
	var d := 9.0
	shell(xf, w, d, 3.4, Color(0.80, 0.84, 0.80), 2.2)
	flat_roof(xf, w, d, 3.4, Color(0.30, 0.45, 0.40))
	sign_text(xf, Vector3(0.0, 4.4, d * 0.5 + 0.3), "FARMÁCIA", Color(0.5, 1.0, 0.7))
	furniture(xf, Vector3(5.0, 1.0, 0.8), Vector3(0.0, 0.0, 1.5), Color(0.85, 0.85, 0.85))
	for i in 3:
		var x := -3.6 + float(i) * 3.6
		furniture(xf, Vector3(2.4, 1.9, 0.6), Vector3(x, 0.0, -d * 0.5 + 0.6), Color(0.75, 0.80, 0.78))
		container(xf, "Prateleira de remédios", "pharmacy", Vector3(x, 1.9, -d * 0.5 + 0.6))
	lamp(xf, Vector3(0.0, 2.9, 0.0), 1.6)


func police_station(xf: Transform3D) -> void:
	var w := 14.0
	var d := 10.0
	shell(xf, w, d, 3.4, Color(0.45, 0.50, 0.58), 2.2)
	flat_roof(xf, w, d, 3.4, Color(0.18, 0.20, 0.26))
	sign_text(xf, Vector3(0.0, 4.4, d * 0.5 + 0.3), "DELEGACIA", Color(0.6, 0.75, 1.0))
	furniture(xf, Vector3(5.0, 1.0, 0.9), Vector3(-2.0, 0.0, 1.5), Color(0.35, 0.30, 0.25))
	box(xf, Vector3(0.3, 3.0, 5.0), Vector3(2.0, 1.5, -2.5), Color(0.45, 0.50, 0.58))  # divisória da cela
	furniture(xf, Vector3(1.6, 1.9, 0.7), Vector3(-5.0, 0.0, -d * 0.5 + 0.6), Color(0.30, 0.34, 0.30))
	container(xf, "Armário de armas", "police", Vector3(-5.0, 1.9, -d * 0.5 + 0.6))
	furniture(xf, Vector3(1.6, 1.9, 0.7), Vector3(-2.8, 0.0, -d * 0.5 + 0.6), Color(0.30, 0.34, 0.30))
	container(xf, "Armário de evidências", "police", Vector3(-2.8, 1.9, -d * 0.5 + 0.6))
	furniture(xf, Vector3(1.2, 0.8, 0.8), Vector3(5.0, 0.0, -d * 0.5 + 0.8), Color(0.40, 0.30, 0.20))
	container(xf, "Mesa do delegado", "police", Vector3(5.0, 0.8, -d * 0.5 + 0.8))
	lamp(xf, Vector3(0.0, 2.9, 0.0), 1.5)


func hardware_store(xf: Transform3D) -> void:
	var w := 14.0
	var d := 10.0
	shell(xf, w, d, 3.4, Color(0.62, 0.55, 0.40), 2.4)
	flat_roof(xf, w, d, 3.4, Color(0.25, 0.22, 0.18))
	sign_text(xf, Vector3(0.0, 4.4, d * 0.5 + 0.3), "FERRAGEM", Color(1.0, 0.7, 0.3))
	for i in 3:
		var x := -4.5 + float(i) * 4.5
		furniture(xf, Vector3(3.0, 1.9, 0.7), Vector3(x, 0.0, -d * 0.5 + 0.7), Color(0.50, 0.40, 0.28))
		container(xf, "Prateleira de ferramentas", "garage", Vector3(x, 1.9, -d * 0.5 + 0.7))
	furniture(xf, Vector3(4.0, 1.0, 0.9), Vector3(0.0, 0.0, 1.5), Color(0.40, 0.30, 0.20))
	lamp(xf, Vector3(0.0, 2.9, 0.0))


func general_store(xf: Transform3D) -> void:
	var w := 12.0
	var d := 10.0
	shell(xf, w, d, 3.4, Color(0.60, 0.64, 0.50), 2.2)
	flat_roof(xf, w, d, 3.4, Color(0.30, 0.26, 0.20))
	sign_text(xf, Vector3(0.0, 4.4, d * 0.5 + 0.3), "MERCADO", Color(0.7, 1.0, 0.6))
	for i in 3:
		var x := -3.6 + float(i) * 3.6
		furniture(xf, Vector3(2.6, 1.8, 0.7), Vector3(x, 0.0, -d * 0.5 + 0.7), Color(0.55, 0.55, 0.50))
		container(xf, "Prateleira do mercado", "kitchen" if i < 2 else "roadside", Vector3(x, 1.8, -d * 0.5 + 0.7))
	furniture(xf, Vector3(2.4, 1.2, 0.8), Vector3(-2.0, 0.0, 0.5), Color(0.55, 0.55, 0.50))
	container(xf, "Corredor do mercado", "kitchen", Vector3(-2.0, 1.2, 0.5))
	lamp(xf, Vector3(0.0, 2.9, 0.0), 1.5)


func church(xf: Transform3D) -> void:
	var w := 10.0
	var d := 18.0
	var wall := Color(0.88, 0.86, 0.80)
	shell(xf, w, d, 5.0, wall, 2.4)
	gable_roof(xf, w, d, 5.0, Color(0.25, 0.22, 0.22), wall)
	box(xf, Vector3(3.2, 9.0, 3.2), Vector3(0.0, 4.5, d * 0.5 + 1.6), wall)  # campanário
	prism(xf, Vector3(3.6, 2.4, 3.6), Vector3(0.0, 10.2, d * 0.5 + 1.6), Color(0.25, 0.22, 0.22))
	box(xf, Vector3(0.2, 1.4, 0.2), Vector3(0.0, 12.2, d * 0.5 + 1.6), Color(0.9, 0.9, 0.85), false)
	box(xf, Vector3(0.8, 0.2, 0.2), Vector3(0.0, 12.4, d * 0.5 + 1.6), Color(0.9, 0.9, 0.85), false)
	for i in 4:  # bancos
		furniture(xf, Vector3(3.0, 0.5, 0.8), Vector3(-2.0, 0.0, -3.0 + float(i) * 2.2), WOOD)
		furniture(xf, Vector3(3.0, 0.5, 0.8), Vector3(2.0, 0.0, -3.0 + float(i) * 2.2), WOOD)
	furniture(xf, Vector3(2.0, 1.0, 0.8), Vector3(0.0, 0.0, -d * 0.5 + 0.9), Color(0.5, 0.4, 0.3))
	container(xf, "Altar", "generic", Vector3(0.0, 1.0, -d * 0.5 + 0.9))
	furniture(xf, Vector3(1.0, 1.2, 0.8), Vector3(w * 0.5 - 0.8, 0.0, -d * 0.5 + 0.9), Color(0.5, 0.4, 0.3))
	container(xf, "Armário da sacristia", "kitchen", Vector3(w * 0.5 - 0.8, 1.2, -d * 0.5 + 0.9))


# --- Fazenda ---

func barn(xf: Transform3D) -> void:
	var w := 12.0
	var d := 16.0
	var red := Color(0.55, 0.14, 0.12)
	shell(xf, w, d, 5.0, red, 4.0)
	gable_roof(xf, w, d, 5.0, Color(0.30, 0.28, 0.27), red)
	for i in 2:
		furniture(xf, Vector3(2.0, 1.2, 1.0), Vector3(-w * 0.5 + 1.5, 0.0, -d * 0.5 + 1.2 + float(i) * 3.0), WOOD)
	container(xf, "Baú de ração", "farm", Vector3(-w * 0.5 + 1.5, 1.2, -d * 0.5 + 1.2), 2.6)
	furniture(xf, Vector3(2.4, 1.0, 1.0), Vector3(w * 0.5 - 1.8, 0.0, -d * 0.5 + 1.2), Color(0.45, 0.35, 0.25))
	container(xf, "Bancada do celeiro", "garage", Vector3(w * 0.5 - 1.8, 1.0, -d * 0.5 + 1.2), 2.6)
	for i in 3:  # fardos de feno
		furniture(xf, Vector3(1.2, 0.8, 1.2), Vector3(-1.0 + float(i) * 1.4, 0.0, 0.0), Color(0.75, 0.65, 0.30))
	lamp(xf, Vector3(0.0, 3.5, 0.0), 1.2, 10.0)


func silo(xf: Transform3D) -> void:
	box(xf, Vector3(5.0, 11.0, 5.0), Vector3(0.0, 5.5, 0.0), Color(0.62, 0.64, 0.66))
	cyl(xf, 0.0, 2.9, 2.2, Vector3(0.0, 12.1, 0.0), Color(0.45, 0.47, 0.50), Vector3.ZERO, 10)


func water_tower(xf: Transform3D) -> void:
	for sx in [-2.0, 2.0]:
		for sz in [-2.0, 2.0]:
			box(xf, Vector3(0.4, 12.0, 0.4), Vector3(sx, 6.0, sz), Color(0.35, 0.37, 0.38))
	cyl(xf, 3.2, 3.2, 4.5, Vector3(0.0, 14.2, 0.0), Color(0.55, 0.58, 0.60), Vector3.ZERO, 12)
	cyl(xf, 0.0, 3.4, 1.6, Vector3(0.0, 17.2, 0.0), Color(0.40, 0.42, 0.44), Vector3.ZERO, 12)
	sign_text(xf, Vector3(0.0, 14.5, 3.3), "MILLBROOK", Color(0.1, 0.1, 0.12))


# --- Veículos ---

func car(xf: Transform3D, color: Color, title: String = "Porta-malas do carro", truck: bool = false) -> void:
	if truck:
		box(xf, Vector3(2.0, 0.9, 4.6), Vector3(0.0, 0.85, 0.0), color)
		box(xf, Vector3(1.9, 0.8, 1.8), Vector3(0.0, 1.7, -0.5), color.darkened(0.1), false)
		container(xf, "Caçamba da caminhonete", "vehicle", Vector3(0.0, 1.35, 1.7), 2.8)
		for x in [-1.0, 1.0]:
			for z in [-1.5, 1.5]:
				cyl(xf, 0.42, 0.42, 0.3, Vector3(x, 0.42, z), Color(0.06, 0.06, 0.06), Vector3(0.0, 0.0, 90.0), 8)
		return
	box(xf, Vector3(1.9, 0.8, 4.3), Vector3(0.0, 0.75, 0.0), color)
	box(xf, Vector3(1.7, 0.7, 2.2), Vector3(0.0, 1.45, -0.2), color.darkened(0.15), false)
	box(xf, Vector3(1.72, 0.45, 2.0), Vector3(0.0, 1.5, -0.2), DARK_GLASS, false)
	container(xf, title, "vehicle", Vector3(0.0, 1.2, 1.8), 2.8)
	for x in [-0.95, 0.95]:
		for z in [-1.3, 1.3]:
			cyl(xf, 0.38, 0.38, 0.25, Vector3(x, 0.38, z), Color(0.06, 0.06, 0.06), Vector3(0.0, 0.0, 90.0), 8)
