extends Node3D

# Negative spins it backwards
@export var wheel_speed_degrees_per_second: float = -6.0

@export var gondola_orbit_radius: float = 7.2
@export var gondola_hang_offset: float = 2.6
@export_range(1, 8, 1) var gondola_count := 6

@export var hanger_half_width: float = 0.8
@export var hanger_bar_radius: float = 0.035

# These numbers are tied to the current 420 max speed from the controls script.
@export var hot_glow_start_speed: float = 378.0
@export var hot_glow_full_speed: float = 420.0
@export var hot_glow_color := Color(0.55, 1.0, 0.08, 1.0)
@export var hot_glow_light_energy: float = 2.8
@export var spark_start_speed: float = 84.0
@export var spark_full_speed: float = 420.0
@export var spark_color := Color(1.0, 0.58, 0.1, 1.0)

# Sometimes treats this mesh name weird after import
const WHEEL_NODE_NAME := "frame_wheel"
const WHEEL_NODE_FALLBACK_NAME := "frame"

# The Blender ropes looked bad once the basket started moving, adjusted
const ROPE_NODE_NAMES := [
	"rope_a",
	"rope_b",
	"rope_c",
	"rope_d",
]

var _wheel: Node3D
var _basket: Node3D
var _rider: Node3D
var _gondola_center_x := 0.0
var _basket_basis := Basis.IDENTITY
var _rider_basis := Basis.IDENTITY
var _rider_offset_from_basket := Vector3.ZERO
var _baskets: Array[Node3D] = []
var _riders: Array[Node3D] = []
var _socket_local_positions: Array[Vector3] = []
var _left_hanger_bars: Array[MeshInstance3D] = []
var _right_hanger_bars: Array[MeshInstance3D] = []
var _wheel_meshes: Array[MeshInstance3D] = []
var _hot_glow_material: StandardMaterial3D
var _hot_glow_light: OmniLight3D
var _axle_sparks: GPUParticles3D
var _spark_process_material: ParticleProcessMaterial

func _ready() -> void:
	_setup_ferris_wheel()

func _process(delta: float) -> void:
	if _wheel == null or _baskets.is_empty():
		return

	var spin_delta := deg_to_rad(wheel_speed_degrees_per_second) * delta
	_wheel.rotate_x(spin_delta)

	_update_gondolas()
	_update_hot_glow()
	_update_sparks()

func _setup_ferris_wheel() -> void:
	_wheel = _find_wheel_node()
	_basket = _find_node3d("basket")
	_rider = _find_node3d("kid_one")

	if _wheel == null or _basket == null:
		push_warning("StageOne could not find the ferris wheel mesh; animation is disabled.")
		return

	_gondola_center_x = _get_frame_center_x()
	_basket_basis = _basket.global_basis

	if _rider != null:
		_rider_basis = _rider.global_basis
		_rider_offset_from_basket = _rider.global_position - _basket.global_position

	for node_name in ROPE_NODE_NAMES:
		var rope := _find_node3d(node_name)
		if rope != null:
			rope.visible = false

	_create_gondolas()
	_create_hanger_bars()
	_setup_hot_glow()
	_setup_sparks()
	_update_gondolas()

func _create_gondolas() -> void:
	_baskets.clear()
	_riders.clear()
	_socket_local_positions.clear()

	# Duplicating the one Blender cart for now is faster than rebuilding the wheel asset.
	var basket_parent := _basket.get_parent()
	var rider_is_inside_basket := _rider != null and _is_descendant_of(_rider, _basket)
	var rider_parent := _rider.get_parent() if _rider != null else null
	var count := clampi(gondola_count, 1, 8)

	for index in count:
		var basket := _basket
		var rider := _rider

		if index > 0:
			basket = _basket.duplicate()
			basket.name = "basket_%02d" % [index + 1]
			basket_parent.add_child(basket)

			if rider_is_inside_basket:
				rider = basket.find_child(_rider.name, true, false) as Node3D
			elif _rider != null and rider_parent != null:
				rider = _rider.duplicate()
				rider.name = "kid_%02d" % [index + 1]
				rider_parent.add_child(rider)

		_baskets.append(basket)
		_riders.append(rider)

		var angle := TAU * float(index) / float(count)
		var socket_world_position := _wheel.global_position + Vector3(0.0, sin(angle) * gondola_orbit_radius, cos(angle) * gondola_orbit_radius)
		_socket_local_positions.append(_wheel.to_local(socket_world_position))

