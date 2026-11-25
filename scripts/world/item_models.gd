extends RefCounted
## Modelos 3D low-poly dos itens, montados por código (latas, garrafas, armas, ferramentas...).
## Cada item vira UMA malha com uma superfície por cor, guardada em cache (itens iguais compartilham).
##   ItemModels.ground_mesh(id)  -> malha do item deitado/apoiado no chão (base em y=0)
##   ItemModels.held_mesh(id)    -> malha da arma na mão: comprimento ao longo de +Y, origem na empunhadura;
##                                  nas armas de fogo o cano aponta para +Y e o "alto" da arma é +Z.
## Para trocar por modelos .glb de verdade no futuro, basta o jogo procurar res://assets/items/<id>.glb antes.

static var _cache: Dictionary = {}

# Paleta
const STEEL := Color(0.62, 0.64, 0.68)
const DARK_STEEL := Color(0.22, 0.23, 0.26)
const GUN_BLACK := Color(0.12, 0.12, 0.14)
const WOOD := Color(0.48, 0.32, 0.18)
const DARK_WOOD := Color(0.30, 0.19, 0.11)
const BRASS := Color(0.78, 0.60, 0.22)
const RED := Color(0.72, 0.14, 0.12)
const WHITE := Color(0.90, 0.90, 0.88)
const RUBBER := Color(0.10, 0.10, 0.10)


# --- Construtor de malha ---

class Builder:
	var surf: Dictionary = {}
	var xf := Transform3D.IDENTITY
	var cache: Dictionary = {}

	func _arrays(key: String, mesh: Mesh) -> Array:
		if not cache.has(key):
			cache[key] = mesh.get_mesh_arrays()
		return cache[key]

	func _push(color: Color, arrays: Array, t: Transform3D) -> void:
		var key := color.to_html(false)
		if not surf.has(key):
			surf[key] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "i": PackedInt32Array(), "c": color}
		var s: Dictionary = surf[key]
		var bv: PackedVector3Array = s["v"]
		var bn: PackedVector3Array = s["n"]
		var bi: PackedInt32Array = s["i"]
		var base := bv.size()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var full := xf * t
		for k in verts.size():
			bv.append(full * verts[k])
			bn.append((full.basis * norms[k]).normalized())
		for k in idx.size():
			bi.append(base + idx[k])
		s["v"] = bv
		s["n"] = bn
		s["i"] = bi

	static func _t(pos: Vector3, rot_deg: Vector3, scl: Vector3) -> Transform3D:
		var b := Basis.from_euler(rot_deg * (PI / 180.0))
		b = b * Basis.from_scale(scl)
		return Transform3D(b, pos)

	func box(size: Vector3, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> void:
		var m := BoxMesh.new()
		m.size = size
		_push(color, _arrays("b%s" % str(size), m), _t(pos, rot_deg, Vector3.ONE))

	func cyl(r_top: float, r_bot: float, h: float, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO, segs: int = 10) -> void:
		var m := CylinderMesh.new()
		m.top_radius = r_top
		m.bottom_radius = r_bot
		m.height = h
		m.radial_segments = segs
		m.rings = 1
		_push(color, _arrays("c%.3f_%.3f_%.3f_%d" % [r_top, r_bot, h, segs], m), _t(pos, rot_deg, Vector3.ONE))

	func sphere(r: float, pos: Vector3, color: Color, scl: Vector3 = Vector3.ONE, segs: int = 10) -> void:
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = segs
		m.rings = maxi(segs / 2, 3)
		_push(color, _arrays("s%.3f_%d" % [r, segs], m), _t(pos, Vector3.ZERO, scl))

	func torus(r_in: float, r_out: float, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> void:
		var m := TorusMesh.new()
		m.inner_radius = r_in
		m.outer_radius = r_out
		m.rings = 14
		m.ring_segments = 6
		_push(color, _arrays("t%.3f_%.3f" % [r_in, r_out], m), _t(pos, rot_deg, Vector3.ONE))

	func prism(size: Vector3, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> void:
		var m := PrismMesh.new()
		m.size = size
		_push(color, _arrays("p%s" % str(size), m), _t(pos, rot_deg, Vector3.ONE))

	static var _bm: Dictionary = {}

	static func _bmat(color: Color) -> StandardMaterial3D:
		var key := color.to_html(false)
		if _bm.has(key):
			return _bm[key]
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.75
		_bm[key] = m
		return m

	func min_y() -> float:
		var lo := 1.0e9
		for k in surf:
			for v in surf[k]["v"]:
				lo = minf(lo, v.y)
		return lo

	func finish(lift: bool) -> ArrayMesh:
		var dy := -min_y() if lift else 0.0
		var am := ArrayMesh.new()
		for k in surf:
			var s: Dictionary = surf[k]
			var verts: PackedVector3Array = s["v"]
			if dy != 0.0:
				for i in verts.size():
					verts[i] = verts[i] + Vector3(0.0, dy, 0.0)
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = s["n"]
			arr[Mesh.ARRAY_INDEX] = s["i"]
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var idx := am.get_surface_count() - 1
			am.surface_set_material(idx, _bmat(s["c"]))
		return am


# --- API ---

static func ground_mesh(id: String) -> ArrayMesh:
	var key := "g_" + id
	if _cache.has(key):
		return _cache[key]
	var b := Builder.new()
	var data := ItemDB.get_item(id)
	var weapon: bool = data.has("len")
	if weapon:
		b.xf = Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0)), Vector3.ZERO)
		_weapon(b, id)
		b.xf = Transform3D.IDENTITY
	else:
		if not _item(b, id):
			_fallback(b, id)
	var mesh := b.finish(true)
	_cache[key] = mesh
	return mesh


