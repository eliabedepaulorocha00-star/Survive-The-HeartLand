extends Node3D
## Boneco articulado (cabeça, pescoço, tronco, braços com cotovelo, pernas com joelho,
## mãos e sapatos) com roupas do dia a dia. Serve para o jogador, a prévia da customização e os zumbis.
## Olha para -Z. Altura de ~1,75 m. Tudo feito de formas simples; modelos pintados entram depois.

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}

var zombie: bool = false
var _legs: Array = []  # [{hip, knee}, ...]
var _arms: Array = []  # [{shoulder, elbow}, ...]
var _head: Node3D
var _phase: float = 0.0
var _amount: float = 0.0
var _seed: float = 0.0


## `a`: dicionário de CharacterData.appearance(). `backpack`: desenha a mochila nas costas.
func build(a: Dictionary, backpack: bool = false) -> void:
	_seed = randf() * TAU
	var female: bool = bool(a.get("female", false))
	var skin: Color = a.get("skin_color", Color(0.87, 0.68, 0.53))
	var top: Color = a.get("top_color", Color(0.6, 0.12, 0.1))
	var bottom: Color = a.get("bottom_color", Color(0.2, 0.3, 0.5))
	var shoes: Color = a.get("shoe_color", Color(0.1, 0.1, 0.1))
	var top_style: int = int(a.get("top_style", 0))
	var bottom_style: int = int(a.get("bottom_style", 0))
	var long_sleeves: bool = top_style != 0
	var shorts: bool = bottom_style == 1

	var sw := 0.38 if female else 0.46  # largura dos ombros
	var hw := 0.36 if female else 0.33  # largura do quadril
	var s := 0.95 if female else 1.0
	scale = Vector3(s, s, s)

	# Pelve e tronco
	_box(self, Vector3(hw, 0.20, 0.22), Vector3(0.0, 0.93, 0.0), bottom)
	_box(self, Vector3(sw * 0.9, 0.54, 0.24), Vector3(0.0, 1.27, 0.0), top)
	if female:
		_box(self, Vector3(sw * 0.85, 0.12, 0.26), Vector3(0.0, 1.38, -0.01), top)  # busto
	if top_style == 1:  # xadrez: faixas mais escuras
		var dark := top.darkened(0.35)
		for x in [-0.12, 0.0, 0.12]:
			_box(self, Vector3(0.04, 0.50, 0.255), Vector3(x, 1.27, 0.0), dark)
		for y in [1.15, 1.30, 1.45]:
			_box(self, Vector3(sw * 0.9, 0.035, 0.255), Vector3(0.0, y, 0.0), dark)
	if top_style == 2:  # moletom: capuz e bolso
		_box(self, Vector3(0.26, 0.14, 0.12), Vector3(0.0, 1.58, 0.12), top.darkened(0.1))
		_box(self, Vector3(0.26, 0.10, 0.02), Vector3(0.0, 1.10, -0.125), top.darkened(0.2))
	_box(self, Vector3(0.09, 0.10, 0.09), Vector3(0.0, 1.58, 0.0), skin)  # pescoço
	if backpack:
		_box(self, Vector3(0.36, 0.46, 0.18), Vector3(0.0, 1.27, 0.21), Color(0.28, 0.32, 0.20))
		_box(self, Vector3(0.28, 0.16, 0.06), Vector3(0.0, 1.22, 0.31), Color(0.22, 0.26, 0.16))

	# Cabeça
	_head = Node3D.new()
	_head.position = Vector3(0.0, 1.68, 0.0)
	add_child(_head)
	var head := MeshInstance3D.new()
	head.mesh = _mesh("sphere", Vector3.ONE)
	head.scale = Vector3(0.22, 0.26, 0.24)
	head.material_override = _mat(skin)
	_head.add_child(head)
	_box(_head, Vector3(0.035, 0.05, 0.05), Vector3(0.0, -0.02, -0.125), skin.darkened(0.08))  # nariz
	var eye := Color(0.08, 0.08, 0.08) if not zombie else Color(0.85, 0.85, 0.7)
	for x in [-0.05, 0.05]:
		_box(_head, Vector3(0.035, 0.02, 0.01), Vector3(x, 0.03, -0.115), eye)
	_box(_head, Vector3(0.06, 0.012, 0.01), Vector3(0.0, -0.065, -0.115), skin.darkened(0.3))  # boca
	_build_hair(int(a.get("hair_style", 1)), a.get("hair_color", Color(0.3, 0.2, 0.1)), top)

	# Pernas (quadril -> joelho)
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * hw * 0.3, 0.88, 0.0)
		add_child(hip)
		if shorts:
			_box(hip, Vector3(0.16, 0.26, 0.17), Vector3(0.0, -0.13, 0.0), bottom)
			_box(hip, Vector3(0.14, 0.18, 0.15), Vector3(0.0, -0.35, 0.0), skin)
		else:
			_box(hip, Vector3(0.16, 0.44, 0.17), Vector3(0.0, -0.22, 0.0), bottom)
		var knee := Node3D.new()
		knee.position = Vector3(0.0, -0.44, 0.0)
		hip.add_child(knee)
		_box(knee, Vector3(0.14, 0.40, 0.15), Vector3(0.0, -0.20, 0.0), skin if shorts else bottom)
		_box(knee, Vector3(0.15, 0.09, 0.27), Vector3(0.0, -0.43, -0.04), shoes)
		_legs.append({"hip": hip, "knee": knee})

	# Braços (ombro -> cotovelo -> mão)
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * (sw * 0.5 + 0.045), 1.50, 0.0)
		add_child(shoulder)
		_box(shoulder, Vector3(0.12, 0.30, 0.12), Vector3(0.0, -0.14, 0.0), top)
		var elbow := Node3D.new()
		elbow.position = Vector3(0.0, -0.29, 0.0)
		shoulder.add_child(elbow)
		_box(elbow, Vector3(0.10, 0.27, 0.10), Vector3(0.0, -0.13, 0.0), top if long_sleeves else skin)
		_box(elbow, Vector3(0.09, 0.09, 0.10), Vector3(0.0, -0.30, 0.0), skin)  # mão
		_arms.append({"shoulder": shoulder, "elbow": elbow})

	if zombie:
		_make_zombie()


