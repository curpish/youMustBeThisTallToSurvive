extends MeshInstance3D
# Slowly spins the carousel around its local +Y (forward). Gated by an
# on-screen notifier so it does no work when the carousel isn't in view —
# cheap, and keeps it idle off-screen.

@export var spin_speed := 0.2  # radians/sec around local +Y

var _notifier: VisibleOnScreenNotifier3D


func _ready() -> void:
	# Notifier inherits our transform, so the mesh's local AABB lines up.
	_notifier = VisibleOnScreenNotifier3D.new()
	_notifier.aabb = get_aabb()
	add_child(_notifier)


func _process(delta: float) -> void:
	if not _notifier.is_on_screen():
		return
	rotate_object_local(Vector3.UP, spin_speed * delta)