static func held_mesh(id: String) -> ArrayMesh:
	var key := "h_" + id
	if _cache.has(key):
		return _cache[key]
	var b := Builder.new()
	_weapon(b, id)
	var mesh := b.finish(false)
	_cache[key] = mesh
	return mesh


## Altura aproximada do item no chão (para o brilho/etiqueta).
static func _fallback(b: Builder, id: String) -> void:
	var weight: float = ItemDB.weight_of(id)
	var s := clampf(0.10 + weight * 0.06, 0.10, 0.40)
	b.box(Vector3(s * 1.3, s * 0.6, s), Vector3(0.0, s * 0.3, 0.0), ItemDB.color_of(id))


# --- Armas (comprimento ao longo de +Y) ---

static func _weapon(b: Builder, id: String) -> void:
	match id:
		"bat":
			b.cyl(0.018, 0.018, 0.22, Vector3(0, 0.11, 0), Color(0.30, 0.22, 0.14))  # cabo
			b.cyl(0.020, 0.040, 0.28, Vector3(0, 0.36, 0), WOOD)
			b.cyl(0.040, 0.042, 0.34, Vector3(0, 0.67, 0), WOOD)
			b.sphere(0.042, Vector3(0, 0.84, 0), WOOD, Vector3(1, 0.5, 1))
			b.cyl(0.024, 0.024, 0.03, Vector3(0, -0.005, 0), DARK_WOOD)  # nó do cabo
		"axe":
			b.cyl(0.018, 0.016, 0.72, Vector3(0, 0.36, 0), WOOD)
			b.box(Vector3(0.04, 0.16, 0.07), Vector3(0, 0.68, 0.0), DARK_STEEL)
			b.prism(Vector3(0.16, 0.20, 0.03), Vector3(0.0, 0.69, 0.10), STEEL, Vector3(0, 90, 90))
			b.box(Vector3(0.05, 0.08, 0.05), Vector3(0, 0.72, -0.045), DARK_STEEL)
		"machete":
			b.cyl(0.016, 0.016, 0.16, Vector3(0, 0.08, 0), RUBBER)
			b.box(Vector3(0.05, 0.015, 0.03), Vector3(0, 0.165, 0), DARK_STEEL)
			b.box(Vector3(0.01, 0.50, 0.075), Vector3(0, 0.43, 0.012), STEEL)
			b.prism(Vector3(0.075, 0.06, 0.01), Vector3(0, 0.71, 0.012), STEEL, Vector3(0, 90, 0))
		"kitchen_knife":
			b.box(Vector3(0.025, 0.11, 0.015), Vector3(0, 0.055, 0), DARK_WOOD)
			b.box(Vector3(0.006, 0.17, 0.034), Vector3(0, 0.195, 0), STEEL)
		"hunting_knife":
			b.cyl(0.015, 0.015, 0.11, Vector3(0, 0.055, 0), Color(0.25, 0.16, 0.10))
			b.box(Vector3(0.05, 0.012, 0.02), Vector3(0, 0.116, 0), BRASS)
			b.box(Vector3(0.007, 0.15, 0.03), Vector3(0, 0.20, 0), STEEL)
		"crowbar":
			b.cyl(0.013, 0.013, 0.62, Vector3(0, 0.31, 0), Color(0.12, 0.16, 0.30))
			b.cyl(0.013, 0.013, 0.16, Vector3(0, 0.66, 0.045), Color(0.12, 0.16, 0.30), Vector3(-30, 0, 0))
			b.box(Vector3(0.02, 0.06, 0.03), Vector3(0, 0.74, 0.085), Color(0.12, 0.16, 0.30))
			b.cyl(0.013, 0.013, 0.12, Vector3(0, -0.02, -0.03), Color(0.12, 0.16, 0.30), Vector3(25, 0, 0))
		"frying_pan":
			b.cyl(0.016, 0.014, 0.28, Vector3(0, 0.14, 0), RUBBER)
			b.cyl(0.14, 0.12, 0.04, Vector3(0, 0.40, 0), DARK_STEEL, Vector3(0, 0, 0), 14)
			b.cyl(0.115, 0.115, 0.01, Vector3(0, 0.425, 0), Color(0.08, 0.08, 0.09), Vector3(0, 0, 0), 14)
		"shovel":
			b.cyl(0.017, 0.017, 0.80, Vector3(0, 0.40, 0), WOOD)
			b.box(Vector3(0.09, 0.03, 0.03), Vector3(0, 0.81, 0), DARK_WOOD)
			b.prism(Vector3(0.20, 0.12, 0.012), Vector3(0, 0.04, 0.01), STEEL, Vector3(0, 0, 180))
			b.box(Vector3(0.20, 0.14, 0.012), Vector3(0, 0.15, 0.01), STEEL)
		"pipe":
			b.cyl(0.022, 0.022, 0.80, Vector3(0, 0.40, 0), Color(0.40, 0.40, 0.44), Vector3.ZERO, 8)
			b.cyl(0.028, 0.028, 0.03, Vector3(0, 0.79, 0), DARK_STEEL, Vector3.ZERO, 8)
			b.cyl(0.028, 0.028, 0.03, Vector3(0, 0.01, 0), DARK_STEEL, Vector3.ZERO, 8)
		"pitchfork":
			b.cyl(0.017, 0.017, 1.00, Vector3(0, 0.50, 0), WOOD)
			b.box(Vector3(0.20, 0.025, 0.02), Vector3(0, 1.00, 0), STEEL)
			for x in [-0.09, 0.0, 0.09]:
				b.box(Vector3(0.012, 0.22, 0.012), Vector3(x, 1.12, 0), STEEL)
		"nail_plank":
			b.box(Vector3(0.08, 0.80, 0.025), Vector3(0, 0.40, 0), Color(0.55, 0.42, 0.26))
			for i in 5:
				b.cyl(0.004, 0.004, 0.07, Vector3((float(i % 2) - 0.5) * 0.04, 0.58 + float(i) * 0.05, 0.04), Color(0.55, 0.55, 0.58), Vector3(90, 0, 0), 5)
		"golf_club":
			b.cyl(0.008, 0.011, 0.90, Vector3(0, 0.45, 0), Color(0.70, 0.70, 0.74), Vector3.ZERO, 6)
			b.cyl(0.013, 0.013, 0.25, Vector3(0, 0.12, 0), RUBBER, Vector3.ZERO, 6)
			b.box(Vector3(0.04, 0.05, 0.09), Vector3(0, 0.92, 0.04), STEEL)
		"sledgehammer":
			b.cyl(0.020, 0.018, 0.88, Vector3(0, 0.44, 0), WOOD)
			b.box(Vector3(0.20, 0.10, 0.10), Vector3(0, 0.90, 0), DARK_STEEL)
			b.box(Vector3(0.015, 0.10, 0.11), Vector3(0.10, 0.90, 0), STEEL)
			b.box(Vector3(0.015, 0.10, 0.11), Vector3(-0.10, 0.90, 0), STEEL)
		"hammer":
			b.cyl(0.015, 0.014, 0.30, Vector3(0, 0.15, 0), WOOD)
			b.box(Vector3(0.12, 0.04, 0.04), Vector3(0, 0.32, 0), DARK_STEEL)
			b.box(Vector3(0.04, 0.05, 0.045), Vector3(0.07, 0.32, 0), STEEL)
		"wrench":
			b.box(Vector3(0.03, 0.34, 0.012), Vector3(0, 0.17, 0), STEEL)
			b.cyl(0.04, 0.04, 0.012, Vector3(0, 0.36, 0), STEEL, Vector3(90, 0, 0), 8)
			b.box(Vector3(0.03, 0.05, 0.014), Vector3(0.03, 0.40, 0), DARK_STEEL)
		"pistol":
			b.box(Vector3(0.032, 0.20, 0.034), Vector3(0, 0.10, 0.045), DARK_STEEL)  # ferrolho
			b.box(Vector3(0.026, 0.19, 0.020), Vector3(0, 0.10, 0.018), GUN_BLACK)
			b.box(Vector3(0.030, 0.07, 0.085), Vector3(0, 0.00, -0.035), GUN_BLACK, Vector3(-12, 0, 0))  # empunhadura
			b.box(Vector3(0.008, 0.02, 0.03), Vector3(0, 0.07, -0.01), GUN_BLACK)  # gatilho
			b.box(Vector3(0.008, 0.012, 0.012), Vector3(0, 0.19, 0.067), STEEL)  # massa de mira
		"revolver":
			b.box(Vector3(0.034, 0.10, 0.050), Vector3(0, 0.05, 0.03), DARK_STEEL)
			b.cyl(0.032, 0.032, 0.07, Vector3(0, 0.06, 0.03), STEEL, Vector3.ZERO, 8)  # tambor
			b.cyl(0.011, 0.011, 0.20, Vector3(0, 0.20, 0.045), DARK_STEEL, Vector3.ZERO, 7)  # cano
			b.box(Vector3(0.028, 0.06, 0.09), Vector3(0, -0.01, -0.035), DARK_WOOD, Vector3(-18, 0, 0))
			b.box(Vector3(0.008, 0.012, 0.014), Vector3(0, 0.30, 0.062), STEEL)
		"shotgun":
			b.cyl(0.013, 0.013, 0.62, Vector3(0, 0.42, 0.030), DARK_STEEL, Vector3.ZERO, 8)  # cano
			b.cyl(0.011, 0.011, 0.40, Vector3(0, 0.34, 0.0), DARK_STEEL, Vector3.ZERO, 8)  # tubo do carregador
			b.box(Vector3(0.05, 0.20, 0.07), Vector3(0, 0.06, 0.015), DARK_WOOD)  # fórmula
			b.box(Vector3(0.05, 0.16, 0.05), Vector3(0, 0.34, -0.010), WOOD)  # pump
			b.box(Vector3(0.04, 0.28, 0.07), Vector3(0, -0.20, -0.012), DARK_WOOD, Vector3(-10, 0, 0))  # coronha
			b.box(Vector3(0.008, 0.012, 0.014), Vector3(0, 0.72, 0.048), BRASS)
		"hunting_rifle":
			b.cyl(0.011, 0.011, 0.62, Vector3(0, 0.42, 0.028), DARK_STEEL, Vector3.ZERO, 8)
			b.box(Vector3(0.045, 0.40, 0.065), Vector3(0, 0.12, 0.012), WOOD)
			b.box(Vector3(0.040, 0.30, 0.080), Vector3(0, -0.22, -0.010), WOOD, Vector3(-9, 0, 0))
			b.cyl(0.018, 0.018, 0.20, Vector3(0, 0.10, 0.082), GUN_BLACK, Vector3.ZERO, 8)  # luneta
			b.cyl(0.026, 0.020, 0.04, Vector3(0, 0.21, 0.082), GUN_BLACK, Vector3.ZERO, 8)
			b.box(Vector3(0.01, 0.025, 0.03), Vector3(0, 0.10, 0.052), DARK_STEEL)
		"rifle_22":
			b.cyl(0.009, 0.009, 0.58, Vector3(0, 0.38, 0.025), DARK_STEEL, Vector3.ZERO, 7)
			b.box(Vector3(0.040, 0.34, 0.055), Vector3(0, 0.08, 0.008), Color(0.58, 0.40, 0.22))
			b.box(Vector3(0.036, 0.26, 0.070), Vector3(0, -0.20, -0.008), Color(0.58, 0.40, 0.22), Vector3(-8, 0, 0))
			b.box(Vector3(0.008, 0.012, 0.016), Vector3(0, 0.66, 0.042), STEEL)
		_:
			var data := ItemDB.get_item(id)
			var length := float(data.get("len", 0.6))
			b.box(Vector3(0.05, length, 0.05), Vector3(0, length * 0.5, 0), ItemDB.color_of(id))


