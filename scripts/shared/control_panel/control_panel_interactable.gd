class_name ControlPanelInteractable
extends RefCounted

var node: Node3D
var meshes: Array[MeshInstance3D] = []
var rest_position := Vector3.ZERO
var rest_basis := Basis.IDENTITY
var glow_material: StandardMaterial3D
var surface_material_template: Material
var hovered := false
var tween: Tween


func bind(root: Node, node_name: StringName, glow_color: Color, glow_energy: float) -> bool:
	var found := root.find_child(String(node_name), true, false) as Node3D
	if found == null:
		return false

	bind_node(found, glow_color, glow_energy)
	return true


func bind_node(target_node: Node3D, glow_color: Color, glow_energy: float) -> void:
	node = target_node
	rest_position = node.position
	rest_basis = node.basis
	meshes.clear()
	_collect_meshes(node, meshes)
	glow_material = _make_glow_material(glow_color, glow_energy)


func set_glow(enabled: bool) -> void:
	for mesh in meshes:
		mesh.material_overlay = glow_material if enabled else null


# Applies a steady indicator state, either through a tintable surface material
# or through the default overlay glow.
func set_glow_color(glow_color: Color, glow_energy: float) -> void:
	if surface_material_template != null:
		_set_surface_material_color(glow_color, glow_energy)
		return

	glow_material = _make_glow_material(glow_color, glow_energy)
	for mesh in meshes:
		mesh.material_overlay = glow_material


func set_surface_material_template(material: Material) -> void:
	surface_material_template = material


func set_hovered(value: bool) -> bool:
	if hovered == value:
		return false
	hovered = value
	set_glow(value)
	return true


func contains_screen_point(camera: Camera3D, screen_position: Vector2, padding: float) -> bool:
	if node == null or camera == null:
		return false

	var bounds := screen_rect(camera).grow(padding)
	return bounds.has_point(screen_position)


func screen_rect(camera: Camera3D) -> Rect2:
	if meshes.is_empty():
		var screen_position := camera.unproject_position(node.global_position)
		return Rect2(screen_position - Vector2(24.0, 24.0), Vector2(48.0, 48.0))

	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for mesh_instance in meshes:
		var aabb := mesh_instance.get_aabb()
		for x in [aabb.position.x, aabb.end.x]:
			for y in [aabb.position.y, aabb.end.y]:
				for z in [aabb.position.z, aabb.end.z]:
					var world_point := mesh_instance.global_transform * Vector3(x, y, z)
					if camera.is_position_behind(world_point):
						continue
					var screen_point := camera.unproject_position(world_point)
					min_point = min_point.min(screen_point)
					max_point = max_point.max(screen_point)

	if min_point.x == INF or max_point.x == -INF:
		var fallback_position := camera.unproject_position(node.global_position)
		return Rect2(fallback_position - Vector2(24.0, 24.0), Vector2(48.0, 48.0))

	var rect := Rect2(min_point, max_point - min_point)
	var minimum_size := Vector2(56.0, 56.0)
	if rect.size.x < minimum_size.x:
		rect.position.x -= (minimum_size.x - rect.size.x) * 0.5
		rect.size.x = minimum_size.x
	if rect.size.y < minimum_size.y:
		rect.position.y -= (minimum_size.y - rect.size.y) * 0.5
		rect.size.y = minimum_size.y
	return rect


func animate_press(owner: Node, offset: Vector3, press_time: float, release_time: float) -> void:
	if node == null:
		return
	if tween != null:
		tween.kill()

	node.position = rest_position
	tween = owner.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position", rest_position + offset, press_time)
	tween.tween_property(node, "position", rest_position, release_time).set_trans(Tween.TRANS_BACK)


func _collect_meshes(mesh_root: Node, target: Array[MeshInstance3D]) -> void:
	if mesh_root is MeshInstance3D:
		target.append(mesh_root)
	for child in mesh_root.get_children():
		_collect_meshes(child, target)


func _make_glow_material(glow_color: Color, glow_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = glow_color
	material.emission_enabled = true
	material.emission = Color(glow_color.r, glow_color.g, glow_color.b)
	material.emission_energy_multiplier = glow_energy
	return material


func _set_surface_material_color(glow_color: Color, glow_energy: float) -> void:
	var color := Color(glow_color.r, glow_color.g, glow_color.b, 1.0)
	for mesh in meshes:
		var material := surface_material_template.duplicate(true) as Material
		if material is ShaderMaterial:
			var shader_material := material as ShaderMaterial
			shader_material.set_shader_parameter("illuminationColor", color)
			shader_material.set_shader_parameter("illuminationBrightness", glow_energy)
		elif material is StandardMaterial3D:
			var standard_material := material as StandardMaterial3D
			standard_material.albedo_color = color
			standard_material.emission_enabled = true
			standard_material.emission = color
			standard_material.emission_energy_multiplier = glow_energy
		mesh.material_overlay = null
		mesh.material_override = material
