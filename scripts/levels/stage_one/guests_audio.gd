extends Node

const SCREAM_DELAY_MIN := 0.2
const SCREAM_DELAY_MAX := 0.4
const CHEER_DELAY_MIN := 0.5
const CHEER_DELAY_MAX := 1.0

@export var scream_fling: AudioStreamPlayer
@export var crowd_cheer: AudioStreamPlayer


func _ready() -> void:
	if scream_fling == null:
		scream_fling = get_node_or_null("scream_fling")
	if crowd_cheer == null:
		crowd_cheer = get_node_or_null("crowd_cheer")
	Events.fling.connect(_on_fling)


func _on_fling() -> void:
	var scream_delay := randf_range(SCREAM_DELAY_MIN, SCREAM_DELAY_MAX)
	get_tree().create_timer(scream_delay).timeout.connect(_play_scream, CONNECT_ONE_SHOT)
	var cheer_delay := randf_range(CHEER_DELAY_MIN, CHEER_DELAY_MAX)
	get_tree().create_timer(cheer_delay).timeout.connect(_play_cheer, CONNECT_ONE_SHOT)


func _play_scream() -> void:
	if scream_fling != null:
		scream_fling.play()


func _play_cheer() -> void:
	if crowd_cheer != null:
		crowd_cheer.play()