# --- Itens comuns (em pé / deitados no chão, base perto de y=0; o Builder ajusta o apoio) ---

static func _item(b: Builder, id: String) -> bool:
	match id:
		# Enlatados
		"canned_beans": _can(b, Color(0.55, 0.28, 0.12), Color(0.85, 0.75, 0.40))
		"canned_corn": _can(b, Color(0.90, 0.75, 0.15), Color(0.35, 0.55, 0.20))
		"canned_soup": _can(b, Color(0.75, 0.18, 0.15), WHITE)
		"canned_tuna": _can(b, Color(0.25, 0.45, 0.75), WHITE, 0.034, 0.05)
		"canned_meat": _can(b, Color(0.62, 0.22, 0.20), Color(0.85, 0.80, 0.70), 0.040, 0.075)
		"canned_peaches": _can(b, Color(0.95, 0.62, 0.20), Color(0.80, 0.30, 0.15))
		"can_empty": _can(b, Color(0.65, 0.66, 0.70), Color(0.65, 0.66, 0.70))
		# Comida embalada
		"cereal_bar": _pack(b, Vector3(0.12, 0.02, 0.04), Color(0.80, 0.55, 0.20), Color(0.40, 0.25, 0.10))
		"crackers": _pack(b, Vector3(0.10, 0.04, 0.16), Color(0.85, 0.30, 0.15), Color(0.95, 0.85, 0.45))
		"cereal": _pack(b, Vector3(0.20, 0.30, 0.07), Color(0.20, 0.50, 0.80), Color(0.95, 0.80, 0.20), true)
		"pasta": _pack(b, Vector3(0.09, 0.22, 0.04), Color(0.90, 0.80, 0.30), Color(0.75, 0.15, 0.15), true)
		"chocolate": _pack(b, Vector3(0.14, 0.015, 0.07), Color(0.35, 0.18, 0.10), Color(0.80, 0.20, 0.25))
		"jerky": _pack(b, Vector3(0.12, 0.03, 0.18), Color(0.45, 0.22, 0.12), Color(0.85, 0.65, 0.30))
		"bread":
			b.box(Vector3(0.24, 0.10, 0.12), Vector3(0, 0.05, 0), Color(0.75, 0.55, 0.30))
			b.sphere(0.07, Vector3(0, 0.10, 0), Color(0.78, 0.58, 0.32), Vector3(1.7, 0.6, 0.85))
			b.box(Vector3(0.05, 0.11, 0.125), Vector3(0.10, 0.055, 0), Color(0.85, 0.30, 0.20))  # fecho do saco
		"peanut_butter":
			b.cyl(0.045, 0.045, 0.10, Vector3(0, 0.05, 0), Color(0.80, 0.55, 0.25))
			b.cyl(0.048, 0.048, 0.03, Vector3(0, 0.115, 0), Color(0.75, 0.15, 0.12))
			b.cyl(0.0465, 0.0465, 0.05, Vector3(0, 0.05, 0), Color(0.90, 0.80, 0.55))
		"donut":
			b.torus(0.018, 0.05, Vector3(0, 0.02, 0), Color(0.80, 0.55, 0.30))
			b.torus(0.019, 0.050, Vector3(0, 0.03, 0), Color(0.92, 0.45, 0.62), Vector3.ZERO)
		"egg", "boiled_egg":
			b.sphere(0.03, Vector3(0, 0.04, 0), Color(0.93, 0.88, 0.76) if id == "egg" else Color(0.96, 0.95, 0.90), Vector3(0.85, 1.2, 0.85))
		"apple":
			b.sphere(0.045, Vector3(0, 0.045, 0), Color(0.75, 0.12, 0.10), Vector3(1, 0.92, 1))
			b.cyl(0.004, 0.004, 0.03, Vector3(0, 0.095, 0), Color(0.30, 0.20, 0.10), Vector3.ZERO, 4)
			b.box(Vector3(0.03, 0.006, 0.016), Vector3(0.018, 0.09, 0), Color(0.25, 0.55, 0.20), Vector3(0, 0, 20))
		"carrot":
			b.cyl(0.026, 0.004, 0.18, Vector3(0, 0.03, 0), Color(0.92, 0.50, 0.12), Vector3(0, 0, 90))
			b.box(Vector3(0.05, 0.012, 0.02), Vector3(0.11, 0.03, 0), Color(0.22, 0.55, 0.20))
		"potato", "cooked_potato":
			b.sphere(0.05, Vector3(0, 0.04, 0), Color(0.62, 0.48, 0.30) if id == "potato" else Color(0.85, 0.72, 0.42), Vector3(1.3, 0.8, 1.0))
		"tomato":
			b.sphere(0.045, Vector3(0, 0.04, 0), Color(0.82, 0.14, 0.10), Vector3(1.0, 0.85, 1.0))
			b.box(Vector3(0.04, 0.008, 0.012), Vector3(0, 0.082, 0), Color(0.25, 0.55, 0.18))
		"corn_cob", "cooked_corn":
			b.cyl(0.024, 0.02, 0.18, Vector3(0, 0.03, 0), Color(0.95, 0.78, 0.18), Vector3(0, 0, 90), 8)
			if id == "corn_cob":
				b.cyl(0.03, 0.01, 0.10, Vector3(-0.08, 0.035, 0), Color(0.45, 0.60, 0.25), Vector3(0, 0, 90), 6)
		"cooked_pasta":
			b.cyl(0.07, 0.06, 0.04, Vector3(0, 0.02, 0), WHITE, Vector3.ZERO, 12)
			b.sphere(0.05, Vector3(0, 0.05, 0), Color(0.92, 0.82, 0.45), Vector3(1.2, 0.5, 1.2))
		# Bebidas
		"water_bottle": _bottle(b, Color(0.70, 0.85, 0.95), Color(0.2, 0.45, 0.85), 0.032, 0.20)
		"dirty_water": _bottle(b, Color(0.50, 0.42, 0.25), Color(0.25, 0.25, 0.28), 0.032, 0.20)
		"bottle_empty": _bottle(b, Color(0.82, 0.90, 0.92), Color(0.2, 0.45, 0.85), 0.032, 0.20)
		"soda":
			_can(b, Color(0.78, 0.12, 0.12), Color(0.95, 0.95, 0.95), 0.032, 0.12)
		"juice": _pack(b, Vector3(0.06, 0.12, 0.04), Color(0.95, 0.60, 0.15), Color(0.30, 0.65, 0.25), true)
		"milk": _pack(b, Vector3(0.07, 0.17, 0.07), WHITE, Color(0.25, 0.45, 0.80), true)
		"sweet_tea": _bottle(b, Color(0.55, 0.30, 0.10), Color(0.90, 0.75, 0.20), 0.036, 0.22)
		"bourbon": _bottle(b, Color(0.50, 0.28, 0.08), Color(0.20, 0.12, 0.06), 0.036, 0.24, Color(0.95, 0.88, 0.70))
		# Medicina
		"bandage":
			b.cyl(0.04, 0.04, 0.05, Vector3(0, 0.025, 0), WHITE, Vector3.ZERO, 12)
			b.cyl(0.042, 0.042, 0.012, Vector3(0, 0.025, 0), Color(0.82, 0.78, 0.68), Vector3.ZERO, 12)
		"adhesive":
			b.box(Vector3(0.08, 0.008, 0.035), Vector3(0, 0.004, 0), Color(0.90, 0.75, 0.60))
			b.box(Vector3(0.03, 0.010, 0.03), Vector3(0, 0.006, 0), WHITE)
		"vitamins": _pill_bottle(b, Color(0.95, 0.60, 0.15), Color(0.95, 0.95, 0.90))
		"painkillers": _pill_bottle(b, Color(0.85, 0.35, 0.12), WHITE)
		"antibiotics": _pill_bottle(b, Color(0.22, 0.55, 0.65), WHITE)
		"antiseptic":
			b.cyl(0.032, 0.032, 0.12, Vector3(0, 0.06, 0), Color(0.55, 0.30, 0.12), Vector3.ZERO, 10)
			b.cyl(0.015, 0.02, 0.03, Vector3(0, 0.135, 0), Color(0.55, 0.30, 0.12), Vector3.ZERO, 8)
			b.cyl(0.018, 0.018, 0.025, Vector3(0, 0.16, 0), WHITE, Vector3.ZERO, 8)
			b.cyl(0.0335, 0.0335, 0.05, Vector3(0, 0.06, 0), WHITE, Vector3.ZERO, 10)
		"first_aid_kit":
			b.box(Vector3(0.22, 0.14, 0.09), Vector3(0, 0.07, 0), Color(0.88, 0.88, 0.86))
			b.box(Vector3(0.07, 0.07, 0.095), Vector3(0, 0.07, 0), RED)
			b.box(Vector3(0.15, 0.025, 0.095), Vector3(0, 0.07, 0), RED)
			b.box(Vector3(0.10, 0.02, 0.03), Vector3(0, 0.15, 0), Color(0.55, 0.55, 0.58))  # alça
		"splint":
			b.box(Vector3(0.40, 0.014, 0.05), Vector3(0, 0.007, 0), Color(0.60, 0.45, 0.28))
			b.box(Vector3(0.40, 0.014, 0.05), Vector3(0, 0.021, 0.03), Color(0.65, 0.50, 0.32))
			b.box(Vector3(0.05, 0.05, 0.09), Vector3(0.05, 0.02, 0.012), Color(0.85, 0.82, 0.74))
		"suture_kit":
			b.box(Vector3(0.14, 0.04, 0.09), Vector3(0, 0.02, 0), Color(0.25, 0.40, 0.60))
			b.box(Vector3(0.04, 0.045, 0.09), Vector3(0, 0.02, 0), Color(0.80, 0.80, 0.82))
			b.cyl(0.004, 0.004, 0.10, Vector3(0, 0.05, 0), STEEL, Vector3(90, 0, 0), 4)
		# Ferramentas e utilidades
		"flashlight":
			b.cyl(0.020, 0.020, 0.14, Vector3(0, 0.03, 0), Color(0.15, 0.15, 0.18), Vector3(0, 0, 90), 10)
			b.cyl(0.034, 0.022, 0.05, Vector3(0.10, 0.03, 0), Color(0.78, 0.60, 0.15), Vector3(0, 0, 90), 10)
			b.cyl(0.028, 0.028, 0.006, Vector3(0.127, 0.03, 0), Color(1.0, 0.95, 0.70), Vector3(0, 0, 90), 10)
			b.box(Vector3(0.02, 0.012, 0.016), Vector3(-0.01, 0.055, 0), RED)
		"battery":
			b.cyl(0.016, 0.016, 0.05, Vector3(0, 0.016, 0), Color(0.15, 0.15, 0.17), Vector3(0, 0, 90), 8)
			b.cyl(0.0165, 0.0165, 0.018, Vector3(0.015, 0.016, 0), BRASS, Vector3(0, 0, 90), 8)
			b.cyl(0.006, 0.006, 0.01, Vector3(-0.03, 0.016, 0), STEEL, Vector3(0, 0, 90), 6)
		"lighter":
			b.box(Vector3(0.03, 0.07, 0.012), Vector3(0, 0.035, 0), Color(0.80, 0.15, 0.15))
			b.box(Vector3(0.032, 0.015, 0.014), Vector3(0, 0.075, 0), STEEL)
		"matches":
			b.box(Vector3(0.05, 0.02, 0.035), Vector3(0, 0.01, 0), Color(0.75, 0.55, 0.15))
			b.box(Vector3(0.052, 0.008, 0.025), Vector3(0, 0.02, 0), Color(0.15, 0.15, 0.18))
		"rope":
			for i in 3:
				b.torus(0.012, 0.075 - float(i) * 0.008, Vector3(0, 0.014 + float(i) * 0.022, 0), Color(0.72, 0.60, 0.38))
		"duct_tape":
			b.torus(0.022, 0.05, Vector3(0, 0.025, 0), Color(0.55, 0.57, 0.60))
			b.torus(0.012, 0.035, Vector3(0, 0.025, 0), Color(0.30, 0.30, 0.32))
		"wire":
			b.torus(0.008, 0.06, Vector3(0, 0.012, 0), Color(0.55, 0.55, 0.60))
			b.torus(0.008, 0.05, Vector3(0, 0.028, 0), Color(0.60, 0.60, 0.65))
		"nails":
			b.box(Vector3(0.10, 0.05, 0.07), Vector3(0, 0.025, 0), Color(0.75, 0.65, 0.35))
			b.box(Vector3(0.102, 0.012, 0.072), Vector3(0, 0.03, 0), RED)
		"plank":
			b.box(Vector3(0.9, 0.025, 0.12), Vector3(0, 0.0125, 0), Color(0.62, 0.46, 0.28))
			b.box(Vector3(0.88, 0.005, 0.01), Vector3(0, 0.026, 0.02), Color(0.50, 0.36, 0.20))
		"saw":
			b.box(Vector3(0.45, 0.004, 0.07), Vector3(0, 0.002, 0), STEEL)
			b.box(Vector3(0.12, 0.03, 0.05), Vector3(-0.29, 0.015, 0), Color(0.80, 0.30, 0.10))
		"screwdriver":
			b.cyl(0.016, 0.014, 0.10, Vector3(-0.04, 0.016, 0), Color(0.88, 0.45, 0.10), Vector3(0, 0, 90), 8)
			b.cyl(0.004, 0.004, 0.12, Vector3(0.09, 0.016, 0), STEEL, Vector3(0, 0, 90), 5)
		"map":
			b.box(Vector3(0.22, 0.012, 0.16), Vector3(0, 0.006, 0), Color(0.85, 0.80, 0.62))
			b.box(Vector3(0.11, 0.003, 0.16), Vector3(0.055, 0.0135, 0), Color(0.80, 0.74, 0.55))
			b.box(Vector3(0.10, 0.003, 0.02), Vector3(-0.04, 0.0135, 0.03), Color(0.35, 0.55, 0.35))
		"radio":
			b.box(Vector3(0.18, 0.11, 0.06), Vector3(0, 0.055, 0), Color(0.25, 0.35, 0.28))
			b.cyl(0.032, 0.032, 0.005, Vector3(-0.04, 0.055, 0.032), Color(0.12, 0.12, 0.12), Vector3(90, 0, 0), 10)
			b.cyl(0.012, 0.012, 0.02, Vector3(0.05, 0.075, 0.03), Color(0.85, 0.80, 0.60), Vector3(90, 0, 0), 8)
			b.cyl(0.004, 0.004, 0.20, Vector3(0.07, 0.19, -0.02), STEEL, Vector3.ZERO, 4)
		"pot":
			b.cyl(0.09, 0.08, 0.10, Vector3(0, 0.05, 0), Color(0.45, 0.46, 0.50), Vector3.ZERO, 12)
			b.cyl(0.08, 0.08, 0.006, Vector3(0, 0.098, 0), Color(0.10, 0.10, 0.11), Vector3.ZERO, 12)
			b.box(Vector3(0.12, 0.015, 0.03), Vector3(0.15, 0.08, 0), Color(0.12, 0.12, 0.13))
		"gas_can":
			b.box(Vector3(0.20, 0.26, 0.10), Vector3(0, 0.13, 0), Color(0.75, 0.15, 0.10))
			b.cyl(0.02, 0.02, 0.07, Vector3(0.06, 0.295, 0), Color(0.15, 0.15, 0.16), Vector3(0, 0, -30), 8)
			b.box(Vector3(0.08, 0.02, 0.025), Vector3(-0.03, 0.27, 0), Color(0.55, 0.10, 0.08))  # alça
			b.box(Vector3(0.10, 0.08, 0.102), Vector3(0, 0.13, 0), Color(0.95, 0.85, 0.20))  # faixa
		"compass":
			b.cyl(0.04, 0.04, 0.016, Vector3(0, 0.008, 0), BRASS, Vector3.ZERO, 14)
			b.cyl(0.033, 0.033, 0.004, Vector3(0, 0.017, 0), Color(0.90, 0.90, 0.85), Vector3.ZERO, 14)
			b.box(Vector3(0.004, 0.003, 0.05), Vector3(0, 0.02, 0), RED, Vector3(0, 35, 0))
		"fishing_rod":
			b.cyl(0.006, 0.010, 0.95, Vector3(0, 0.02, 0), Color(0.15, 0.15, 0.18), Vector3(0, 0, 90), 6)
			b.cyl(0.02, 0.02, 0.03, Vector3(-0.25, 0.05, 0), Color(0.55, 0.55, 0.60), Vector3(90, 0, 0), 8)
			b.cyl(0.016, 0.016, 0.1, Vector3(-0.38, 0.02, 0), Color(0.60, 0.15, 0.12), Vector3(0, 0, 90), 6)
		"sleeping_bag":
			b.cyl(0.08, 0.08, 0.30, Vector3(0, 0.08, 0), Color(0.18, 0.35, 0.22), Vector3(90, 0, 0), 12)
			b.cyl(0.082, 0.082, 0.03, Vector3(0, 0.08, 0.08), Color(0.12, 0.12, 0.14), Vector3(90, 0, 0), 12)
			b.cyl(0.082, 0.082, 0.03, Vector3(0, 0.08, -0.08), Color(0.12, 0.12, 0.14), Vector3(90, 0, 0), 12)
		"circuit":
			b.box(Vector3(0.10, 0.006, 0.07), Vector3(0, 0.003, 0), Color(0.10, 0.45, 0.22))
			b.box(Vector3(0.03, 0.01, 0.03), Vector3(-0.01, 0.01, 0.0), Color(0.08, 0.08, 0.10))
			b.box(Vector3(0.012, 0.008, 0.02), Vector3(0.03, 0.009, -0.015), BRASS)
			b.box(Vector3(0.02, 0.008, 0.008), Vector3(0.02, 0.009, 0.02), Color(0.7, 0.7, 0.75))
		"scrap":
			b.box(Vector3(0.10, 0.012, 0.07), Vector3(0, 0.006, 0), Color(0.45, 0.46, 0.50), Vector3(0, 20, 0))
			b.box(Vector3(0.07, 0.012, 0.09), Vector3(0.02, 0.016, 0.01), Color(0.55, 0.40, 0.30), Vector3(0, -30, 4))
			b.box(Vector3(0.05, 0.01, 0.05), Vector3(-0.03, 0.025, 0.02), Color(0.60, 0.60, 0.64), Vector3(0, 50, -6))
		# Roupas e tecidos
		"rag": _cloth(b, Vector3(0.12, 0.03, 0.10), Color(0.72, 0.68, 0.58))
		"bedsheet": _cloth(b, Vector3(0.22, 0.05, 0.18), Color(0.85, 0.84, 0.80))
		"blanket": _cloth(b, Vector3(0.26, 0.07, 0.20), Color(0.55, 0.25, 0.22))
		"tshirt": _cloth(b, Vector3(0.20, 0.04, 0.18), Color(0.45, 0.55, 0.65))
		"curtain": _cloth(b, Vector3(0.20, 0.05, 0.16), Color(0.62, 0.50, 0.30))
		"jeans": _cloth(b, Vector3(0.22, 0.06, 0.15), Color(0.25, 0.35, 0.55))
		_:
			# Munição: caixinha com projéteis
			if id.begins_with("ammo_"):
				_ammo(b, id)
				return true
			return false
	return true


