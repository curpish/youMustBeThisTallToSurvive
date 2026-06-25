extends Control

const BAND_TARGETS: Array[float] = [0.0, 65.0, 150.0, 280.0, 420.0]
const BAND_NAMES: Array[String] = ["STATIC", "JOG", "NOMINAL", "EXCEEDANCE", "OVERSPEED"]
const BAND_COLORS: Array[Color] = [
	Color(0.45, 0.85, 0.45),
	Color(0.55, 0.85, 0.40),
	Color(0.95, 0.78, 0.30),
	Color(0.95, 0.50, 0.28),
	Color(0.96, 0.26, 0.24),
]
const LIT_ALPHA := 1.0
const UNLIT_ALPHA := 0.28

const FAULT_KEYS: Array[String] = ["q", "w", "e", "r"]
const FAULT_PRESSED_COLOR := Color(1.0, 0.85, 0.2)
const FAULT_MODE_COLORS: Dictionary = {
	1: Color(0.35, 0.95, 0.35),
	2: Color(1.0, 0.85, 0.2),
	3: Color(1.0, 0.25, 0.18),
}

@export var speed_bands: HSlider
@export var band_strip: Control
@export var governor_button: Button
@export var big_stop_button: Button
@export var shudder_label: Label
@export var estop_label: Label
@export var severity_label: Label
@export var fault_cluster: HBoxContainer
@export var hands_overlay_path: NodePath = NodePath("../../PlayerHandsOverlay")
@export var show_debug_visuals := true
@export var enable_debug_speed_slider := false
@export var show_debug_big_stop_button := false
@export var show_debug_governor_button := false
@export var show_debug_fault_buttons := false
@export var show_debug_mode_buttons := false
@export var show_debug_game_over_button := true

var _band_labels: Array[Label] = []
var _fault_buttons: Dictionary = {}
var _fault_styles: Dictionary = {}
var _mode_buttons: Array[Button] = []
var _damage_label: Label
var _game_over_button: Button
var _controls_ready := false

func _ready() -> void:
	if enable_debug_speed_slider:
		_setup_speed_bands()
	else:
		_hide_speed_bands()
	_setup_governor()
	_setup_big_stop()
	_setup_faults()
	_setup_mode_select()
	_setup_game_over_button()
	_setup_damage_readout()
	RideState.faults_changed.connect(_refresh_fault_buttons)
	RideState.damage_changed.connect(_refresh_extra_readouts)
	RideState.selected_mode_changed.connect(_on_selected_mode_changed)
	RideState.controls_locked_changed.connect(_on_controls_locked_changed)
	_set_controls_enabled(false)
	_apply_debug_visibility()
	_wait_for_hands()

func _process(_delta: float) -> void:
	_refresh_governor_button()
	_refresh_extra_readouts()
	if not _controls_ready or RideState.controls_locked:
		return

	if Input.is_action_just_pressed("space"):
		RideState.request_governor_override()
	if enable_debug_speed_slider:
		_sync_lever_to_target()
	_update_fault_buttons()

func _unhandled_input(event: InputEvent) -> void:
	if not _controls_ready or RideState.controls_locked:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				_set_mode(1)
			KEY_2:
				_set_mode(2)
			KEY_3:
				_set_mode(3)

func _wait_for_hands() -> void:
	var hands_overlay := get_node_or_null(hands_overlay_path)
	if hands_overlay == null or not hands_overlay.has_signal("hands_ready"):
		_enable_controls()
		return

	hands_overlay.hands_ready.connect(_enable_controls)

func _enable_controls() -> void:
	_controls_ready = true
	_set_controls_enabled(true)

func _set_controls_enabled(enabled: bool) -> void:
	enabled = enabled and not RideState.controls_locked
	if speed_bands != null and enable_debug_speed_slider:
		speed_bands.editable = enabled
	if governor_button != null:
		governor_button.disabled = true if not show_debug_governor_button else not enabled
	if big_stop_button != null and show_debug_big_stop_button:
		big_stop_button.disabled = not enabled
	if _game_over_button != null:
		_game_over_button.disabled = not enabled
	for button in _mode_buttons:
		button.disabled = not enabled
	for action in _fault_buttons:
		_fault_buttons[action].disabled = true if not show_debug_fault_buttons else not enabled

func _setup_speed_bands() -> void:
	if speed_bands == null:
		speed_bands = get_node_or_null("VBoxSpeedBands/SpeedBands")
	if speed_bands == null:
		push_warning("DebugRideControls: SpeedBands slider not found.")
		return

	_collect_band_labels()
	speed_bands.value_changed.connect(_on_speed_bands_value_changed)
	speed_bands.set_value_no_signal(_nearest_band_index(RideState.target_rpm))
	_apply_band(int(speed_bands.value))

