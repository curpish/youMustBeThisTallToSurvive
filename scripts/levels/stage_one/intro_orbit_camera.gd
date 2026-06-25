extends Camera3D

signal intro_finished
signal fling_watch_finished

@export var play_intro := true
@export var intro_duration := 8.0
@export var orbit_turns := 0.65
@export var orbit_radius := 32.0
@export var orbit_height := 8.0
@export var settle_start := 0.78
@export var look_at_target := Vector3(0.0, 4.0, 0.0)
@export var victory_zoom_distance_scale := 0.8
@export var victory_blend_duration := 1.3

var _time := 0.0
var _final_transform := Transform3D.IDENTITY
var _final_distance := 0.0
var _final_angle := 0.0
var _settle_transform := Transform3D.IDENTITY
var _settle_ready := false
var _done := false
var _spectacle_active := false
var _spectacle_time := 0.0
var _spectacle_start := Transform3D.IDENTITY
var _spectacle_target_a: Node3D
var _spectacle_target_b: Node3D
var _victory_active := false
var _victory_time := 0.0
var _victory_start := Transform3D.IDENTITY
var _victory_target_transform := Transform3D.IDENTITY

const SPECTACLE_FOLLOW_TIME := 2.0
const SPECTACLE_HOLD_TIME := 0.8
const SPECTACLE_RETURN_TIME := 1.35

func _ready() -> void:
	_final_transform = global_transform
	var final_offset := global_position - look_at_target
	_final_distance = maxf(Vector2(final_offset.x, final_offset.z).length(), 0.001)
	_final_angle = atan2(final_offset.z, final_offset.x)

	if not play_intro:
		_done = true
		intro_finished.emit()
		return

	_update_intro_camera(0.0)

func _process(delta: float) -> void:
	if _spectacle_active:
		_update_spectacle_camera(delta)
		return

	if _victory_active:
		_update_victory_camera(delta)
		return

	if _done:
		return

	_time += delta
	var progress := clampf(_time / maxf(intro_duration, 0.001), 0.0, 1.0)
	_update_intro_camera(progress)

	if progress >= 1.0:
		global_transform = _final_transform
		_done = true
		intro_finished.emit()

func _update_intro_camera(progress: float) -> void:
	var settle_at := clampf(settle_start, 0.05, 0.95)
	if progress < settle_at:
		_settle_ready = false
		global_transform = _get_orbit_transform(progress / settle_at)
		return

	if not _settle_ready:
		_settle_transform = _get_orbit_transform(1.0)
		_settle_ready = true

	var settle_progress := inverse_lerp(settle_at, 1.0, progress)
	global_transform = _blend_transforms(_settle_transform, _final_transform, _smoother_step(settle_progress))

func _get_orbit_transform(progress: float) -> Transform3D:
	var eased := _smoother_step(clampf(progress, 0.0, 1.0))
	var angle := lerpf(_final_angle + TAU * orbit_turns, _final_angle, eased)
	var radius := lerpf(orbit_radius, _final_distance, eased)
	var height := lerpf(orbit_height, _final_transform.origin.y, eased)
	var camera_position := look_at_target + Vector3(cos(angle) * radius, height - look_at_target.y, sin(angle) * radius)

	var orbit_transform := Transform3D(Basis.IDENTITY, camera_position)
	return orbit_transform.looking_at(look_at_target, Vector3.UP)

func _blend_transforms(from_transform: Transform3D, to_transform: Transform3D, weight: float) -> Transform3D:
	var from_rotation := Quaternion(from_transform.basis)
	var to_rotation := Quaternion(to_transform.basis)
	var blended_rotation := from_rotation.slerp(to_rotation, weight)
	var blended_position := from_transform.origin.lerp(to_transform.origin, weight)
	return Transform3D(Basis(blended_rotation), blended_position)

func _smoother_step(value: float) -> float:
	return value * value * value * (value * (value * 6.0 - 15.0) + 10.0)

func watch_fling(target_a: Node3D, target_b: Node3D = null) -> void:
	if not _done:
		return

	_spectacle_active = true
	_spectacle_time = 0.0
	_spectacle_start = global_transform
	_spectacle_target_a = target_a
	_spectacle_target_b = target_b

func is_watching_fling() -> bool:
	return _spectacle_active

func _update_spectacle_camera(delta: float) -> void:
	_spectacle_time += delta
	var total_time := SPECTACLE_FOLLOW_TIME + SPECTACLE_HOLD_TIME + SPECTACLE_RETURN_TIME
	if _spectacle_time >= total_time:
		global_transform = _final_transform
		_spectacle_active = false
		RideState.set_controls_locked(false)
		fling_watch_finished.emit()
		return

	if _spectacle_time <= SPECTACLE_FOLLOW_TIME + SPECTACLE_HOLD_TIME:
		var follow_weight := _smoother_step(clampf(_spectacle_time / SPECTACLE_FOLLOW_TIME, 0.0, 1.0))
		global_transform = _blend_transforms(_spectacle_start, _get_spectacle_transform(), follow_weight)
		return

	var return_progress := (_spectacle_time - SPECTACLE_FOLLOW_TIME - SPECTACLE_HOLD_TIME) / SPECTACLE_RETURN_TIME
	global_transform = _blend_transforms(_get_spectacle_transform(), _final_transform, _smoother_step(return_progress))

func _get_spectacle_transform() -> Transform3D:
	var target := _get_spectacle_target()
	var final_offset := _final_transform.origin - look_at_target
	var camera_position := target + final_offset * 0.72 + Vector3(0.0, 2.2, 0.0)
	return Transform3D(Basis.IDENTITY, camera_position).looking_at(target + Vector3.UP * 0.8, Vector3.UP)

func _get_spectacle_target() -> Vector3:
	var target := Vector3.ZERO
	var count := 0
	if is_instance_valid(_spectacle_target_a):
		target += _spectacle_target_a.global_position
		count += 1
	if is_instance_valid(_spectacle_target_b):
		target += _spectacle_target_b.global_position
		count += 1
	if count <= 0:
		return look_at_target
	return target / float(count)

func watch_victory(target_position: Vector3) -> void:
	_victory_active = true
	_victory_time = 0.0
	_victory_start = global_transform
	_victory_target_transform = _get_victory_transform(target_position)

func _update_victory_camera(delta: float) -> void:
	_victory_time += delta
	var weight := _smoother_step(clampf(_victory_time / maxf(victory_blend_duration, 0.001), 0.0, 1.0))
	global_transform = _blend_transforms(_victory_start, _victory_target_transform, weight)

func _get_victory_transform(target_position: Vector3) -> Transform3D:
	var final_offset := _final_transform.origin - look_at_target
	var camera_position := target_position + final_offset * victory_zoom_distance_scale
	return Transform3D(Basis.IDENTITY, camera_position).looking_at(target_position, Vector3.UP)
