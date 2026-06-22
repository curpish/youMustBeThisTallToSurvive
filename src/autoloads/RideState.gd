extends Node

# RideState holds all values relative to the ride, other game systems will
# call to this autoload for checks on conditional triggers.
# Cosmetic/audio/anim stay on their own _process/signal handlers.

const ACCEL := 12.0  # RPM/s spin-up authority once at full momentum
const DECEL := 6.0  # RPM/s coast-down (constant: a long, heavy coast)
# Heavy-wheel feel: spin-up rate is weak from a standstill and builds with
# speed. This is the accel floor at 0 rpm, as a fraction of ACCEL.
# Lower = heavier / more hesitant start; 1.0 = old constant acceleration.
const SPIN_UP_INERTIA := 0.2

# Governor override: jam the screwdriver in, the governor drops for a fixed
# window, then re-engages and recharges before it can be jammed again.
const GOVERNOR_OVERRIDE_DURATION := 10.0  # seconds the governor stays disabled
const GOVERNOR_COOLDOWN := 20.0  # seconds after release before it can re-trigger

# Big Stop: slam the oversized button for an emergency stop. The wheel grinds
# down hard (brake friction/slip), not instant, and shudders by how fast it was
# going when hit. No cooldown yet -- iterate freely.
const BIG_STOP_DECEL := 55.0  # RPM/s hard brake (rpm_max -> 0 in ~1.5s)
const SHUDDER_DECAY := 3.0  # how fast residual judder settles once stopped

var feel: float = 1.0 # scales both accel and decel, helpful to test
var rpm_max: float = 80.0 # OVERSPEED ceiling; headroom above the top band (72)
var rpm_governed: float = 22.0 # governor fights you the moment you pass NOMINAL (18)
var is_governed: bool = true
var target_rpm: float = 0.0
var angular_velocity: float = 0.0
var wheel_angle: float = 0.0
var governor_override_time_left: float = 0.0  # > 0 while the override is active
var governor_cooldown_left: float = 0.0  # > 0 while recharging, can't re-trigger
var is_emergency_stopping: bool = false  # true while a Big Stop is grinding down
var shudder: float = 0.0  # 0..~1 brake-judder intensity; the wheel jitters by this
var last_stop_severity: float = 0.0  # speed fraction at the last Big Stop; damage hook


func _physics_process(delta: float) -> void:
	_update_governor(delta)

	var clamped_target: float
	var rate: float
	if is_emergency_stopping:
		# Big Stop owns the wheel: hard brake to zero AND force the throttle to
		# the lowest band (STATIC / 0) the whole time, so a mid-stop throttle-up
		# can't sneak through and the lever gets dragged down with it.
		target_rpm = 0.0
		clamped_target = 0.0
		rate = BIG_STOP_DECEL * feel
		if angular_velocity <= 0.0:
			is_emergency_stopping = false
	else:
		var effective_max := rpm_governed if is_governed else rpm_max
		clamped_target = minf(target_rpm, effective_max)
		if angular_velocity < clamped_target:
			# Spin-up authority ramps from ACCEL*SPIN_UP_INERTIA (standstill) up to
			# ACCEL (at rpm_max), so the wheel hesitates, then builds momentum.
			var momentum := angular_velocity / rpm_max
			rate = ACCEL * (SPIN_UP_INERTIA + (1.0 - SPIN_UP_INERTIA) * momentum) * feel
		else:
			rate = DECEL * feel

	angular_velocity = move_toward(angular_velocity, clamped_target, rate * delta)
	wheel_angle += angular_velocity * (TAU / 60.0) * delta

	_update_shudder(delta)


func request_governor_override() -> bool:
	# Called by the SPACE control / future lever. Drops the governor if ready.
	if not can_override_governor():
		return false
	governor_override_time_left = GOVERNOR_OVERRIDE_DURATION
	is_governed = false
	Events.governor_overridden.emit()
	return true


func can_override_governor() -> bool:
	return governor_override_time_left <= 0.0 and governor_cooldown_left <= 0.0


func big_stop() -> void:
	# Called by the oversized emergency-stop button / future panel.
	if is_emergency_stopping:
		return
	target_rpm = 0.0
	Events.big_stop.emit()
	is_emergency_stopping = true
	# How fast we were going when slammed: drives the judder now and (later)
	# how much damage a dirty Big Stop deals. GDD section 8.2.
	last_stop_severity = angular_velocity / rpm_max


func _update_shudder(delta: float) -> void:
	if is_emergency_stopping:
		# Brake fighting the wheel: judder tracks the speed it is still bleeding
		# off, so it slips and rattles hard, then eases as the wheel grinds down.
		shudder = angular_velocity / rpm_max
	else:
		shudder = move_toward(shudder, 0.0, SHUDDER_DECAY * delta)


func _update_governor(delta: float) -> void:
	if governor_override_time_left > 0.0:
		governor_override_time_left -= delta
		if governor_override_time_left <= 0.0:
			# Screwdriver pops out: governor re-engages (violent decel follows
			# for free, since clamped_target snaps back to rpm_governed).
			governor_override_time_left = 0.0
			is_governed = true
			governor_cooldown_left = GOVERNOR_COOLDOWN
	elif governor_cooldown_left > 0.0:
		governor_cooldown_left = maxf(0.0, governor_cooldown_left - delta)


func reset() -> void:
	target_rpm = 0.0
	angular_velocity = 0.0
	wheel_angle = 0.0
	is_governed = true
	governor_override_time_left = 0.0
	governor_cooldown_left = 0.0
	is_emergency_stopping = false
	shudder = 0.0
	last_stop_severity = 0.0