func _setup_governor() -> void:
	if governor_button == null:
		governor_button = get_node_or_null("vboxGovernor/Button")
	if governor_button == null:
		push_warning("DebugRideControls: governor Button not found.")
		return

	governor_button.focus_mode = Control.FOCUS_NONE
	governor_button.pressed.connect(func() -> void:
		RideState.request_governor_override()
	)
	if not show_debug_governor_button:
		_hide_governor()
	_refresh_governor_button()

func _setup_big_stop() -> void:
	if big_stop_button == null:
		big_stop_button = get_node_or_null("vboxBigStop/Button")
	if big_stop_button == null:
		push_warning("DebugRideControls: Big Stop Button not found.")
		return

	big_stop_button.focus_mode = Control.FOCUS_NONE
	if not show_debug_big_stop_button:
		var big_stop_box := big_stop_button.get_parent()
		if big_stop_box is Control:
			big_stop_box.visible = false
		big_stop_button.disabled = true
		return

	big_stop_button.pressed.connect(func() -> void:
		RideState.big_stop()
	)

func _setup_faults() -> void:
	if fault_cluster == null:
		fault_cluster = get_node_or_null("hboxFaultCodeCluster")
	if fault_cluster == null:
		push_warning("DebugRideControls: fault cluster not found.")
		return

	for mode in FAULT_MODE_COLORS:
		var style := StyleBoxFlat.new()
		style.bg_color = FAULT_MODE_COLORS[mode]
		_fault_styles[mode] = style

	for action in FAULT_KEYS:
		var button := fault_cluster.get_node_or_null("vboxButton_%s/Button" % action.to_upper())
		if button is Button:
			button.focus_mode = Control.FOCUS_NONE
			button.text = action.to_upper()
			_fault_buttons[action] = button
			button.pressed.connect(_try_clear_fault.bind(action))
		else:
			push_warning("DebugRideControls: fault button for '%s' not found." % action)
	if not show_debug_fault_buttons:
		_hide_fault_cluster()
	_refresh_fault_buttons()

func _setup_mode_select() -> void:
	if not show_debug_mode_buttons:
		_hide_mode_select()
		return

	var box := VBoxContainer.new()
	box.name = "vboxModeSelect"
	box.anchor_left = 0.37
	box.anchor_top = 0.76
	box.anchor_right = 0.49
	box.anchor_bottom = 0.91
	add_child(box)

	var label := Label.new()
	label.theme = _debug_theme()
	label.text = "MODE SELECT"
	box.add_child(label)

	var row := HBoxContainer.new()
	box.add_child(row)
	for mode in [1, 2, 3]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(54, 54)
		button.focus_mode = Control.FOCUS_NONE
		button.theme = _debug_theme()
		button.text = str(mode)
		button.pressed.connect(_set_mode.bind(mode))
		row.add_child(button)
		_mode_buttons.append(button)
	_refresh_mode_buttons()


func _setup_game_over_button() -> void:
	if not show_debug_game_over_button:
		return

	var box := VBoxContainer.new()
	box.name = "vboxGameOver"
	box.anchor_left = 0.02
	box.anchor_top = 0.58
	box.anchor_right = 0.17
	box.anchor_bottom = 0.72
	add_child(box)

	var label := Label.new()
	label.theme = _debug_theme()
	label.text = "GAME OVER"
	box.add_child(label)

	_game_over_button = Button.new()
	_game_over_button.custom_minimum_size = Vector2(120.0, 36.0)
	_game_over_button.focus_mode = Control.FOCUS_NONE
	_game_over_button.theme = _debug_theme()
	_game_over_button.text = "TEST"
	_game_over_button.pressed.connect(_trigger_game_over_test)
	box.add_child(_game_over_button)


func _setup_damage_readout() -> void:
	var readouts := get_node_or_null("../extraReadOuts")
	if readouts == null:
		return
	_damage_label = Label.new()
	_damage_label.theme = _debug_theme()
	readouts.add_child(_damage_label)
	_refresh_extra_readouts()
	_apply_debug_visibility()

func _update_fault_buttons() -> void:
	for action in FAULT_KEYS:
		if Input.is_action_just_pressed(action):
			_try_clear_fault(action)

func _try_clear_fault(action: String) -> void:
	if not _controls_ready or RideState.controls_locked:
		return
	var selected_mode := RideState.selected_mode
	var cleared := RideState.clear_fault(action, selected_mode)
	if cleared:
		print("CLEARED FAULT %s IN MODE %d" % [action.to_upper(), selected_mode])
	else:
		var fault_mode := RideState.get_fault_mode(action)
		if fault_mode > 0:
			print("FAULT %s NEEDS MODE %d, SELECTED MODE %d" % [action.to_upper(), fault_mode, selected_mode])

func _set_mode(mode: int) -> void:
	if RideState.controls_locked:
		return
	RideState.set_selected_mode(mode)