func _is_descendant_of(node: Node, possible_parent: Node) -> bool:
	var parent := node.get_parent()
	while parent != null:
		if parent == possible_parent:
			return true
		parent = parent.get_parent()

	return false

func _find_node3d(node_name: String) -> Node3D:
	var found := find_child(node_name, true, false)
	if found is Node3D:
		return found

	return null

func _find_wheel_node() -> Node3D:
	var wheel := _find_node3d(WHEEL_NODE_NAME)
	if wheel != null:
		return wheel

	wheel = _find_node3d(WHEEL_NODE_FALLBACK_NAME)
	if wheel != null and wheel.get_class() == "VehicleWheel3D":
		return wheel

	return null

func _create_hanger_bars() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.09, 0.07)
	material.roughness = 0.8

	for index in _baskets.size():
		_left_hanger_bars.append(_create_hanger_bar("HangerLeft_%02d" % [index + 1], material))
		_right_hanger_bars.append(_create_hanger_bar("HangerRight_%02d" % [index + 1], material))

func _create_hanger_bar(bar_name: String, material: Material) -> MeshInstance3D:
	var bar := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 8
	mesh.top_radius = hanger_bar_radius
	mesh.bottom_radius = hanger_bar_radius
	bar.name = bar_name
	bar.mesh = mesh
	bar.material_override = material
	add_child(bar)
	return bar

func _setup_hot_glow() -> void:
	_wheel_meshes.clear()
	_find_wheel_meshes(_wheel)

	# A silly danger glow. It only gets applied once the wheel is near the redline.
	_hot_glow_material = StandardMaterial3D.new()
	_hot_glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hot_glow_material.albedo_color = Color(hot_glow_color.r, hot_glow_color.g, hot_glow_color.b, 0.0)
	_hot_glow_material.emission_enabled = true
	_hot_glow_material.emission = hot_glow_color
	_hot_glow_material.emission_energy_multiplier = 0.0
	_hot_glow_material.roughness = 0.95

	_hot_glow_light = OmniLight3D.new()
	_hot_glow_light.name = "WheelHotGlow"
	_hot_glow_light.light_color = hot_glow_color
	_hot_glow_light.light_energy = 0.0
	_hot_glow_light.omni_range = gondola_orbit_radius * 2.5
	add_child(_hot_glow_light)
	_hot_glow_light.global_position = _wheel.global_position

func _setup_sparks() -> void:
	# Little angry axle sparks once the player starts pushing the ride too hard.
	var spark_mesh := QuadMesh.new()
	spark_mesh.size = Vector2(0.08, 0.08)

	var spark_mesh_material := StandardMaterial3D.new()
	spark_mesh_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	spark_mesh_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mesh_material.albedo_color = spark_color
	spark_mesh_material.emission_enabled = true
	spark_mesh_material.emission = spark_color
	spark_mesh_material.emission_energy_multiplier = 3.0
	spark_mesh.material = spark_mesh_material

	_spark_process_material = ParticleProcessMaterial.new()
	_spark_process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_spark_process_material.emission_sphere_radius = 0.28
	_spark_process_material.direction = Vector3(0.0, 0.4, 1.0)
	_spark_process_material.spread = 160.0
	_spark_process_material.gravity = Vector3(0.0, -5.0, 0.0)
	_spark_process_material.initial_velocity_min = 2.5
	_spark_process_material.initial_velocity_max = 6.5
	_spark_process_material.scale_min = 0.5
	_spark_process_material.scale_max = 1.35
	_spark_process_material.color = spark_color

	_axle_sparks = GPUParticles3D.new()
	_axle_sparks.name = "AxleSparks"
	_axle_sparks.amount = 90
	_axle_sparks.lifetime = 0.42
	_axle_sparks.explosiveness = 0.0
	_axle_sparks.randomness = 0.65
	_axle_sparks.emitting = false
	_axle_sparks.process_material = _spark_process_material
	_axle_sparks.draw_pass_1 = spark_mesh
	add_child(_axle_sparks)
	_axle_sparks.global_position = _wheel.global_position

