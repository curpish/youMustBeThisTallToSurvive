extends Node3D

const BAND_TARGETS: Array[float] = [0.0, 65.0, 150.0, 280.0, 420.0]
const HOVER_REFRESH_INTERVAL := 1.0 / 30.0
const WEB_PARTICLE_SCALE := 0.5
const FAULT_INDICATOR_MATERIAL := preload("res://Yam/materials/matsForShaders/indicatorLight_mat.tres")
const MODE_LABEL_BORDER_COLOR := Color(0.0, 0.0, 0.0, 1.0)
const MODE_LABEL_BORDER_SHADE_COLOR := Color(0.12, 0.12, 0.12, 1.0)
const MODE_LABEL_BORDER_WIDTH_FRACTION := 0.055
const MODE_LABELS := {
	&"label_1_geo": {
		"text": "1",
		"background": Color(0.82, 0.82, 0.78, 1.0),
		"foreground": Color(0.0, 0.0, 0.0, 1.0),
	},
	&"label_2_geo": {
		"text": "2",
		"background": Color(0.10, 0.48, 1.0, 1.0),
		"foreground": Color(0.96, 0.98, 1.0, 1.0),
	},
	&"label_3_geo": {
		"text": "3",
		"background": Color(1.0, 0.12, 0.12, 1.0),
		"foreground": Color(1.0, 0.96, 0.86, 1.0),
	},
}

@export var counter_digit_names: Array[StringName] = [
	&"rpmCounter_ten_thousands_digit",
	&"rpmCounter_thousands_digit",
	&"rpmCounter_hundreds_digit",
	&"rpmCounter_tens_digit",
	&"rpmCounter_single_digit",
]
@export var spin_axis := Vector3.RIGHT
@export var spin_direction := 1.0
@export var speed_handle_name := &"speedControl_handle_geo"
@export var speed_dial_name := &"speedControl_face"
@export var speed_handle_axis := Vector3.FORWARD
@export_range(-180.0, 180.0, 1.0, "radians_as_degrees") var speed_stop_angle := 0.0
@export_range(-180.0, 180.0, 1.0, "radians_as_degrees") var speed_fast_angle := deg_to_rad(180.0)
@export var drag_screen_radius := 140.0
@export var handle_hit_padding := 30.0
@export var handle_touch_hit_padding := 48.0
@export var handle_glow_color := Color(0.35, 0.95, 1.0, 0.5)
@export var handle_glow_energy := 1.8
@export var big_stop_button_name := &"bigStop_button_geo"
@export var big_stop_hit_padding := 28.0
@export var big_stop_touch_hit_padding := 46.0
@export var big_stop_press_offset := Vector3(0.0, -0.055, 0.0)
@export var big_stop_press_in_time := 0.055
@export var big_stop_pop_back_time := 0.16
@export var big_stop_glow_color := Color(0.35, 0.95, 1.0, 0.5)
@export var big_stop_glow_energy := 1.9
@export var mode_dial_name := &"dial_dial_geo"
@export var mode_dial_axis := Vector3.UP
@export_range(-180.0, 180.0, 1.0, "radians_as_degrees") var mode_one_angle := 0.0
@export_range(-180.0, 180.0, 1.0, "radians_as_degrees") var mode_two_angle := deg_to_rad(30.0)
@export_range(-180.0, 180.0, 1.0, "radians_as_degrees") var mode_three_angle := deg_to_rad(90.0)
@export var mode_dial_hit_padding := 28.0
@export var mode_dial_touch_hit_padding := 46.0
@export var mode_dial_glow_color := Color(0.35, 0.95, 1.0, 0.5)
@export var mode_dial_glow_energy := 1.7
@export var governor_screwdriver_name := &"screwdriver_geo"
@export var governor_hit_padding := 8.0
@export var governor_touch_hit_padding := 22.0
@export var governor_press_offset := Vector3(0.0, 0.075, 0.0)
@export_range(-20.0, 20.0, 0.5, "radians_as_degrees") var governor_jiggle_angle := deg_to_rad(2.4)
@export var governor_press_time := 0.07
@export var governor_jiggle_time := 0.045
@export var governor_release_time := 0.14
@export var governor_glow_color := Color(0.35, 0.95, 1.0, 0.5)
@export var governor_glow_energy := 1.65
@export var governor_cooldown_spark_offset := Vector3(0.0, 0.0, -0.08)
@export var governor_cooldown_spark_color := Color(1.0, 0.5, 0.08, 1.0)
@export var governor_cooldown_spark_amount := 26
@export var governor_cooldown_spark_lifetime := 0.26
@export var panel_button_names: Dictionary = {
	"q": &"pushButton_button_Q",
	"w": &"pushButton_button_W",
	"e": &"pushButton_button_E",
	"r": &"pushButton_button_R",
	"t": &"pushButton_button_T",
	"y": &"pushButton_button_Y",
}
@export var panel_button_hit_padding := 10.0
@export var panel_button_touch_hit_padding := 26.0
@export var panel_button_press_offset := Vector3(0.0, -0.035, 0.0)
@export var panel_button_press_in_time := 0.045
@export var panel_button_pop_back_time := 0.12
@export var panel_button_glow_color := Color(0.35, 0.95, 1.0, 0.5)
@export var panel_button_glow_energy := 1.7
@export var fault_indicator_names: Dictionary = {
	"q": &"indicatorLight_light_Q",
	"w": &"indicatorLight_light_W",
	"e": &"indicatorLight_light_E",
	"r": &"indicatorLight_light_R",
	"t": &"indicatorLight_light_T",
	"y": &"indicatorLight_light_Y",
}
@export var fault_indicator_color := Color(1.0, 0.06, 0.02, 0.85)
@export var fault_indicator_warning_color := Color(0.04, 0.26, 0.78, 0.85)
@export var fault_indicator_safe_color := Color(0.55, 0.55, 0.55, 1.0)
@export var fault_indicator_energy := 1.0
@export var fault_indicator_off_energy := 0.0
@export var heat_gauge_needle_path: NodePath
@export var heat_gauge_needle_name := &"analogDial_needle_geo"
@export var heat_gauge_axis := Vector3.FORWARD
@export var heat_gauge_min_rotation_degrees := -85.0
@export var heat_gauge_max_rotation_degrees := 85.0
@export var heat_gauge_smoothing := 8.0

