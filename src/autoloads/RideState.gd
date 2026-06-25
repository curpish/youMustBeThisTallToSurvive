extends Node

# Shared ride values live here.
# Scene scripts read this and decide how to show it.

const MAX_WHEEL_SPEED := 420.0
const STOPPED_SPEED_EPSILON := 0.1

const ACCEL := 30.0
const DECEL := 28.0
# Low speed should feel heavy, then build power as the wheel gets moving.
const SPIN_UP_INERTIA := 0.25

const FAULT_ACTIONS: Array[String] = ["q", "w", "e", "r", "t", "y"]
const FAULT_SPAWN_RPM := 65.0
const DAMAGE_PER_FAULT := 10.0
const DAMAGE_STOP_BONUS := 28.0

const GOVERNOR_OVERRIDE_DURATION := 12.0
const GOVERNOR_COOLDOWN := 20.0
# The screwdriver takes a moment to seat before the governor drops.
const GOVERNOR_PRIME_MIN := 1.0
const GOVERNOR_PRIME_MAX := 2.0

const BIG_STOP_DECEL := 260.0
const SHUDDER_DECAY := 3.0

@export var max_wheel_speed := MAX_WHEEL_SPEED
@export var heat_threshold_speed := 170.0
@export var heat_marker_count := 10
@export var heat_increase_rate := 20.0
@export var heat_cool_rate := 35.0
@export var overheat_speed := MAX_WHEEL_SPEED
@export var riders_required_to_win := 6

# The Big Stop success window starts forgiving and tightens with every press
# or missed (overheat) stop, with a floor so it never gets impossibly precise.
@export var big_stop_initial_min_speed := 379.0
@export var big_stop_initial_max_speed := 410.0
@export var big_stop_difficulty_stage_count := 10
@export var big_stop_minimum_window_size := 12.0
@export var big_stop_shrink_per_stage := 2.0

# The panel lights are the fault system's active_faults / FAULT_ACTIONS -
# they get harder to keep clear as heat stage rises, and all six lit at once
# is the danger state that auto-triggers Big Stop.
@export var panel_pressure_enabled := true
@export var panel_heat_stage_pressure_multiplier := 0.12
@export var panel_min_spawn_interval_factor := 0.35

var feel: float = 1.0
var rpm_max: float = MAX_WHEEL_SPEED
var rpm_governed: float = 170.0
var is_governed: bool = true
var target_rpm: float = 0.0
var angular_velocity: float = 0.0
var wheel_angle: float = 0.0
var axle_heat: float = 0.0
var heat_floor_stage: int = 0
var heat_floor_value: float = 0.0
var has_crossed_heat_threshold_this_spin := false
var basket_released_this_spin := false
var overheat_penalty_applied_this_spin := false
var is_last_chance := false
var is_failure_sequence_active := false
var riders_launched_count: int = 0
var is_victory_sequence_active := false
var big_stop_difficulty_stage := 0
var big_stop_max_speed_penalty_applied_this_spin := false
var big_stop_current_min_speed := 0.0
var big_stop_current_max_speed := 0.0
var last_big_stop_was_successful := false
var panel_auto_big_stop_triggered_this_spin := false
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
var _was_moving_last_tick := false
var _last_chance_this_spin := false
var _heat_was_building := false
var _heat_was_cooling := false

signal faults_changed
signal damage_changed
signal controls_locked_changed(locked: bool)
signal selected_mode_changed(mode: int)
signal axle_heat_changed
signal heat_floor_changed(stage: int, floor_value: float)
signal axle_failure_triggered
signal victory_triggered


func _physics_process(delta: float) -> void:
	_sync_speed_tuning()
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

	_update_axle_heat(delta)
	_update_spin_lifecycle()
	_update_faults(delta)
	_check_panel_auto_big_stop()
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
	_begin_big_stop("manual")


func is_big_stop_success(current_speed: float) -> bool:
	return current_speed >= big_stop_current_min_speed and current_speed <= big_stop_current_max_speed


func get_current_big_stop_success_window() -> Dictionary:
	return {"min_speed": big_stop_current_min_speed, "max_speed": big_stop_current_max_speed}


