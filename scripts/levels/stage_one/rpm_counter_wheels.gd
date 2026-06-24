extends Node3D

const DIGIT_STEP := TAU / 10.0
const MAX_DISPLAY_VALUE := 99999.0
const BAND_TARGETS: Array[float] = [0.0, 65.0, 150.0, 280.0, 390.0]

@export var counter_digit_names: Array[StringName] = [
	&"rpmCounter_ten_thousands_digit",
	&"rpmCounter_thousands_digit",
	&"rpmCounter_hundreds_digit",
	&"rpmCounter_tens_digit",
	&"rpmCounter_single_digit",
]
@export var spin_axis := Vector3.RIGHT
@export var spin_direction := 1.0
@export var speed_handle_name := &"speedControl_handle_geo"
@export var speed_dial_name := &"speedControl_face"
@export var speed_handle_axis := Vector3.FORWARD
@export_range(-180.0, 180.0, 1.0, "radians_as_degrees") var speed_stop_angle := 0.0
@export_range(-180.0, 180.0, 1.0, "radians_as_degrees") var speed_fast_angle := deg_to_rad(180.0)
@export var drag_screen_radius := 140.0
@export var handle_hit_padding := 30.0
@export var handle_touch_hit_padding := 48.0
@export var handle_glow_color := Color(0.95, 0.82, 0.28, 0.55)
@export var handle_glow_energy := 1.8
@export var big_stop_button_name := &"bigStop_button_geo"
@export var big_stop_hit_padding := 28.0
@export var big_stop_touch_hit_padding := 46.0
@export var big_stop_press_offset := Vector3(0.0, -0.055, 0.0)
@export var big_stop_press_in_time := 0.055
@export var big_stop_pop_back_time := 0.16
@export var big_stop_glow_color := Color(1.0, 0.22, 0.1, 0.58)
@export var big_stop_glow_energy := 1.9
@export var mode_dial_name := &"dial_dial_geo"
@export var mode_dial_axis := Vector3.UP
@export_range(-180.0, 180.0, 1.0, "radians_as_degrees") var mode_one_angle := 0.0
@export_range(-180.0, 180.0, 1.0, "radians_as_degrees") var mode_two_angle := deg_to_rad(30.0)
@export_range(-180.0, 180.0, 1.0, "radians_as_degrees") var mode_three_angle := deg_to_rad(90.0)
@export var mode_dial_hit_padding := 28.0
@export var mode_dial_touch_hit_padding := 46.0
@export var mode_dial_glow_color := Color(0.35, 0.95, 1.0, 0.5)
@export var mode_dial_glow_energy := 1.7

var _digits: Array[Node3D] = []
var _rest_bases: Array[Basis] = []
var _speed_handle: Node3D
var _speed_dial: Node3D
var _speed_handle_rest_basis := Basis.IDENTITY
var _speed_handle_meshes: Array[MeshInstance3D] = []
var _speed_handle_glow: StandardMaterial3D
var _speed_handle_hovered := false
var _dragging_speed_handle := false
var _active_touch_index := -1
var _big_stop_button: Node3D
var _big_stop_button_rest_position := Vector3.ZERO
var _big_stop_meshes: Array[MeshInstance3D] = []
var _big_stop_glow: StandardMaterial3D
var _big_stop_hovered := false
var _big_stop_tween: Tween
var _mode_dial: Node3D
var _mode_dial_rest_basis := Basis.IDENTITY
var _mode_dial_meshes: Array[MeshInstance3D] = []
var _mode_dial_glow: StandardMaterial3D
var _mode_dial_hovered := false
var _dragging_mode_dial := false


func _ready() -> void:
	_collect_digits()
	_setup_speed_handle()
	_setup_big_stop_button()
	_setup_mode_dial()
	_update_counter()
	_update_speed_handle()
	_update_mode_dial()


func _process(_delta: float) -> void:
	_update_counter()
	_update_speed_handle()
	_update_mode_dial()
	_update_speed_handle_hover()
	_update_big_stop_hover()
	_update_mode_dial_hover()
	_update_cursor_shape()


