extends Node3D


func _process(_delta: float) -> void:
	rotation.z = RideState.wheel_angle