static func _can(b: Builder, body: Color, label: Color, r: float = 0.038, h: float = 0.11) -> void:
	b.cyl(r, r, h, Vector3(0, h * 0.5, 0), body, Vector3.ZERO, 12)
	b.cyl(r * 1.04, r * 1.04, h * 0.04, Vector3(0, h * 0.02, 0), Color(0.70, 0.71, 0.75), Vector3.ZERO, 12)
	b.cyl(r * 1.04, r * 1.04, h * 0.04, Vector3(0, h * 0.98, 0), Color(0.70, 0.71, 0.75), Vector3.ZERO, 12)
	b.cyl(r * 1.01, r * 1.01, h * 0.48, Vector3(0, h * 0.5, 0), label, Vector3.ZERO, 12)
	b.cyl(r * 0.5, r * 0.5, 0.004, Vector3(0, h + 0.002, 0), Color(0.80, 0.81, 0.85), Vector3.ZERO, 8)


static func _bottle(b: Builder, body: Color, cap: Color, r: float, h: float, label: Color = Color(0, 0, 0, 0)) -> void:
	b.cyl(r, r, h * 0.62, Vector3(0, h * 0.31, 0), body, Vector3.ZERO, 12)
	b.cyl(r * 0.40, r, h * 0.16, Vector3(0, h * 0.70, 0), body, Vector3.ZERO, 12)
	b.cyl(r * 0.40, r * 0.40, h * 0.14, Vector3(0, h * 0.85, 0), body, Vector3.ZERO, 8)
	b.cyl(r * 0.46, r * 0.46, h * 0.08, Vector3(0, h * 0.96, 0), cap, Vector3.ZERO, 8)
	var l := label if label.a > 0.0 else Color(cap.r, cap.g, cap.b)
	b.cyl(r * 1.02, r * 1.02, h * 0.22, Vector3(0, h * 0.30, 0), l, Vector3.ZERO, 12)