func _begin_big_stop(source: String) -> void:
	if controls_locked or is_failure_sequence_active or is_victory_sequence_active:
		return
	if is_emergency_stopping:
		return
	target_rpm = 0.0
	is_emergency_stopping = true
	last_stop_severity = angular_velocity / rpm_max

	if source == "manual":
		# The press is judged against the window the player was actually
		# shown, then difficulty advances for next time.
		var speed := absf(angular_velocity)
		last_big_stop_was_successful = is_big_stop_success(speed)
		print("BIG STOP: speed %.1f vs window %.1f-%.1f -> %s" % [
			speed,
			big_stop_current_min_speed,
			big_stop_current_max_speed,
			"SUCCESS" if last_big_stop_was_successful else "MISS",
		])
		_increase_big_stop_difficulty("big_stop_pressed")
	else:
		# Forced/automatic stop (overheat or all-six-panel-lights-red) - the
		# player did not choose this moment, so it is always a miss and does
		# not touch the manual-press difficulty progression.
		last_big_stop_was_successful = false

	_apply_big_stop_damage()
	if source == "overheat":
		print("AXLE HEAT: auto big stop triggered at %.1f RPM" % absf(angular_velocity))
	elif source == "panel_pressure":
		print("PANEL LIGHTS: auto big stop triggered at %.1f RPM" % absf(angular_velocity))
	Events.big_stop.emit()


func mark_basket_released() -> void:
	basket_released_this_spin = true
	print("AXLE HEAT: basket release succeeded this spin")

	# basket_released_this_spin above resets every spin for the heat system;
	# this counter is cumulative for the whole run and drives the win condition.
	riders_launched_count += 1
	print("RIDER LAUNCH: success, total launched = %d" % riders_launched_count)
	if riders_launched_count >= riders_required_to_win:
		_trigger_victory()


func debug_trigger_axle_failure() -> void:
	_trigger_axle_failure()


func debug_trigger_victory() -> void:
	_trigger_victory()


func clear_fault(action: String, mode: int) -> bool:
	if controls_locked:
		return false
	if not active_faults.has(action):
		return false
	if int(active_faults[action]) != mode:
		return false

	active_faults.erase(action)
	print("PANEL LIGHTS: %s indicator reset to green (mode %d)" % [action.to_upper(), mode])
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


func _sync_speed_tuning() -> void:
	rpm_max = maxf(max_wheel_speed, 1.0)
	heat_marker_count = maxi(heat_marker_count, 1)
	heat_threshold_speed = clampf(heat_threshold_speed, 0.0, rpm_max)
	overheat_speed = clampf(overheat_speed, 0.0, rpm_max)
	_recalculate_heat_floor()
	_recalculate_big_stop_window()


func _update_axle_heat(delta: float) -> void:
	if is_victory_sequence_active:
		return
	var speed := absf(angular_velocity)
	var old_heat := axle_heat
	var is_building := speed > heat_threshold_speed and not is_failure_sequence_active
	var is_stopped := speed <= STOPPED_SPEED_EPSILON

	if is_building:
		axle_heat = minf(rpm_max, axle_heat + heat_increase_rate * delta)
		has_crossed_heat_threshold_this_spin = true
		if not _heat_was_building:
			print("AXLE HEAT: heat starts building at %.1f RPM" % speed)
	elif is_stopped:
		axle_heat = move_toward(axle_heat, heat_floor_value, heat_cool_rate * delta)
		if old_heat > axle_heat and not _heat_was_cooling:
			print("AXLE HEAT: cooling toward floor %.1f" % heat_floor_value)

	_heat_was_building = is_building
	_heat_was_cooling = is_stopped and old_heat > axle_heat

	if speed >= overheat_speed and not overheat_penalty_applied_this_spin:
		overheat_penalty_applied_this_spin = true
		print("AXLE HEAT: overheat at %.1f RPM" % speed)
		_increase_heat_floor("overheat penalty")
		_apply_big_stop_missed_window_penalty()
		Events.overheated.emit()
		_begin_big_stop("overheat")

	axle_heat = clampf(axle_heat, 0.0, rpm_max)
	if not is_equal_approx(old_heat, axle_heat):
		axle_heat_changed.emit()


