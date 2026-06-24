extends Node3D

# The wheel no longer owns its speed; it reads the shared spin model
# (RideState.wheel_angle). This is only the spin direction along the hub axis.
# Negative keeps the original "spins backwards" look.
@export var spin_direction: float = -1.0

@export var gondola_orbit_radius: float = 7.2
@export var gondola_hang_offset: float = 2.6
@export_range(1, 8, 1) var gondola_count := 6

@export var hanger_half_width: float = 0.8
@export var hanger_bar_radius: float = 0.035

# These are RPM now because the wheel follows RideState.
@export var hot_glow_start_speed: float = 378.0
@export var hot_glow_full_speed: float = 420.0
@export var hot_glow_color := Color(0.55, 1.0, 0.08, 1.0)
@export var hot_glow_light_energy: float = 2.8
@export var spark_start_speed: float = 84.0
@export var spark_full_speed: float = 420.0
@export var spark_color := Color(1.0, 0.58, 0.1, 1.0)
@export var basket_fling_speed: float = 379.0
@export var fling_ground_y: float = 0.25

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
var _gondola_flying: Array[bool] = []
var _basket_velocities: Array[Vector3] = []
var _rider_velocities: Array[Vector3] = []
var _rider_spin_axes: Array[Vector3] = []
var _rider_spin_speeds: Array[float] = []
var _basket_bounces: Array[int] = []
var _rider_bounces: Array[int] = []
var _flight_ages: Array[float] = []
var _basket_rest_scales: Array[Vector3] = []
var _rider_rest_scales: Array[Vector3] = []
var _wheel_rest_basis := Basis.IDENTITY
var _wheel_meshes: Array[MeshInstance3D] = []
var _hot_glow_material: StandardMaterial3D
var _hot_glow_light: OmniLight3D
var _axle_sparks: GPUParticles3D
var _spark_process_material: ParticleProcessMaterial

func _ready() -> void:
	_setup_ferris_wheel()
	Events.big_stop.connect(_on_big_stop)

func _process(_delta: float) -> void:
	if _wheel == null or _baskets.is_empty():
		return

	# Display the shared spin model. RideState.wheel_angle is the accumulated
	# rotation in radians; we apply it around the hub's X axis from the rest
	# pose. Pre-multiplying matches the old rotate_x accumulation exactly.
	var angle := spin_direction * RideState.wheel_angle
	_wheel.basis = Basis(Vector3.RIGHT, angle) * _wheel_rest_basis

	_update_gondolas()
	_update_flying_gondolas(_delta)
	_update_hot_glow()
	_update_sparks()

func _setup_ferris_wheel() -> void:
	_wheel = _find_wheel_node()
	_basket = _find_node3d("basket")
	_rider = _find_node3d("kid_one")

	if _wheel == null or _basket == null:
		push_warning("StageOne could not find the ferris wheel mesh; animation is disabled.")
		return

	_wheel_rest_basis = _wheel.basis
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
	_gondola_flying.clear()
	_basket_velocities.clear()
	_rider_velocities.clear()
	_rider_spin_axes.clear()
	_rider_spin_speeds.clear()
	_basket_bounces.clear()
	_rider_bounces.clear()
	_flight_ages.clear()
	_basket_rest_scales.clear()
	_rider_rest_scales.clear()

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
		_gondola_flying.append(false)
		_basket_velocities.append(Vector3.ZERO)
		_rider_velocities.append(Vector3.ZERO)
		_rider_spin_axes.append(Vector3.RIGHT)
		_rider_spin_speeds.append(0.0)
		_basket_bounces.append(0)
		_rider_bounces.append(0)
		_flight_ages.append(0.0)
		_basket_rest_scales.append(basket.scale)
		_rider_rest_scales.append(rider.scale if rider != null else Vector3.ONE)

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
	var heat := inverse_lerp(hot_glow_start_speed, hot_glow_full_speed, absf(RideState.angular_velocity))
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
	var spark_heat := inverse_lerp(spark_start_speed, spark_full_speed, absf(RideState.angular_velocity))
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
	if _gondola_flying[index]:
		return

	var basket := _baskets[index]
	var rider := _riders[index]
	var attachment := _wheel.to_global(_socket_local_positions[index])

	attachment.x = _gondola_center_x
	var basket_position := attachment + Vector3.DOWN * gondola_hang_offset
	basket_position.x = _gondola_center_x

	# Keep attached baskets upright until Big Stop throws one loose.
	basket.global_position = basket_position
	basket.global_basis = _basket_basis

	if rider != null:
		rider.global_position = basket.global_position + _rider_offset_from_basket
		rider.global_basis = _rider_basis

	_update_hanger_bars(index, attachment, basket.global_position)

func _on_big_stop() -> void:
	if RideState.last_stop_severity * RideState.rpm_max < basket_fling_speed:
		return

	var index := _find_leftmost_gondola()
	if index < 0:
		return

	_throw_gondola(index)

