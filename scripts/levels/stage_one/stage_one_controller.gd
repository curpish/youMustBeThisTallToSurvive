extends Node

var _readout: Label

func _ready() -> void:
	if not OS.is_debug_build():
		return
	_build_ui()

func _process(_delta: float) -> void:
	if _readout == null:
		return

	var safety_limit := RideState.rpm_max * 0.9
	var fling_speed := 379.0
	var fling_ready := RideState.angular_velocity >= fling_speed
	_readout.text = "target_rpm:  %.1f\nsafety limit:  %.1f rpm\nfling ready:  %s (%.0f+ rpm)" % [
		RideState.target_rpm,
		safety_limit,
		"YES" if fling_ready else "NO",
		fling_speed,
	]

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DebugReadoutOverlay"
	add_child(layer)

	var box := VBoxContainer.new()
	box.position = Vector2(16.0, 8.0)
	layer.add_child(box)

	_readout = Label.new()
	_readout.add_theme_font_size_override("font_size", 18)
	box.add_child(_readout)
