# Owns any processes of setting up or tearing down gamestate

extends Node

enum Phase { BOARDING, RUNNING, CLOSED }

const MAIN_SCENE := "res://scenes/levels/stage_one/stage_one.tscn"

# Master bus fade-in safeguard: ramp from near-silent up to 0 dB at boot so any
# first-frame audio garbage (reverb/enhance buffers warming up, autoplay streams
# firing before the engine settles) happens while we're inaudible.
const MASTER_FADE_DURATION := 0.8  # seconds to reach full volume
const MASTER_FADE_START_DB := -60.0  # effectively silent

var phase: Phase = Phase.BOARDING


func _ready() -> void:
	_fade_in_master()


func _fade_in_master() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master < 0:
		return
	AudioServer.set_bus_volume_db(master, MASTER_FADE_START_DB)
	var tween := create_tween()
	tween.tween_method(
		func(db: float) -> void: AudioServer.set_bus_volume_db(master, db),
		MASTER_FADE_START_DB, 0.0, MASTER_FADE_DURATION
	)


func restart() -> void:
	await Transitions.fade_out()
	RideState.reset()
	get_tree().change_scene_to_packed(load(MAIN_SCENE))
	await get_tree().process_frame
	Transitions.fade_in()
