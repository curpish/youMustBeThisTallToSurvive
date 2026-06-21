extends VBoxContainer

@export var enabled: bool = true
@export var update_interval: float = 2.0

var _label: Label
var _timer: Timer


func _ready() -> void:
	if not enabled:
		hide()
		return

	_label = Label.new()
	add_child(_label)

	_timer = Timer.new()
	_timer.wait_time = update_interval
	_timer.autostart = true
	_timer.timeout.connect(_refresh)
	add_child(_timer)

	_refresh()


func _refresh() -> void:
	_label.text = """--- RideState ---
target_rpm:       %.2f
angular_velocity: %.2f
rotations:        %.2f
position (rad):   %.2f
is_governed:      %s
rpm_governed:     %.2f
rpm_max:          %.2f
feel:             %.2f
""" % [
		RideState.target_rpm,
		RideState.angular_velocity,
		RideState.wheel_angle / TAU,
		fmod(RideState.wheel_angle, TAU),
		str(RideState.is_governed),
		RideState.rpm_governed,
		RideState.rpm_max,
		RideState.feel,
	]
