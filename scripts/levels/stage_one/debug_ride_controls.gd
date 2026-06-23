extends Control
# Node-based debug ride control. The SpeedBands slider snaps between the ride's
# speed bands and writes RideState.target_rpm, so dragging it drives the real
# spin model the way the telegraph lever eventually will. Lives under the Debug
# CanvasLayer; throwaway until the real lever lands.

# target_rpm for each band, indexed by slider position (GDD section 10). The
# slider's range/step is meant to match this array (min 0, max size - 1,
# step 1) so each notch lands on exactly one band.
const BAND_TARGETS: Array[float] = [0.0, 6.0, 18.0, 38.0, 72.0]
const BAND_NAMES: Array[String] = ["STATIC", "JOG", "NOMINAL", "EXCEEDANCE", "OVERSPEED"]
# Telegraph backlight per band (GDD section 10: green -> amber -> red).
const BAND_COLORS: Array[Color] = [
	Color(0.45, 0.85, 0.45),
	Color(0.55, 0.85, 0.40),
	Color(0.95, 0.78, 0.30),
	Color(0.95, 0.50, 0.28),
	Color(0.96, 0.26, 0.24),
]
const LIT_ALPHA := 1.0
const UNLIT_ALPHA := 0.28

# Fault buttons: each input action maps to a vboxButton_X/Button under the
# cluster. They light yellow while held now; the fault-clear minigame will hook
# the same buttons later (GDD section 8.2).
const FAULT_KEYS: Array[String] = ["q", "w", "e", "r"]
const FAULT_PRESSED_COLOR := Color(1.0, 0.85, 0.2)  # yellow

@export var speed_bands: HSlider
@export var band_strip: Control  # one Label child per band, in low->high order
@export var governor_button: Button  # SPACE control; shows ready / override / cooldown
@export var big_stop_button: Button  # oversized emergency-stop button
@export var shudder_label: Label  # live brake-judder intensity
@export var estop_label: Label  # is_emergency_stopping ON/OFF
@export var severity_label: Label  # speed fraction at the last Big Stop
@export var fault_cluster: HBoxContainer  # holds the Q/W/E/R fault buttons

var _band_labels: Array[Label] = []
var _fault_buttons: Dictionary = {}  # action name -> Button
var _fault_pressed_style: StyleBoxFlat  # flat yellow swapped in while a key is held

func _ready() -> void:
	_setup_speed_bands()
	_setup_governor()
	_setup_big_stop()
	_setup_faults()

func _process(_delta: float) -> void:
	# SPACE jams the governor override (button click does the same).
	if Input.is_action_just_pressed("space"):
		RideState.request_governor_override()
	_refresh_governor_button()
	_refresh_extra_readouts()
	_sync_lever_to_target()
	_update_fault_buttons()

func _setup_speed_bands() -> void:
	if speed_bands == null:
		speed_bands = get_node_or_null("VBoxSpeedBands/SpeedBands")
	if speed_bands == null:
		push_warning("DebugRideControls: SpeedBands slider not found.")
		return

	_collect_band_labels()
	speed_bands.value_changed.connect(_on_speed_bands_value_changed)
	# Start the slider on whichever band the ride is already targeting.
	speed_bands.set_value_no_signal(_nearest_band_index(RideState.target_rpm))
	_apply_band(int(speed_bands.value))

func _setup_governor() -> void:
	if governor_button == null:
		governor_button = get_node_or_null("vboxGovernor/Button")
	if governor_button == null:
		push_warning("DebugRideControls: governor Button not found.")
		return

	governor_button.focus_mode = Control.FOCUS_NONE  # so SPACE can't double-fire it
	governor_button.pressed.connect(func() -> void: RideState.request_governor_override())
	_refresh_governor_button()

func _setup_big_stop() -> void:
	if big_stop_button == null:
		big_stop_button = get_node_or_null("vboxBigStop/Button")
	if big_stop_button == null:
		push_warning("DebugRideControls: Big Stop Button not found.")
		return

	big_stop_button.focus_mode = Control.FOCUS_NONE  # so SPACE can't trip it
	big_stop_button.pressed.connect(func() -> void: RideState.big_stop())

