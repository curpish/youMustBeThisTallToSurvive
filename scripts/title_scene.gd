extends Node3D

const CREDITS := [
	["Trine", "Music, mixing, audio engineering"],
	["Dan", "Foley / voice, writing"],
	["Pmayer", "QA, testing, documentation (ride-operator domain knowledge)"],
	["Eggs", "Modeling, programming, general"],
	["pcpuppet", "Programming, design, general (modular models; movement math)"],
	["Yam", "Artist, 2D/3D, world art"],
	["Coopy", "Programming, design, ui, audio engineering, general (state machine + variables)"],
]

@export var wheel_spin_speed := 0.18
@export var credits_roll_speed := 45.0
@export var spin_direction := -1.0
@export var gondola_orbit_radius := 7.2
@export var gondola_hang_offset := 2.6
@export_range(1, 8, 1) var gondola_count := 6

var _wheel: Node3D
var _basket: Node3D
var _rider: Node3D
var _wheel_angle := 0.0
var _wheel_rest_basis := Basis.IDENTITY
var _basket_basis := Basis.IDENTITY
var _rider_basis := Basis.IDENTITY
var _rider_offset_from_basket := Vector3.ZERO
var _gondola_center_x := 0.0
var _baskets: Array[Node3D] = []
var _riders: Array[Node3D] = []
var _socket_local_positions: Array[Vector3] = []
var _main_menu: VBoxContainer
var _difficulty_menu: VBoxContainer
var _credits_layer: Control
var _credits_label: Label
var _return_button: Button
var _credits_rolling := false


func _ready() -> void:
	GameOrchestrator.phase = GameOrchestrator.Phase.BOARDING
	get_viewport().size_changed.connect(_on_viewport_resized)
	_setup_ferris_preview()
	_build_fog()
	_build_ui()
	_show_main_menu()


func _process(delta: float) -> void:
	if is_instance_valid(_wheel):
		_wheel_angle += wheel_spin_speed * delta
		_wheel.basis = Basis(Vector3.RIGHT, spin_direction * _wheel_angle) * _wheel_rest_basis
		_update_gondolas()
	if _credits_rolling:
		_update_credits(delta)


func _on_viewport_resized() -> void:
	if is_instance_valid(_credits_label):
		_reset_credits_position()



func _find_wheel() -> Node3D:
	var names := [&"frame_wheel", &"wheel", &"Wheel"]
	for node_name in names:
		var found := find_child(node_name, true, false)
		if found is Node3D:
			return found
	return null


func _setup_ferris_preview() -> void:
	_wheel = _find_wheel()
	_basket = _find_node3d("basket")
	_rider = _find_node3d("kid_one")

	if _wheel == null or _basket == null:
		push_warning("Title scene could not find the ferris wheel preview nodes.")
		return

	_wheel_rest_basis = _wheel.basis
	_basket_basis = _basket.global_basis
	_gondola_center_x = _get_frame_center_x()

	if _rider != null:
		_rider_basis = _rider.global_basis
		_rider_offset_from_basket = _rider.global_position - _basket.global_position

	for node_name in [&"rope_a", &"rope_b", &"rope_c", &"rope_d"]:
		var rope := _find_node3d(node_name)
		if rope != null:
			rope.visible = false

	_create_gondolas()
	_update_gondolas()


func _find_node3d(node_name: StringName) -> Node3D:
	var found := find_child(node_name, true, false)
	if found is Node3D:
		return found
	return null


func _create_gondolas() -> void:
	_baskets.clear()
	_riders.clear()
	_socket_local_positions.clear()

	var basket_parent := _basket.get_parent()
	var rider_is_inside_basket := _rider != null and _is_descendant_of(_rider, _basket)
	var rider_parent := _rider.get_parent() if _rider != null else null
	var count := clampi(gondola_count, 1, 8)

	for index in count:
		var basket := _basket
		var rider := _rider

		if index > 0:
			basket = _basket.duplicate()
			basket.name = "title_basket_%02d" % [index + 1]
			basket_parent.add_child(basket)

			if rider_is_inside_basket:
				rider = basket.find_child(_rider.name, true, false) as Node3D
			elif _rider != null and rider_parent != null:
				rider = _rider.duplicate()
				rider.name = "title_kid_%02d" % [index + 1]
				rider_parent.add_child(rider)

		_baskets.append(basket)
		_riders.append(rider)

		var angle := TAU * float(index) / float(count)
		var socket_world_position := _wheel.global_position + Vector3(
			0.0,
			sin(angle) * gondola_orbit_radius,
			cos(angle) * gondola_orbit_radius
		)
		_socket_local_positions.append(_wheel.to_local(socket_world_position))


func _update_gondolas() -> void:
	for index in _baskets.size():
		var basket := _baskets[index]
		var rider := _riders[index]
		var attachment := _wheel.to_global(_socket_local_positions[index])
		attachment.x = _gondola_center_x

		var basket_position := attachment + Vector3.DOWN * gondola_hang_offset
		basket_position.x = _gondola_center_x
		basket.global_position = basket_position
		basket.global_basis = _basket_basis

		if rider != null:
			rider.global_position = basket.global_position + _rider_offset_from_basket
			rider.global_basis = _rider_basis


func _is_descendant_of(node: Node, possible_parent: Node) -> bool:
	var parent := node.get_parent()
	while parent != null:
		if parent == possible_parent:
			return true
		parent = parent.get_parent()
	return false


func _get_frame_center_x() -> float:
	var left_arm := _find_node3d(&"frame_arm_left")
	var right_arm := _find_node3d(&"frame_arm_right")
	if left_arm != null and right_arm != null:
		return (left_arm.global_position.x + right_arm.global_position.x) * 0.5
	return _wheel.global_position.x


