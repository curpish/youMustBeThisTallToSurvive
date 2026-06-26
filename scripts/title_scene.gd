extends Node3D

const CREDITS := [
	["NetherYam", "Art Lead & Concept Artist"],
	["Eggsnbaconbits", "3D Modeling"],
	["Officer Dan", "Hand-model, Sound & Voice Over"],
	["PmayerW", "Document Designer"],
	["PcPuppet", "Programming Lead, 3D Modeling"],
	["CoopyCopa", "Jam Lead, Sound Engineer, Programmer"],
	["The Adam Butler", "Music"],
]
const WEB_FOG_AMOUNT := 3
const TITLE_BGM := preload("res://assets/audio/music/Survive Main Menu.ogg") # is at 120 bpm
const CREDITS_BACKDROP_SHADER := preload("res://scripts/ui/credits_backdrop.gdshader")

# Sentimental concept-art slideshow shown while the credits roll. Each image
# fades in at a different spot, lingers, then fades away; the next begins its
# fade-in as the current fades out for a gentle crossfade.
const CONCEPT_IMAGES := [
	preload("res://reference/image.png"),
	preload("res://reference/IMG_0342.png"),
	preload("res://reference/image0.jpg"),
	preload("res://reference/IMG_0343.png"),
	preload("res://reference/marry.png"),
	preload("res://reference/IMG_0344.png"),
]
# Scattered placements (screen-fraction center, tilt, relative size). Tuned to
# stay clear of the title and read as a casual photo wall behind the names.
const CONCEPT_PLACEMENTS := [
	{"pos": Vector2(0.26, 0.42), "rot": -5.0, "scale": 0.95},
	{"pos": Vector2(0.74, 0.58), "rot": 4.0, "scale": 1.05},
	{"pos": Vector2(0.30, 0.70), "rot": 3.0, "scale": 0.85},
	{"pos": Vector2(0.72, 0.34), "rot": -4.0, "scale": 0.9},
	{"pos": Vector2(0.22, 0.55), "rot": 6.0, "scale": 1.0},
	{"pos": Vector2(0.78, 0.74), "rot": -3.0, "scale": 0.8},
]
@export var concept_fade_in := 1.6
@export var concept_hold := 4.5
@export var concept_fade_out := 1.8
@export var concept_base_fraction := 0.42  # image size vs. the screen's short edge

@export var wheel_spin_speed := 0.18
@export var credits_roll_speed := 45.0
@export var title_music_volume_db := -6.0
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
var _concept_layer: Control
var _concept_index := 0
var _credits_label: Label
var _return_button: Button
var _credits_rolling := false
var _credits_finishing := false
var _title_music: AudioStreamPlayer
var _ui_root: Control
var _options: OptionsPanel


func _ready() -> void:
	GameOrchestrator.phase = GameOrchestrator.Phase.BOARDING
	if OS.has_feature("web"):
		_disable_light_shadows(self)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_setup_title_music()
	_setup_ferris_preview()
	_build_fog()
	_build_ui()
	_show_main_menu()


func _disable_light_shadows(node: Node) -> void:
	if node is Light3D:
		(node as Light3D).shadow_enabled = false
	for child in node.get_children():
		_disable_light_shadows(child)


func _setup_title_music() -> void:
	if DisplayServer.get_name() == "headless":
		return

	_title_music = AudioStreamPlayer.new()
	_title_music.name = "TitleMusic"
	_title_music.bus = "Music"
	_title_music.stream = TITLE_BGM
	_title_music.volume_db = title_music_volume_db
	add_child(_title_music)
	_ensure_title_music_loop()
	_force_music_bus_dry()
	_title_music.play()


# The title has no stage_one_music driving the Music-bus reverb, so it would sit
# at its authored wet default. Force a fully dry signal so the menu track is
# clean. stage_one_music re-applies its own dry/wet when gameplay starts.
func _force_music_bus_dry() -> void:
	var bus_index := AudioServer.get_bus_index("Music")
	if bus_index < 0:
		return
	for i in AudioServer.get_bus_effect_count(bus_index):
		var effect := AudioServer.get_bus_effect(bus_index, i)
		if effect is AudioEffectReverb:
			effect.dry = 1.0
			effect.wet = 0.0
			return


func _ensure_title_music_loop() -> void:
	if _title_music.stream == null:
		return
	if _title_music.stream is AudioStreamWAV:
		(_title_music.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif "loop" in _title_music.stream:
		_title_music.stream.loop = true


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
	fog.amount = WEB_FOG_AMOUNT if OS.has_feature("web") else 80
	fog.fixed_fps = 24 if OS.has_feature("web") else 0
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
	_main_menu.add_child(_make_button("Options", _on_options_pressed))
	_main_menu.add_child(_make_button("Credits", _on_credits_pressed))
	_main_menu.add_child(_make_button("Gameplay Feedback Survey", _on_feedback_survey_pressed))

	_ui_root = root

	_difficulty_menu = _make_menu(Vector2(0.07, 0.46), root)
	_difficulty_menu.add_child(_make_button("Normal", _on_normal_pressed))
	_difficulty_menu.add_child(_make_button("Hard", _on_hard_pressed))
	_difficulty_menu.add_child(_make_button("Back", _show_main_menu))

	_credits_layer = Control.new()
	_credits_layer.name = "CreditsLayer"
	_credits_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_credits_layer)

	# Darkened + slightly blurred backdrop behind the rolling credits. First child
	# so it sits under the text; swallows clicks meant for the menu behind it.
	var backdrop := ColorRect.new()
	backdrop.name = "CreditsBackdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop_material := ShaderMaterial.new()
	backdrop_material.shader = CREDITS_BACKDROP_SHADER
	backdrop.material = backdrop_material
	_credits_layer.add_child(backdrop)

	# Concept-art slideshow sits above the blur but below the rolling text so the
	# names stay legible over the photos.
	_concept_layer = Control.new()
	_concept_layer.name = "ConceptArt"
	_concept_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_concept_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_credits_layer.add_child(_concept_layer)

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
	return MenuStyle.button(label, callback)


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


