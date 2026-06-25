extends Node

enum Phase { BOARDING, RUNNING, CLOSED }

const TITLE_SCENE := "res://scenes/title_scene.tscn"
const STAGE_ONE_SCENE := "res://scenes/levels/stage_one/stage_one.tscn"

const MASTER_FADE_DURATION := 0.8
const MASTER_FADE_START_DB := -60.0

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
	await start_stage_one()


func start_stage_one(difficulty: String = "") -> void:
	await Transitions.fade_out()
	if difficulty == "hard":
		RideState.set_difficulty(RideState.Difficulty.HARD)
	elif difficulty == "normal":
		RideState.set_difficulty(RideState.Difficulty.NORMAL)
	RideState.reset()
	phase = Phase.RUNNING
	get_tree().change_scene_to_packed(load(STAGE_ONE_SCENE))
	await get_tree().process_frame
	Transitions.fade_in()


func return_to_title() -> void:
	await Transitions.fade_out()
	RideState.reset()
	phase = Phase.BOARDING
	get_tree().change_scene_to_packed(load(TITLE_SCENE))
	await get_tree().process_frame
	Transitions.fade_in()