func _trigger_game_over_test() -> void:
	if RideState.controls_locked:
		return
	print("DEBUG: triggering game over test")
	RideState.debug_trigger_axle_failure()


func _on_selected_mode_changed(_mode: int) -> void:
	_refresh_mode_buttons()

func _refresh_mode_buttons() -> void:
	for i in _mode_buttons.size():
		var mode := i + 1
		var button := _mode_buttons[i]
		if mode == RideState.selected_mode:
			button.add_theme_stylebox_override("normal", _fault_styles.get(mode, _flat_style(FAULT_PRESSED_COLOR)))
			button.add_theme_stylebox_override("hover", _fault_styles.get(mode, _flat_style(FAULT_PRESSED_COLOR)))
		else:
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_stylebox_override("hover")

func _refresh_fault_buttons() -> void:
	for action in _fault_buttons:
		var mode := RideState.get_fault_mode(action)
		_set_fault_lit(_fault_buttons[action], mode)

func _set_fault_lit(button: Button, mode: int) -> void:
	for state in ["normal", "hover", "pressed"]:
		if mode > 0:
			button.add_theme_stylebox_override(state, _fault_styles.get(mode, _flat_style(FAULT_PRESSED_COLOR)))
		else:
			button.remove_theme_stylebox_override(state)

func _refresh_governor_button() -> void:
	if governor_button == null:
		return
	if not show_debug_governor_button:
		governor_button.disabled = true
		return
	if RideState.controls_locked:
		governor_button.text = "WATCH"
		governor_button.disabled = true
		return
	if not _controls_ready:
		governor_button.text = "WAIT"
		governor_button.disabled = true
		return
	if RideState.governor_prime_time_left > 0.0:
		governor_button.text = "ARMING  %.1f" % RideState.governor_prime_time_left
		governor_button.disabled = true
	elif RideState.governor_override_time_left > 0.0:
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
	if _damage_label != null:
		_damage_label.text = "DAMAGE  %.0f / %.0f  LAST %.0f  FAULTS %d" % [
			RideState.damage,
			RideState.damage_max,
			RideState.last_stop_damage,
			RideState.get_uncleared_fault_count(),
		]

func _sync_lever_to_target() -> void:
	if speed_bands == null:
		return
	var index := _nearest_band_index(RideState.target_rpm)
	if int(round(speed_bands.value)) != index:
		speed_bands.set_value_no_signal(index)
		_light_band(index)

func _on_speed_bands_value_changed(value: float) -> void:
	if RideState.controls_locked:
		return
	_apply_band(int(round(value)))

func _apply_band(index: int) -> void:
	index = clampi(index, 0, BAND_TARGETS.size() - 1)
	RideState.target_rpm = BAND_TARGETS[index]
	speed_bands.tooltip_text = BAND_NAMES[index]
	_light_band(index)

func _light_band(index: int) -> void:
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

func _debug_theme() -> Theme:
	if shudder_label != null and shudder_label.theme != null:
		return shudder_label.theme
	if governor_button != null and governor_button.theme != null:
		return governor_button.theme
	return null

func _flat_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	return style

func _on_controls_locked_changed(_locked: bool) -> void:
	_set_controls_enabled(_controls_ready)

func _apply_debug_visibility() -> void:
	modulate.a = 1.0 if show_debug_visuals else 0.0
	_hide_speed_bands()
	if not show_debug_governor_button:
		_hide_governor()
	if not show_debug_fault_buttons:
		_hide_fault_cluster()
	if _game_over_button != null:
		var game_over_box := _game_over_button.get_parent()
		if game_over_box is Control:
			game_over_box.visible = show_debug_visuals and show_debug_game_over_button
	var readouts := get_node_or_null("../extraReadOuts")
	if readouts != null:
		readouts.visible = show_debug_visuals


func _hide_speed_bands() -> void:
	if enable_debug_speed_slider:
		return
	var speed_box := get_node_or_null("vboxSpeedBands")
	if speed_box != null:
		speed_box.visible = false
	if speed_bands != null:
		speed_bands.editable = false


func _hide_governor() -> void:
	var governor_box := get_node_or_null("vboxGovernor")
	if governor_box is Control:
		governor_box.visible = false
	if governor_button != null:
		governor_button.disabled = true


func _hide_fault_cluster() -> void:
	if fault_cluster == null:
		fault_cluster = get_node_or_null("hboxFaultCodeCluster")
	if fault_cluster is Control:
		fault_cluster.visible = false
	for action in _fault_buttons:
		_fault_buttons[action].disabled = true


func _hide_mode_select() -> void:
	var mode_box := get_node_or_null("vboxModeSelect")
	if mode_box != null:
		mode_box.queue_free()
	_mode_buttons.clear()