func _find_wheel_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		_wheel_meshes.append(node)

	for child in node.get_children():
		_find_wheel_meshes(child)

func _update_hot_glow() -> void:
	if _hot_glow_light == null or _hot_glow_material == null:
		return

	# Below the start speed nothing glows, then it ramps into full bad-idea mode.
	var heat := inverse_lerp(hot_glow_start_speed, hot_glow_full_speed, absf(wheel_speed_degrees_per_second))
	heat = clampf(heat, 0.0, 1.0)

	var pulse := 0.78 + sin(Time.get_ticks_msec() * 0.018) * 0.22
	var glow_alpha := heat * 0.42
	_hot_glow_material.albedo_color = Color(hot_glow_color.r, hot_glow_color.g, hot_glow_color.b, glow_alpha)
	_hot_glow_material.emission_energy_multiplier = heat * (1.8 + pulse * 1.2)

	for mesh in _wheel_meshes:
		mesh.material_overlay = _hot_glow_material if heat > 0.0 else null

	_hot_glow_light.global_position = _wheel.global_position
	_hot_glow_light.light_energy = heat * hot_glow_light_energy * pulse

func _update_sparks() -> void:
	if _axle_sparks == null or _spark_process_material == null:
		return

	# Starts early so the wheel feels sketchy before it is fully cooked.
	var spark_heat := inverse_lerp(spark_start_speed, spark_full_speed, absf(wheel_speed_degrees_per_second))
	spark_heat = clampf(spark_heat, 0.0, 1.0)
	_axle_sparks.global_position = _wheel.global_position
	_axle_sparks.emitting = spark_heat > 0.0
	_axle_sparks.amount_ratio = maxf(spark_heat, 0.05) if spark_heat > 0.0 else 0.0
	_spark_process_material.initial_velocity_min = lerpf(1.4, 4.5, spark_heat)
	_spark_process_material.initial_velocity_max = lerpf(3.0, 9.0, spark_heat)

func _update_gondolas() -> void:
	for index in _baskets.size():
		_update_gondola(index)

func _update_gondola(index: int) -> void:
	var basket := _baskets[index]
	var rider := _riders[index]
	var attachment := _wheel.to_global(_socket_local_positions[index])

	attachment.x = _gondola_center_x
	var basket_position := attachment + Vector3.DOWN * gondola_hang_offset
	basket_position.x = _gondola_center_x

	# Keep the basket upright. No bonus points for throwing the kid out yet haha
	basket.global_position = basket_position
	basket.global_basis = _basket_basis

	if rider != null:
		rider.global_position = basket.global_position + _rider_offset_from_basket
		rider.global_basis = _rider_basis

	_update_hanger_bars(index, attachment, basket.global_position)

func _update_hanger_bars(index: int, attachment: Vector3, basket_position: Vector3) -> void:
	if index >= _left_hanger_bars.size() or index >= _right_hanger_bars.size():
		return

	var left_offset := Vector3.LEFT * hanger_half_width
	var right_offset := Vector3.RIGHT * hanger_half_width
	var basket_top_offset := Vector3.UP * 1.2
	_set_bar_between(_left_hanger_bars[index], attachment + left_offset, basket_position + basket_top_offset + left_offset)
	_set_bar_between(_right_hanger_bars[index], attachment + right_offset, basket_position + basket_top_offset + right_offset)

func _set_bar_between(bar: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	var midpoint := (start + end) * 0.5
	var direction := end - start
	var length := direction.length()
	if length <= 0.001:
		return

	var cylinder := bar.mesh as CylinderMesh
	cylinder.height = length
	bar.global_position = midpoint
	bar.global_basis = _basis_from_y_axis(direction.normalized())

func _basis_from_y_axis(y_axis: Vector3) -> Basis:
	# CylinderMesh uses Y as its length axis.
	var x_axis := Vector3.FORWARD.cross(y_axis)
	if x_axis.length_squared() < 0.001:
		x_axis = Vector3.RIGHT
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)

func _get_frame_center_x() -> float:
	var left_arm := _find_node3d("frame_arm_left")
	var right_arm := _find_node3d("frame_arm_right")
	if left_arm != null and right_arm != null:
		return (left_arm.global_position.x + right_arm.global_position.x) * 0.5

	return _wheel.global_position.x