var _rpm_counter := RpmDigitCounter.new()
var _speed_handle: Node3D
var _speed_dial: Node3D
var _speed_handle_rest_basis := Basis.IDENTITY
var _speed_handle_part := ControlPanelInteractable.new()
var _speed_handle_hovered := false
var _dragging_speed_handle := false
var _active_touch_index := -1
var _big_stop_button: Node3D
var _big_stop_part := ControlPanelInteractable.new()
var _big_stop_hovered := false
var _mode_dial: Node3D
var _mode_dial_rest_basis := Basis.IDENTITY
var _mode_dial_part := ControlPanelInteractable.new()
var _mode_dial_hovered := false
var _dragging_mode_dial := false
var _governor_screwdriver: Node3D
var _governor_screwdriver_rest_position := Vector3.ZERO
var _governor_screwdriver_rest_basis := Basis.IDENTITY
var _governor_screwdriver_part := ControlPanelInteractable.new()
var _governor_screwdriver_hovered := false
var _governor_screwdriver_tween: Tween
var _governor_cooldown_sparks: GPUParticles3D
var _governor_cooldown_spark_material: ParticleProcessMaterial
var _panel_buttons: Dictionary = {}
var _panel_button_parts: Dictionary = {}
var _hovered_panel_button := ""
var _fault_indicator_parts: Dictionary = {}
var _heat_gauge_needle: Node3D
var _heat_gauge_needle_rest_basis := Basis.IDENTITY
var _heat_gauge_angle_degrees := 0.0
var _cursor_shape: Input.CursorShape = Input.CURSOR_ARROW
var _hover_refresh_elapsed := HOVER_REFRESH_INTERVAL
var _last_hover_mouse_position := Vector2(INF, INF)
var _last_hover_controls_locked := false


func _ready() -> void:
	_rpm_counter.bind(self, counter_digit_names)
	_setup_speed_handle()
	_setup_big_stop_button()
	_setup_mode_dial()
	_setup_governor_screwdriver()
	_setup_panel_buttons()
	_setup_fault_indicators()
	_setup_heat_gauge()
	_setup_mode_label_colors()
	RideState.faults_changed.connect(_refresh_fault_indicators)
	_update_counter()
	_update_speed_handle()
	_update_mode_dial()
	_update_heat_gauge(0.0)
	_refresh_fault_indicators()


func _process(_delta: float) -> void:
	_update_counter()
	_update_speed_handle()
	_update_mode_dial()
	_update_heat_gauge(_delta)
	_update_hover_state(_delta)
	_update_governor_cooldown_sparks()


