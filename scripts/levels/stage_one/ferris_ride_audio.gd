extends Node

const BED_SILENT_DB := -80.0
const BED_NEAR_DB := -4.0
const BED_FAST_DB := -10.0
const BED_GATE_FRAC := 0.04
const BED_PITCH_MIN := 0.85
const BED_PITCH_MAX := 1.35
const BED_VOLUME_RATE := 48.0
const BED_PITCH_RATE := 1.4
const SHUDDER_PITCH_DROP := 0.25

const SQUEAK_INTERVAL := TAU / 3.0
const SQUEAK_JITTER := 0.6
const SQUEAK_PROBABILITY := 0.7
const SHUDDER_SQUEAK_BUMP := 0.3
const SHUDDER_SQUEAK_DB := 6.0

@export var wheel_running: AudioStreamPlayer
@export var squeaks: AudioStreamPlayer
@export var fling_gondola: AudioStreamPlayer

var _squeak_base_db := 0.0
var _next_squeak_angle := 0.0


func _ready() -> void:
	if wheel_running == null:
		wheel_running = get_node_or_null("wheel_running")
	if squeaks == null:
		squeaks = get_node_or_null("squeaks")

	if wheel_running != null:
		if "loop" in wheel_running.stream:
			wheel_running.stream.loop = true
		wheel_running.volume_db = BED_SILENT_DB
		wheel_running.pitch_scale = BED_PITCH_MIN
		wheel_running.play()
	else:
		push_warning("FerrisRideAudio: wheel_running player not found.")

	if squeaks != null:
		_squeak_base_db = squeaks.volume_db
	else:
		push_warning("FerrisRideAudio: squeaks player not found.")
	_schedule_next_squeak(RideState.wheel_angle)

	if fling_gondola == null:
		fling_gondola = get_node_or_null("fling_gondola")
	if fling_gondola != null:
		Events.fling.connect(func() -> void: fling_gondola.play())
	else:
		push_warning("FerrisRideAudio: fling_gondola player not found.")


func _process(delta: float) -> void:
	var speed_frac := clampf(RideState.angular_velocity / RideState.rpm_max, 0.0, 1.0)
	_update_bed(delta, speed_frac)
	_update_squeaks()


func _update_bed(delta: float, speed_frac: float) -> void:
	if wheel_running == null:
		return

	var gate := clampf(speed_frac / BED_GATE_FRAC, 0.0, 1.0)
	var loud_db := lerpf(BED_NEAR_DB, BED_FAST_DB, speed_frac)
	var target_db := lerpf(BED_SILENT_DB, loud_db, gate)
	wheel_running.volume_db = move_toward(
		wheel_running.volume_db, target_db, BED_VOLUME_RATE * delta
	)

	var target_pitch := lerpf(BED_PITCH_MIN, BED_PITCH_MAX, speed_frac)
	target_pitch -= SHUDDER_PITCH_DROP * RideState.shudder
	wheel_running.pitch_scale = move_toward(
		wheel_running.pitch_scale, target_pitch, BED_PITCH_RATE * delta
	)


func _update_squeaks() -> void:
	if squeaks == null:
		return
	if RideState.wheel_angle < _next_squeak_angle:
		return
	_schedule_next_squeak(RideState.wheel_angle)

	var probability := SQUEAK_PROBABILITY + RideState.shudder * SHUDDER_SQUEAK_BUMP
	if randf() <= probability:
		squeaks.volume_db = _squeak_base_db + RideState.shudder * SHUDDER_SQUEAK_DB
		squeaks.play()


func _schedule_next_squeak(from_angle: float) -> void:
	var interval := SQUEAK_INTERVAL * (1.0 + randf_range(-SQUEAK_JITTER, SQUEAK_JITTER))
	_next_squeak_angle = from_angle + interval
