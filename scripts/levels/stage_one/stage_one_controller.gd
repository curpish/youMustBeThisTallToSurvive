extends Node

var _readout: Label

func _ready() -> void:
	if not OS.is_debug_build():
		return
	_build_ui()

func _process(_delta: float) -> void:
	if _readout == null:
		return

	var fling_speed := 379.0
	var fling_max_speed := 410.0
	var fling_ready := RideState.angular_velocity >= fling_speed and RideState.angular_velocity <= fling_max_speed
	_readout.text = (
		"target_rpm:  %.1f\n"
		+ "redline:     %.1f rpm\n"
		+ "auto stop:   %.1f rpm\n"
		+ "fling ready:  %s (%.0f-%.0f rpm)\n"
		+ "axle heat:   %.1f / %.1f\n"
		+ "heat floor:  stage %d (%.1f)\n"
		+ "last chance: %s\n"
		+ "overheat:    %s"
	) % [
		RideState.target_rpm,
		fling_max_speed,
		RideState.overheat_speed,
		"YES" if fling_ready else "NO",
		fling_speed,
		fling_max_speed,
		RideState.axle_heat,
		RideState.rpm_max,
		RideState.heat_floor_stage,
		RideState.heat_floor_value,
		"YES" if RideState.is_last_chance else "NO",
		"YES" if RideState.overheat_penalty_applied_this_spin else "NO",
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
