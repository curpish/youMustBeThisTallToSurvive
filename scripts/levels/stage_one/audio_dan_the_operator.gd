extends AudioStreamPlayer

enum Bucket { EFFORT_LIGHT, EFFORT_HEAVY, RELIEF, DISMAY, IDLE }

const BANK := {
	Bucket.EFFORT_LIGHT: [
		preload("res://assets/audio/dan_the_operator/effort/light/groan1.ogg"),
		preload("res://assets/audio/dan_the_operator/effort/light/groan5_small.ogg"),
		preload("res://assets/audio/dan_the_operator/effort/light/groan6_small.ogg"),
		preload("res://assets/audio/dan_the_operator/effort/light/groan7_small.ogg"),
		preload("res://assets/audio/dan_the_operator/effort/light/huff_frustrated.ogg"),
	],
	Bucket.EFFORT_HEAVY: [
		preload("res://assets/audio/dan_the_operator/effort/heavy/groan2_big.ogg"),
		preload("res://assets/audio/dan_the_operator/effort/heavy/groan3.ogg"),
		preload("res://assets/audio/dan_the_operator/effort/heavy/groan4_super.ogg"),
		preload("res://assets/audio/dan_the_operator/effort/heavy/gritting_teeth.ogg"),
		preload("res://assets/audio/dan_the_operator/effort/heavy/huff_frustrated_long.ogg"),
		preload("res://assets/audio/dan_the_operator/effort/heavy/breaths_frustrated.ogg"),
	],
	Bucket.RELIEF: [
		preload("res://assets/audio/dan_the_operator/reaction/relief/annoyed_relief.ogg"),
		preload("res://assets/audio/dan_the_operator/reaction/relief/okie.ogg"),
	],
	Bucket.DISMAY: [
		preload("res://assets/audio/dan_the_operator/reaction/dismay/oh_man.ogg"),
		preload("res://assets/audio/dan_the_operator/reaction/dismay/waving_annoyed.ogg"),
		preload("res://assets/audio/dan_the_operator/reaction/dismay/pft.ogg"),
	],
	Bucket.IDLE: [
		preload("res://assets/audio/dan_the_operator/idle/breath_deep.ogg"),
	],
}

const COOLDOWN := 0.5
const IDLE_MIN := 6.0
const IDLE_MAX := 12.0
const HEAVY_THRESHOLD := 0.6
const IDLE_CALM_RPM := 1.0

var _bags: Dictionary
var _last_played: Dictionary
var _current_priority: int = -1
var _last_play_time: float
var _idle_timer: float


func _ready() -> void:
	finished.connect(_on_finished)
	Events.rider_lost.connect(func(): bark(Bucket.DISMAY, 3))
	Events.overheated.connect(func(): bark(Bucket.DISMAY, 3))
	Events.fling.connect(func(): bark(Bucket.RELIEF, 2))
	Events.governor_overridden.connect(func(): bark(Bucket.EFFORT_HEAVY, 2))
	Events.big_stop.connect(func(): bark(Bucket.EFFORT_HEAVY, 1))
	_idle_timer = randf_range(IDLE_MIN, IDLE_MAX)


func _process(delta: float) -> void:
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_idle_timer = randf_range(IDLE_MIN, IDLE_MAX)
		if not playing and RideState.angular_velocity < IDLE_CALM_RPM:
			bark(Bucket.IDLE, 0)


func play_effort(intensity: float) -> void:
	if intensity >= HEAVY_THRESHOLD:
		bark(Bucket.EFFORT_HEAVY, 2)
	else:
		bark(Bucket.EFFORT_LIGHT, 1)


func bark(bucket: Bucket, priority: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0

	if playing and priority <= _current_priority:
		return
	if not playing and priority < 2 and now - _last_play_time < COOLDOWN:
		return

	stream = _pick(bucket)
	play()
	_current_priority = priority
	_last_play_time = now


func _pick(bucket: Bucket) -> AudioStream:
	var bag: Array = _bags.get(bucket, [])
	if bag.is_empty():
		bag = BANK[bucket].duplicate()
		bag.shuffle()
		if bag.size() > 1 and bag.back() == _last_played.get(bucket):
			var tail: int = bag.size() - 1
			var first: Variant = bag[0]
			bag[0] = bag[tail]
			bag[tail] = first
		_bags[bucket] = bag
	var clip: AudioStream = bag.pop_back()
	_last_played[bucket] = clip
	return clip


func _on_finished() -> void:
	_current_priority = -1