func _find_leftmost_gondola() -> int:
	var camera := get_viewport().get_camera_3d()
	var best_index := -1
	var best_x := INF

	for index in _baskets.size():
		if _gondola_flying[index]:
			continue

		var basket := _baskets[index]
		var screen_x: float
		if camera != null and not camera.is_position_behind(basket.global_position):
			screen_x = camera.unproject_position(basket.global_position).x
		else:
			screen_x = basket.global_position.x

		if screen_x < best_x:
			best_x = screen_x
			best_index = index

	return best_index

func _throw_gondola(index: int) -> void:
	_gondola_flying[index] = true
	_basket_bounces[index] = 0
	_rider_bounces[index] = 0
	_flight_ages[index] = 0.0
	RideState.set_controls_locked(true)

	if index < _left_hanger_bars.size():
		_left_hanger_bars[index].visible = false
	if index < _right_hanger_bars.size():
		_right_hanger_bars[index].visible = false

	var basket := _baskets[index]
	var rider := _riders[index]
	var launch_speed := clampf(RideState.last_stop_severity, 0.0, 1.0)
	var side_throw := 1.0
	_basket_velocities[index] = Vector3(0.0, 9.5, side_throw * lerpf(10.0, 17.0, launch_speed))

	if rider != null:
		# Kid gets kicked free of the basket with extra spin. Fake ragdoll, good enough to laugh at.
		_rider_velocities[index] = Vector3(randf_range(-1.0, 1.0), 12.5, side_throw * lerpf(14.0, 23.0, launch_speed))
		_rider_spin_axes[index] = Vector3(randf(), randf(), randf()).normalized()
		_rider_spin_speeds[index] = lerpf(5.5, 11.0, launch_speed)
		rider.global_position = basket.global_position + _rider_offset_from_basket

	_start_spectacle_camera(basket, rider)
	print("BASKET %d LAUNCHED AT %.1f RPM" % [index + 1, RideState.last_stop_severity * RideState.rpm_max])

func _start_spectacle_camera(basket: Node3D, rider: Node3D) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.has_method("watch_fling"):
		camera.watch_fling(basket, rider)
	else:
		RideState.set_controls_locked(false)

func _update_flying_gondolas(delta: float) -> void:
	for index in _baskets.size():
		if not _gondola_flying[index]:
			continue

		_flight_ages[index] += delta
		_update_flying_basket(index, delta)
		_update_flying_rider(index, delta)
		_update_fling_disappear(index)

func _update_flying_basket(index: int, delta: float) -> void:
	var basket := _baskets[index]
	var velocity := _basket_velocities[index]
	velocity += Vector3.DOWN * 12.0 * delta
	basket.global_position += velocity * delta
	basket.rotate_object_local(Vector3.RIGHT, 2.1 * delta)

	if basket.global_position.y <= fling_ground_y and _basket_bounces[index] < 3:
		basket.global_position.y = fling_ground_y
		velocity.y = absf(velocity.y) * 0.48
		velocity.z *= 0.62
		_basket_bounces[index] += 1
	elif basket.global_position.y <= fling_ground_y:
		basket.global_position.y = fling_ground_y
		velocity *= 0.86

	_basket_velocities[index] = velocity

func _update_flying_rider(index: int, delta: float) -> void:
	var rider := _riders[index]
	if rider == null:
		return

	var velocity := _rider_velocities[index]
	velocity += Vector3.DOWN * 13.0 * delta
	rider.global_position += velocity * delta
	rider.rotate_object_local(_rider_spin_axes[index], _rider_spin_speeds[index] * delta)

	if rider.global_position.y <= fling_ground_y and _rider_bounces[index] < 4:
		rider.global_position.y = fling_ground_y
		velocity.y = absf(velocity.y) * 0.52
		velocity.z *= 0.68
		_rider_spin_speeds[index] *= 0.74
		_rider_bounces[index] += 1
	elif rider.global_position.y <= fling_ground_y:
		rider.global_position.y = fling_ground_y
		velocity *= 0.84
		_rider_spin_speeds[index] *= 0.9

	_rider_velocities[index] = velocity

func _update_fling_disappear(index: int) -> void:
	var fade_progress := clampf((_flight_ages[index] - 2.2) / 1.25, 0.0, 1.0)
	if fade_progress <= 0.0:
		return

	var scale_weight := 1.0 - _smoother_step(fade_progress)
	var basket := _baskets[index]
	basket.scale = _basket_rest_scales[index] * maxf(scale_weight, 0.03)

	var rider := _riders[index]
	if rider != null:
		rider.scale = _rider_rest_scales[index] * maxf(scale_weight, 0.03)

	if fade_progress >= 1.0:
		basket.visible = false
		if rider != null:
			rider.visible = false

func _smoother_step(value: float) -> float:
	value = clampf(value, 0.0, 1.0)
	return value * value * value * (value * (value * 6.0 - 15.0) + 10.0)

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
