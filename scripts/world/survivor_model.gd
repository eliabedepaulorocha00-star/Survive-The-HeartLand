extends "res://scripts/world/humanoid.gd"
## Sobrevivente com modelo 3D de verdade (assets/models/apocalypse_survivor.glb).
## O .glb veio sem esqueleto: montamos um Skeleton3D por código e os pesos de skinning vêm de
## survivor_skin_data.gd (gerado por tools/make_skin.py). As animações são as mesmas do humanoid.gd:
## os nós de junta (ombro, cotovelo, quadril, joelho) continuam existindo, invisíveis, e a cada quadro
## copiamos a rotação deles para os ossos.

const SkinData = preload("res://scripts/world/survivor_skin_data.gd")
const MODEL_PATH := "res://assets/models/apocalypse_survivor.glb"
const HEIGHT := 1.75
const Q := 2048.0

# Ossos: [nome, pai, posição global em T-pose]. Os índices precisam bater com tools/make_skin.py.
const BONES := [
	["hips", -1, Vector3(0.0, 0.92, 0.0)],
	["chest", 0, Vector3(0.0, 1.05, 0.0)],
	["neck", 1, Vector3(0.0, 1.52, 0.0)],
	["head", 2, Vector3(0.0, 1.62, 0.0)],
	["arm_r", 1, Vector3(0.245, 1.36, 0.0)],
	["forearm_r", 4, Vector3(0.525, 1.36, 0.0)],
	["hand_r", 5, Vector3(0.75, 1.36, 0.0)],
	["arm_l", 1, Vector3(-0.245, 1.36, 0.0)],
	["forearm_l", 7, Vector3(-0.525, 1.36, 0.0)],
	["hand_l", 8, Vector3(-0.75, 1.36, 0.0)],
	["thigh_r", 0, Vector3(0.105, 0.90, 0.0)],
	["shin_r", 10, Vector3(0.105, 0.47, 0.0)],
	["foot_r", 11, Vector3(0.105, 0.10, 0.0)],
	["thigh_l", 0, Vector3(-0.105, 0.90, 0.0)],
	["shin_l", 13, Vector3(-0.105, 0.47, 0.0)],
	["foot_l", 14, Vector3(-0.105, 0.10, 0.0)],
]

static var _skin_mesh: ArrayMesh
static var _skin_weights: Dictionary = {}

var _skeleton: Skeleton3D
var _skinned: MeshInstance3D


func build(_a: Dictionary, backpack: bool = false) -> void:
	_seed = randf() * TAU
	_build_joints()
	_build_skinned_mesh()
	if backpack:
		_add_backpack()
	_sync_bones()


## Nós de junta invisíveis (mesma convenção do humanoid.gd: pose em pé, braços pendurados).
func _build_joints() -> void:
	_head = Node3D.new()
	_head.position = Vector3(0.0, 1.62, 0.0)
	add_child(_head)
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.105, 0.90, 0.0)
		add_child(hip)
		var knee := Node3D.new()
		knee.position = Vector3(0.0, -0.43, 0.0)
		hip.add_child(knee)
		_legs.append({"hip": hip, "knee": knee})
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * 0.245, 1.36, 0.0)
		add_child(shoulder)
		var elbow := Node3D.new()
		elbow.position = Vector3(0.0, -0.28, 0.0)
		shoulder.add_child(elbow)
		_arms.append({"shoulder": shoulder, "elbow": elbow})
		if side > 0.0:
			hand = elbow


func _build_skinned_mesh() -> void:
	_skeleton = Skeleton3D.new()
	add_child(_skeleton)
	for b in BONES:
		_skeleton.add_bone(b[0])
	for i in BONES.size():
		var parent: int = BONES[i][1]
		_skeleton.set_bone_parent(i, parent)
		var pos: Vector3 = BONES[i][2]
		if parent >= 0:
			pos -= BONES[parent][2]
		_skeleton.set_bone_rest(i, Transform3D(Basis(), pos))
	_skeleton.reset_bone_poses()

	_skinned = MeshInstance3D.new()
	_skinned.mesh = _get_mesh()
	_skeleton.add_child(_skinned)
	_skinned.skeleton = NodePath("..")
	_skinned.skin = _skeleton.create_skin_from_rest_transforms()
	_skinned.extra_cull_margin = 1.5
	_skinned.visibility_range_end = 150.0


