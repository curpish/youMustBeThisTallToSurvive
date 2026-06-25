extends Node

var _readout: Label

func _ready() -> void:
	if not OS.is_debug_build():
		return
	_build_ui()

func _process(_delta: float) -> void:
	if _readout == null:
		return

	var fling_speed := RideState.big_stop_current_min_speed
	var fling_max_speed := RideState.big_stop_current_max_speed
	var fling_ready := RideState.angular_velocity >= fling_speed and RideState.angular_velocity <= fling_max_speed
	var auto_big_stop_armed := (
		RideState.panel_pressure_enabled
		and not RideState.panel_auto_big_stop_triggered_this_spin
	)
	_readout.text = (
		"Difficulty:  %s\n"
		+ "target_rpm:  %.1f\n"
		+ "redline:     %.1f rpm\n"
		+ "auto stop:   %.1f rpm\n"
		+ "fling ready:  %s (%.0f-%.0f rpm)\n"
		+ "axle heat:   %.1f / %.1f\n"
		+ "heat floor:  stage %d (%.1f)\n"
		+ "last chance: %s\n"
		+ "overheat:    %s\n"
		+ "Big Stop Window: %.0f - %.0f\n"
		+ "Big Stop Stage:  %d / %d\n"
		+ "Panel Lights: %s\n"
		+ "Panel Pressure Delay: %.1fs\n"
		+ "Auto Big Stop Armed: %s"
	) % [
		RideState.Difficulty.keys()[RideState.difficulty],
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
		fling_speed,
		fling_max_speed,
		RideState.big_stop_difficulty_stage,
		RideState.big_stop_difficulty_stage_count - 1,
		_format_panel_lights(),
		RideState.get_current_panel_spawn_interval(),
		"true" if auto_big_stop_armed else "false",
	]

func _format_panel_lights() -> String:
	var parts: Array[String] = []
	for action in RideState.FAULT_ACTIONS:
		var mode := RideState.get_fault_mode(action)
		var state := "G"
		if mode == 3:
			state = "R"
		elif mode == 2:
			state = "Y"
		parts.append("%s %s" % [action.to_upper(), state])
	return " | ".join(parts)

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
