extends VBoxContainer

# Debug stand-in for the telegraph handle.
# Attach to a VBoxContainer in the debug UI.
# Remove when the real Handle scene is in.

@export var rpm_loading: float = 1.0
@export var rpm_scenic: float = 3.0
@export var rpm_brisk: float = 6.0
@export var rpm_lunar: float = 9.0


func _ready() -> void:
	_add_button("STOP", 0.0)
	_add_button("LOADING", rpm_loading)
	_add_button("SCENIC", rpm_scenic)
	_add_button("BRISK", rpm_brisk)
	_add_button("LUNAR", rpm_lunar)
	_add_separator()
	_add_toggle_button()


func _add_button(label: String, rpm: float) -> void:
	var btn := Button.new()
	btn.text = label
	btn.pressed.connect(func(): RideState.target_rpm = rpm)
	add_child(btn)


func _add_separator() -> void:
	add_child(HSeparator.new())


func _add_toggle_button() -> void:
	var btn := Button.new()
	btn.text = _governor_label()
	btn.pressed.connect(func():
		RideState.is_governed = not RideState.is_governed
		Events.governor_overridden.emit()
		btn.text = _governor_label()
	)
	add_child(btn)


func _governor_label() -> String:
	return "GOVERNOR: ON" if RideState.is_governed else "GOVERNOR: OFF"