func _setup_faults() -> void:
	if fault_cluster == null:
		fault_cluster = get_node_or_null("hboxFaultCodeCluster")
	if fault_cluster == null:
		push_warning("DebugRideControls: fault cluster not found.")
		return

	_fault_pressed_style = StyleBoxFlat.new()
	_fault_pressed_style.bg_color = FAULT_PRESSED_COLOR

	# Each action q/w/e/r maps to vboxButton_<KEY>/Button under the cluster.
	for action in FAULT_KEYS:
		var button := fault_cluster.get_node_or_null("vboxButton_%s/Button" % action.to_upper())
		if button is Button:
			button.focus_mode = Control.FOCUS_NONE
			_fault_buttons[action] = button
		else:
			push_warning("DebugRideControls: fault button for '%s' not found." % action)

func _update_fault_buttons() -> void:
	# Swap a flat yellow stylebox in while the key is held (a real repaint, not a
	# modulate tint), themed default otherwise. Toggle only on key edges so we
	# are not re-overriding every frame. The fault-clear minigame will drive
	# these off RideState faults later.
	for action in _fault_buttons:
		if Input.is_action_just_pressed(action):
			_set_fault_lit(_fault_buttons[action], true)
		elif Input.is_action_just_released(action):
			_set_fault_lit(_fault_buttons[action], false)

func _set_fault_lit(button: Button, lit: bool) -> void:
	for state in ["normal", "hover", "pressed"]:
		if lit:
			button.add_theme_stylebox_override(state, _fault_pressed_style)
		else:
			button.remove_theme_stylebox_override(state)

func _refresh_governor_button() -> void:
	if governor_button == null:
		return
	if RideState.governor_override_time_left > 0.0:
		governor_button.text = "OVERRIDE  %.1f" % RideState.governor_override_time_left
		governor_button.disabled = true
	elif RideState.governor_cooldown_left > 0.0:
		governor_button.text = "COOLDOWN  %.1f" % RideState.governor_cooldown_left
		governor_button.disabled = true
	else:
		governor_button.text = "( SPACE )"
		governor_button.disabled = false

func _refresh_extra_readouts() -> void:
	if shudder_label != null:
		shudder_label.text = "SHUDDER  %.2f" % RideState.shudder
	if estop_label != null:
		estop_label.text = "E-STOP  %s" % ("ON" if RideState.is_emergency_stopping else "OFF")
	if severity_label != null:
		severity_label.text = "SEVERITY  %.2f" % RideState.last_stop_severity

func _sync_lever_to_target() -> void:
	# Lever follows RideState.target_rpm, so external forces (Big Stop pinning it
	# to STATIC) visibly drag the slider down. set_value_no_signal avoids writing
	# target_rpm back; we only move when the band actually changed.
	if speed_bands == null:
		return
	var index := _nearest_band_index(RideState.target_rpm)
	if int(round(speed_bands.value)) != index:
		speed_bands.set_value_no_signal(index)
		_light_band(index)

func _on_speed_bands_value_changed(value: float) -> void:
	_apply_band(int(round(value)))

func _apply_band(index: int) -> void:
	index = clampi(index, 0, BAND_TARGETS.size() - 1)
	RideState.target_rpm = BAND_TARGETS[index]
	speed_bands.tooltip_text = BAND_NAMES[index]
	_light_band(index)

func _light_band(index: int) -> void:
	# Active band lit at full alpha; the rest dimmed like an unlit faceplate.
	for i in _band_labels.size():
		_band_labels[i].modulate = Color(1.0, 1.0, 1.0, LIT_ALPHA if i == index else UNLIT_ALPHA)

func _collect_band_labels() -> void:
	_band_labels.clear()
	if band_strip == null:
		return
	for child in band_strip.get_children():
		if child is Label:
			_band_labels.append(child)
	if _band_labels.size() != BAND_NAMES.size():
		push_warning("DebugRideControls: BandStrip has %d labels, expected %d." % [
			_band_labels.size(), BAND_NAMES.size(),
		])
	# Script owns text + color so the faceplate can't drift from the contract.
	for i in mini(_band_labels.size(), BAND_NAMES.size()):
		_band_labels[i].text = BAND_NAMES[i]
		_band_labels[i].add_theme_color_override("font_color", BAND_COLORS[i])

func _nearest_band_index(target_rpm: float) -> int:
	var best_index := 0
	var best_distance := INF
	for i in BAND_TARGETS.size():
		var distance: float = absf(BAND_TARGETS[i] - target_rpm)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index
