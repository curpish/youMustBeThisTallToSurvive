extends CanvasLayer
# Throwaway debug overlay: buttons that fire the Events / effort calls Dan
# reacts to, so the barks can be auditioned live. Delete the node (and this
# script) when the mix is dialed in.

@export var dan: AudioStreamPlayer  # dan's audiostreamplayer

func _ready() -> void:
	# tear down the debug just in case it sneaks into production build somehow
	if not OS.is_debug_build():
		queue_free()
		return
	# to the known scene path so the effort/idle buttons can't hit a null Dan.
	if dan == null:
		dan = get_node_or_null("../Audio/AudioDanTheOperator")
	if dan == null:
		push_error("DebugDanButtons: could not find AudioDanTheOperator node")
	
	#build a vbox for buttons
	var box := VBoxContainer.new()
	box.position = Vector2(16, 160)
	add_child(box)

	# event-bus reactions (no node ref needed)
	_add(box, "fling  →  RELIEF", func(): Events.fling.emit())
	_add(box, "rider_lost  →  DISMAY", func(): Events.rider_lost.emit())
	_add(box, "overheated  →  DISMAY", func(): Events.overheated.emit())
	_add(box, "governor_overridden  →  EFFORT_HEAVY", func(): Events.governor_overridden.emit())

	# direct effort entry the lever will eventually call
	_add(box, "play_effort(0.2)  →  EFFORT_LIGHT", func(): dan.play_effort(0.2))
	_add(box, "play_effort(0.8)  →  EFFORT_HEAVY", func(): dan.play_effort(0.8))

	# idle bark, bypassing the timer/calm gate
	_add(box, "IDLE bark", func(): dan.bark(dan.Bucket.IDLE, 0))


func _add(box: VBoxContainer, label: String, on_press: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE  # keep clicks from stealing game input
	b.pressed.connect(on_press)
	box.add_child(b)
