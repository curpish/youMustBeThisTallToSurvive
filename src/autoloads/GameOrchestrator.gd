# Owns any processes of setting up or tearing down gamestate

extends Node

enum Phase { BOARDING, RUNNING, CLOSED }

const MAIN_SCENE := "res://scenes/levels/stage_one/stage_one.tscn"

var phase: Phase = Phase.BOARDING


func restart() -> void:
	await Transitions.fade_out()
	RideState.reset()
	get_tree().change_scene_to_packed(load(MAIN_SCENE))
	await get_tree().process_frame
	Transitions.fade_in()