func _input(event: InputEvent) -> void:
	if RideState.controls_locked:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _is_pointer_on_big_stop(event.position, big_stop_hit_padding):
				_press_big_stop()
				get_viewport().set_input_as_handled()
			elif _is_pointer_on_mode_dial(event.position, mode_dial_hit_padding):
				_dragging_mode_dial = true
				_set_mode_from_screen_position(event.position)
				get_viewport().set_input_as_handled()
			elif _speed_handle != null:
				_dragging_speed_handle = _is_pointer_on_speed_handle(event.position, handle_hit_padding)
				if _dragging_speed_handle:
					_set_speed_from_screen_position(event.position)
					get_viewport().set_input_as_handled()
		else:
			_dragging_speed_handle = false
			_dragging_mode_dial = false
	elif event is InputEventMouseMotion and _dragging_speed_handle:
		_set_speed_from_screen_position(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging_mode_dial:
		_set_mode_from_screen_position(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed and _active_touch_index == -1:
			if _is_pointer_on_big_stop(event.position, big_stop_touch_hit_padding):
				_active_touch_index = event.index
				_press_big_stop()
				get_viewport().set_input_as_handled()
			elif _is_pointer_on_mode_dial(event.position, mode_dial_touch_hit_padding):
				_active_touch_index = event.index
				_dragging_mode_dial = true
				_set_mode_from_screen_position(event.position)
				get_viewport().set_input_as_handled()
			elif _speed_handle != null and _is_pointer_on_speed_handle(event.position, handle_touch_hit_padding):
				_active_touch_index = event.index
				_dragging_speed_handle = true
				_set_speed_from_screen_position(event.position)
				get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _active_touch_index:
			_active_touch_index = -1
			_dragging_speed_handle = false
			_dragging_mode_dial = false
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _active_touch_index:
		if _dragging_speed_handle:
			_set_speed_from_screen_position(event.position)
		elif _dragging_mode_dial:
			_set_mode_from_screen_position(event.position)
		get_viewport().set_input_as_handled()


func _collect_digits() -> void:
	_digits.clear()
	_rest_bases.clear()

	for digit_name in counter_digit_names:
		var digit := find_child(String(digit_name), true, false) as Node3D
		if digit == null:
			push_warning("RPM counter digit wheel '%s' was not found." % digit_name)
			continue

		_digits.append(digit)
		_rest_bases.append(digit.basis)


func _setup_speed_handle() -> void:
	_speed_handle = find_child(String(speed_handle_name), true, false) as Node3D
	if _speed_handle == null:
		push_warning("Speed control handle '%s' was not found." % speed_handle_name)
		return

	_speed_dial = find_child(String(speed_dial_name), true, false) as Node3D
	_speed_handle_rest_basis = _speed_handle.basis
	_collect_meshes(_speed_handle, _speed_handle_meshes)
	_setup_speed_handle_glow()


func _setup_big_stop_button() -> void:
	_big_stop_button = find_child(String(big_stop_button_name), true, false) as Node3D
	if _big_stop_button == null:
		push_warning("Big Stop button '%s' was not found." % big_stop_button_name)
		return

	_big_stop_button_rest_position = _big_stop_button.position
	_collect_meshes(_big_stop_button, _big_stop_meshes)
	_setup_big_stop_glow()


func _setup_mode_dial() -> void:
	_mode_dial = find_child(String(mode_dial_name), true, false) as Node3D
	if _mode_dial == null:
		push_warning("Mode select dial '%s' was not found." % mode_dial_name)
		return

	_mode_dial_rest_basis = _mode_dial.basis
	_collect_meshes(_mode_dial, _mode_dial_meshes)
	_setup_mode_dial_glow()


func _update_counter() -> void:
	if _digits.is_empty():
		return

	var value := clampf(absf(RideState.angular_velocity), 0.0, MAX_DISPLAY_VALUE)
	var axis := spin_axis.normalized()
	if axis.length_squared() <= 0.0:
		axis = Vector3.RIGHT

	for i in _digits.size():
		var place_index := _digits.size() - i - 1
		var divisor := pow(10.0, place_index)
		var digit_value: float
		if place_index == 0:
			digit_value = fmod(value, 10.0)
		else:
			digit_value = float(int(floor(value / divisor)) % 10)
		var angle := spin_direction * digit_value * DIGIT_STEP
		_digits[i].basis = Basis(axis, angle) * _rest_bases[i]


func _update_speed_handle() -> void:
	if _speed_handle == null:
		return

	var t := _target_rpm_to_unit(RideState.target_rpm)
	var angle := lerpf(speed_stop_angle, speed_fast_angle, t)
	var axis := speed_handle_axis.normalized()
	if axis.length_squared() <= 0.0:
		axis = Vector3.FORWARD

	_speed_handle.basis = Basis(axis, angle) * _speed_handle_rest_basis


func _update_mode_dial() -> void:
	if _mode_dial == null:
		return

	var axis := mode_dial_axis.normalized()
	if axis.length_squared() <= 0.0:
		axis = Vector3.FORWARD

	_mode_dial.basis = _mode_dial_rest_basis * Basis(axis, _mode_angle_for_mode(RideState.selected_mode))


func _update_speed_handle_hover() -> void:
	if _speed_handle == null:
		return
	if RideState.controls_locked:
		if _speed_handle_hovered:
			_speed_handle_hovered = false
			_set_speed_handle_glow(false)
		return

	var hovered := _dragging_speed_handle
	if _active_touch_index == -1:
		hovered = hovered or _is_pointer_on_speed_handle(get_viewport().get_mouse_position(), handle_hit_padding)

	if hovered == _speed_handle_hovered:
		return

	_speed_handle_hovered = hovered
	_set_speed_handle_glow(hovered)


func _update_big_stop_hover() -> void:
	if _big_stop_button == null:
		return
	if RideState.controls_locked:
		if _big_stop_hovered:
			_big_stop_hovered = false
			_set_big_stop_glow(false)
		return

	var hovered := _active_touch_index == -1 and _is_pointer_on_big_stop(
		get_viewport().get_mouse_position(),
		big_stop_hit_padding
	)
	if hovered == _big_stop_hovered:
		return

	_big_stop_hovered = hovered
	_set_big_stop_glow(hovered)


func _update_mode_dial_hover() -> void:
	if _mode_dial == null:
		return
	if RideState.controls_locked:
		if _mode_dial_hovered:
			_mode_dial_hovered = false
			_set_mode_dial_glow(false)
		return

	var hovered := _dragging_mode_dial
	if _active_touch_index == -1:
		hovered = hovered or _is_pointer_on_mode_dial(get_viewport().get_mouse_position(), mode_dial_hit_padding)

	if hovered == _mode_dial_hovered:
		return

	_mode_dial_hovered = hovered
	_set_mode_dial_glow(hovered)


func _update_cursor_shape() -> void:
	if RideState.controls_locked:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return

	var hovering_interactable := (
		_speed_handle_hovered
		or _big_stop_hovered
		or _mode_dial_hovered
		or _dragging_speed_handle
		or _dragging_mode_dial
	)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovering_interactable else Input.CURSOR_ARROW)


func _is_pointer_on_speed_handle(screen_position: Vector2, padding: float) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(_speed_handle.global_position):
		return false

	var bounds := _node_screen_rect(_speed_handle, camera)
	bounds = bounds.grow(padding)
	return bounds.has_point(screen_position)


func _is_pointer_on_big_stop(screen_position: Vector2, padding: float) -> bool:
	if _big_stop_button == null:
		return false

	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(_big_stop_button.global_position):
		return false

	var bounds := _node_screen_rect(_big_stop_button, camera)
	bounds = bounds.grow(padding)
	return bounds.has_point(screen_position)


func _is_pointer_on_mode_dial(screen_position: Vector2, padding: float) -> bool:
	if _mode_dial == null:
		return false

	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(_mode_dial.global_position):
		return false

	var bounds := _node_screen_rect(_mode_dial, camera)
	bounds = bounds.grow(padding)
	return bounds.has_point(screen_position)


func _press_big_stop() -> void:
	if _big_stop_button == null:
		return

	RideState.big_stop()
	if _big_stop_tween != null:
		_big_stop_tween.kill()

	_big_stop_tween = create_tween()
	_big_stop_tween.set_trans(Tween.TRANS_QUAD)
	_big_stop_tween.set_ease(Tween.EASE_OUT)
	_big_stop_tween.tween_property(
		_big_stop_button,
		"position",
		_big_stop_button_rest_position + big_stop_press_offset,
		big_stop_press_in_time
	)
	_big_stop_tween.tween_property(
		_big_stop_button,
		"position",
		_big_stop_button_rest_position,
		big_stop_pop_back_time
	).set_trans(Tween.TRANS_BACK)


func _set_mode_from_screen_position(screen_position: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or _mode_dial == null:
		return

	var center := camera.unproject_position(_mode_dial.global_position)
	var vector := screen_position - center
	if vector.length_squared() <= 16.0:
		return

	var clock_angle := rad_to_deg(atan2(vector.x, -vector.y))
	if clock_angle < 0.0:
		clock_angle += 360.0

	var targets := [300.0, 270.0, 210.0]
	var best_mode := 1
	var best_distance := INF
	for i in targets.size():
		var distance := absf(angle_difference(deg_to_rad(clock_angle), deg_to_rad(targets[i])))
		if distance < best_distance:
			best_distance = distance
			best_mode = i + 1

	RideState.set_selected_mode(best_mode)


func _set_speed_from_screen_position(screen_position: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var dial_position := _speed_dial_screen_position(camera)
	var radius := maxf(drag_screen_radius, 1.0)
	var t := clampf((screen_position.x - (dial_position.x - radius)) / (radius * 2.0), 0.0, 1.0)
	RideState.target_rpm = BAND_TARGETS[_unit_to_band_index(t)]


func _speed_dial_screen_position(camera: Camera3D) -> Vector2:
	var dial_node := _speed_dial if _speed_dial != null else _speed_handle
	if camera.is_position_behind(dial_node.global_position):
		return get_viewport().get_mouse_position()
	return camera.unproject_position(dial_node.global_position)


func _node_screen_rect(node: Node3D, camera: Camera3D) -> Rect2:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance == null:
		var screen_position := camera.unproject_position(node.global_position)
		return Rect2(screen_position - Vector2(24.0, 24.0), Vector2(48.0, 48.0))

	var aabb := mesh_instance.get_aabb()
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for x in [aabb.position.x, aabb.end.x]:
		for y in [aabb.position.y, aabb.end.y]:
			for z in [aabb.position.z, aabb.end.z]:
				var world_point := mesh_instance.global_transform * Vector3(x, y, z)
				if camera.is_position_behind(world_point):
					continue
				var screen_point := camera.unproject_position(world_point)
				min_point = min_point.min(screen_point)
				max_point = max_point.max(screen_point)

	if min_point.x == INF or max_point.x == -INF:
		var fallback_position := camera.unproject_position(node.global_position)
		return Rect2(fallback_position - Vector2(24.0, 24.0), Vector2(48.0, 48.0))

	var rect := Rect2(min_point, max_point - min_point)
	var minimum_size := Vector2(56.0, 56.0)
	if rect.size.x < minimum_size.x:
		rect.position.x -= (minimum_size.x - rect.size.x) * 0.5
		rect.size.x = minimum_size.x
	if rect.size.y < minimum_size.y:
		rect.position.y -= (minimum_size.y - rect.size.y) * 0.5
		rect.size.y = minimum_size.y
	return rect


func _collect_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		_collect_meshes(child, meshes)


func _setup_speed_handle_glow() -> void:
	_speed_handle_glow = StandardMaterial3D.new()
	_speed_handle_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_speed_handle_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_speed_handle_glow.albedo_color = handle_glow_color
	_speed_handle_glow.emission_enabled = true
	_speed_handle_glow.emission = Color(handle_glow_color.r, handle_glow_color.g, handle_glow_color.b)
	_speed_handle_glow.emission_energy_multiplier = handle_glow_energy


func _setup_big_stop_glow() -> void:
	_big_stop_glow = StandardMaterial3D.new()
	_big_stop_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_big_stop_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_big_stop_glow.albedo_color = big_stop_glow_color
	_big_stop_glow.emission_enabled = true
	_big_stop_glow.emission = Color(big_stop_glow_color.r, big_stop_glow_color.g, big_stop_glow_color.b)
	_big_stop_glow.emission_energy_multiplier = big_stop_glow_energy


func _setup_mode_dial_glow() -> void:
	_mode_dial_glow = StandardMaterial3D.new()
	_mode_dial_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mode_dial_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mode_dial_glow.albedo_color = mode_dial_glow_color
	_mode_dial_glow.emission_enabled = true
	_mode_dial_glow.emission = Color(mode_dial_glow_color.r, mode_dial_glow_color.g, mode_dial_glow_color.b)
	_mode_dial_glow.emission_energy_multiplier = mode_dial_glow_energy


func _set_speed_handle_glow(enabled: bool) -> void:
	for mesh in _speed_handle_meshes:
		mesh.material_overlay = _speed_handle_glow if enabled else null


func _set_big_stop_glow(enabled: bool) -> void:
	for mesh in _big_stop_meshes:
		mesh.material_overlay = _big_stop_glow if enabled else null


func _set_mode_dial_glow(enabled: bool) -> void:
	for mesh in _mode_dial_meshes:
		mesh.material_overlay = _mode_dial_glow if enabled else null


func _mode_angle_for_mode(mode: int) -> float:
	match clampi(mode, 1, 3):
		1:
			return mode_one_angle
		2:
			return mode_two_angle
		3:
			return mode_three_angle
		_:
			return mode_one_angle


func _target_rpm_to_unit(target_rpm: float) -> float:
	return float(_nearest_band_index(target_rpm)) / float(BAND_TARGETS.size() - 1)


func _unit_to_band_index(value: float) -> int:
	return clampi(roundi(value * float(BAND_TARGETS.size() - 1)), 0, BAND_TARGETS.size() - 1)


func _nearest_band_index(target_rpm: float) -> int:
	var best_index := 0
	var best_distance := INF
	for i in BAND_TARGETS.size():
		var distance := absf(BAND_TARGETS[i] - target_rpm)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index
