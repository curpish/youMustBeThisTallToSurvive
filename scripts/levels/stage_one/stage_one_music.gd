extends AudioStreamPlayer

const MAX_TIERS := 6
@export var intensity_tracks: Array[AudioStream] = []
@export var victory_music: AudioStream
@export var game_over_music: AudioStream

const ENGAGE_FRAC := 0.03
const DISENGAGE_FRAC := 0.005

const VOLUME_FULL_RPM := 7.4
const MUSIC_SILENT_DB := -60.0
const VOLUME_RATE := 24.0

const PITCH_START := 0.65
const PITCH_JOG_RPM := 6.0
const PITCH_HOLD_RPM := 18.0
const PITCH_LOG_GAIN := 0.04
const PITCH_RATE := 1.2

const DRY_REST := 0.1
const DRY_FULL := 1.0
const WET_REST := 0.2
const WET_FULL := 0.0
const REVERB_RATE := 1.5

var _full_volume_db := 0.0
var _normal_pitch := 1.0
var _reverb: AudioEffectReverb
var _engaged := false
var _flung := 0
var _current_tier := -1
var _ended := false


func _ready() -> void:
	_full_volume_db = volume_db
	_normal_pitch = pitch_scale
	pitch_scale = PITCH_START
	_resolve_reverb()
	_ensure_loop()
	if _reverb != null:
		_reverb.dry = DRY_REST
		_reverb.wet = WET_REST

	Events.fling.connect(_on_fling)
	RideState.victory_triggered.connect(_on_victory)
	RideState.axle_failure_triggered.connect(_on_failure)
	_apply_tier(0)

	volume_db = MUSIC_SILENT_DB
	play()
	stream_paused = true


func _process(delta: float) -> void:
	if _ended:
		return
	var speed_frac := clampf(RideState.angular_velocity / RideState.rpm_max, 0.0, 1.0)
	_update_engagement(speed_frac)

	var av := RideState.angular_velocity

	var target_db := _volume_target_db(av) if _engaged else MUSIC_SILENT_DB
	volume_db = move_toward(volume_db, target_db, VOLUME_RATE * delta)
	if not _engaged and volume_db <= MUSIC_SILENT_DB + 0.5:
		stream_paused = true

	pitch_scale = move_toward(pitch_scale, _pitch_target(av), PITCH_RATE * delta)

	var s := smoothstep(0.0, 1.0, speed_frac)
	if _reverb != null:
		_reverb.dry = move_toward(_reverb.dry, lerpf(DRY_REST, DRY_FULL, s), REVERB_RATE * delta)
		_reverb.wet = move_toward(_reverb.wet, lerpf(WET_REST, WET_FULL, s), REVERB_RATE * delta)


func _volume_target_db(av: float) -> float:
	var amp := clampf(sqrt(av / VOLUME_FULL_RPM), 0.0, 1.0)
	return _full_volume_db + linear_to_db(maxf(amp, 0.0001))


func _pitch_target(av: float) -> float:
	if av <= PITCH_JOG_RPM:
		return lerpf(PITCH_START, _normal_pitch, av / PITCH_JOG_RPM)
	if av <= PITCH_HOLD_RPM:
		return _normal_pitch
	return _normal_pitch + PITCH_LOG_GAIN * log(1.0 + (av - PITCH_HOLD_RPM))


func _update_engagement(speed_frac: float) -> void:
	if _engaged:
		if speed_frac < DISENGAGE_FRAC:
			_engaged = false
	elif speed_frac > ENGAGE_FRAC:
		_engaged = true
		stream_paused = false


func _on_fling() -> void:
	if _ended:
		return
	_flung += 1
	_apply_tier(mini(_flung, MAX_TIERS - 1))


func _on_victory() -> void:
	_play_end_music(victory_music, "victory")


func _on_failure() -> void:
	_play_end_music(game_over_music, "game over")


# Terminal hand-off: latch out of the dynamic score and play a fixed end track.
# _ended freezes _process and _on_fling, so no speed/pitch/reverb modulation or
# tier swaps can fight the stinger. Reverb is snapped clean (full dry, no wet)
# so the track reads present instead of muffled.
func _play_end_music(track: AudioStream, label: String) -> void:
	if _ended:
		return
	_ended = true
	if track == null:
		push_warning("StageOneMusic: no %s track assigned." % label)
		stop()
		return

	stream = track
	_ensure_loop()
	pitch_scale = _normal_pitch
	volume_db = _full_volume_db
	if _reverb != null:
		_reverb.dry = DRY_FULL
		_reverb.wet = WET_FULL
	stream_paused = false
	play()


func _apply_tier(tier: int) -> void:
	if tier == _current_tier:
		return
	_current_tier = tier
	if tier == 0:
		return

	var index := tier - 1
	if index < intensity_tracks.size() and intensity_tracks[index] != null:
		stream = intensity_tracks[index]
		_ensure_loop()
		if not stream_paused:
			play()
	else:
		push_warning("StageOneMusic: no track assigned for tier %d." % tier)


func _resolve_reverb() -> void:
	var bus_index := AudioServer.get_bus_index("Music")
	if bus_index < 0:
		push_warning("StageOneMusic: Music bus not found; reverb crossfade disabled.")
		return
	for i in AudioServer.get_bus_effect_count(bus_index):
		var effect := AudioServer.get_bus_effect(bus_index, i)
		if effect is AudioEffectReverb:
			_reverb = effect
			return
	push_warning("StageOneMusic: no Reverb on the Music bus; crossfade disabled.")


func _ensure_loop() -> void:
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream != null and "loop" in stream:
		stream.loop = true
