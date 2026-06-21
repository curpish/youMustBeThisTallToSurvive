extends Node3D

# Negative spins it backwards
@export var wheel_speed_degrees_per_second: float = -6.0

@export var gondola_orbit_radius: float = 7.2
@export var gondola_hang_offset: float = 2.6

@export var hanger_half_width: float = 0.8
@export var hanger_bar_radius: float = 0.035

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
var _socket_local_position := Vector3.ZERO
var _gondola_center_x := 0.0
var _basket_basis := Basis.IDENTITY
var _rider_basis := Basis.IDENTITY
var _rider_offset_from_basket := Vector3.ZERO
var _hanger_bars: Array[MeshInstance3D] = []

func _ready() -> void:
	_setup_ferris_wheel()

func _process(delta: float) -> void:
	if _wheel == null or _basket == null:
		return

	var spin_delta := deg_to_rad(wheel_speed_degrees_per_second) * delta
	_wheel.rotate_x(spin_delta)

	_update_gondola()

func _setup_ferris_wheel() -> void:
	_wheel = _find_wheel_node()
	_basket = _find_node3d("basket")
	_rider = _find_node3d("kid_one")

	if _wheel == null or _basket == null:
		push_warning("StageOne could not find the ferris wheel mesh; animation is disabled.")
		return

	var socket_world_position := _wheel.global_position + Vector3(0.0, 0.0, gondola_orbit_radius)
	_socket_local_position = _wheel.to_local(socket_world_position)
	_gondola_center_x = _get_frame_center_x()
	_basket_basis = _basket.global_basis

	if _rider != null:
		_rider_basis = _rider.global_basis
		_rider_offset_from_basket = _rider.global_position - _basket.global_position

	for node_name in ROPE_NODE_NAMES:
		var rope := _find_node3d(node_name)
		if rope != null:
			rope.visible = false

	_create_hanger_bars()
	_update_gondola()

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

	for bar_name in ["HangerLeft", "HangerRight"]:
		var bar := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.radial_segments = 8
		mesh.top_radius = hanger_bar_radius
		mesh.bottom_radius = hanger_bar_radius
		bar.name = bar_name
		bar.mesh = mesh
		bar.material_override = material
		add_child(bar)
		_hanger_bars.append(bar)

func _update_gondola() -> void:
	var attachment := _wheel.to_global(_socket_local_position)

	attachment.x = _gondola_center_x
	var basket_position := attachment + Vector3.DOWN * gondola_hang_offset
	basket_position.x = _gondola_center_x

	# Keep the basket upright. No bonus points for throwing the kid out yet haha
	_basket.global_position = basket_position
	_basket.global_basis = _basket_basis

	if _rider != null:
		_rider.global_position = _basket.global_position + _rider_offset_from_basket
		_rider.global_basis = _rider_basis

	_update_hanger_bars(attachment)

func _update_hanger_bars(attachment: Vector3) -> void:
	if _hanger_bars.size() != 2:
		return

	var left_offset := Vector3.LEFT * hanger_half_width
	var right_offset := Vector3.RIGHT * hanger_half_width
	var basket_top_offset := Vector3.UP * 1.2
	_set_bar_between(_hanger_bars[0], attachment + left_offset, _basket.global_position + basket_top_offset + left_offset)
	_set_bar_between(_hanger_bars[1], attachment + right_offset, _basket.global_position + basket_top_offset + right_offset)

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
