extends CanvasLayer

@export var dan: AudioStreamPlayer

func _ready() -> void:
	if not OS.is_debug_build():
		return
	if dan == null:
		dan = get_node_or_null("../Audio/AudioDanTheOperator")
	if dan == null:
		push_error("DebugDanButtons: could not find AudioDanTheOperator node")
	
	var box := VBoxContainer.new()
	box.position = Vector2(16, 160)
	add_child(box)

	_add(box, "fling -> RELIEF", func(): Events.fling.emit())
	_add(box, "rider_lost -> DISMAY", func(): Events.rider_lost.emit())
	_add(box, "overheated -> DISMAY", func(): Events.overheated.emit())
	_add(box, "governor_overridden -> EFFORT_HEAVY", func(): Events.governor_overridden.emit())

	_add(box, "play_effort(0.2) -> EFFORT_LIGHT", func(): dan.play_effort(0.2))
	_add(box, "play_effort(0.8) -> EFFORT_HEAVY", func(): dan.play_effort(0.8))

	_add(box, "IDLE bark", func(): dan.bark(dan.Bucket.IDLE, 0))


func _add(box: VBoxContainer, label: String, on_press: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	box.add_child(b)
