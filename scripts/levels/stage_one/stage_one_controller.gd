extends Node

@export var wheel_path: NodePath = NodePath("..")
@export var speed_gain_degrees_per_second: float = 7.5
@export var max_wheel_speed_degrees_per_second: float = 800.0
@export var debug_message_duration: float = 0.8

var _wheel_controller: Node
var _debug_label: Label
var _debug_message_time_left := 0.0

func _ready() -> void:
	_wheel_controller = get_node_or_null(wheel_path)
	if _wheel_controller == null:
		push_warning("StageOneController could not find the wheel controller.")

	_create_debug_label()

func _process(delta: float) -> void:
	_update_debug_label(delta)

	if _wheel_controller == null:
		return

	if Input.is_key_pressed(KEY_F):
		_add_wheel_speed(delta)

func _add_wheel_speed(delta: float) -> void:
	var current_speed: float = _wheel_controller.wheel_speed_degrees_per_second
	var speed_direction := signf(current_speed)

	if speed_direction == 0.0:
		speed_direction = -1.0

	var new_speed := current_speed + speed_direction * speed_gain_degrees_per_second * delta
	var max_speed := max_wheel_speed_degrees_per_second
	_wheel_controller.wheel_speed_degrees_per_second = clampf(new_speed, -max_speed, max_speed)

	var speed_added := absf(_wheel_controller.wheel_speed_degrees_per_second - current_speed)
	_show_speed_debug(speed_added)

func _create_debug_label() -> void:
	_debug_label = Label.new()
	_debug_label.name = "TemporarySpeedDebugLabel"
	_debug_label.position = Vector2(24.0, 24.0)
	_debug_label.add_theme_font_size_override("font_size", 24)
	_debug_label.text = ""
	_debug_label.visible = false
	get_tree().root.add_child.call_deferred(_debug_label)

func _show_speed_debug(speed_added: float) -> void:
	if _debug_label == null:
		return

	_debug_label.text = "increased speed by %.2f deg/sec" % speed_added
	_debug_label.visible = true
	_debug_message_time_left = debug_message_duration

func _update_debug_label(delta: float) -> void:
	if _debug_label == null or not _debug_label.visible:
		return

	_debug_message_time_left -= delta
	if _debug_message_time_left <= 0.0:
		_debug_label.visible = false
