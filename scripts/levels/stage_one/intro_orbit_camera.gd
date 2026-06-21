extends Camera3D

@export var play_intro := true
@export var intro_duration := 8.0
@export var orbit_turns := 0.65
@export var orbit_radius := 32.0
@export var orbit_height := 8.0
@export var look_at_target := Vector3(0.0, 4.0, 0.0)

var _time := 0.0
var _final_transform := Transform3D.IDENTITY
var _final_distance := 0.0
var _final_angle := 0.0
var _done := false

func _ready() -> void:
	_final_transform = global_transform
	var final_offset := global_position - look_at_target
	_final_distance = maxf(Vector2(final_offset.x, final_offset.z).length(), 0.001)
	_final_angle = atan2(final_offset.z, final_offset.x)

	if not play_intro:
		_done = true
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

func _update_intro_camera(progress: float) -> void:
	var eased := _smoother_step(progress)
	var angle := lerpf(_final_angle + TAU * orbit_turns, _final_angle, eased)
	var radius := lerpf(orbit_radius, _final_distance, eased)
	var height := lerpf(orbit_height, _final_transform.origin.y, eased)
	var camera_position := look_at_target + Vector3(cos(angle) * radius, height - look_at_target.y, sin(angle) * radius)

	var orbit_transform := global_transform
	orbit_transform.origin = camera_position
	global_transform = orbit_transform
	look_at(look_at_target, Vector3.UP)

	# Blend into the editor camera
	global_transform = global_transform.interpolate_with(_final_transform, eased * eased)

func _smoother_step(value: float) -> float:
	return value * value * value * (value * (value * 6.0 - 15.0) + 10.0)
