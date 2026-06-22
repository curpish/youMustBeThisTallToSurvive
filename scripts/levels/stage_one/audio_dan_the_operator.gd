extends AudioStreamPlayer
# dynamic player for Dan's voice barks. Humanistic requirements, monophonic.
# One mouth: a single AudioStreamPlayer that picks a bark from a context bucket,
# never repeats within a shuffle bag, and lets higher-priority reactions
# interrupt lower ones. Reads RideState, listens to Events.

# bucket keys used as bank keys and bark() args.
# tip: prints as the enum index, not the name, if you debug with print(bucket).
enum Bucket { EFFORT_LIGHT, EFFORT_HEAVY, RELIEF, DISMAY, IDLE }

# full literal paths per preload — preload won't take a built/concatenated path,
# which is also why there's no runtime folder scan (that breaks on web export).
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

# timing/tuning
const COOLDOWN := 0.5
const IDLE_MIN := 6.0
const IDLE_MAX := 12.0
const HEAVY_THRESHOLD := 0.6  # normalized 0–1, effort intensity split
const IDLE_CALM_RPM := 1.0    # only idle-bark when the wheel is near-still

var _bags: Dictionary        # bucket -> Array[AudioStream], drained shuffle bag
var _last_played: Dictionary # bucket -> AudioStream, for anti-adjacent swap
var _current_priority: int = -1
var _last_play_time: float
var _idle_timer: float


func _ready() -> void:
	finished.connect(_on_finished)
	Events.rider_lost.connect(func(): bark(Bucket.DISMAY, 3))
	Events.overheated.connect(func(): bark(Bucket.DISMAY, 3))
	Events.fling.connect(func(): bark(Bucket.RELIEF, 2))
	Events.governor_overridden.connect(func(): bark(Bucket.EFFORT_HEAVY, 2))
	_idle_timer = randf_range(IDLE_MIN, IDLE_MAX)


func _process(delta: float) -> void:
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_idle_timer = randf_range(IDLE_MIN, IDLE_MAX)
		if not playing and RideState.angular_velocity < IDLE_CALM_RPM:
			bark(Bucket.IDLE, 0)


# public entry the lever/input calls. intensity from pull magnitude or
# RideState.angular_velocity / rpm_max.
func play_effort(intensity: float) -> void:
	if intensity >= HEAVY_THRESHOLD:
		bark(Bucket.EFFORT_HEAVY, 2)
	else:
		bark(Bucket.EFFORT_LIGHT, 1)


# the gate: one-mouth interrupt + cooldown, then play.
func bark(bucket: Bucket, priority: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0

	# interrupt rule: only a strictly higher priority cuts off a playing bark.
	# otherwise drop it — no queue keeps it tight.
	if playing and priority <= _current_priority:
		return

	# cooldown: low-priority barks respect a quiet gap; priority >= 2 bypasses it.
	if not playing and priority < 2 and now - _last_play_time < COOLDOWN:
		return

	stream = _pick(bucket)
	play()
	_current_priority = priority
	_last_play_time = now


# shuffle-bag selection: cycle every clip before any repeat, with an
# anti-adjacent swap to stop a repeat across the bag-refill seam.
func _pick(bucket: Bucket) -> AudioStream:
	var bag: Array = _bags.get(bucket, [])
	if bag.is_empty():
		# critical copy — shuffling/popping BANK directly would permanently
		# destroy the source clips (const does not freeze the inner arrays).
		bag = BANK[bucket].duplicate()
		bag.shuffle()
		# size() > 1 guard stops IDLE (single clip) from erroring on the swap.
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
	# release the lock so the next bark of any priority can play.
	_current_priority = -1
