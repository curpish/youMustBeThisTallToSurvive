extends Node

# Shared ride values live here.
# Scene scripts read this and decide how to show it.

const ACCEL := 30.0
const DECEL := 28.0
# Low speed should feel heavy, then build power as the wheel gets moving.
const SPIN_UP_INERTIA := 0.25

const FAULT_ACTIONS: Array[String] = ["q", "w", "e", "r"]
const FAULT_SPAWN_RPM := 65.0
const DAMAGE_PER_FAULT := 10.0
const DAMAGE_STOP_BONUS := 28.0

const GOVERNOR_OVERRIDE_DURATION := 10.0
const GOVERNOR_COOLDOWN := 20.0
# The screwdriver takes a moment to seat before the governor drops.
const GOVERNOR_PRIME_MIN := 1.0
const GOVERNOR_PRIME_MAX := 2.0

const BIG_STOP_DECEL := 260.0
const SHUDDER_DECAY := 3.0

var feel: float = 1.0
var rpm_max: float = 420.0
var rpm_governed: float = 170.0
var is_governed: bool = true
var target_rpm: float = 0.0
var angular_velocity: float = 0.0
var wheel_angle: float = 0.0
var governor_prime_time_left: float = 0.0
var governor_override_time_left: float = 0.0
var governor_cooldown_left: float = 0.0
var is_emergency_stopping: bool = false
var shudder: float = 0.0
var last_stop_severity: float = 0.0
var active_faults: Dictionary = {}
var damage: float = 0.0
var damage_max: float = 100.0
var last_stop_damage: float = 0.0
var controls_locked: bool = false
var selected_mode: int = 1

var _fault_pressure: float = 0.0
var _fault_cursor: int = 0

signal faults_changed
signal damage_changed
signal controls_locked_changed(locked: bool)
signal selected_mode_changed(mode: int)


func _physics_process(delta: float) -> void:
	_update_governor(delta)

	var clamped_target: float
	var rate: float
	if is_emergency_stopping:
		# Big Stop holds the throttle at zero while the wheel grinds down.
		target_rpm = 0.0
		clamped_target = 0.0
		rate = BIG_STOP_DECEL * feel
		if angular_velocity <= 0.0:
			is_emergency_stopping = false
	else:
		var effective_max := rpm_governed if is_governed else rpm_max
		clamped_target = minf(target_rpm, effective_max)
		if angular_velocity < clamped_target:
			var momentum := angular_velocity / rpm_max
			rate = ACCEL * (SPIN_UP_INERTIA + (1.0 - SPIN_UP_INERTIA) * momentum) * feel
		else:
			rate = DECEL * feel

	angular_velocity = move_toward(angular_velocity, clamped_target, rate * delta)
	wheel_angle += angular_velocity * (TAU / 60.0) * delta

	_update_faults(delta)
	_update_shudder(delta)


func request_governor_override() -> bool:
	if controls_locked:
		return false
	if not can_override_governor():
		return false
	governor_prime_time_left = randf_range(GOVERNOR_PRIME_MIN, GOVERNOR_PRIME_MAX)
	Events.governor_priming.emit()
	return true


func can_override_governor() -> bool:
	return (
		governor_prime_time_left <= 0.0
		and governor_override_time_left <= 0.0
		and governor_cooldown_left <= 0.0
	)


func big_stop() -> void:
	if controls_locked:
		return
	if is_emergency_stopping:
		return
	target_rpm = 0.0
	is_emergency_stopping = true
	last_stop_severity = angular_velocity / rpm_max
	_apply_big_stop_damage()
	Events.big_stop.emit()


func clear_fault(action: String, mode: int) -> bool:
	if controls_locked:
		return false
	if not active_faults.has(action):
		return false
	if int(active_faults[action]) != mode:
		return false

	active_faults.erase(action)
	faults_changed.emit()
	return true


func get_fault_mode(action: String) -> int:
	if not active_faults.has(action):
		return 0
	return int(active_faults[action])


func get_uncleared_fault_count() -> int:
	return active_faults.size()