func _update_spin_lifecycle() -> void:
	if is_victory_sequence_active:
		return
	var moving := absf(angular_velocity) > STOPPED_SPEED_EPSILON
	if moving and not _was_moving_last_tick:
		basket_released_this_spin = false
		has_crossed_heat_threshold_this_spin = false
		overheat_penalty_applied_this_spin = false
		big_stop_max_speed_penalty_applied_this_spin = false
		panel_auto_big_stop_triggered_this_spin = false
		_last_chance_this_spin = is_last_chance
		print("AXLE HEAT: spin started, last chance=%s" % is_last_chance)
	elif not moving and _was_moving_last_tick:
		_resolve_stopped_spin()

	_was_moving_last_tick = moving


func _resolve_stopped_spin() -> void:
	print("AXLE HEAT: spin stopped, basket_released=%s" % basket_released_this_spin)
	if has_crossed_heat_threshold_this_spin:
		_increase_heat_floor("heated spin stop")

	if _last_chance_this_spin and not basket_released_this_spin:
		_trigger_axle_failure()

	has_crossed_heat_threshold_this_spin = false
	overheat_penalty_applied_this_spin = false
	_last_chance_this_spin = is_last_chance


func _increase_heat_floor(reason: String) -> void:
	var old_stage := heat_floor_stage
	var was_last_chance := is_last_chance
	heat_floor_stage = clampi(heat_floor_stage + 1, 0, heat_marker_count)
	_recalculate_heat_floor()
	axle_heat = maxf(axle_heat, heat_floor_value)
	if heat_floor_stage == old_stage:
		return

	print("AXLE HEAT: floor stage increased to %d (%.1f) via %s" % [
		heat_floor_stage,
		heat_floor_value,
		reason,
	])
	if panel_pressure_enabled:
		print("PANEL LIGHTS: heat stage %d -> spawn interval factor %.2f (lights turn red faster)" % [
			heat_floor_stage,
			_panel_spawn_interval_factor(),
		])
	heat_floor_changed.emit(heat_floor_stage, heat_floor_value)
	axle_heat_changed.emit()

	if is_last_chance and not was_last_chance:
		print("AXLE HEAT: last chance begins")


func _recalculate_heat_floor() -> void:
	heat_floor_stage = clampi(heat_floor_stage, 0, heat_marker_count)
	heat_floor_value = (rpm_max / float(maxi(heat_marker_count, 1))) * float(heat_floor_stage)
	is_last_chance = heat_floor_stage >= heat_marker_count - 1


func _apply_big_stop_missed_window_penalty() -> void:
	if big_stop_max_speed_penalty_applied_this_spin:
		return
	big_stop_max_speed_penalty_applied_this_spin = true
	print("BIG STOP: missed window, wheel reached overheat/max speed - difficulty penalty applied")
	_increase_big_stop_difficulty("missed_max_speed")


func _increase_big_stop_difficulty(reason: String) -> void:
	var old_stage := big_stop_difficulty_stage
	big_stop_difficulty_stage = clampi(big_stop_difficulty_stage + 1, 0, big_stop_difficulty_stage_count - 1)
	_recalculate_big_stop_window()
	if big_stop_difficulty_stage == old_stage:
		return

	print("BIG STOP: difficulty stage increased to %d/%d via %s (window now %.1f-%.1f)" % [
		big_stop_difficulty_stage,
		big_stop_difficulty_stage_count - 1,
		reason,
		big_stop_current_min_speed,
		big_stop_current_max_speed,
	])


func _recalculate_big_stop_window() -> void:
	big_stop_difficulty_stage = clampi(big_stop_difficulty_stage, 0, big_stop_difficulty_stage_count - 1)
	var center_speed := (big_stop_initial_min_speed + big_stop_initial_max_speed) / 2.0
	var initial_window_size := big_stop_initial_max_speed - big_stop_initial_min_speed
	var shrink := float(big_stop_difficulty_stage) * big_stop_shrink_per_stage
	var window_size := maxf(initial_window_size - shrink, big_stop_minimum_window_size)
	var half_window := window_size / 2.0
	big_stop_current_min_speed = center_speed - half_window
	big_stop_current_max_speed = center_speed + half_window


