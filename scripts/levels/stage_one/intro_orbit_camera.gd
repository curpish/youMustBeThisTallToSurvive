extends Camera3D

# Other stuff waits on this so the player can't mess with controls during the intro.
signal intro_finished

@export var play_intro := true
@export var intro_duration := 8.0
@export var orbit_turns := 0.65
@export var orbit_radius := 32.0
@export var orbit_height := 8.0
@export var settle_start := 0.78
@export var look_at_target := Vector3(0.0, 4.0, 0.0)

var _time := 0.0
var _final_transform := Transform3D.IDENTITY
var _final_distance := 0.0
var _final_angle := 0.0
var _settle_transform := Transform3D.IDENTITY
var _settle_ready := false
var _done := false

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
