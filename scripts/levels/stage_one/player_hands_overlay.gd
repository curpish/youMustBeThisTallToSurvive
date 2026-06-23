extends CanvasLayer

# Controls stay locked until the hands finish sliding into place.
signal hands_ready

@export var hand_sheet: Texture2D
@export var camera_path: NodePath = NodePath("../Camera3D")
@export var frame_size := Vector2i(480, 270)
@export var frame_count := 248
@export var columns := 16
@export var frames_per_second := 10.0
@export var rise_duration := 1.6
@export var settle_delay := 0.15
@export var target_anchor := Vector2(0.82, 0.75)
@export var start_offset := 240.0
@export var hand_scale := 2.0
@export var bottom_padding := 8.0
@export var rise_overhang := 220.0

@onready var _hands: Sprite2D = $Hands

var _active := false
var _ready_to_play := false
var _rise_time := 0.0
var _anim_time := 0.0

func _ready() -> void:
	_hands.texture = hand_sheet
	_hands.centered = true
	_hands.region_enabled = true
	_hands.visible = false
	_hands.scale = Vector2.ONE * hand_scale
	_set_frame(0)
	_place_hands(0.0)

	var intro_camera := get_node_or_null(camera_path)
	if intro_camera != null and intro_camera.has_signal("intro_finished"):
		intro_camera.intro_finished.connect(_show_hands)
	else:
		_show_hands()

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
	_set_frame(0)

func _place_hands(progress: float) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var scaled_height := frame_size.y * hand_scale

	# Keep the bottom covered so the arm doesn't float above the camera edge.
	var bottom_locked_y := viewport_size.y - bottom_padding - scaled_height * 0.5
	var lowest_start_y := viewport_size.y + rise_overhang - scaled_height * 0.5
	var anchor_y := viewport_size.y * target_anchor.y
	var target := Vector2(viewport_size.x * target_anchor.x, maxf(anchor_y, bottom_locked_y))
	var start := Vector2(target.x, minf(target.y + start_offset, lowest_start_y))
	_hands.position = start.lerp(target, progress)

func _set_frame(frame: int) -> void:
	# The gif is baked into one sheet because Godot doesn't really want animated gifs here.
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
