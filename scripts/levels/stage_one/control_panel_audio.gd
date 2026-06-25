extends Node

const FAULT_KEYS: Array[String] = ["q", "w", "e", "r", "t", "y"]
const SPEED_TARGETS: Array[float] = [0.0, 65.0, 150.0, 280.0, 420.0]
const SPEED_SETTING_PITCHES: Array[float] = [0.85, 0.98, 1.1, 1.22, 1.36]

@export var button: AudioStreamPlayer
@export var big_stop: AudioStreamPlayer
@export var lever: AudioStreamPlayer
@export var governor_in: AudioStreamPlayer
@export var governor_out: AudioStreamPlayer

var _last_target_rpm := 0.0


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

	_last_target_rpm = RideState.target_rpm
	Events.big_stop.connect(_on_big_stop)
	Events.governor_priming.connect(_on_governor_priming)
	Events.governor_overridden.connect(_on_governor_overridden)
	Events.panel_button_pressed.connect(_on_panel_button_pressed)


func _process(_delta: float) -> void:
	for action in FAULT_KEYS:
		if Input.is_action_just_pressed(action):
			if button != null:
				button.play()
			break

	if RideState.target_rpm != _last_target_rpm:
		_last_target_rpm = RideState.target_rpm
		if lever != null:
			lever.pitch_scale = SPEED_SETTING_PITCHES[_nearest_speed_setting(RideState.target_rpm)]
			lever.play()


func _on_big_stop() -> void:
	if big_stop != null:
		big_stop.play()


func _on_panel_button_pressed(_action: String) -> void:
	if button != null:
		button.play()


func _on_governor_priming() -> void:
	if governor_out != null:
		governor_out.play()


func _on_governor_overridden() -> void:
	if governor_in != null:
		governor_in.play()


func _nearest_speed_setting(target_rpm: float) -> int:
	var best_index := 0
	var best_distance := INF
	for i in SPEED_TARGETS.size():
		var distance := absf(SPEED_TARGETS[i] - target_rpm)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index