func _on_feedback_survey_pressed() -> void:
	GameOrchestrator.open_feedback_survey()


func _on_options_pressed() -> void:
	if _options != null:
		return
	_options = OptionsPanel.new()
	_options.closed.connect(func() -> void: _options = null)
	_ui_root.add_child(_options)


func _on_credits_pressed() -> void:
	_main_menu.visible = false
	_difficulty_menu.visible = false
	_credits_layer.visible = true
	_credits_rolling = true
	_reset_credits_position()
	_start_concept_images()


func _finish_credits() -> void:
	if _credits_finishing or not _credits_rolling:
		return
	_credits_finishing = true
	# Stop rolling the names, then fade the whole credits layer out and return.
	_credits_rolling = false
	var fade := create_tween()
	fade.tween_property(_credits_layer, "modulate:a", 0.0, 1.2)
	fade.tween_callback(_show_main_menu)


func _show_main_menu() -> void:
	_credits_rolling = false
	_credits_finishing = false
	_stop_concept_images()
	_main_menu.visible = true
	_difficulty_menu.visible = false
	_credits_layer.visible = false
	_credits_layer.modulate.a = 1.0  # reset after any fade-out


func _start_concept_images() -> void:
	_stop_concept_images()
	_concept_index = 0
	_show_next_concept_image()


func _stop_concept_images() -> void:
	if not is_instance_valid(_concept_layer):
		return
	for child in _concept_layer.get_children():
		child.queue_free()


func _show_next_concept_image() -> void:
	if not _credits_rolling or not is_instance_valid(_concept_layer):
		return
	if _concept_index >= CONCEPT_IMAGES.size():
		return  # one-shot: play through the set once, then stop

	var texture: Texture2D = CONCEPT_IMAGES[_concept_index]
	var place: Dictionary = CONCEPT_PLACEMENTS[_concept_index % CONCEPT_PLACEMENTS.size()]
	_concept_index += 1
	var is_last := _concept_index >= CONCEPT_IMAGES.size()
	_spawn_concept_image(texture, place, is_last)

	if is_last:
		return  # last image's fade-out drives the return to the menu

	# Hand off to the next image as this one starts fading out (crossfade).
	var next_delay := concept_fade_in + concept_hold
	get_tree().create_timer(next_delay).timeout.connect(_show_next_concept_image)


func _spawn_concept_image(texture: Texture2D, place: Dictionary, is_last := false) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var base := minf(viewport_size.x, viewport_size.y) * concept_base_fraction * float(place["scale"])

	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size = Vector2(base, base)
	rect.pivot_offset = rect.size * 0.5
	var center: Vector2 = Vector2(viewport_size.x * place["pos"].x, viewport_size.y * place["pos"].y)
	rect.position = center - rect.size * 0.5
	rect.rotation_degrees = float(place["rot"])
	rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_concept_layer.add_child(rect)

	var life := concept_fade_in + concept_hold + concept_fade_out

	# Fade in, hold, fade out, then free.
	var fade := create_tween()
	fade.tween_property(rect, "modulate:a", 1.0, concept_fade_in)
	fade.tween_interval(concept_hold)
	fade.tween_property(rect, "modulate:a", 0.0, concept_fade_out)
	fade.tween_callback(rect.queue_free)
	if is_last:
		# When the final image has fully faded out, fade the whole credits scene
		# away and drop back to the main menu.
		fade.tween_callback(_finish_credits)

	# Slow Ken Burns drift for a sentimental, hand-held feel.
	var drift := create_tween()
	drift.tween_property(rect, "scale", Vector2.ONE * 1.06, life)


func _reset_credits_position() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_credits_label.custom_minimum_size = Vector2(min(viewport_size.x * 0.78, 1160.0), 0.0)
	_credits_label.size = Vector2(min(viewport_size.x * 0.78, 1160.0), 1.0)
	_credits_label.position = Vector2((viewport_size.x - _credits_label.size.x) * 0.5, viewport_size.y + 40.0)


func _update_credits(delta: float) -> void:
	_credits_label.position.y -= credits_roll_speed * delta
	# Loop the text back around; the concept-art slideshow drives the actual end
	# of the credits (see _finish_credits), so the names keep rolling until then.
	if _credits_label.position.y + _credits_label.get_minimum_size().y < -60.0:
		_reset_credits_position()
