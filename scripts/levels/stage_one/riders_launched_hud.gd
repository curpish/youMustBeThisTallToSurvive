extends CanvasLayer

@export var intro_camera_path: NodePath = NodePath("../Camera3D")
@export var top_padding := 28.0
@export var right_padding := 28.0
@export var fade_time := 0.75
@export var pop_time := 0.16
@export var pop_scale := 1.18
@export var accent_color := Color(0.95, 0.75, 0.28, 1.0)

var _card: PanelContainer
var _count_label: Label
var _pop_tween: Tween


func _ready() -> void:
	_build_ui()
	_reposition_card()
	visible = false
	_card.modulate.a = 0.0
	get_viewport().size_changed.connect(_reposition_card)
	RideState.riders_launched_changed.connect(_on_riders_launched_changed)

	var intro_camera := get_node_or_null(intro_camera_path)
	if intro_camera != null and intro_camera.has_signal("intro_finished"):
		intro_camera.intro_finished.connect(_show_card)
	else:
		_show_card()


func _build_ui() -> void:
	_card = PanelContainer.new()
	_card.name = "RidersLaunchedCard"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", _card_style())
	add_child(_card)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	_card.add_child(box)

	var caption := Label.new()
	caption.text = "RIDERS LAUNCHED"
	_style_label(caption)
	box.add_child(caption)

	_count_label = Label.new()
	_count_label.text = _score_text()
	_style_label(_count_label)
	box.add_child(_count_label)


func _style_label(label: Label) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", accent_color)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.035, 0.01))
	label.add_theme_constant_override("outline_size", 5)


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.03, 0.72)
	style.border_color = accent_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 7
	return style


func _reposition_card() -> void:
	if _card == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var card_size := _card.get_combined_minimum_size()
	_card.size = card_size
	_card.position = Vector2(viewport_size.x - card_size.x - right_padding, top_padding)


func _show_card() -> void:
	visible = true
	var tween := create_tween()
	tween.tween_property(_card, "modulate:a", 1.0, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_riders_launched_changed(count: int) -> void:
	_count_label.text = "%d" % count
	_reposition_card()
	if _pop_tween != null:
		_pop_tween.kill()
	_count_label.pivot_offset = _count_label.size * 0.5
	_count_label.scale = Vector2.ONE
	_pop_tween = create_tween()
	_pop_tween.tween_property(_count_label, "scale", Vector2.ONE * pop_scale, pop_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_property(_count_label, "scale", Vector2.ONE, pop_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _score_text() -> String:
	return "%d" % RideState.riders_launched_count