func set_selected_mode(mode: int) -> void:
	mode = clampi(mode, 1, 3)
	if selected_mode == mode:
		return
	selected_mode = mode
	selected_mode_changed.emit(selected_mode)


func set_controls_locked(locked: bool) -> void:
	if controls_locked == locked:
		return
	controls_locked = locked
	controls_locked_changed.emit(locked)


func _update_shudder(delta: float) -> void:
	if is_emergency_stopping:
		shudder = angular_velocity / rpm_max
	else:
		shudder = move_toward(shudder, 0.0, SHUDDER_DECAY * delta)


func _update_governor(delta: float) -> void:
	if governor_prime_time_left > 0.0:
		governor_prime_time_left -= delta
		if governor_prime_time_left <= 0.0:
			governor_prime_time_left = 0.0
			is_governed = false
			governor_override_time_left = GOVERNOR_OVERRIDE_DURATION
			Events.governor_overridden.emit()
	elif governor_override_time_left > 0.0:
		governor_override_time_left -= delta
		if governor_override_time_left <= 0.0:
			governor_override_time_left = 0.0
			is_governed = true
			governor_cooldown_left = GOVERNOR_COOLDOWN
	elif governor_cooldown_left > 0.0:
		governor_cooldown_left = maxf(0.0, governor_cooldown_left - delta)


func _update_faults(delta: float) -> void:
	if is_emergency_stopping or active_faults.size() >= FAULT_ACTIONS.size():
		return
	if angular_velocity < FAULT_SPAWN_RPM:
		_fault_pressure = maxf(0.0, _fault_pressure - delta)
		return

	var speed_fraction := clampf(angular_velocity / rpm_max, 0.0, 1.0)
	var pressure_gain := 0.6 + speed_fraction * 1.4
	if angular_velocity > rpm_governed:
		pressure_gain += 0.8
	if speed_fraction > 0.7:
		pressure_gain += 0.8

	var spawn_interval := lerpf(9.0, 3.0, speed_fraction)
	_fault_pressure += pressure_gain * delta
	if _fault_pressure >= spawn_interval:
		_fault_pressure = 0.0
		_spawn_fault(speed_fraction)


func _spawn_fault(speed_fraction: float) -> void:
	for i in FAULT_ACTIONS.size():
		var action := FAULT_ACTIONS[(_fault_cursor + i) % FAULT_ACTIONS.size()]
		if active_faults.has(action):
			continue

		_fault_cursor = (_fault_cursor + i + 1) % FAULT_ACTIONS.size()
		active_faults[action] = _mode_for_speed(speed_fraction)
		print("FAULT %s LIT - MODE %d" % [action.to_upper(), active_faults[action]])
		faults_changed.emit()
		return


func _mode_for_speed(speed_fraction: float) -> int:
	if speed_fraction >= 0.7:
		return 3
	if speed_fraction >= 0.35:
		return 2
	return 1


func _apply_big_stop_damage() -> void:
	var fault_count := get_uncleared_fault_count()
	if fault_count <= 0:
		last_stop_damage = 0.0
		damage_changed.emit()
		return

	last_stop_damage = fault_count * (DAMAGE_PER_FAULT + DAMAGE_STOP_BONUS * last_stop_severity)
	damage = minf(damage_max, damage + last_stop_damage)
	print("BIG STOP DAMAGE %.0f, TOTAL %.0f / %.0f" % [last_stop_damage, damage, damage_max])
	damage_changed.emit()


func reset() -> void:
	target_rpm = 0.0
	angular_velocity = 0.0
	wheel_angle = 0.0
	is_governed = true
	governor_prime_time_left = 0.0
	governor_override_time_left = 0.0
	governor_cooldown_left = 0.0
	is_emergency_stopping = false
	shudder = 0.0
	last_stop_severity = 0.0
	active_faults.clear()
	damage = 0.0
	last_stop_damage = 0.0
	controls_locked = false
	selected_mode = 1
	_fault_pressure = 0.0
	_fault_cursor = 0
	faults_changed.emit()
	damage_changed.emit()
	controls_locked_changed.emit(false)
	selected_mode_changed.emit(selected_mode)
