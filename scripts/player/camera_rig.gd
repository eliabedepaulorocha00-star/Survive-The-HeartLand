extends Node3D
## Câmera híbrida: terceira pessoa (sobre o ombro) <-> primeira pessoa,
## com troca suave (lerp de distância e FOV), colisão com paredes (SpringArm3D)
## e tremor procedural (shake).

const TPS_LENGTH := 3.2
const TPS_SHOULDER := 0.55
const TPS_FOV := 68.0
const FPS_FOV := 78.0
const MIN_PITCH := -75.0
const MAX_PITCH := 70.0

var yaw: float = 0.0  # radianos
var pitch: float = -0.15  # radianos
var target_height: float = 1.55
var blend: float = 0.0  # 0 = terceira pessoa, 1 = primeira pessoa
var target_blend: float = 0.0
var camera: Camera3D

var _arm: SpringArm3D
var _trauma: float = 0.0


func _ready() -> void:
	position = Vector3(0.0, target_height, 0.0)

	_arm = SpringArm3D.new()
	_arm.collision_mask = 1  # só enxerga o cenário (paredes, árvores, carros)
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	_arm.shape = sphere
	_arm.margin = 0.1
	_arm.spring_length = TPS_LENGTH
	_arm.position.x = TPS_SHOULDER
	add_child(_arm)

	camera = Camera3D.new()
	camera.fov = TPS_FOV
	camera.current = true
	_arm.add_child(camera)

	GameSettings.changed.connect(_apply_settings)
	_apply_settings()
	_apply_rotation()


## Distância de renderização vem das configurações.
func _apply_settings() -> void:
	camera.far = GameSettings.distance_m()


func _process(delta: float) -> void:
	blend = lerpf(blend, target_blend, clampf(7.0 * delta, 0.0, 1.0))
	if absf(blend - target_blend) < 0.002:
		blend = target_blend
	_arm.spring_length = maxf(0.02, lerpf(TPS_LENGTH, 0.0, blend))
	_arm.position.x = lerpf(TPS_SHOULDER, 0.0, blend)
	camera.fov = lerpf(TPS_FOV, FPS_FOV, blend)
	position.y = lerpf(position.y, target_height, clampf(8.0 * delta, 0.0, 1.0))

	# Tremor: cresce com o quadrado do "trauma" e decai sozinho.
	var t := _trauma * _trauma
	camera.h_offset = randf_range(-1.0, 1.0) * t * 0.4
	camera.v_offset = randf_range(-1.0, 1.0) * t * 0.4
	camera.rotation.z = randf_range(-1.0, 1.0) * t * 0.06
	_trauma = maxf(0.0, _trauma - delta * 1.6)


## Gira a câmera com o arrasto do dedo (rel em pixels).
func apply_look(rel: Vector2) -> void:
	var boost := 1.0 + GameSettings.look_accel * clampf(rel.length() / 30.0, 0.0, 1.0)
	var k := deg_to_rad(GameSettings.look_sensitivity) * boost
	var invert := -1.0 if GameSettings.invert_y else 1.0
	yaw -= rel.x * k
	pitch = clampf(pitch - rel.y * k * invert, deg_to_rad(MIN_PITCH), deg_to_rad(MAX_PITCH))
	_apply_rotation()


func toggle_view() -> void:
	target_blend = 0.0 if target_blend > 0.5 else 1.0


func is_first_person() -> bool:
	return target_blend > 0.5


## Tremor de câmera (tiros, explosões, sustos). amount de 0 a 1.
func shake(amount: float = 0.3) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _apply_rotation() -> void:
	rotation = Vector3(pitch, yaw, 0.0)