## Malha do .glb convertida para o espaço do jogo e com ossos/pesos. Montada uma vez só.
static func _get_mesh() -> ArrayMesh:
	if _skin_mesh != null:
		return _skin_mesh
	_load_skin_weights()
	var scene: PackedScene = load(MODEL_PATH)
	var root := scene.instantiate()
	var src: MeshInstance3D = _find_mesh(root)
	var arrays: Array = src.mesh.surface_get_arrays(0)
	var material: Material = src.mesh.surface_get_material(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var n := verts.size()
	var bones := PackedInt32Array()
	var wts := PackedFloat32Array()
	bones.resize(n * 4)
	wts.resize(n * 4)
	var rot := Basis(Vector3.UP, PI * 0.5)
	var missing := 0
	var new_verts := PackedVector3Array()
	var new_norms := PackedVector3Array()
	new_verts.resize(n)
	new_norms.resize(n)
	for i in n:
		var v: Vector3 = verts[i]
		var key := Vector3i(roundi(v.x * Q), roundi(v.y * Q), roundi(v.z * Q))
		if _skin_weights.has(key):
			var e: Array = _skin_weights[key]
			for k in 4:
				bones[i * 4 + k] = e[k]
				wts[i * 4 + k] = float(e[4 + k]) / 255.0
		else:
			missing += 1
			bones[i * 4] = 0
			wts[i * 4] = 1.0
		new_verts[i] = rot * (v * HEIGHT) + Vector3(0.0, HEIGHT * 0.5, 0.0)
		new_norms[i] = rot * norms[i]
	if missing > 0:
		push_warning("survivor_model: %d vértices sem peso" % missing)
	arrays[Mesh.ARRAY_VERTEX] = new_verts
	arrays[Mesh.ARRAY_NORMAL] = new_norms
	arrays[Mesh.ARRAY_TANGENT] = null
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = wts
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material != null:
		am.surface_set_material(0, material)
	root.free()
	_skin_mesh = am
	return _skin_mesh


static func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for c in node.get_children():
		var r := _find_mesh(c)
		if r != null:
			return r
	return null


static func _load_skin_weights() -> void:
	if not _skin_weights.is_empty():
		return
	var raw := Marshalls.base64_to_raw(SkinData.DATA)
	var count := raw.decode_u32(0)
	var off := 4
	for i in count:
		var key := Vector3i(raw.decode_s16(off), raw.decode_s16(off + 2), raw.decode_s16(off + 4))
		var e: Array = []
		for k in 8:
			e.append(raw[off + 6 + k])
		_skin_weights[key] = e
		off += 14


## Mochila nas costas, presa ao osso do peito.
func _add_backpack() -> void:
	var att := BoneAttachment3D.new()
	att.bone_name = "chest"
	_skeleton.add_child(att)
	for spec in [[Vector3(0.36, 0.46, 0.18), Vector3(0.0, 0.14, 0.23), Color(0.28, 0.32, 0.20)], [Vector3(0.28, 0.16, 0.06), Vector3(0.0, 0.10, 0.33), Color(0.22, 0.26, 0.16)]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = spec[0]
		mi.mesh = bm
		mi.position = spec[1]
		var m := StandardMaterial3D.new()
		m.albedo_color = spec[2]
		m.roughness = 0.9
		mi.material_override = m
		att.add_child(mi)


## Anima como o humanoid.gd e depois copia as juntas para os ossos.
func animate(speed: float, delta: float) -> void:
	super.animate(speed, delta)
	_sync_bones()


func _sync_bones() -> void:
	var down_r := Quaternion(Vector3.BACK, -PI * 0.5)  # braço direito: do T para pendurado
	var down_l := Quaternion(Vector3.BACK, PI * 0.5)
	# _arms[0] = lado -X (esquerdo do boneco), _arms[1] = lado +X
	_set_arm(_arms[1], 4, down_r)
	_set_arm(_arms[0], 7, down_l)
	_skeleton.set_bone_pose_rotation(10, Quaternion(_legs[1]["hip"].basis))
	_skeleton.set_bone_pose_rotation(11, Quaternion(_legs[1]["knee"].basis))
	_skeleton.set_bone_pose_rotation(13, Quaternion(_legs[0]["hip"].basis))
	_skeleton.set_bone_pose_rotation(14, Quaternion(_legs[0]["knee"].basis))
	_skeleton.set_bone_pose_rotation(3, Quaternion(_head.basis))


func _set_arm(arm: Dictionary, bone: int, down: Quaternion) -> void:
	var sh := Quaternion(arm["shoulder"].basis)
	var el := Quaternion(arm["elbow"].basis)
	_skeleton.set_bone_pose_rotation(bone, sh * down)
	_skeleton.set_bone_pose_rotation(bone + 1, down.inverse() * el * down)
