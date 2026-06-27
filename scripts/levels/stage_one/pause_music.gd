class_name PauseMusicPlayer
extends AudioStreamPlayer
# Shared "downtime" music for the Operation Manual and the in-game pause menu.
# A single player, ref-counted so overlapping owners (e.g. opening the manual
# from an already-paused menu) never double up or cut each other off.
#
# Lives in stage_one.tscn and joins the "pause_music" group; callers find it via
# get_tree().get_first_node_in_group("pause_music").

const SILENT_DB := -60.0

@export var music_volume_db := -10.0    # target level while active
@export var fade_in_time := 0.6
@export var fade_out_time := 0.5
@export var page_turn_duck_db := 9.0    # how far the volume dips on a page turn
@export var page_turn_duck_time := 0.16 # dip time; it recovers over ~3x this

var _owners := {}
var _vol_tween: Tween
var _duck_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep playing / fading while paused
	add_to_group("pause_music")
	bus = "Master"
	volume_db = SILENT_DB
	_ensure_loop()


func _ensure_loop() -> void:
	if stream != null and "loop" in stream:
		stream.loop = true


# Start (or keep) the music for a given owner. Idempotent per owner.
func request(owner: Object) -> void:
	_owners[owner] = true
	if not playing:
		volume_db = SILENT_DB
		play()
	_fade_to(music_volume_db, fade_in_time)


# Release one owner; the track fades out and stops only when the last one lets go.
func release(owner: Object) -> void:
	_owners.erase(owner)
	if _owners.is_empty():
		_fade_to(SILENT_DB, fade_out_time, true)


# Subtle dip-and-recover for a page turn.
func page_turn_duck() -> void:
	if not playing or _owners.is_empty():
		return
	if _vol_tween != null and _vol_tween.is_running():
		return  # don't fight an active fade-in/out
	if _duck_tween != null:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_property(self, "volume_db", music_volume_db - page_turn_duck_db, page_turn_duck_time) \
		.from(music_volume_db).set_trans(Tween.TRANS_SINE)
	_duck_tween.tween_property(self, "volume_db", music_volume_db, page_turn_duck_time * 3.0) \
		.set_trans(Tween.TRANS_SINE)


func _fade_to(db: float, time: float, stop_after := false) -> void:
	if _vol_tween != null:
		_vol_tween.kill()
	if _duck_tween != null:
		_duck_tween.kill()
	_vol_tween = create_tween()
	_vol_tween.tween_property(self, "volume_db", db, time)
	if stop_after:
		_vol_tween.tween_callback(stop)
