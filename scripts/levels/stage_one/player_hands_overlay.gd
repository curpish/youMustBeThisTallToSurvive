extends CanvasLayer

signal hands_ready

const WHITE_DISCARD_SHADER := preload("res://scripts/levels/stage_one/player_hands_white_discard.gdshader")

@export var hand_sheet: Texture2D
@export var camera_path: NodePath = NodePath("../Camera3D")
@export var frame_size := Vector2i(480, 270)
@export var frame_count := 248
@export var columns := 16
@export var frames_per_second := 10.0
@export var rise_duration := 1.6
@export var settle_delay := 0.15
@export var duck_duration := 0.3  # fast drop out of frame when the fling cinematic starts
@export var return_duration := 1.2  # rise back after the cinematic (quicker than the intro)
@export var target_anchor := Vector2(0.82, 0.75)
@export var start_offset := 240.0
@export var hand_scale := 2.7
@export var bottom_padding := 8.0
@export var rise_overhang := 220.0
@export var follow_enabled := true
@export var follow_speed := 36.0
@export var reach_min_anchor := Vector2(0.0, 0.34)
@export var reach_max_anchor := Vector2(1.0, 0.98)
@export var hand_hotspot := Vector2(275.0, 82.0)
@export var cursor_follow_offset := Vector2(0.0, 0.0)
@export var right_crop_guard := 16.0
@export var remove_sheet_white := true

@onready var _hands: Sprite2D = $Hands

var _active := false
var _ready_to_play := false
var _rise_time := 0.0
var _anim_time := 0.0
var _follow_position := Vector2.ZERO
var _follow_target := Vector2.ZERO
var _has_follow_target := false
var _active_touch_index := -1
var _duck := 0.0  # 0 = hands present, 1 = dropped fully out of frame
var _duck_tween: Tween

func _ready() -> void:
	_hands.texture = hand_sheet
	_hands.centered = true
	_hands.region_enabled = true
	_hands.visible = false
	_hands.scale = Vector2.ONE * hand_scale
	if remove_sheet_white:
		_hands.material = _build_white_discard_material()
	_set_frame(0)
	_place_hands(0.0)

	var intro_camera := get_node_or_null(camera_path)
	if intro_camera != null and intro_camera.has_signal("intro_finished"):
		intro_camera.intro_finished.connect(_show_hands)
	else:
		_show_hands()

	# Duck out for the fling cinematic, then rise back when the camera is done.
	if intro_camera != null and intro_camera.has_signal("fling_watch_finished"):
		intro_camera.fling_watch_finished.connect(_on_fling_watch_finished)
	Events.fling.connect(_on_fling_started)

func _process(delta: float) -> void:
	if not _active:
		return

	_rise_time += delta
	_anim_time += delta

	var rise_progress := clampf((_rise_time - settle_delay) / maxf(rise_duration, 0.001), 0.0, 1.0)
	_place_hands(_smooth_step(rise_progress))
	if not _ready_to_play and rise_progress >= 1.0:
		_ready_to_play = true
		hands_ready.emit()

	var frame := int(floor(_anim_time * frames_per_second)) % frame_count
	_set_frame(frame)

func _show_hands() -> void:
	_active = true
	_ready_to_play = false
	_rise_time = 0.0
	_anim_time = 0.0
	_hands.visible = true
	_place_hands(0.0)
	_follow_position = _hands.position
	_follow_target = _hands.position
	_has_follow_target = false
	_set_frame(0)

func _place_hands(progress: float) -> void:
	var viewport_size := get_viewport().get_visible_rect().size

	var bottom_locked_y := _bottom_locked_y(viewport_size)
	var lowest_start_y := viewport_size.y + rise_overhang - frame_size.y * hand_scale * 0.5
	var anchor_y := viewport_size.y * target_anchor.y
	var target := Vector2(viewport_size.x * target_anchor.x, maxf(anchor_y, bottom_locked_y))
	var start := Vector2(target.x, minf(target.y + start_offset, lowest_start_y))
	var intro_position := start.lerp(target, progress)

	# Duck offset is layered on at the end so it composes with both the intro
	# rise and the cursor-follow without corrupting their tracked positions.
	var drop := Vector2(0.0, _duck_drop(viewport_size) * _duck)

	if not follow_enabled or not _ready_to_play:
		_follow_position = intro_position
		_follow_target = intro_position
		_hands.position = intro_position + drop
		return

	_update_follow_target(viewport_size)
	var desired := _follow_target if _has_follow_target else intro_position
	_follow_position = _follow_position.lerp(desired, 1.0 - exp(-follow_speed * get_process_delta_time()))
	_hands.position = _constrain_hand_position(_follow_position, viewport_size) + drop


