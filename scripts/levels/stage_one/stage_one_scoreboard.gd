extends Node3D

@export var scoreboard_scene: PackedScene
@export var intro_camera_path: NodePath = NodePath("..")
@export var counter_offset := Vector3(0.0, 0.625, 0.21)
@export var counter_scale := 0.23
@export var fade_time := 0.75
@export var pop_time := 0.16
@export var count_color := Color(1.0, 0.72, 0.24, 1.0)
@export var count_emission_energy := 2.8

const BULB_NODE_MARKER := "warm_bulb"

@export var bulb_flicker_speed := 1.6
@export var bulb_flicker_depth := 0.45
@export var bulb_dropout_chance := 0.35
@export var bulb_dropout_strength := 0.85
@export var bulb_dropout_recovery := 5.0

var _visual_root: Node3D
var _counter: Label3D
var _score := 0
var _base_scale := Vector3.ONE
var _fade_materials: Array[StandardMaterial3D] = []
var _fade_emission_energy: Array[float] = []
var _bulb_materials: Array[StandardMaterial3D] = []
var _bulb_base_emission: Array[float] = []
var _bulb_phase: Array[float] = []
var _bulb_dropout: Array[float] = []


func _ready() -> void:
	_base_scale = scale
	visible = false
	scale = _base_scale * 0.88
	_spawn_scoreboard()
	_setup_counter()
	_set_alpha(0.0)

	Events.fling.connect(_on_fling)

	var intro_camera := get_node_or_null(intro_camera_path)
	if intro_camera != null and intro_camera.has_signal("intro_finished"):
		intro_camera.intro_finished.connect(_show_scoreboard)
	else:
		_show_scoreboard()


func _spawn_scoreboard() -> void:
	if scoreboard_scene == null:
		push_warning("StageOneScoreboard has no scoreboard scene assigned.")
		return

	_visual_root = scoreboard_scene.instantiate() as Node3D
	if _visual_root == null:
		push_warning("StageOneScoreboard could not instance the scoreboard scene.")
		return

	add_child(_visual_root)
	_visual_root.rotation_degrees = Vector3.ZERO
	_hide_placeholder_counter(_visual_root)
	_prepare_fade_materials(_visual_root)


func _setup_counter() -> void:
	_counter = Label3D.new()
	_counter.name = "RidersLaunchedCounter"
	_counter.text = _score_text()
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_counter.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_counter.no_depth_test = true
	_counter.font_size = 112
	_counter.outline_size = 8
	_counter.modulate = Color(
		count_color.r * count_emission_energy,
		count_color.g * count_emission_energy,
		count_color.b * count_emission_energy,
		count_color.a
	)
	_counter.outline_modulate = Color(0.08, 0.035, 0.01, 1.0)
	_counter.position = counter_offset
	_counter.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	_counter.scale = Vector3.ONE * counter_scale

	add_child(_counter)


func _prepare_fade_materials(node: Node) -> void:
	if node is MeshInstance3D:
		_prepare_mesh_fade_materials(node)
	for child in node.get_children():
		_prepare_fade_materials(child)


func _prepare_mesh_fade_materials(mesh_instance: MeshInstance3D) -> void:
	var mesh := mesh_instance.mesh
	if mesh == null:
		return

	for surface_index in mesh.get_surface_count():
		var source := mesh_instance.get_surface_override_material(surface_index)
		if source == null:
			source = mesh.surface_get_material(surface_index)

		var material := _fade_material_from(source)
		mesh_instance.set_surface_override_material(surface_index, material)
		_track_fade_material(material)

		if material.emission_enabled and mesh_instance.name.containsn(BULB_NODE_MARKER):
			_bulb_materials.append(material)
			_bulb_base_emission.append(material.emission_energy_multiplier)
			_bulb_phase.append(randf() * TAU)
			_bulb_dropout.append(0.0)


func _fade_material_from(source: Material) -> StandardMaterial3D:
	var material: StandardMaterial3D
	if source is StandardMaterial3D:
		material = source.duplicate(true) as StandardMaterial3D
	else:
		material = StandardMaterial3D.new()

	if source != null and not source is StandardMaterial3D:
		material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Flat lighting and no shine here, so it reads chunky instead of glossy plastic.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	material.metallic = 0.0
	material.roughness = 1.0
	material.metallic_specular = 0.0

	return material


func _track_fade_material(material: StandardMaterial3D) -> void:
	_fade_materials.append(material)
	_fade_emission_energy.append(material.emission_energy_multiplier if material.emission_enabled else 0.0)


func _show_scoreboard() -> void:
	visible = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_alpha, 0.0, 1.0, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", _base_scale, fade_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if not visible:
		return
	_update_bulb_flicker(delta)


func _update_bulb_flicker(delta: float) -> void:
	var time := Time.get_ticks_msec() / 1000.0
	for i in _bulb_materials.size():
		_bulb_dropout[i] = maxf(0.0, _bulb_dropout[i] - delta * bulb_dropout_recovery)
		if _bulb_dropout[i] <= 0.0 and randf() < bulb_dropout_chance * delta:
			_bulb_dropout[i] = 1.0

		var pulse := 0.5 + 0.5 * sin(time * bulb_flicker_speed + _bulb_phase[i])
		var flicker := 1.0 - bulb_flicker_depth * (1.0 - pulse)
		flicker *= 1.0 - bulb_dropout_strength * _bulb_dropout[i]

		_bulb_materials[i].emission_energy_multiplier = _bulb_base_emission[i] * flicker


func _on_fling() -> void:
	_score += 1
	if _counter == null:
		return

	_counter.text = _score_text()
	var tween := create_tween()
	tween.tween_property(_counter, "scale", Vector3.ONE * counter_scale * 1.18, pop_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_counter, "scale", Vector3.ONE * counter_scale, pop_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_alpha(alpha: float) -> void:
	for i in _fade_materials.size():
		var material := _fade_materials[i]
		var color := material.albedo_color
		color.a = alpha
		material.albedo_color = color
		if material.emission_enabled:
			material.emission_energy_multiplier = _fade_emission_energy[i] * alpha

	if _counter != null:
		_counter.modulate.a = alpha


func _hide_placeholder_counter(node: Node) -> void:
	if node.name.contains("counter_placeholder"):
		if node is Node3D:
			node.visible = false
		return

	for child in node.get_children():
		_hide_placeholder_counter(child)


func _score_text() -> String:
	return "%03d" % _score