func _update_hover_state(delta: float) -> void:
	_hover_refresh_elapsed += delta
	var mouse_position := get_viewport().get_mouse_position()
	var mouse_moved := mouse_position.distance_squared_to(_last_hover_mouse_position) > 0.25
	var controls_lock_changed := RideState.controls_locked != _last_hover_controls_locked
	var needs_refresh := (
		mouse_moved
		or controls_lock_changed
		or _dragging_speed_handle
		or _dragging_mode_dial
		or _active_touch_index != -1
		or _hover_refresh_elapsed >= HOVER_REFRESH_INTERVAL
	)
	if not needs_refresh:
		return

	_hover_refresh_elapsed = 0.0
	_last_hover_mouse_position = mouse_position
	_last_hover_controls_locked = RideState.controls_locked

	# Computed once here and reused below, since several of the hover/priority
	# checks need to know whether the pointer is on big stop, the mode dial,
	# or the governor screwdriver.
	var on_speed_handle := _active_touch_index == -1 and _is_pointer_on_speed_handle(mouse_position, handle_hit_padding)
	var on_big_stop := _active_touch_index == -1 and _is_pointer_on_big_stop(mouse_position, big_stop_hit_padding)
	var on_mode_dial := _active_touch_index == -1 and _is_pointer_on_mode_dial(mouse_position, mode_dial_hit_padding)
	var on_governor := _active_touch_index == -1 and _is_pointer_on_governor_screwdriver(mouse_position, governor_hit_padding)
	var higher_priority_hover := on_big_stop or on_mode_dial or on_governor
	var on_panel_button := "" if (_active_touch_index != -1 or higher_priority_hover) else _panel_button_at_position(mouse_position, panel_button_hit_padding)

	_update_speed_handle_hover(on_speed_handle)
	_update_big_stop_hover(on_big_stop)
	_update_mode_dial_hover(on_mode_dial)
	_update_governor_screwdriver_hover(on_governor, on_big_stop)
	_update_panel_button_hover(on_panel_button)
	_update_cursor_shape()


