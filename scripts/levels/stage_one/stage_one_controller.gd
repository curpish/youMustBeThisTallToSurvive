extends Node

@export var wheel_path: NodePath = NodePath("..")
@export var speed_gain_degrees_per_second: float = 22.0
@export var max_wheel_speed_degrees_per_second: float = 420.0
@export var safety_speed_ratio: float = 0.9
@export var debug_message_duration: float = 0.8
@export var hands_overlay_path: NodePath = NodePath("../PlayerHandsOverlay")

var _wheel_controller: Node
var _debug_label: Label
var _debug_message_time_left := 0.0
var _controls_ready := false

func _ready() -> void:
	_wheel_controller = get_node_or_null(wheel_path)
	if _wheel_controller == null:
		push_warning("StageOneController could not find the wheel controller.")

	_create_debug_label()
	_wait_for_hands()

func _process(delta: float) -> void:
	_update_debug_label(delta)

	if _wheel_controller == null:
		return

	if Input.is_key_pressed(KEY_F):
		if not _controls_ready:
			_show_waiting_debug()
			return

		_add_wheel_speed(delta)

func _wait_for_hands() -> void:
	var hands_overlay := get_node_or_null(hands_overlay_path)

	# If the overlay breaks while testing, don't trap the whole level with dead controls.
	if hands_overlay == null or not hands_overlay.has_signal("hands_ready"):
		_controls_ready = true
		return

	hands_overlay.hands_ready.connect(_enable_controls)

func _enable_controls() -> void:
	_controls_ready = true

func _add_wheel_speed(delta: float) -> void:
	var current_speed: float = _wheel_controller.wheel_speed_degrees_per_second
	var speed_direction := signf(current_speed)

	if speed_direction == 0.0:
		speed_direction = -1.0

	var new_speed := current_speed + speed_direction * speed_gain_degrees_per_second * delta
	var max_speed := max_wheel_speed_degrees_per_second
	_wheel_controller.wheel_speed_degrees_per_second = clampf(new_speed, -max_speed, max_speed)

	var current_speed_after: float = absf(_wheel_controller.wheel_speed_degrees_per_second)
	_show_speed_debug(current_speed_after)

func _create_debug_label() -> void:
	_debug_label = Label.new()
	_debug_label.name = "TemporarySpeedDebugLabel"
	_debug_label.position = Vector2(24.0, 24.0)
	_debug_label.add_theme_font_size_override("font_size", 24)
	_debug_label.text = ""
	_debug_label.visible = false
	get_tree().root.add_child.call_deferred(_debug_label)

func _show_speed_debug(current_speed: float) -> void:
	if _debug_label == null:
		return

	# Temporary readout while the wheel tuning is still changing.
	var max_speed := max_wheel_speed_degrees_per_second
	var safety_speed := max_speed * safety_speed_ratio
	_debug_label.text = "speed increasing\ncurrent: %.1f / %.1f deg/sec\nsafety limit: %.1f deg/sec" % [
		current_speed,
		max_speed,
		safety_speed,
	]
	_debug_label.visible = true
	_debug_message_time_left = debug_message_duration

func _show_waiting_debug() -> void:
	if _debug_label == null:
		return

	_debug_label.text = "hold up\noperator is getting situated"
	_debug_label.visible = true
	_debug_message_time_left = 0.35

func _update_debug_label(delta: float) -> void:
	if _debug_label == null or not _debug_label.visible:
		return

	_debug_message_time_left -= delta
	if _debug_message_time_left <= 0.0:
		_debug_label.visible = false