static func _pill_bottle(b: Builder, body: Color, label: Color) -> void:
	b.cyl(0.027, 0.027, 0.08, Vector3(0, 0.04, 0), body, Vector3.ZERO, 10)
	b.cyl(0.030, 0.030, 0.022, Vector3(0, 0.091, 0), label, Vector3.ZERO, 10)
	b.cyl(0.0275, 0.0275, 0.035, Vector3(0, 0.04, 0), label, Vector3.ZERO, 10)


static func _pack(b: Builder, size: Vector3, body: Color, accent: Color, upright: bool = false) -> void:
	b.box(size, Vector3(0, size.y * 0.5, 0), body)
	if upright:
		b.box(Vector3(size.x * 0.8, size.y * 0.38, size.z + 0.004), Vector3(0, size.y * 0.5, 0), accent)
		b.box(Vector3(size.x * 0.4, size.y * 0.1, size.z + 0.008), Vector3(0, size.y * 0.85, 0), body.darkened(0.2))
	else:
		b.box(Vector3(size.x * 0.7, size.y + 0.004, size.z * 0.5), Vector3(0, size.y * 0.5, 0), accent)


static func _cloth(b: Builder, size: Vector3, color: Color) -> void:
	b.box(size, Vector3(0, size.y * 0.5, 0), color)
	b.box(Vector3(size.x * 0.96, size.y * 0.12, size.z * 0.96), Vector3(0, size.y * 0.35, 0), color.darkened(0.18))
	b.box(Vector3(size.x * 0.96, size.y * 0.12, size.z * 0.96), Vector3(0, size.y * 0.68, 0), color.lightened(0.08))