func _build_hair(style: int, color: Color, cap_color: Color) -> void:
	if style == 0:
		return
	var h := _mat(color)
	if style == 5:  # boné
		var cap := MeshInstance3D.new()
		cap.mesh = _mesh("sphere", Vector3.ONE)
		cap.scale = Vector3(0.25, 0.20, 0.27)
		cap.material_override = _mat(cap_color.darkened(0.2))
		cap.position = Vector3(0.0, 0.07, 0.01)
		_head.add_child(cap)
		_box(_head, Vector3(0.20, 0.025, 0.12), Vector3(0.0, 0.07, -0.17), cap_color.darkened(0.3))
		return
	var top := MeshInstance3D.new()
	top.mesh = _mesh("sphere", Vector3.ONE)
	top.scale = Vector3(0.25, 0.16 if style == 2 else 0.20, 0.27)
	top.material_override = h
	top.position = Vector3(0.0, 0.08, 0.01)
	_head.add_child(top)
	if style == 3:  # longo
		_box(_head, Vector3(0.25, 0.30, 0.08), Vector3(0.0, -0.08, 0.12), color)
	elif style == 4:  # rabo de cavalo
		_box(_head, Vector3(0.07, 0.22, 0.07), Vector3(0.0, -0.06, 0.16), color)


# Zumbi: pele pálida, olhar vidrado, sangue e braços esticados à frente.
func _make_zombie() -> void:
	var blood := Color(0.35, 0.04, 0.04)
	for i in 3:
		_box(self, Vector3(randf_range(0.06, 0.16), randf_range(0.06, 0.2), 0.01), Vector3(randf_range(-0.15, 0.15), randf_range(1.1, 1.45), -0.126), blood)
	_box(_head, Vector3(0.08, 0.05, 0.01), Vector3(0.04, -0.07, -0.122), blood)
	_head.rotation.z = randf_range(-0.2, 0.2)


# --- Animação ---

## `speed`: velocidade horizontal em m/s.
func animate(speed: float, delta: float) -> void:
	var target := clampf(speed / 3.0, 0.0, 1.5)
	_amount = lerpf(_amount, target, clampf(8.0 * delta, 0.0, 1.0))
	_phase += delta * (4.0 + speed * 1.8)
	var s := sin(_phase) * _amount
	for i in 2:
		var sg := 1.0 if i == 0 else -1.0
		var leg: Dictionary = _legs[i]
		leg["hip"].rotation.x = s * 0.75 * sg
		leg["knee"].rotation.x = -maxf(0.0, -s * sg) * 0.9 * _amount
		var arm: Dictionary = _arms[i]
		if zombie:
			arm["shoulder"].rotation.x = 1.35 + sin(_phase * 0.5 + _seed + i) * 0.08
			arm["elbow"].rotation.x = 0.15
		else:
			arm["shoulder"].rotation.x = -s * 0.6 * sg
			arm["elbow"].rotation.x = 0.15 + 0.5 * maxf(0.0, s * sg) * _amount
	if zombie:
		_head.rotation.x = 0.15


# --- Auxiliares ---

func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.9
		_mats[key] = m
	return _mats[key]


func _mesh(kind: String, size: Vector3) -> Mesh:
	var key := "sphere" if kind == "sphere" else "box%s" % size
	if not _meshes.has(key):
		if kind == "sphere":
			var sm := SphereMesh.new()
			sm.radius = 0.5
			sm.height = 1.0
			sm.radial_segments = 12
			sm.rings = 6
			# esfera unitária: quem usa ajusta o tamanho com a escala do nó
			_meshes[key] = sm
		else:
			var bm := BoxMesh.new()
			bm.size = size
			_meshes[key] = bm
	return _meshes[key]


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh("box", size)
	mi.material_override = _mat(color)
	mi.position = pos
	if zombie:
		mi.visibility_range_end = 90.0  # longe demais: nem desenha
	parent.add_child(mi)
	return mi