func _build_fog() -> void:
	var fog := GPUParticles3D.new()
	fog.name = "TitleFog"
	fog.amount = 80
	fog.lifetime = 9.0
	fog.visibility_aabb = AABB(Vector3(-24.0, -6.0, -14.0), Vector3(48.0, 16.0, 28.0))
	fog.position = Vector3(0.0, 1.5, -1.0)
	fog.draw_pass_1 = _make_fog_mesh()
	fog.process_material = _make_fog_process_material()
	fog.emitting = true
	add_child(fog)


func _make_fog_mesh() -> QuadMesh:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.62, 0.68, 0.66, 0.18)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.disable_receive_shadows = true

	var mesh := QuadMesh.new()
	mesh.size = Vector2(7.0, 2.2)
	mesh.material = material
	return mesh


func _make_fog_process_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(15.0, 2.8, 5.0)
	material.direction = Vector3(-0.25, 0.02, 0.0)
	material.spread = 42.0
	material.initial_velocity_min = 0.04
	material.initial_velocity_max = 0.18
	material.gravity = Vector3.ZERO
	material.scale_min = 0.8
	material.scale_max = 1.35
	return material


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TitleUi"
	add_child(layer)

	var root := Control.new()
	root.name = "TitleRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	var title := Label.new()
	title.text = "YOU MUST BE THIS TALL TO SURVIVE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.54))
	title.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.0))
	title.add_theme_constant_override("outline_size", 8)
	title.anchor_left = 0.055
	title.anchor_top = 0.12
	title.anchor_right = 0.82
	title.anchor_bottom = 0.24
	root.add_child(title)

	_main_menu = _make_menu(Vector2(0.07, 0.48), root)
	_main_menu.add_child(_make_button("Play Game", _on_play_pressed))
	_main_menu.add_child(_make_button("Credits", _on_credits_pressed))

	_difficulty_menu = _make_menu(Vector2(0.07, 0.46), root)
	_difficulty_menu.add_child(_make_button("Normal", _on_normal_pressed))
	_difficulty_menu.add_child(_make_button("Hard", _on_hard_pressed))
	_difficulty_menu.add_child(_make_button("Back", _show_main_menu))

	_credits_layer = Control.new()
	_credits_layer.name = "CreditsLayer"
	_credits_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_credits_layer)

	_credits_label = Label.new()
	_credits_label.text = _format_credits()
	_credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_credits_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_credits_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_credits_label.add_theme_font_size_override("font_size", 34)
	_credits_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
	_credits_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	_credits_label.add_theme_constant_override("outline_size", 6)
	_credits_layer.add_child(_credits_label)

	_return_button = _make_button("Return to Menu", _show_main_menu)
	_return_button.anchor_left = 0.055
	_return_button.anchor_top = 0.82
	_return_button.anchor_right = 0.27
	_return_button.anchor_bottom = 0.9
	_return_button.size_flags_horizontal = Control.SIZE_FILL
	_credits_layer.add_child(_return_button)


func _make_menu(anchor: Vector2, parent: Control) -> VBoxContainer:
	var menu := VBoxContainer.new()
	menu.custom_minimum_size = Vector2(320.0, 150.0)
	menu.anchor_left = anchor.x
	menu.anchor_top = anchor.y
	menu.anchor_right = anchor.x + 0.22
	menu.anchor_bottom = anchor.y + 0.2
	menu.add_theme_constant_override("separation", 14)
	parent.add_child(menu)
	return menu


func _make_button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(300.0, 58.0)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.06, 0.05, 0.04, 0.78), Color(0.95, 0.75, 0.28)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.08, 0.16, 0.2, 0.9), Color(0.25, 0.72, 1.0)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.02, 0.08, 0.1, 0.95), Color(0.25, 0.72, 1.0)))
	button.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	button.add_theme_color_override("font_hover_color", Color(0.72, 0.95, 1.0))
	button.pressed.connect(callback)
	return button


func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 18
	style.content_margin_right = 18
	return style


func _format_credits() -> String:
	var lines := ["CREDITS", ""]
	for credit in CREDITS:
		lines.append("%s" % credit[0])
		lines.append("%s" % credit[1])
		lines.append("")
	return "\n".join(lines)


func _on_play_pressed() -> void:
	_main_menu.visible = false
	_difficulty_menu.visible = true
	_credits_layer.visible = false
	_credits_rolling = false


func _on_normal_pressed() -> void:
	GameOrchestrator.start_stage_one("normal")


func _on_hard_pressed() -> void:
	GameOrchestrator.start_stage_one("hard")


func _on_credits_pressed() -> void:
	_main_menu.visible = false
	_difficulty_menu.visible = false
	_credits_layer.visible = true
	_credits_rolling = true
	_reset_credits_position()


func _show_main_menu() -> void:
	_credits_rolling = false
	_main_menu.visible = true
	_difficulty_menu.visible = false
	_credits_layer.visible = false


func _reset_credits_position() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_credits_label.custom_minimum_size = Vector2(min(viewport_size.x * 0.78, 1160.0), 0.0)
	_credits_label.size = Vector2(min(viewport_size.x * 0.78, 1160.0), 1.0)
	_credits_label.position = Vector2((viewport_size.x - _credits_label.size.x) * 0.5, viewport_size.y + 40.0)


func _update_credits(delta: float) -> void:
	_credits_label.position.y -= credits_roll_speed * delta
	if _credits_label.position.y + _credits_label.get_minimum_size().y < -60.0:
		_show_main_menu()