static func _ammo(b: Builder, id: String) -> void:
	var tint := Color(0.35, 0.40, 0.25)
	if id == "ammo_12ga":
		tint = Color(0.65, 0.18, 0.15)
	elif id == "ammo_3006":
		tint = Color(0.25, 0.35, 0.22)
	elif id == "ammo_22":
		tint = Color(0.75, 0.70, 0.55)
	b.box(Vector3(0.10, 0.05, 0.06), Vector3(0, 0.025, 0), tint)
	b.box(Vector3(0.102, 0.012, 0.062), Vector3(0, 0.03, 0), Color(0.90, 0.80, 0.30))
	var big := id == "ammo_12ga"
	for i in 3:
		var x := -0.025 + float(i) * 0.025
		if big:
			b.cyl(0.011, 0.011, 0.06, Vector3(x, 0.055, 0.0), Color(0.75, 0.15, 0.12), Vector3.ZERO, 6)
			b.cyl(0.0115, 0.0115, 0.014, Vector3(x, 0.03, 0.0), BRASS, Vector3.ZERO, 6)
		else:
			b.cyl(0.006, 0.006, 0.03, Vector3(x, 0.065, 0.0), BRASS, Vector3.ZERO, 6)
			b.cyl(0.002, 0.006, 0.014, Vector3(x, 0.087, 0.0), Color(0.60, 0.42, 0.20), Vector3.ZERO, 6)
