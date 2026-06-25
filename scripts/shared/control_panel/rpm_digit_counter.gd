class_name RpmDigitCounter
extends RefCounted

const DIGIT_STEP := TAU / 10.0
const MAX_DISPLAY_VALUE := 99999.0

var digits: Array[Node3D] = []
var rest_bases: Array[Basis] = []


func bind(root: Node, digit_names: Array[StringName]) -> void:
	digits.clear()
	rest_bases.clear()

	for digit_name in digit_names:
		var digit := root.find_child(String(digit_name), true, false) as Node3D
		if digit == null:
			push_warning("RPM counter digit wheel '%s' was not found." % digit_name)
			continue

		digits.append(digit)
		rest_bases.append(digit.basis)


func update(value: float, spin_axis: Vector3, spin_direction: float) -> void:
	if digits.is_empty():
		return

	var display_value := clampf(absf(value), 0.0, MAX_DISPLAY_VALUE)
	var axis := spin_axis.normalized()
	if axis.length_squared() <= 0.0:
		axis = Vector3.RIGHT

	for i in digits.size():
		var place_index := digits.size() - i - 1
		var divisor := pow(10.0, place_index)
		var digit_value: float
		if place_index == 0:
			digit_value = fmod(display_value, 10.0)
		else:
			digit_value = float(int(floor(display_value / divisor)) % 10)

		var angle := spin_direction * digit_value * DIGIT_STEP
		digits[i].basis = Basis(axis, angle) * rest_bases[i]
