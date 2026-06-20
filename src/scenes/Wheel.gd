extends Node3D

# Pure view — reads RideState.wheel_angle and applies it to rotation.
# Writes nothing back. Adjust rotation axis to match the model's axle orientation.

func _process(_delta: float) -> void:
	rotation.z = RideState.wheel_angle
