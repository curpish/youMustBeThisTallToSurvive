extends Node
# Player settings: volumes + fullscreen. Owns the values, applies them to the
# audio buses / window, and persists to user://settings.cfg (works on web via
# browser storage). The options UI is a pure view of this singleton.
#
# Volumes are stored linear 0..1 and applied as an OFFSET from each bus's design
# dB, so a slider at 100% preserves the mix the layout was authored with.
# The SFX slider scales the SFX bus plus Ambience / Screams / Dan together.

const CONFIG_PATH := "user://settings.cfg"
const SFX_GROUP: Array[String] = ["SFX", "Ambience", "Screams", "Dan", "Ride"]
const MUTE_LINEAR := 0.0005
const MUTE_DB := -80.0

var master_linear := 0.5
var music_linear := 0.5
var sfx_linear := 0.5
var fullscreen := false

# Whether the Operation Manual has been shown this session. Deliberately NOT
# persisted: it shows once per launch (first shift), then restarts skip it.
var manual_seen := false

var _design_db: Dictionary = {}


func _ready() -> void:
	_capture_design_db()
	_load()
	_apply_master()
	_apply_group(["Music"], music_linear)
	_apply_group(SFX_GROUP, sfx_linear)
	# Fullscreen is NOT auto-applied: browsers only allow it from a user gesture,
	# so it's set the first time the player toggles it in-session.


# --- public API used by the options panel -------------------------------------

func set_master(linear: float) -> void:
	master_linear = clampf(linear, 0.0, 1.0)
	_apply_master()
	_save()


func set_music(linear: float) -> void:
	music_linear = clampf(linear, 0.0, 1.0)
	_apply_group(["Music"], music_linear)
	_save()


func set_sfx(linear: float) -> void:
	sfx_linear = clampf(linear, 0.0, 1.0)
	_apply_group(SFX_GROUP, sfx_linear)
	_save()


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	var mode := (
		DisplayServer.WINDOW_MODE_FULLSCREEN if enabled
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	DisplayServer.window_set_mode(mode)
	_save()


func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() in [
		DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
	]


# Master fade-in target, read by GameOrchestrator so its boot fade lands on the
# saved master level instead of full volume.
func master_target_db() -> float:
	return _linear_to_db(master_linear)


# --- application --------------------------------------------------------------

func _apply_master() -> void:
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, master_target_db())


func _apply_group(buses: Array, linear: float) -> void:
	var offset := _linear_to_db(linear)
	for bus_name in buses:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx < 0:
			continue
		var design: float = _design_db.get(bus_name, 0.0)
		AudioServer.set_bus_volume_db(idx, design + offset)


func _capture_design_db() -> void:
	for bus_name in (["Music"] + SFX_GROUP):
		var idx := AudioServer.get_bus_index(bus_name)
		_design_db[bus_name] = AudioServer.get_bus_volume_db(idx) if idx >= 0 else 0.0


func _linear_to_db(linear: float) -> float:
	if linear <= MUTE_LINEAR:
		return MUTE_DB
	return linear_to_db(linear)


# --- persistence --------------------------------------------------------------

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_linear)
	cfg.set_value("audio", "music", music_linear)
	cfg.set_value("audio", "sfx", sfx_linear)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(CONFIG_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	master_linear = clampf(cfg.get_value("audio", "master", 0.5), 0.0, 1.0)
	music_linear = clampf(cfg.get_value("audio", "music", 1.0), 0.0, 1.0)
	sfx_linear = clampf(cfg.get_value("audio", "sfx", 1.0), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("display", "fullscreen", false))
