extends Node
# Debug readout overlay for the shared spin model: a live RideState dump so we
# can watch the numbers while driving the wheel. Interactive controls live on
# the node-based panel now (SpeedBands slider + vboxGovernor); this is read-only.
# Throwaway: delete when the real panel readout lands.

var _readout: Label

func _ready() -> void:
	if not OS.is_debug_build():
		return
	_build_ui()

func _process(_delta: float) -> void:
	if _readout == null:
		return

	var effective_max: float = (
		RideState.rpm_governed if RideState.is_governed else RideState.rpm_max
	)
	var safety_limit := RideState.rpm_max * 0.9
	var fling_speed := 379.0
	var fling_ready := RideState.angular_velocity >= fling_speed
	_readout.text = "target_rpm:  %.1f\nangular_velocity:  %.2f\nwheel_angle:  %.2f rad\ngovernor:  %s (cap %.0f)\nsafety limit:  %.1f rpm\nfling ready:  %s (%.0f+ rpm)\noverride:  %.1fs   cooldown:  %.1fs" % [
		RideState.target_rpm,
		RideState.angular_velocity,
		RideState.wheel_angle,
		"ON" if RideState.is_governed else "OFF",
		effective_max,
		safety_limit,
		"YES" if fling_ready else "NO",
		fling_speed,
		RideState.governor_override_time_left,
		RideState.governor_cooldown_left,
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
