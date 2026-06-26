extends Node

const SPEED_TARGETS: Array[float] = [0.0, 65.0, 150.0, 280.0, 420.0]
const SPEED_SETTING_PITCHES: Array[float] = [0.85, 0.98, 1.1, 1.22, 1.36]
const LEVER_SOUND_MIN_INTERVAL := 0.08

@export var button: AudioStreamPlayer
@export var big_stop: AudioStreamPlayer
@export var lever: AudioStreamPlayer
@export var governor_in: AudioStreamPlayer
@export var governor_out: AudioStreamPlayer
@export var mode_switch: AudioStreamPlayer

var _last_target_rpm := 0.0
var _last_speed_setting := 0
var _last_lever_sound_time := -INF


func _ready() -> void:
	if button == null:
		button = get_node_or_null("button")
	if big_stop == null:
		big_stop = get_node_or_null("big_stop")
	if lever == null:
		lever = get_node_or_null("lever")
	if governor_in == null:
		governor_in = get_node_or_null("governor_in")
	if governor_out == null:
		governor_out = get_node_or_null("governor_out")
	if mode_switch == null:
		mode_switch = get_node_or_null("mode_switch")

	_last_target_rpm = RideState.target_rpm
	_last_speed_setting = _nearest_speed_setting(RideState.target_rpm)
	if lever != null:
		lever.max_polyphony = 1
	if button != null:
		button.max_polyphony = 1
	Events.big_stop.connect(_on_big_stop)
	Events.governor_priming.connect(_on_governor_priming)
	Events.governor_overridden.connect(_on_governor_overridden)
	Events.panel_button_pressed.connect(_on_panel_button_pressed)
	Events.mode_switched.connect(_on_mode_switched)


func _process(_delta: float) -> void:
	# Button SFX is driven by Events.panel_button_pressed (mouse or keyboard),
	# so this only watches for speed-band changes to click the lever.
	if RideState.target_rpm != _last_target_rpm:
		_last_target_rpm = RideState.target_rpm
		var speed_setting := _nearest_speed_setting(RideState.target_rpm)
		if speed_setting != _last_speed_setting:
			_last_speed_setting = speed_setting
			_play_lever(speed_setting)


func _on_big_stop() -> void:
	if big_stop != null:
		big_stop.play()


func _on_panel_button_pressed(_action: String) -> void:
	_play_button()


func _on_mode_switched(_mode: int) -> void:
	if mode_switch != null:
		mode_switch.play()


func _play_button() -> void:
	if button == null:
		return
	button.stop()
	button.play()


func _on_governor_priming() -> void:
	if governor_out != null:
		governor_out.play()


func _on_governor_overridden() -> void:
	if governor_in != null:
		governor_in.play()


func _play_lever(speed_setting: int) -> void:
	if lever == null:
		return

	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_lever_sound_time < LEVER_SOUND_MIN_INTERVAL:
		return

	_last_lever_sound_time = now
	lever.pitch_scale = SPEED_SETTING_PITCHES[speed_setting]
	lever.stop()
	lever.play()


func _nearest_speed_setting(target_rpm: float) -> int:
	var best_index := 0
	var best_distance := INF
	for i in SPEED_TARGETS.size():
		var distance := absf(SPEED_TARGETS[i] - target_rpm)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index
