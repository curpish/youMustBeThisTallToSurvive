extends Node

const FADE_DURATION := 0.4

var _curtain: ColorRect


func _ready() -> void:
	# Always animate, even when the tree is paused (e.g. the Operation Manual
	# freezes the sim the moment the stage loads, before this fade-in finishes).
	process_mode = Node.PROCESS_MODE_ALWAYS

	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)

	_curtain = ColorRect.new()
	_curtain.color = Color.BLACK
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.modulate.a = 0.0
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_curtain)


func fade_out() -> void:
	await _tween_alpha(1.0)


func fade_in() -> void:
	await _tween_alpha(0.0)


func _tween_alpha(target: float) -> void:
	var tween := create_tween()
	tween.tween_property(_curtain, "modulate:a", target, FADE_DURATION)
	await tween.finished