func _check_panel_auto_big_stop() -> void:
	if not panel_pressure_enabled:
		return
	# controls_locked already covers failure/victory on its own, but this
	# checks both explicitly so it still holds even if that ever changes.
	if controls_locked or is_failure_sequence_active or is_victory_sequence_active:
		return
	if panel_auto_big_stop_triggered_this_spin:
		return
	if not are_all_panel_lights_red():
		return

	panel_auto_big_stop_triggered_this_spin = true
	print("PANEL LIGHTS: all six red at once - auto Big Stop triggers")
	_begin_big_stop("panel_pressure")
	active_faults.clear()
	faults_changed.emit()
	print("PANEL LIGHTS: all six reset to green after auto Big Stop")


func _trigger_axle_failure() -> void:
	# A successful launch already marks basket_released_this_spin true, which
	# rules out failure for that same spin - so this guard is really only for
	# the debug trigger path.
	if is_failure_sequence_active or is_victory_sequence_active:
		return
	is_failure_sequence_active = true
	target_rpm = 0.0
	is_emergency_stopping = false
	set_controls_locked(true)
	print("AXLE HEAT: failure sequence triggers")
	axle_failure_triggered.emit()


func _trigger_victory() -> void:
	if is_victory_sequence_active or is_failure_sequence_active:
		return
	is_victory_sequence_active = true
	target_rpm = 0.0
	is_emergency_stopping = false
	set_controls_locked(true)
	print("VICTORY: win condition reached, riders launched = %d" % riders_launched_count)
	print("VICTORY: player input locked")
	victory_triggered.emit()


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
	# controls_locked already covers failure/victory/Big-Stop-grinding/the
	# fling spectacle camera lock - no point lighting panels the player can't
	# react to.
	if controls_locked or is_emergency_stopping or active_faults.size() >= FAULT_ACTIONS.size():
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
	if panel_pressure_enabled:
		spawn_interval *= _panel_spawn_interval_factor()

	_fault_pressure += pressure_gain * delta
	if _fault_pressure >= spawn_interval:
		_fault_pressure = 0.0
		_spawn_fault(speed_fraction)


func _panel_spawn_interval_factor() -> float:
	# Higher heat stages compress the spawn interval further, on top of the
	# existing speed-based scaling, clamped so it never becomes impossibly
	# fast no matter how high the stage climbs.
	return clampf(
		1.0 - float(heat_floor_stage) * panel_heat_stage_pressure_multiplier,
		panel_min_spawn_interval_factor,
		1.0
	)


func get_current_panel_spawn_interval() -> float:
	var speed_fraction := clampf(angular_velocity / rpm_max, 0.0, 1.0)
	var interval := lerpf(9.0, 3.0, speed_fraction)
	if panel_pressure_enabled:
		interval *= _panel_spawn_interval_factor()
	return interval


func are_all_panel_lights_red() -> bool:
	return active_faults.size() >= FAULT_ACTIONS.size()


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
	_sync_speed_tuning()
	target_rpm = 0.0
	angular_velocity = 0.0
	wheel_angle = 0.0
	axle_heat = 0.0
	heat_floor_stage = 0
	heat_floor_value = 0.0
	has_crossed_heat_threshold_this_spin = false
	basket_released_this_spin = false
	overheat_penalty_applied_this_spin = false
	is_last_chance = false
	is_failure_sequence_active = false
	riders_launched_count = 0
	is_victory_sequence_active = false
	big_stop_difficulty_stage = 0
	big_stop_max_speed_penalty_applied_this_spin = false
	panel_auto_big_stop_triggered_this_spin = false
	last_big_stop_was_successful = false
	_recalculate_big_stop_window()
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
	_was_moving_last_tick = false
	_last_chance_this_spin = false
	_heat_was_building = false
	_heat_was_cooling = false
	faults_changed.emit()
	damage_changed.emit()
	axle_heat_changed.emit()
	heat_floor_changed.emit(heat_floor_stage, heat_floor_value)
	controls_locked_changed.emit(false)
	selected_mode_changed.emit(selected_mode)