func _input(event: InputEvent) -> void:
	if RideState.controls_locked:
		return

	if event is InputEventKey:
		_handle_hotkey(event)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _is_pointer_on_big_stop(event.position, big_stop_hit_padding):
				_press_big_stop()
				get_viewport().set_input_as_handled()
			elif _is_pointer_on_mode_dial(event.position, mode_dial_hit_padding):
				_dragging_mode_dial = true
				_set_mode_from_screen_position(event.position)
				get_viewport().set_input_as_handled()
			elif _is_pointer_on_governor_screwdriver(event.position, governor_hit_padding):
				_press_governor_screwdriver()
				get_viewport().set_input_as_handled()
			else:
				var panel_button := _panel_button_at_position(event.position, panel_button_hit_padding)
				if panel_button != "":
					_press_panel_button(panel_button)
					get_viewport().set_input_as_handled()
				elif _speed_handle != null:
					_dragging_speed_handle = _is_pointer_on_speed_handle(event.position, handle_hit_padding)
					if _dragging_speed_handle:
						_set_speed_from_screen_position(event.position)
						get_viewport().set_input_as_handled()
		else:
			_dragging_speed_handle = false
			_dragging_mode_dial = false
	elif event is InputEventMouseMotion and _dragging_speed_handle:
		_set_speed_from_screen_position(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging_mode_dial:
		_set_mode_from_screen_position(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed and _active_touch_index == -1:
			if _is_pointer_on_big_stop(event.position, big_stop_touch_hit_padding):
				_active_touch_index = event.index
				_press_big_stop()
				get_viewport().set_input_as_handled()
			elif _is_pointer_on_mode_dial(event.position, mode_dial_touch_hit_padding):
				_active_touch_index = event.index
				_dragging_mode_dial = true
				_set_mode_from_screen_position(event.position)
				get_viewport().set_input_as_handled()
			elif _is_pointer_on_governor_screwdriver(event.position, governor_touch_hit_padding):
				_active_touch_index = event.index
				_press_governor_screwdriver()
				get_viewport().set_input_as_handled()
			else:
				var panel_button := _panel_button_at_position(event.position, panel_button_touch_hit_padding)
				if panel_button != "":
					_active_touch_index = event.index
					_press_panel_button(panel_button)
					get_viewport().set_input_as_handled()
				elif _speed_handle != null and _is_pointer_on_speed_handle(event.position, handle_touch_hit_padding):
					_active_touch_index = event.index
					_dragging_speed_handle = true
					_set_speed_from_screen_position(event.position)
					get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _active_touch_index:
			_active_touch_index = -1
			_dragging_speed_handle = false
			_dragging_mode_dial = false
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _active_touch_index:
		if _dragging_speed_handle:
			_set_speed_from_screen_position(event.position)
		elif _dragging_mode_dial:
			_set_mode_from_screen_position(event.position)
		get_viewport().set_input_as_handled()


# Keyboard mirror of the click handlers: q/w/e/r/t/y press a fault button,
# 1/2/3 pick a mode, space is Big Stop, shift bypasses the governor. Each path
# reuses the same _press_* / RideState calls a mouse click would, so animation,
# audio (via Events) and game logic stay identical. is_action_pressed() ignores
# key repeats by default, so a held key won't retrigger.
func _handle_hotkey(event: InputEvent) -> void:
	for action in panel_button_names:
		if event.is_action_pressed(action):
			_press_panel_button(action)
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("mode_1"):
		RideState.set_selected_mode(1)
	elif event.is_action_pressed("mode_2"):
		RideState.set_selected_mode(2)
	elif event.is_action_pressed("mode_3"):
		RideState.set_selected_mode(3)
	elif event.is_action_pressed("space"):
		_press_big_stop()
	elif event.is_action_pressed("governor"):
		_press_governor_screwdriver()
	else:
		return
	get_viewport().set_input_as_handled()


func _setup_speed_handle() -> void:
	if not _speed_handle_part.bind(self, speed_handle_name, handle_glow_color, handle_glow_energy):
		push_warning("Speed control handle '%s' was not found." % speed_handle_name)
		return

	_speed_handle = _speed_handle_part.node
	_speed_dial = find_child(String(speed_dial_name), true, false) as Node3D
	_speed_handle_rest_basis = _speed_handle_part.rest_basis


func _setup_big_stop_button() -> void:
	if not _big_stop_part.bind(self, big_stop_button_name, big_stop_glow_color, big_stop_glow_energy):
		push_warning("Big Stop button '%s' was not found." % big_stop_button_name)
		return

	_big_stop_button = _big_stop_part.node


func _setup_mode_dial() -> void:
	if not _mode_dial_part.bind(self, mode_dial_name, mode_dial_glow_color, mode_dial_glow_energy):
		push_warning("Mode select dial '%s' was not found." % mode_dial_name)
		return

	_mode_dial = _mode_dial_part.node
	_mode_dial_rest_basis = _mode_dial_part.rest_basis


func _setup_governor_screwdriver() -> void:
	if not _governor_screwdriver_part.bind(self, governor_screwdriver_name, governor_glow_color, governor_glow_energy):
		push_warning("Governor screwdriver '%s' was not found." % governor_screwdriver_name)
		return

	_governor_screwdriver = _governor_screwdriver_part.node
	_governor_screwdriver_rest_position = _governor_screwdriver_part.rest_position
	_governor_screwdriver_rest_basis = _governor_screwdriver_part.rest_basis
	_setup_governor_cooldown_sparks()


func _setup_panel_buttons() -> void:
	for action in panel_button_names:
		var part := ControlPanelInteractable.new()
		if not part.bind(self, panel_button_names[action], panel_button_glow_color, panel_button_glow_energy):
			push_warning("Panel button '%s' was not found." % panel_button_names[action])
			continue

		_panel_buttons[action] = part.node
		_panel_button_parts[action] = part
		if action == "t" or action == "y":
			print("PANEL: %s button wired up (node %s) - press/highlight animation active" % [
				action.to_upper(),
				part.node.name,
			])


func _setup_fault_indicators() -> void:
	for action in fault_indicator_names:
		var part := ControlPanelInteractable.new()
		if not part.bind(self, fault_indicator_names[action], fault_indicator_safe_color, fault_indicator_energy):
			continue

		part.set_surface_material_template(FAULT_INDICATOR_MATERIAL)
		_fault_indicator_parts[action] = part
		if action == "t" or action == "y":
			print("PANEL: %s indicator light wired up (node %s)" % [action.to_upper(), part.node.name])

	if _fault_indicator_parts.size() >= fault_indicator_names.size():
		return

	var ordered_indicators := _ordered_fault_indicator_nodes()
	if ordered_indicators.size() >= fault_indicator_names.size():
		_fault_indicator_parts.clear()
		var actions := ["q", "w", "e", "r", "t", "y"]
		for i in mini(actions.size(), ordered_indicators.size()):
			var part := ControlPanelInteractable.new()
			part.bind_node(ordered_indicators[i], fault_indicator_safe_color, fault_indicator_energy)
			part.set_surface_material_template(FAULT_INDICATOR_MATERIAL)
			_fault_indicator_parts[actions[i]] = part
			if actions[i] == "t" or actions[i] == "y":
				print("PANEL: %s indicator light wired up via fallback ordering (node %s)" % [
					actions[i].to_upper(),
					ordered_indicators[i].name,
				])
		return

	if _fault_indicator_parts.is_empty():
		push_warning("No fault indicator lights were found.")


func _setup_heat_gauge() -> void:
	if String(heat_gauge_needle_path) != "":
		_heat_gauge_needle = get_node_or_null(heat_gauge_needle_path) as Node3D
	if _heat_gauge_needle == null:
		_heat_gauge_needle = find_child(String(heat_gauge_needle_name), true, false) as Node3D
	if _heat_gauge_needle == null:
		push_warning("Heat gauge needle '%s' was not found." % heat_gauge_needle_name)
		return

	_heat_gauge_needle_rest_basis = _heat_gauge_needle.basis
	_heat_gauge_angle_degrees = heat_gauge_min_rotation_degrees
	print("AXLE HEAT: gauge needle found at %s, axis=%s" % [
		_heat_gauge_needle.get_path(),
		heat_gauge_axis,
	])


func _setup_mode_label_colors() -> void:
	for label_name in MODE_LABELS:
		var source := find_child(String(label_name), true, false) as MeshInstance3D
		if source == null:
			push_warning("Mode selector label '%s' was not found." % label_name)
			continue

		var config: Dictionary = MODE_LABELS[label_name]
		var bounds := source.get_aabb()
		var plate_size := Vector2(bounds.size.x, bounds.size.z)
		if plate_size.x <= 0.0 or plate_size.y <= 0.0:
			push_warning("Mode selector label '%s' had invalid bounds." % label_name)
			continue

		var parent := source.get_parent()
		var replacement := Node3D.new()
		replacement.name = "%s_colored" % source.name
		replacement.transform = source.transform
		parent.add_child(replacement)
		parent.move_child(replacement, source.get_index() + 1)

		_add_mode_label_border(replacement, plate_size)

		var plate := MeshInstance3D.new()
		plate.name = "background"
		var plate_mesh := PlaneMesh.new()
		plate_mesh.size = plate_size
		plate.mesh = plate_mesh
		plate.material_override = _make_mode_label_material(config["background"])
		plate.position = Vector3(0.0, 0.0008, 0.0)
		replacement.add_child(plate)

		var number := MeshInstance3D.new()
		number.name = "number"
		var text_mesh := TextMesh.new()
		text_mesh.text = String(config["text"])
		text_mesh.font_size = 36
		text_mesh.depth = 0.001
		text_mesh.pixel_size = 0.00155
		text_mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number.mesh = text_mesh
		number.material_override = _make_mode_label_material(config["foreground"])
		number.position = Vector3(0.0, 0.0022, 0.0)
		number.rotation.x = deg_to_rad(-90.0)
		replacement.add_child(number)

		source.visible = false


func _add_mode_label_border(parent: Node3D, plate_size: Vector2) -> void:
	var border_width := maxf(minf(plate_size.x, plate_size.y) * MODE_LABEL_BORDER_WIDTH_FRACTION, 0.002)
	var half_size := plate_size * 0.5
	var black_material := _make_mode_label_material(MODE_LABEL_BORDER_COLOR)
	var shade_material := _make_mode_label_material(MODE_LABEL_BORDER_SHADE_COLOR)

	_add_mode_label_border_strip(
		parent,
		"border_top",
		Vector2(plate_size.x + border_width * 2.0, border_width),
		Vector3(0.0, 0.001, -half_size.y - border_width * 0.5),
		black_material
	)
	_add_mode_label_border_strip(
		parent,
		"border_left",
		Vector2(border_width, plate_size.y),
		Vector3(-half_size.x - border_width * 0.5, 0.001, 0.0),
		black_material
	)
	_add_mode_label_border_strip(
		parent,
		"border_bottom",
		Vector2(plate_size.x + border_width * 2.0, border_width),
		Vector3(0.0, 0.001, half_size.y + border_width * 0.5),
		shade_material
	)
	_add_mode_label_border_strip(
		parent,
		"border_right",
		Vector2(border_width, plate_size.y),
		Vector3(half_size.x + border_width * 0.5, 0.001, 0.0),
		shade_material
	)


func _add_mode_label_border_strip(parent: Node3D, strip_name: String, strip_size: Vector2, strip_position: Vector3, material: Material) -> void:
	var strip := MeshInstance3D.new()
	strip.name = strip_name
	var strip_mesh := PlaneMesh.new()
	strip_mesh.size = strip_size
	strip.mesh = strip_mesh
	strip.material_override = material
	strip.position = strip_position
	parent.add_child(strip)


func _make_mode_label_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "mode_label_%s" % color.to_html(false)
	material.albedo_color = color
	material.roughness = 0.78
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _ordered_fault_indicator_nodes() -> Array[Node3D]:
	var indicators: Array[Node3D] = []
	_collect_fault_indicator_nodes(self, indicators)
	indicators.sort_custom(_sort_fault_indicators)
	return indicators


func _collect_fault_indicator_nodes(node: Node, indicators: Array[Node3D]) -> void:
	if node is Node3D and node.name.begins_with("indicatorLight_light"):
		indicators.append(node)
	for child in node.get_children():
		_collect_fault_indicator_nodes(child, indicators)


func _sort_fault_indicators(a: Node3D, b: Node3D) -> bool:
	if not is_equal_approx(a.global_position.z, b.global_position.z):
		return a.global_position.z < b.global_position.z
	return a.global_position.x < b.global_position.x


func _update_counter() -> void:
	_rpm_counter.update(RideState.angular_velocity, spin_axis, spin_direction)


func _update_speed_handle() -> void:
	if _speed_handle == null:
		return

	var t := _target_rpm_to_unit(RideState.target_rpm)
	var angle := lerpf(speed_stop_angle, speed_fast_angle, t)
	var axis := speed_handle_axis.normalized()
	if axis.length_squared() <= 0.0:
		axis = Vector3.FORWARD

	_speed_handle.basis = Basis(axis, angle) * _speed_handle_rest_basis


func _update_mode_dial() -> void:
	if _mode_dial == null:
		return

	var axis := mode_dial_axis.normalized()
	if axis.length_squared() <= 0.0:
		axis = Vector3.FORWARD

	_mode_dial.basis = _mode_dial_rest_basis * Basis(axis, _mode_angle_for_mode(RideState.selected_mode))


func _update_heat_gauge(delta: float) -> void:
	if _heat_gauge_needle == null:
		return

	var max_heat := maxf(RideState.rpm_max, 1.0)
	var heat_percent := clampf(RideState.axle_heat / max_heat, 0.0, 1.0)
	var target_angle := lerpf(heat_gauge_min_rotation_degrees, heat_gauge_max_rotation_degrees, heat_percent)
	var smoothing := clampf(heat_gauge_smoothing, 0.0, 60.0)
	var weight := 1.0 if delta <= 0.0 or smoothing <= 0.0 else 1.0 - exp(-smoothing * delta)
	_heat_gauge_angle_degrees = lerpf(_heat_gauge_angle_degrees, target_angle, weight)

	var axis := heat_gauge_axis.normalized()
	if axis.length_squared() <= 0.0:
		axis = Vector3.FORWARD

	_heat_gauge_needle.basis = _heat_gauge_needle_rest_basis * Basis(axis, deg_to_rad(_heat_gauge_angle_degrees))


func _update_speed_handle_hover(pointer_on_handle: bool) -> void:
	if _speed_handle == null:
		return
	if RideState.controls_locked:
		if _speed_handle_hovered:
			_speed_handle_hovered = false
			_set_speed_handle_glow(false)
		return

	var hovered := _dragging_speed_handle or pointer_on_handle
	if hovered == _speed_handle_hovered:
		return

	_speed_handle_hovered = hovered
	_set_speed_handle_glow(hovered)


func _update_big_stop_hover(pointer_on_big_stop: bool) -> void:
	if _big_stop_button == null:
		return
	if RideState.controls_locked:
		if _big_stop_hovered:
			_big_stop_hovered = false
			_set_big_stop_glow(false)
		return

	if pointer_on_big_stop == _big_stop_hovered:
		return

	_big_stop_hovered = pointer_on_big_stop
	_set_big_stop_glow(pointer_on_big_stop)


func _update_mode_dial_hover(pointer_on_mode_dial: bool) -> void:
	if _mode_dial == null:
		return
	if RideState.controls_locked:
		if _mode_dial_hovered:
			_mode_dial_hovered = false
			_set_mode_dial_glow(false)
		return

	var hovered := _dragging_mode_dial or pointer_on_mode_dial
	if hovered == _mode_dial_hovered:
		return

	_mode_dial_hovered = hovered
	_set_mode_dial_glow(hovered)


func _update_governor_screwdriver_hover(pointer_on_governor: bool, pointer_on_big_stop: bool) -> void:
	if _governor_screwdriver == null:
		return
	if RideState.controls_locked:
		if _governor_screwdriver_hovered:
			_governor_screwdriver_hovered = false
			_set_governor_screwdriver_glow(false)
		return

	var hovered := pointer_on_governor and not pointer_on_big_stop
	if hovered == _governor_screwdriver_hovered:
		return

	_governor_screwdriver_hovered = hovered
	_set_governor_screwdriver_glow(hovered)


func _update_governor_cooldown_sparks() -> void:
	if _governor_cooldown_sparks == null or _governor_screwdriver == null:
		return

	_governor_cooldown_sparks.global_position = _governor_spark_position()
	_governor_cooldown_sparks.emitting = (
		RideState.governor_prime_time_left > 0.0
		or RideState.governor_override_time_left > 0.0
		or RideState.governor_cooldown_left > 0.0
	)


func _update_panel_button_hover(hovered_action: String) -> void:
	if RideState.controls_locked:
		if _hovered_panel_button != "":
			_set_panel_button_glow(_hovered_panel_button, false)
			_hovered_panel_button = ""
		return

	if hovered_action == _hovered_panel_button:
		return

	if _hovered_panel_button != "":
		_set_panel_button_glow(_hovered_panel_button, false)
	_hovered_panel_button = hovered_action
	if _hovered_panel_button != "":
		_set_panel_button_glow(_hovered_panel_button, true)


func _update_cursor_shape() -> void:
	if RideState.controls_locked:
		_set_cursor_shape(Input.CURSOR_ARROW)
		return

	var hovering_interactable := (
		_speed_handle_hovered
		or _big_stop_hovered
		or _mode_dial_hovered
		or _governor_screwdriver_hovered
		or _hovered_panel_button != ""
		or _dragging_speed_handle
		or _dragging_mode_dial
	)
	_set_cursor_shape(Input.CURSOR_POINTING_HAND if hovering_interactable else Input.CURSOR_ARROW)


func _set_cursor_shape(shape: Input.CursorShape) -> void:
	if shape == _cursor_shape:
		return
	_cursor_shape = shape
	Input.set_default_cursor_shape(shape)


func _is_pointer_on_speed_handle(screen_position: Vector2, padding: float) -> bool:
	var camera := get_viewport().get_camera_3d()
	return _speed_handle_part.contains_screen_point(camera, screen_position, padding)


func _is_pointer_on_big_stop(screen_position: Vector2, padding: float) -> bool:
	var camera := get_viewport().get_camera_3d()
	return _big_stop_part.contains_screen_point(camera, screen_position, padding)


func _is_pointer_on_mode_dial(screen_position: Vector2, padding: float) -> bool:
	var camera := get_viewport().get_camera_3d()
	return _mode_dial_part.contains_screen_point(camera, screen_position, padding)


func _is_pointer_on_governor_screwdriver(screen_position: Vector2, padding: float) -> bool:
	var camera := get_viewport().get_camera_3d()
	return _governor_screwdriver_part.contains_screen_point(camera, screen_position, padding)


func _panel_button_at_position(screen_position: Vector2, padding: float) -> String:
	for action in panel_button_names:
		if _is_pointer_on_panel_button(action, screen_position, padding):
			return action
	return ""


func _is_pointer_on_panel_button(action: String, screen_position: Vector2, padding: float) -> bool:
	if not _panel_button_parts.has(action):
		return false

	var camera := get_viewport().get_camera_3d()
	var part := _panel_button_parts[action] as ControlPanelInteractable
	return part.contains_screen_point(camera, screen_position, padding)


func _press_big_stop() -> void:
	if _big_stop_button == null:
		return

	RideState.big_stop()
	_big_stop_part.animate_press(self, big_stop_press_offset, big_stop_press_in_time, big_stop_pop_back_time)


func _press_governor_screwdriver() -> void:
	if _governor_screwdriver == null:
		return
	if not RideState.request_governor_override():
		return

	if _governor_screwdriver_tween != null:
		_governor_screwdriver_tween.kill()

	_governor_screwdriver.position = _governor_screwdriver_rest_position
	_governor_screwdriver.basis = _governor_screwdriver_rest_basis
	_governor_screwdriver_tween = create_tween()
	_governor_screwdriver_tween.set_parallel(false)
	_governor_screwdriver_tween.tween_property(
		_governor_screwdriver,
		"position",
		_governor_screwdriver_rest_position + governor_press_offset,
		governor_press_time
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_governor_screwdriver_tween.tween_property(
		_governor_screwdriver,
		"basis",
		_governor_screwdriver_rest_basis * Basis(Vector3.FORWARD, governor_jiggle_angle),
		governor_jiggle_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_governor_screwdriver_tween.tween_property(
		_governor_screwdriver,
		"basis",
		_governor_screwdriver_rest_basis * Basis(Vector3.FORWARD, -governor_jiggle_angle),
		governor_jiggle_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_governor_screwdriver_tween.parallel().tween_property(
		_governor_screwdriver,
		"position",
		_governor_screwdriver_rest_position,
		governor_release_time
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_governor_screwdriver_tween.parallel().tween_property(
		_governor_screwdriver,
		"basis",
		_governor_screwdriver_rest_basis,
		governor_release_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _press_panel_button(action: String) -> void:
	if not _panel_buttons.has(action):
		return

	if RideState.FAULT_ACTIONS.has(action):
		var cleared := RideState.clear_fault(action, RideState.selected_mode)
		if not cleared:
			var fault_mode := RideState.get_fault_mode(action)
			if fault_mode > 0:
				print("PANEL: %s pressed but needs mode %d (selected %d)" % [
					action.to_upper(),
					fault_mode,
					RideState.selected_mode,
				])
	Events.panel_button_pressed.emit(action)

	var part := _panel_button_parts[action] as ControlPanelInteractable
	part.animate_press(self, panel_button_press_offset, panel_button_press_in_time, panel_button_pop_back_time)


func _refresh_fault_indicators() -> void:
	for action in fault_indicator_names:
		var mode := RideState.get_fault_mode(action)
		var color := fault_indicator_safe_color
		var energy := fault_indicator_off_energy
		if mode == 3:
			color = fault_indicator_color
			energy = fault_indicator_energy
		elif mode == 2:
			color = fault_indicator_warning_color
			energy = fault_indicator_energy
		_set_fault_indicator_color(action, color, energy)


func _set_mode_from_screen_position(screen_position: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or _mode_dial == null:
		return

	var center := camera.unproject_position(_mode_dial.global_position)
	var vector := screen_position - center
	if vector.length_squared() <= 16.0:
		return

	var clock_angle := rad_to_deg(atan2(vector.x, -vector.y))
	if clock_angle < 0.0:
		clock_angle += 360.0

	var targets := [300.0, 270.0, 210.0]
	var best_mode := 1
	var best_distance := INF
	for i in targets.size():
		var distance := absf(angle_difference(deg_to_rad(clock_angle), deg_to_rad(targets[i])))
		if distance < best_distance:
			best_distance = distance
			best_mode = i + 1

	RideState.set_selected_mode(best_mode)


func _set_speed_from_screen_position(screen_position: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var dial_position := _speed_dial_screen_position(camera)
	var radius := maxf(drag_screen_radius, 1.0)
	var t := clampf((screen_position.x - (dial_position.x - radius)) / (radius * 2.0), 0.0, 1.0)
	RideState.target_rpm = BAND_TARGETS[_unit_to_band_index(t)]


func _speed_dial_screen_position(camera: Camera3D) -> Vector2:
	var dial_node := _speed_dial if _speed_dial != null else _speed_handle
	if camera.is_position_behind(dial_node.global_position):
		return get_viewport().get_mouse_position()
	return camera.unproject_position(dial_node.global_position)


func _setup_governor_cooldown_sparks() -> void:
	var spark_mesh := QuadMesh.new()
	spark_mesh.size = Vector2(0.045, 0.045)

	var spark_material := StandardMaterial3D.new()
	spark_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.albedo_color = governor_cooldown_spark_color
	spark_material.emission_enabled = true
	spark_material.emission = governor_cooldown_spark_color
	spark_material.emission_energy_multiplier = 2.8
	spark_mesh.material = spark_material

	_governor_cooldown_spark_material = ParticleProcessMaterial.new()
	_governor_cooldown_spark_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_governor_cooldown_spark_material.emission_sphere_radius = 0.025
	_governor_cooldown_spark_material.direction = Vector3(0.0, 0.35, -0.25)
	_governor_cooldown_spark_material.spread = 75.0
	_governor_cooldown_spark_material.gravity = Vector3(0.0, -2.4, 0.0)
	_governor_cooldown_spark_material.initial_velocity_min = 0.35
	_governor_cooldown_spark_material.initial_velocity_max = 1.6
	_governor_cooldown_spark_material.scale_min = 0.45
	_governor_cooldown_spark_material.scale_max = 1.0
	_governor_cooldown_spark_material.color = governor_cooldown_spark_color

	_governor_cooldown_sparks = GPUParticles3D.new()
	_governor_cooldown_sparks.name = "GovernorCooldownSparks"
	_governor_cooldown_sparks.amount = _web_particle_amount(governor_cooldown_spark_amount)
	_governor_cooldown_sparks.amount_ratio = 1.0
	_governor_cooldown_sparks.lifetime = governor_cooldown_spark_lifetime
	_governor_cooldown_sparks.explosiveness = 0.65
	_governor_cooldown_sparks.randomness = 0.9
	_governor_cooldown_sparks.emitting = false
	_governor_cooldown_sparks.process_material = _governor_cooldown_spark_material
	_governor_cooldown_sparks.draw_pass_1 = spark_mesh
	add_child(_governor_cooldown_sparks)
	_governor_cooldown_sparks.global_position = _governor_spark_position()


func _web_particle_amount(base_amount: int) -> int:
	if OS.has_feature("web"):
		return maxi(1, roundi(float(base_amount) * WEB_PARTICLE_SCALE))
	return base_amount


func _set_speed_handle_glow(enabled: bool) -> void:
	_speed_handle_part.set_glow(enabled)


func _set_big_stop_glow(enabled: bool) -> void:
	_big_stop_part.set_glow(enabled)


func _set_mode_dial_glow(enabled: bool) -> void:
	_mode_dial_part.set_glow(enabled)


func _set_governor_screwdriver_glow(enabled: bool) -> void:
	_governor_screwdriver_part.set_glow(enabled)


func _set_panel_button_glow(action: String, enabled: bool) -> void:
	if not _panel_button_parts.has(action):
		return
	var part := _panel_button_parts[action] as ControlPanelInteractable
	part.set_glow(enabled)


func _set_fault_indicator_color(action: String, color: Color, energy: float) -> void:
	if not _fault_indicator_parts.has(action):
		return
	var part := _fault_indicator_parts[action] as ControlPanelInteractable
	part.set_glow_color(color, energy)


func _governor_spark_position() -> Vector3:
	if _governor_screwdriver == null:
		return global_position
	return _governor_screwdriver.to_global(governor_cooldown_spark_offset)


func _mode_angle_for_mode(mode: int) -> float:
	match clampi(mode, 1, 3):
		1:
			return mode_one_angle
		2:
			return mode_two_angle
		3:
			return mode_three_angle
		_:
			return mode_one_angle


func _target_rpm_to_unit(target_rpm: float) -> float:
	return float(_nearest_band_index(target_rpm)) / float(BAND_TARGETS.size() - 1)


func _unit_to_band_index(value: float) -> int:
	return clampi(roundi(value * float(BAND_TARGETS.size() - 1)), 0, BAND_TARGETS.size() - 1)


func _nearest_band_index(target_rpm: float) -> int:
	var best_index := 0
	var best_distance := INF
	for i in BAND_TARGETS.size():
		var distance := absf(BAND_TARGETS[i] - target_rpm)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index
