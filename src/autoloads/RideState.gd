extends Node

# RideState holds all values relative to the ride, other game systems will
# call to this autoload for checks on conditional triggers.
# Cosmetic/audio/anim stay on their own _process/signal handlers.

const ACCEL := 2.0  # RPM/s spinning up
const DECEL := 0.8  # RPM/s coasting down

var feel: float = 1.0 # scales both accel and decel, helpful to test
var rpm_max: float = 10.0 # find the absolute max that reads well
var rpm_governed: float = 5.0 # intended to be overridden by player as "risk"
var is_governed: bool = true
var target_rpm: float = 0.0
var angular_velocity: float = 0.0
var wheel_angle: float = 0.0


func _physics_process(delta: float) -> void:
	var effective_max := rpm_governed if is_governed else rpm_max
	var clamped_target := minf(target_rpm, effective_max)
	var rate := (
		ACCEL * feel if angular_velocity < clamped_target else DECEL * feel
		)
	
	angular_velocity = move_toward(
		angular_velocity, clamped_target, rate * delta
		)
	wheel_angle += angular_velocity * (TAU / 60.0) * delta


func reset() -> void:
	target_rpm = 0.0
	angular_velocity = 0.0
	wheel_angle = 0.0