# Distance to push the hands fully below the screen when ducked.
func _duck_drop(viewport_size: Vector2) -> float:
	return viewport_size.y + frame_size.y * hand_scale


func _on_fling_started() -> void:
	if not _active:
		return
	_animate_duck(1.0, duck_duration, Tween.EASE_IN)


func _on_fling_watch_finished() -> void:
	if not _active:
		return
	_animate_duck(0.0, return_duration, Tween.EASE_OUT)


func _animate_duck(target: float, duration: float, ease: Tween.EaseType) -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_property(self, "_duck", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(ease)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_active_touch_index = event.index
		elif event.index == _active_touch_index:
			_active_touch_index = -1
	elif event is InputEventScreenDrag and event.index == _active_touch_index:
		_set_follow_target_from_pointer(event.position, get_viewport().get_visible_rect().size)

func _update_follow_target(viewport_size: Vector2) -> void:
	if _active_touch_index == -1:
		_set_follow_target_from_pointer(get_viewport().get_mouse_position(), viewport_size)

func _set_follow_target_from_pointer(pointer_position: Vector2, viewport_size: Vector2) -> void:
	var reach_rect := _reach_rect(viewport_size)
	if not reach_rect.has_point(pointer_position):
		_has_follow_target = false
		return

	var clamped_pointer := Vector2(
		clampf(pointer_position.x, reach_rect.position.x, reach_rect.end.x),
		clampf(pointer_position.y, reach_rect.position.y, reach_rect.end.y)
	)
	var frame_center := Vector2(frame_size) * 0.5
	var hotspot_offset := (hand_hotspot - frame_center) * hand_scale
	_follow_target = clamped_pointer + cursor_follow_offset - hotspot_offset
	_has_follow_target = true

func _reach_rect(viewport_size: Vector2) -> Rect2:
	var min_point := viewport_size * reach_min_anchor
	var max_point := viewport_size * reach_max_anchor
	return Rect2(min_point, max_point - min_point)

func _constrain_hand_position(position: Vector2, viewport_size: Vector2) -> Vector2:
	var half_size := Vector2(frame_size) * hand_scale * 0.5
	var constrained := position

	constrained.y = maxf(constrained.y, _minimum_reach_y(viewport_size))
	constrained.x = clampf(
		constrained.x,
		-half_size.x + right_crop_guard,
		viewport_size.x + half_size.x - right_crop_guard
	)
	return constrained

func _bottom_locked_y(viewport_size: Vector2) -> float:
	var scaled_height := frame_size.y * hand_scale
	return viewport_size.y - bottom_padding - scaled_height * 0.5

func _minimum_reach_y(viewport_size: Vector2) -> float:
	var frame_center := Vector2(frame_size) * 0.5
	var hotspot_offset := (hand_hotspot - frame_center) * hand_scale
	var top_reach_y := viewport_size.y * reach_min_anchor.y - hotspot_offset.y
	return minf(_bottom_locked_y(viewport_size), top_reach_y)

func _set_frame(frame: int) -> void:
	var column := frame % columns
	var row := floori(float(frame) / float(columns))
	_hands.region_rect = Rect2(
		column * frame_size.x,
		row * frame_size.y,
		frame_size.x,
		frame_size.y
	)

func _smooth_step(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)

func _build_white_discard_material() -> ShaderMaterial:
	# Precompiled resource shader, so there's no runtime compile cost.
	var material := ShaderMaterial.new()
	material.shader = WHITE_DISCARD_SHADER
	return material
