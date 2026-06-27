extends Node3D

@export var spin_direction: float = -1.0

@export var gondola_orbit_radius: float = 7.2
@export var gondola_hang_offset: float = 2.6
@export_range(1, 8, 1) var gondola_count := 6

@export var hanger_half_width: float = 0.8
@export var hanger_bar_radius: float = 0.035

@export var axle_warning_lead_speed: float = 55.0
@export var axle_glow_radius: float = 1.18
@export var axle_glow_camera_offset: float = 0.85
@export var axle_warning_color := Color(1.0, 0.78, 0.12, 1.0)
@export var axle_sweetspot_color := Color(0.2, 1.0, 0.18, 1.0)
@export var axle_danger_color := Color(1.0, 0.14, 0.08, 1.0)
@export var hot_glow_light_energy: float = 3.6
@export var spark_start_speed: float = 84.0
@export var spark_full_speed: float = 420.0
@export var spark_color := Color(1.0, 0.58, 0.1, 1.0)
@export var progress_palette: Gradient  # color per rung; cool start -> hot finale
@export var progress_flicker_strength := 0.7  # peak brightness swing at the sweet spot
@export var progress_window_lead_speed := 90.0  # speed below the window where flicker begins
@export var show_chase_speed := 2.2  # idle shimmer chase speed around the ring
@export var show_chase_depth := 0.35  # idle brightness wave depth
@export var show_hue_speed := 0.5  # idle hue-breathing speed
@export var show_hue_drift := 0.1  # idle hue-breathing amount (0..1 of the color wheel)
@export var progress_bulb_radius := 0.13
@export var progress_bulb_axle_offset := 0.12  # nudge onto the front rim face
@export var progress_light_range := 1.3
@export var progress_light_energy := 2.5
@export var progress_flash_energy := 6.5
@export var progress_pulse_time := 0.55
@export var fling_ground_y: float = 0.25
@export var fling_collision_radius: float = 0.42
@export var fling_collision_skin: float = 0.05
@export var fling_collision_bounce_limit := 6
@export var basket_collision_bounciness := 0.48
@export var rider_collision_bounciness := 0.56
@export var fling_collision_friction := 0.68
@export var fling_rest_speed := 0.8
@export var fling_floor_normal_dot := 0.5
@export var web_fling_wall_z := 60.0
@export var failure_drop_distance := 3.0
@export var failure_roll_distance := 46.0
@export var failure_drop_duration := 0.6
@export var failure_roll_duration := 4.2
@export var failure_roll_rotation_degrees := 1260.0
@export var game_over_text_delay := 0.75
@export var game_over_display_duration := 3.0
@export var game_over_text := "GAME OVER"
@export var game_over_subtext := "The wheel has left the building."
@export var victory_lift_height := 6.0
@export var victory_lift_duration := 0.8
# Total time the wheel hovers, spins, and glows - the victory text appears
# partway into this window (after victory_text_delay) and stays up for the
# rest of it, right up until the title transition.
@export var victory_spin_duration := 5.0
@export var victory_spin_speed_multiplier := 1.25
@export var victory_hover_spin_speed := 1800.0
@export var victory_glow_energy := 2.5
@export var victory_glow_hue_speed := 2.5
@export var victory_glow_fade_out_time := 0.4
@export var victory_text_delay := 0.2
@export var victory_camera_shake_strength := 0.05
@export var victory_text := "SPIN TO WIN!"
@export var victory_subtext_format := "%d RIDERS LAUNCHED.\nYOU WERE TALL ENOUGH TO SURVIVE."

const WHEEL_NODE_NAME := "frame_wheel"
const WHEEL_NODE_FALLBACK_NAME := "frame"

const ROPE_NODE_NAMES := [
	"rope_a",
	"rope_b",
	"rope_c",
	"rope_d",
]
const WEB_EFFECT_REFRESH_INTERVAL := 1.0 / 30.0
const WEB_AXLE_SPARK_AMOUNT := 36
const PROGRESS_EMISSION_STEADY := 3.0
const PROGRESS_EMISSION_FLASH := 9.0
const PROGRESS_OFF_COLOR := Color(0.05, 0.05, 0.06)  # dark glass for an unlit bulb
const PROGRESS_FLICKER_SLOW_INTERVAL := 0.14  # re-roll cadence far from the window
const PROGRESS_FLICKER_FAST_INTERVAL := 0.01  # re-roll cadence at the sweet spot
const PROGRESS_CHASE_WAVES := 2.0  # crests of the idle brightness wave around the ring
const PROGRESS_STROBE_COLORS: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(1.0, 0.12, 0.12),
	Color(0.15, 0.6, 1.0),
	Color(1.0, 0.85, 0.1),
	Color(1.0, 0.12, 0.7),
]
const PROGRESS_DEFAULT_COLORS: Array[Color] = [
	Color(0.55, 0.85, 1.0),
	Color(0.6, 1.0, 0.7),
	Color(1.0, 0.95, 0.55),
	Color(1.0, 0.72, 0.3),
	Color(1.0, 0.45, 0.3),
	Color(1.0, 0.3, 0.5),
]

var _wheel: Node3D
var _ferris_scene_root: Node3D
var _basket: Node3D
var _rider: Node3D
var _gondola_center_x := 0.0
var _basket_basis := Basis.IDENTITY
var _rider_basis := Basis.IDENTITY
var _rider_offset_from_basket := Vector3.ZERO
var _baskets: Array[Node3D] = []
var _riders: Array[Node3D] = []
var _socket_local_positions: Array[Vector3] = []
var _progress_bulbs: Array[MeshInstance3D] = []
var _progress_lights: Array[OmniLight3D] = []
var _progress_bulb_materials: Array[StandardMaterial3D] = []
var _progress_bulb_pulse: Array[float] = []  # transient flash boost per lit bulb, decays to 0
var _progress_bulb_flicker: Array[float] = []  # held brightness multiplier at the sweet spot
var _progress_bulb_on: Array[bool] = []
var _progress_bulb_base_color: Array[Color] = []  # the bulb's identity color (by progress step)
var _progress_bulb_strobe: Array[Color] = []  # held bold strobe color at the sweet spot
var _progress_bulb_angle: Array[float] = []  # rim angle, for the chase wave
var _progress_order: Array[int] = []  # activation order: opposite ends first, balanced
var _progress_flicker_timer := 0.0
var _progress_show_phase := 0.0
var _progress_lit := 0
var _left_hanger_bars: Array[MeshInstance3D] = []
var _right_hanger_bars: Array[MeshInstance3D] = []
var _gondola_flying: Array[bool] = []
var _basket_velocities: Array[Vector3] = []
var _rider_velocities: Array[Vector3] = []
var _rider_spin_axes: Array[Vector3] = []
var _rider_spin_speeds: Array[float] = []
var _basket_bounces: Array[int] = []
var _rider_bounces: Array[int] = []
var _flight_ages: Array[float] = []
var _basket_rest_scales: Array[Vector3] = []
var _rider_rest_scales: Array[Vector3] = []
var _wheel_rest_basis := Basis.IDENTITY
var _axle_glow_mesh: MeshInstance3D
var _hot_glow_material: StandardMaterial3D
var _hot_glow_light: OmniLight3D
var _last_axle_glow_state := -1
var _axle_sparks: GPUParticles3D
var _spark_process_material: ParticleProcessMaterial
var _fling_collision_root: Node3D
var _failure_sequence_active := false
var _game_over_layer: CanvasLayer
var _victory_sequence_active := false
var _victory_layer: CanvasLayer
var _victory_glow_materials: Array[StandardMaterial3D] = []
var _victory_glow_active := false
var _victory_glow_hue := 0.0
var _victory_hover_active := false
var _victory_hover_angle := 0.0
var _web_render_budget_enabled := false
var _effect_refresh_elapsed := 0.0

func _ready() -> void:
	_web_render_budget_enabled = OS.has_feature("web")
	_apply_web_render_budget()
	_setup_ferris_wheel()
	_setup_fling_collision()
	Events.big_stop.connect(_on_big_stop)
	RideState.axle_failure_triggered.connect(_on_axle_failure_triggered)
	RideState.victory_triggered.connect(_on_victory_triggered)
	RideState.riders_launched_changed.connect(_on_riders_launched_changed)
	_maybe_show_manual()


# Present the Operation Manual on the first shift of the session, freezing the
# sim until the operator signs off. The intro orbit + hands wait behind it
# (their _process is paused), then play once the manual is dismissed.
func _maybe_show_manual() -> void:
	if Settings.manual_seen or DisplayServer.get_name() == "headless":
		return
	Settings.manual_seen = true
	get_tree().paused = true
	var manual := DocumentOverlay.new()
	manual.closed.connect(func() -> void: get_tree().paused = false)
	add_child(manual)

func _process(_delta: float) -> void:
	if _failure_sequence_active:
		return
	if _victory_glow_active:
		_update_victory_glow(_delta)
	if _wheel == null or _baskets.is_empty():
		return

	var angle: float
	if _victory_hover_active:
		# Runs on its own accumulator rather than RideState.angular_velocity,
		# so it can spin far past the gameplay max speed for pure spectacle.
		_victory_hover_angle += victory_hover_spin_speed * (TAU / 60.0) * _delta
		angle = spin_direction * _victory_hover_angle
	else:
		angle = spin_direction * RideState.wheel_angle
	_wheel.basis = Basis(Vector3.RIGHT, angle) * _wheel_rest_basis

	_update_gondolas()
	_update_flying_gondolas(_delta)
	_update_visual_effects(_delta)

func _update_visual_effects(delta: float) -> void:
	if not _web_render_budget_enabled:
		_update_hot_glow()
		_update_sparks()
		_update_progress_lights(delta)
		return

	_effect_refresh_elapsed += delta
	if _effect_refresh_elapsed < WEB_EFFECT_REFRESH_INTERVAL:
		return
	var elapsed := _effect_refresh_elapsed
	_effect_refresh_elapsed = 0.0
	_update_hot_glow()
	_update_sparks()
	_update_progress_lights(elapsed)

func _apply_web_render_budget() -> void:
	if not _web_render_budget_enabled:
		return
	_disable_light_shadows(self)

func _disable_light_shadows(node: Node) -> void:
	if node is Light3D:
		(node as Light3D).shadow_enabled = false
	for child in node.get_children():
		_disable_light_shadows(child)

func _setup_ferris_wheel() -> void:
	_ferris_scene_root = _find_node3d("FerrisScene")
	_wheel = _find_wheel_node()
	_basket = _find_node3d("basket")
	_rider = _find_node3d("kid_one")

	if _wheel == null or _basket == null:
		push_warning("StageOne could not find the ferris wheel mesh; animation is disabled.")
		return

	_wheel_rest_basis = _wheel.basis
	_gondola_center_x = _get_frame_center_x()
	_basket_basis = _basket.global_basis

	if _rider != null:
		_rider_basis = _rider.global_basis
		_rider_offset_from_basket = _rider.global_position - _basket.global_position

	for node_name in ROPE_NODE_NAMES:
		var rope := _find_node3d(node_name)
		if rope != null:
			rope.visible = false

	_create_gondolas()
	_create_hanger_bars()
	_setup_hot_glow()
	_setup_sparks()
	_setup_progress_lights()
	_update_gondolas()

func _create_gondolas() -> void:
	_baskets.clear()
	_riders.clear()
	_socket_local_positions.clear()
	_gondola_flying.clear()
	_basket_velocities.clear()
	_rider_velocities.clear()
	_rider_spin_axes.clear()
	_rider_spin_speeds.clear()
	_basket_bounces.clear()
	_rider_bounces.clear()
	_flight_ages.clear()
	_basket_rest_scales.clear()
	_rider_rest_scales.clear()

	var basket_parent := _basket.get_parent()
	var rider_is_inside_basket := _rider != null and _is_descendant_of(_rider, _basket)
	var rider_parent := _rider.get_parent() if _rider != null else null
	var count := clampi(gondola_count, 1, 8)

	for index in count:
		var basket := _basket
		var rider := _rider

		if index > 0:
			basket = _basket.duplicate()
			basket.name = "basket_%02d" % [index + 1]
			basket_parent.add_child(basket)

			if rider_is_inside_basket:
				rider = basket.find_child(_rider.name, true, false) as Node3D
			elif _rider != null and rider_parent != null:
				rider = _rider.duplicate()
				rider.name = "kid_%02d" % [index + 1]
				rider_parent.add_child(rider)

		_baskets.append(basket)
		_riders.append(rider)
		_gondola_flying.append(false)
		_basket_velocities.append(Vector3.ZERO)
		_rider_velocities.append(Vector3.ZERO)
		_rider_spin_axes.append(Vector3.RIGHT)
		_rider_spin_speeds.append(0.0)
		_basket_bounces.append(0)
		_rider_bounces.append(0)
		_flight_ages.append(0.0)
		_basket_rest_scales.append(basket.scale)
		_rider_rest_scales.append(rider.scale if rider != null else Vector3.ONE)

		var angle := TAU * float(index) / float(count)
		var socket_world_position := _wheel.global_position + Vector3(0.0, sin(angle) * gondola_orbit_radius, cos(angle) * gondola_orbit_radius)
		_socket_local_positions.append(_wheel.to_local(socket_world_position))

func _is_descendant_of(node: Node, possible_parent: Node) -> bool:
	var parent := node.get_parent()
	while parent != null:
		if parent == possible_parent:
			return true
		parent = parent.get_parent()

	return false

func _find_node3d(node_name: String) -> Node3D:
	var found := find_child(node_name, true, false)
	if found is Node3D:
		return found

	return null

func _find_wheel_node() -> Node3D:
	var wheel := _find_node3d(WHEEL_NODE_NAME)
	if wheel != null:
		return wheel

	wheel = _find_node3d(WHEEL_NODE_FALLBACK_NAME)
	if wheel != null and wheel.get_class() == "VehicleWheel3D":
		return wheel

	return null

func _create_hanger_bars() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.09, 0.07)
	material.roughness = 0.8

	for index in _baskets.size():
		_left_hanger_bars.append(_create_hanger_bar("HangerLeft_%02d" % [index + 1], material))
		_right_hanger_bars.append(_create_hanger_bar("HangerRight_%02d" % [index + 1], material))

func _create_hanger_bar(bar_name: String, material: Material) -> MeshInstance3D:
	var bar := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 8
	mesh.top_radius = hanger_bar_radius
	mesh.bottom_radius = hanger_bar_radius
	bar.name = bar_name
	bar.mesh = mesh
	bar.material_override = material
	add_child(bar)
	return bar

func _setup_hot_glow() -> void:
	var glow_mesh := SphereMesh.new()
	glow_mesh.radial_segments = 16
	glow_mesh.rings = 8
	glow_mesh.radius = axle_glow_radius
	glow_mesh.height = axle_glow_radius * 2.0

	_hot_glow_material = StandardMaterial3D.new()
	_hot_glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hot_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hot_glow_material.albedo_color = Color(axle_warning_color.r, axle_warning_color.g, axle_warning_color.b, 0.0)
	_hot_glow_material.emission_enabled = true
	_hot_glow_material.emission = axle_warning_color
	_hot_glow_material.emission_energy_multiplier = 0.0
	_hot_glow_material.roughness = 0.95

	_axle_glow_mesh = MeshInstance3D.new()
	_axle_glow_mesh.name = "AxleSpeedGlow"
	_axle_glow_mesh.mesh = glow_mesh
	_axle_glow_mesh.material_override = _hot_glow_material
	_axle_glow_mesh.visible = false
	add_child(_axle_glow_mesh)
	_axle_glow_mesh.global_position = _axle_glow_position()

	_hot_glow_light = OmniLight3D.new()
	_hot_glow_light.name = "WheelHotGlow"
	_hot_glow_light.light_color = axle_warning_color
	_hot_glow_light.light_energy = 0.0
	_hot_glow_light.shadow_enabled = false
	_hot_glow_light.omni_range = gondola_orbit_radius * 0.8
	_hot_glow_light.visible = not _web_render_budget_enabled
	add_child(_hot_glow_light)
	_hot_glow_light.global_position = _axle_glow_position()

# Progress ring: one bulb per spoke tip on the rotating wheel frame. They orbit
# with the wheel and light up one-by-one as riders are launched - a classic
# carnival marquee that doubles as the player's score readout.
func _setup_progress_lights() -> void:
	_progress_bulbs.clear()
	_progress_lights.clear()
	_progress_bulb_materials.clear()
	_progress_bulb_pulse.clear()
	_progress_bulb_flicker.clear()
	_progress_bulb_on.clear()
	_progress_bulb_base_color.clear()
	_progress_bulb_strobe.clear()
	_progress_bulb_angle.clear()
	_progress_show_phase = 0.0
	_progress_lit = 0
	if _wheel == null:
		return

	var count := mini(_socket_local_positions.size(), RideState.riders_required_to_win)
	for i in count:
		# Sit on the rim where the spoke meets it; the gondola hangs below in
		# world space, so this stays on the frame, not the car.
		var local_pos: Vector3 = _socket_local_positions[i] + Vector3(progress_bulb_axle_offset, 0.0, 0.0)

		# Starts as dark glass (unlit). Unshaded so a lit bulb glows flat and
		# bright; emission is ramped on only once this rung lights.
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = PROGRESS_OFF_COLOR
		material.emission_enabled = true
		material.emission = PROGRESS_OFF_COLOR
		material.emission_energy_multiplier = 0.0

		var bulb_mesh := SphereMesh.new()
		bulb_mesh.radius = progress_bulb_radius
		bulb_mesh.height = progress_bulb_radius * 2.0
		bulb_mesh.radial_segments = 8
		bulb_mesh.rings = 4

		var bulb := MeshInstance3D.new()
		bulb.name = "ProgressBulb_%02d" % [i + 1]
		bulb.mesh = bulb_mesh
		bulb.material_override = material
		bulb.position = local_pos
		_wheel.add_child(bulb)

		var light := OmniLight3D.new()
		light.name = "ProgressLight_%02d" % [i + 1]
		light.light_color = PROGRESS_OFF_COLOR
		light.light_energy = 0.0
		light.shadow_enabled = false
		light.omni_range = progress_light_range
		light.omni_attenuation = 1.0
		light.visible = false  # only enabled (desktop) once this rung lights
		light.position = local_pos
		_wheel.add_child(light)

		_progress_bulbs.append(bulb)
		_progress_bulb_materials.append(material)
		_progress_lights.append(light)
		_progress_bulb_pulse.append(0.0)
		_progress_bulb_flicker.append(1.0)
		_progress_bulb_on.append(false)
		_progress_bulb_base_color.append(PROGRESS_OFF_COLOR)
		_progress_bulb_strobe.append(PROGRESS_OFF_COLOR)
		_progress_bulb_angle.append(TAU * float(i) / float(count))

	_progress_order = _build_progress_order(count)
	# Reflect any progress already on the books (normally 0 at level start).
	_on_riders_launched_changed(RideState.riders_launched_count)


# Activation order that fills opposite ends first and stays balanced: for 6 that
# is [0, 3, 1, 4, 2, 5] - each new bulb lands ~across the wheel from the last.
func _build_progress_order(n: int) -> Array[int]:
	var order: Array[int] = []
	var half := n / 2
	for i in range(half):
		order.append(i)
		order.append(i + half)
	if n % 2 == 1:
		order.append(n - 1)
	return order


# Maps the progress count onto physical bulbs via _progress_order, so launches
# light bulbs at opposite ends of the wheel rather than sweeping one side. The
# color advances with the progress step (k), not the physical position.
func _on_riders_launched_changed(count: int) -> void:
	count = clampi(count, 0, _progress_lights.size())
	for k in range(_progress_order.size()):
		var idx: int = _progress_order[k]
		var should_be_on := k < count
		if should_be_on and not _progress_bulb_on[idx]:
			_activate_rung(idx, _progress_color(k))
		elif not should_be_on and _progress_bulb_on[idx]:
			_deactivate_rung(idx)
	_progress_lit = count


# Turn a bulb on with a launch flash (decays to steady in _update_progress_lights).
func _activate_rung(idx: int, color: Color) -> void:
	_progress_bulb_on[idx] = true
	_progress_bulb_base_color[idx] = color
	_progress_bulb_strobe[idx] = color
	_progress_bulb_pulse[idx] = 1.0
	_progress_bulb_flicker[idx] = 1.0

	var material := _progress_bulb_materials[idx]
	material.albedo_color = color
	material.emission = color
	material.emission_energy_multiplier = PROGRESS_EMISSION_FLASH

	var light := _progress_lights[idx]
	light.light_color = color
	# Desktop gets a real halo light; web rides on the emissive bulb + glow only.
	light.visible = not _web_render_budget_enabled
	if light.visible:
		light.light_energy = progress_flash_energy


func _deactivate_rung(idx: int) -> void:
	_progress_bulb_on[idx] = false
	_progress_bulb_pulse[idx] = 0.0

	var material := _progress_bulb_materials[idx]
	material.albedo_color = PROGRESS_OFF_COLOR
	material.emission = PROGRESS_OFF_COLOR
	material.emission_energy_multiplier = 0.0

	var light := _progress_lights[idx]
	light.light_energy = 0.0
	light.visible = false


func _progress_color(index: int) -> Color:
	if progress_palette != null and progress_palette.get_point_count() > 0:
		var n := maxi(_progress_lights.size() - 1, 1)
		return progress_palette.sample(clampf(float(index) / float(n), 0.0, 1.0))
	return PROGRESS_DEFAULT_COLORS[clampi(index, 0, PROGRESS_DEFAULT_COLORS.size() - 1)]


# 0 far from the Big Stop sweet-spot window, ramping to 1 across the lead-in
# band and pinned at 1 while inside it - the tell the bulbs flicker against.
func _big_stop_window_proximity() -> float:
	if RideState.is_emergency_stopping:
		return 0.0  # the moment has passed; don't re-flicker on the way down
	var lo := RideState.big_stop_current_min_speed
	var hi := RideState.big_stop_current_max_speed
	if lo <= 0.0:
		return 0.0
	var av := absf(RideState.angular_velocity)
	if av >= lo and av <= hi:
		return 1.0
	if av < lo:
		return clampf((av - (lo - progress_window_lead_speed)) / maxf(progress_window_lead_speed, 0.01), 0.0, 1.0)
	# Overshot the window - fall off quickly past the top edge.
	return clampf(1.0 - (av - hi) / maxf(progress_window_lead_speed, 0.01), 0.0, 1.0)


func _shift_hue(color: Color, amount: float) -> Color:
	return Color.from_hsv(fposmod(color.h + amount, 1.0), color.s, color.v, color.a)


# Per-frame light show for lit bulbs. Far from the window: a decadent traveling
# chase with gentle hue-breathing - alive and celebratory. As the Big Stop sweet
# spot nears: the cadence tightens and BOTH color and brightness strobe, bold
# bursts of contrasting hues, peaking in a violent flash right at the window.
func _update_progress_lights(delta: float) -> void:
	if _progress_lit <= 0:
		return
	var proximity := _big_stop_window_proximity()
	_progress_show_phase = fposmod(_progress_show_phase + delta, 3600.0)

	# Re-roll cadence shrinks toward the window: slow shimmer far out, frantic
	# color/brightness strobe at the sweet spot.
	_progress_flicker_timer += delta
	var reroll := false
	if _progress_flicker_timer >= lerpf(PROGRESS_FLICKER_SLOW_INTERVAL, PROGRESS_FLICKER_FAST_INTERVAL, proximity):
		_progress_flicker_timer = 0.0
		reroll = true
	var amp := proximity * progress_flicker_strength

	for idx in range(_progress_bulbs.size()):
		if not _progress_bulb_on[idx]:
			continue

		if _progress_bulb_pulse[idx] > 0.0:
			_progress_bulb_pulse[idx] = move_toward(_progress_bulb_pulse[idx], 0.0, delta / maxf(progress_pulse_time, 0.01))
		var pulse: float = _progress_bulb_pulse[idx]
		var angle: float = _progress_bulb_angle[idx]

		# Idle show: a brightness wave that travels around the ring plus a slow
		# hue breathe, so the lit ring shimmers like a real marquee.
		var wave := 1.0 + show_chase_depth * sin(_progress_show_phase * show_chase_speed - angle * PROGRESS_CHASE_WAVES)
		var hue_breathe := show_hue_drift * sin(_progress_show_phase * show_hue_speed + angle)
		var shimmer_color := _shift_hue(_progress_bulb_base_color[idx], hue_breathe)

		# Sweet-spot strobe: re-roll a bold contrasting color + brightness kick,
		# then blend toward it by proximity so it takes over near the window.
		if reroll and proximity > 0.0:
			_progress_bulb_strobe[idx] = PROGRESS_STROBE_COLORS[randi() % PROGRESS_STROBE_COLORS.size()]
			_progress_bulb_flicker[idx] = maxf(1.0 + amp * (randf() * 2.0 - 1.0), 0.0)
		elif proximity <= 0.0:
			_progress_bulb_flicker[idx] = 1.0

		var color := shimmer_color.lerp(_progress_bulb_strobe[idx], proximity)
		var brightness := lerpf(wave, _progress_bulb_flicker[idx], proximity)
		var pulse_emit := pulse * (PROGRESS_EMISSION_FLASH - PROGRESS_EMISSION_STEADY)
		var pulse_light := pulse * (progress_flash_energy - progress_light_energy)

		var material := _progress_bulb_materials[idx]
		material.albedo_color = color
		material.emission = color
		material.emission_energy_multiplier = (PROGRESS_EMISSION_STEADY + pulse_emit) * brightness

		var light := _progress_lights[idx]
		if light.visible:
			light.light_color = color
			light.light_energy = (progress_light_energy + pulse_light) * brightness


func _setup_sparks() -> void:
	var spark_mesh := QuadMesh.new()
	spark_mesh.size = Vector2(0.08, 0.08)

	var spark_mesh_material := StandardMaterial3D.new()
	spark_mesh_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	spark_mesh_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mesh_material.albedo_color = spark_color
	spark_mesh_material.emission_enabled = true
	spark_mesh_material.emission = spark_color
	spark_mesh_material.emission_energy_multiplier = 3.0
	spark_mesh.material = spark_mesh_material

	_spark_process_material = ParticleProcessMaterial.new()
	_spark_process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_spark_process_material.emission_sphere_radius = 0.28
	_spark_process_material.direction = Vector3(0.0, 0.4, 1.0)
	_spark_process_material.spread = 160.0
	_spark_process_material.gravity = Vector3(0.0, -5.0, 0.0)
	_spark_process_material.initial_velocity_min = 2.5
	_spark_process_material.initial_velocity_max = 6.5
	_spark_process_material.scale_min = 0.5
	_spark_process_material.scale_max = 1.35
	_spark_process_material.color = spark_color

	_axle_sparks = GPUParticles3D.new()
	_axle_sparks.name = "AxleSparks"
	_axle_sparks.amount = WEB_AXLE_SPARK_AMOUNT if _web_render_budget_enabled else 90
	_axle_sparks.fixed_fps = 30 if _web_render_budget_enabled else 0
	_axle_sparks.lifetime = 0.42
	_axle_sparks.explosiveness = 0.0
	_axle_sparks.randomness = 0.65
	_axle_sparks.emitting = false
	_axle_sparks.process_material = _spark_process_material
	_axle_sparks.draw_pass_1 = spark_mesh
	add_child(_axle_sparks)
	_axle_sparks.global_position = _wheel.global_position

func _setup_fling_collision() -> void:
	if _web_render_budget_enabled:
		return

	var environment_root := _find_node3d("YamEnvironment")
	if environment_root == null:
		return

	_fling_collision_root = Node3D.new()
	_fling_collision_root.name = "FlingCollisionProxies"
	_fling_collision_root.visible = false
	add_child(_fling_collision_root)
	_add_mesh_collision_proxies(environment_root)


func _add_mesh_collision_proxies(node: Node) -> void:
	if node is MeshInstance3D:
		_add_mesh_collision_proxy(node as MeshInstance3D)
	for child in node.get_children():
		_add_mesh_collision_proxies(child)


func _add_mesh_collision_proxy(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return

	var shape := mesh_instance.mesh.create_trimesh_shape()
	if shape == null:
		return

	var body := StaticBody3D.new()
	body.name = "%s_collision" % mesh_instance.name
	body.collision_layer = 1
	body.collision_mask = 0
	_fling_collision_root.add_child(body)
	body.global_transform = mesh_instance.global_transform

	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

func _update_hot_glow() -> void:
	if _axle_glow_mesh == null or _hot_glow_light == null or _hot_glow_material == null:
		return

	var speed := absf(RideState.angular_velocity)
	var sweetspot_min := RideState.big_stop_current_min_speed
	var sweetspot_max := RideState.big_stop_current_max_speed
	var warning_start := maxf(0.0, sweetspot_min - axle_warning_lead_speed)

	var state := 0
	var heat := 0.0
	if speed >= warning_start and speed < sweetspot_min:
		state = 1
		heat = clampf(inverse_lerp(warning_start, sweetspot_min, speed), 0.0, 1.0)
	elif speed >= sweetspot_min and speed < sweetspot_max:
		state = 2
		heat = 1.0
	elif speed >= sweetspot_max:
		state = 3
		heat = clampf(inverse_lerp(sweetspot_max, RideState.rpm_max, speed), 0.65, 1.0)

	var pulse := 0.78 + sin(Time.get_ticks_msec() * 0.018) * 0.22
	var glow_position := _axle_glow_position()
	_axle_glow_mesh.global_position = glow_position
	if _hot_glow_light.visible:
		_hot_glow_light.global_position = glow_position
	_axle_glow_mesh.visible = state != 0

	if state != _last_axle_glow_state:
		_last_axle_glow_state = state
		var state_color := _axle_glow_color_for_state(state)
		_hot_glow_material.emission = state_color
		if _hot_glow_light.visible:
			_hot_glow_light.light_color = state_color

	var color := _axle_glow_color_for_state(state)
	_hot_glow_material.albedo_color = Color(color.r, color.g, color.b, heat * 0.85)
	_hot_glow_material.emission_energy_multiplier = heat * (1.4 + pulse * 1.4)
	if _hot_glow_light.visible:
		_hot_glow_light.light_energy = heat * hot_glow_light_energy * pulse


func _axle_glow_position() -> Vector3:
	var glow_position := _wheel.global_position
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return glow_position

	var to_camera := camera.global_position - glow_position
	if to_camera.length_squared() <= 0.001:
		return glow_position

	return glow_position + to_camera.normalized() * axle_glow_camera_offset


func _axle_glow_color_for_state(state: int) -> Color:
	match state:
		1:
			return axle_warning_color
		2:
			return axle_sweetspot_color
		3:
			return axle_danger_color
		_:
			return axle_warning_color

func _update_sparks() -> void:
	if _axle_sparks == null or _spark_process_material == null:
		return

	var spark_heat := inverse_lerp(spark_start_speed, spark_full_speed, absf(RideState.angular_velocity))
	spark_heat = clampf(spark_heat, 0.0, 1.0)
	_axle_sparks.global_position = _wheel.global_position
	_axle_sparks.emitting = spark_heat > 0.0
	_axle_sparks.amount_ratio = maxf(spark_heat, 0.05) if spark_heat > 0.0 else 0.0
	_spark_process_material.initial_velocity_min = lerpf(1.4, 4.5, spark_heat)
	_spark_process_material.initial_velocity_max = lerpf(3.0, 9.0, spark_heat)

func _update_gondolas() -> void:
	for index in _baskets.size():
		_update_gondola(index)

func _update_gondola(index: int) -> void:
	if _gondola_flying[index]:
		return

	var basket := _baskets[index]
	var rider := _riders[index]
	var attachment := _wheel.to_global(_socket_local_positions[index])

	attachment.x = _gondola_center_x
	var basket_position := attachment + Vector3.DOWN * gondola_hang_offset
	basket_position.x = _gondola_center_x

	basket.global_position = basket_position
	basket.global_basis = _basket_basis

	if rider != null:
		rider.global_position = basket.global_position + _rider_offset_from_basket
		rider.global_basis = _rider_basis

	_update_hanger_bars(index, attachment, basket.global_position)

func _on_big_stop() -> void:
	if _failure_sequence_active or _victory_sequence_active:
		return
	# RideState already judged this press against the current progressive
	# window the moment it happened; this is just acting on that verdict.
	if not RideState.last_big_stop_was_successful:
		return

	var index := _find_leftmost_gondola()
	if index < 0:
		return

	_throw_gondola(index)

func _find_leftmost_gondola() -> int:
	var camera := get_viewport().get_camera_3d()
	var best_index := -1
	var best_x := INF

	for index in _baskets.size():
		if _gondola_flying[index]:
			continue

		var basket := _baskets[index]
		var screen_x: float
		if camera != null and not camera.is_position_behind(basket.global_position):
			screen_x = camera.unproject_position(basket.global_position).x
		else:
			screen_x = basket.global_position.x

		if screen_x < best_x:
			best_x = screen_x
			best_index = index

	return best_index

func _throw_gondola(index: int) -> void:
	_gondola_flying[index] = true
	_basket_bounces[index] = 0
	_rider_bounces[index] = 0
	_flight_ages[index] = 0.0
	RideState.set_controls_locked(true)

	if index < _left_hanger_bars.size():
		_left_hanger_bars[index].visible = false
	if index < _right_hanger_bars.size():
		_right_hanger_bars[index].visible = false

	var basket := _baskets[index]
	var rider := _riders[index]
	var launch_speed := clampf(RideState.last_stop_severity, 0.0, 1.0)
	var side_throw := 1.0
	_basket_velocities[index] = Vector3(0.0, 9.5, side_throw * lerpf(10.0, 17.0, launch_speed))

	if rider != null:
		_rider_velocities[index] = Vector3(randf_range(-1.0, 1.0), 12.5, side_throw * lerpf(14.0, 23.0, launch_speed))
		_rider_spin_axes[index] = Vector3(randf(), randf(), randf()).normalized()
		_rider_spin_speeds[index] = lerpf(5.5, 11.0, launch_speed)
		rider.global_position = basket.global_position + _rider_offset_from_basket

	_start_spectacle_camera(basket, rider)
	Events.fling.emit()
	print("BASKET %d LAUNCHED AT %.1f RPM" % [index + 1, RideState.last_stop_severity * RideState.rpm_max])
	# Camera is already watching the fling by the time this can trigger the
	# win condition, so the victory sequence (if any) waits for it to return.
	RideState.mark_basket_released()


func _on_axle_failure_triggered() -> void:
	if _failure_sequence_active:
		return
	_failure_sequence_active = true
	print("AXLE HEAT: ferris wheel breakaway animation starts")
	_run_failure_sequence()


func _run_failure_sequence() -> void:
	_animate_wheel_breakaway()
	await get_tree().create_timer(game_over_text_delay).timeout
	print("AXLE HEAT: placeholder game over text appears")
	_show_game_over_text()
	await get_tree().create_timer(game_over_display_duration).timeout
	print("AXLE HEAT: title menu transition starts")
	await GameOrchestrator.return_to_title()


func _on_victory_triggered() -> void:
	if _victory_sequence_active or _failure_sequence_active:
		return
	_victory_sequence_active = true
	print("VICTORY: sequence starts")
	_run_victory_sequence()


func _run_victory_sequence() -> void:
	await _wait_for_spectacle_camera()
	await _animate_victory_spin()
	print("VICTORY: title menu transition starts")
	await GameOrchestrator.return_to_title()


func _wait_for_spectacle_camera() -> void:
	# The winning launch's basket/rider fling still has the camera mid-watch
	# at this point - let it finish and return before the wheel starts lifting.
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.has_method("is_watching_fling") and camera.is_watching_fling():
		await camera.fling_watch_finished


func _animate_victory_spin() -> void:
	# Shares the failure sequence's pivot builder, which pulls the wheel
	# assembly (frame, axle, baskets, ropes) free of the support arms since
	# frame_arm* is excluded from it by name.
	var target := _build_wheel_breakaway_pivot()
	var camera := get_viewport().get_camera_3d()
	if target != null:
		var lift_position := target.global_position + Vector3.UP * victory_lift_height
		if camera != null and camera.has_method("watch_victory"):
			camera.watch_victory(lift_position)
		var lift_tween := create_tween()
		lift_tween.tween_property(target, "global_position", lift_position, victory_lift_duration) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await lift_tween.finished
	else:
		await get_tree().create_timer(victory_lift_duration).timeout

	# Hovers there for the rest of the sequence, spinning much faster than
	# normal play allows and glowing through a fast-moving rainbow gradient.
	# Opening the governor and bursting target_rpm toward max speed also
	# makes the existing speed-reactive hot glow and sparks flare up for free,
	# since they already read angular_velocity.
	_victory_hover_active = true
	_start_victory_glow(target if target != null else self)
	RideState.is_governed = false
	RideState.target_rpm = RideState.rpm_max * victory_spin_speed_multiplier
	_shake_camera(victory_spin_duration * 0.5, victory_camera_shake_strength)

	# The text comes up soon after the hover starts and stays up for the
	# remainder of the hover, so it is on screen continuously until the
	# title transition begins right after this function returns.
	await get_tree().create_timer(victory_text_delay).timeout
	print("VICTORY: victory text appears")
	_show_victory_text()
	await get_tree().create_timer(maxf(victory_spin_duration - victory_text_delay, 0.0)).timeout

	RideState.target_rpm = 0.0
	_stop_victory_glow()
	_victory_hover_active = false


func _start_victory_glow(root: Node) -> void:
	var instances: Array[MeshInstance3D] = []
	_collect_mesh_instances(root, instances)

	_victory_glow_materials.clear()
	for mesh_instance in instances:
		if mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var material := _glow_material_from(mesh_instance, surface_index)
			mesh_instance.set_surface_override_material(surface_index, material)
			_victory_glow_materials.append(material)

	_victory_glow_hue = 0.0
	_victory_glow_active = true


func _glow_material_from(mesh_instance: MeshInstance3D, surface_index: int) -> StandardMaterial3D:
	var source := mesh_instance.get_surface_override_material(surface_index)
	if source == null:
		source = mesh_instance.mesh.surface_get_material(surface_index)

	var material: StandardMaterial3D
	if source is StandardMaterial3D:
		material = source.duplicate(true) as StandardMaterial3D
	else:
		material = StandardMaterial3D.new()

	material.emission_enabled = true
	material.emission_energy_multiplier = victory_glow_energy
	return material


func _collect_mesh_instances(node: Node, instances: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		instances.append(node)
	for child in node.get_children():
		_collect_mesh_instances(child, instances)


func _update_victory_glow(delta: float) -> void:
	# A continuously rotating hue, with each material offset by its position
	# in the list, paints a rainbow gradient across the wheel rather than one
	# flat color - and the whole gradient sweeps around fast.
	_victory_glow_hue = fmod(_victory_glow_hue + victory_glow_hue_speed * delta, 1.0)
	var count := maxi(_victory_glow_materials.size(), 1)
	for i in _victory_glow_materials.size():
		var phase := float(i) / float(count)
		var hue := fmod(_victory_glow_hue + phase, 1.0)
		_victory_glow_materials[i].emission = Color.from_hsv(hue, 1.0, 1.0)


func _stop_victory_glow() -> void:
	_victory_glow_active = false
	if _victory_glow_materials.is_empty():
		return

	var tween := create_tween()
	tween.set_parallel(true)
	for material in _victory_glow_materials:
		tween.tween_property(material, "emission_energy_multiplier", 0.0, victory_glow_fade_out_time)


func _shake_camera(duration: float, strength: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or strength <= 0.0:
		return

	var tween := create_tween()
	var shake_steps := 8
	var step_time := maxf(duration / float(shake_steps), 0.01)
	for _i in shake_steps:
		var offset := Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		tween.tween_property(camera, "h_offset", offset.x, step_time)
		tween.parallel().tween_property(camera, "v_offset", offset.y, step_time)
	tween.tween_property(camera, "h_offset", 0.0, step_time)
	tween.parallel().tween_property(camera, "v_offset", 0.0, step_time)


func _show_victory_text() -> void:
	if _victory_layer != null:
		_victory_layer.queue_free()

	_victory_layer = CanvasLayer.new()
	_victory_layer.layer = 64
	add_child(_victory_layer)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_victory_layer.add_child(center)

	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.05, 0.0, 0.78)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(1.0, 0.82, 0.2, 0.95)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.content_margin_left = 34.0
	panel_style.content_margin_top = 20.0
	panel_style.content_margin_right = 34.0
	panel_style.content_margin_bottom = 22.0
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.modulate.a = 0.0
	box.scale = Vector2(0.7, 0.7)
	box.pivot_offset = Vector2(320.0, 90.0)
	panel.add_child(box)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = victory_text
	title.add_theme_font_size_override("font_size", 104)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.2))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 12)
	box.add_child(title)

	var subtext := Label.new()
	subtext.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtext.text = victory_subtext_format % RideState.riders_required_to_win
	subtext.add_theme_font_size_override("font_size", 32)
	subtext.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82))
	subtext.add_theme_color_override("font_outline_color", Color.BLACK)
	subtext.add_theme_constant_override("outline_size", 6)
	box.add_child(subtext)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(box, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(box, "scale", Vector2(1.12, 1.12), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(box, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_callback(_start_victory_text_pulse.bind(box))


func _start_victory_text_pulse(box: VBoxContainer) -> void:
	if not is_instance_valid(box):
		return
	var pulse := create_tween()
	pulse.set_loops()
	pulse.tween_property(box, "scale", Vector2(1.06, 1.06), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(box, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _animate_wheel_breakaway() -> void:
	var target := _build_wheel_breakaway_pivot()
	if target == null:
		await get_tree().create_timer(failure_drop_duration + failure_roll_duration).timeout
		return

	var start_position := target.global_position
	var drop_position := start_position + Vector3.DOWN * failure_drop_distance
	var roll_direction := _screen_right_world_direction()
	var roll_position := drop_position + roll_direction * failure_roll_distance

	var tween := create_tween()
	tween.set_parallel(false)
	tween.tween_property(
		target,
		"global_position",
		drop_position,
		failure_drop_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(
		target,
		"global_position",
		roll_position,
		failure_roll_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(
		target,
		"rotation_degrees:x",
		target.rotation_degrees.x + failure_roll_rotation_degrees,
		failure_roll_duration
	).set_trans(Tween.TRANS_LINEAR)
	await tween.finished


func _build_wheel_breakaway_pivot() -> Node3D:
	var breakaway_nodes := _collect_wheel_breakaway_nodes()
	if breakaway_nodes.is_empty():
		return _wheel

	var pivot := Node3D.new()
	pivot.name = "WheelBreakawayPivot"
	add_child(pivot)
	pivot.global_position = _wheel.global_position if _wheel != null else breakaway_nodes[0].global_position

	for node in breakaway_nodes:
		if node == null or not is_instance_valid(node):
			continue
		if node == pivot or node == self:
			continue
		node.reparent(pivot, true)

	return pivot


func _collect_wheel_breakaway_nodes() -> Array[Node3D]:
	var candidates: Array[Node3D] = []
	if _ferris_scene_root != null:
		_collect_named_breakaway_nodes(_ferris_scene_root, candidates)

	for index in _baskets.size():
		if _gondola_flying[index]:
			continue
		_append_unique_node(candidates, _baskets[index])
		_append_unique_node(candidates, _riders[index])

	for bar in _left_hanger_bars:
		if bar.visible:
			_append_unique_node(candidates, bar)
	for bar in _right_hanger_bars:
		if bar.visible:
			_append_unique_node(candidates, bar)

	_append_unique_node(candidates, _axle_glow_mesh)
	_append_unique_node(candidates, _hot_glow_light)
	_append_unique_node(candidates, _axle_sparks)

	var top_level_nodes: Array[Node3D] = []
	for candidate in candidates:
		if _has_selected_ancestor(candidate, candidates):
			continue
		_append_unique_node(top_level_nodes, candidate)

	return top_level_nodes


func _collect_named_breakaway_nodes(node: Node, candidates: Array[Node3D]) -> void:
	if node is Node3D and _is_wheel_breakaway_name(String(node.name)):
		_append_unique_node(candidates, node as Node3D)

	for child in node.get_children():
		_collect_named_breakaway_nodes(child, candidates)


func _is_wheel_breakaway_name(node_name: String) -> bool:
	var lower_name := node_name.to_lower()
	if lower_name.begins_with("frame_arm"):
		return false

	return (
		lower_name.begins_with("frame")
		or lower_name.find("axle") >= 0
		or lower_name.find("axel") >= 0
		or lower_name.begins_with("basket")
		or lower_name.begins_with("kid")
		or lower_name.begins_with("rope")
	)


func _append_unique_node(nodes: Array[Node3D], node: Node3D) -> void:
	if node == null:
		return
	if nodes.has(node):
		return
	nodes.append(node)


func _has_selected_ancestor(node: Node3D, selected_nodes: Array[Node3D]) -> bool:
	var parent := node.get_parent()
	while parent != null:
		if parent is Node3D and selected_nodes.has(parent):
			return true
		parent = parent.get_parent()
	return false


func _screen_right_world_direction() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.FORWARD

	var direction := camera.global_basis.x
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return Vector3.FORWARD
	return direction.normalized()


func _show_game_over_text() -> void:
	if _game_over_layer != null:
		_game_over_layer.queue_free()

	_game_over_layer = CanvasLayer.new()
	_game_over_layer.layer = 64
	add_child(_game_over_layer)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = -150.0
	_game_over_layer.add_child(center)

	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.0, 0.0, 0.78)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(1.0, 0.16, 0.08, 0.9)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.content_margin_left = 34.0
	panel_style.content_margin_top = 20.0
	panel_style.content_margin_right = 34.0
	panel_style.content_margin_bottom = 22.0
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.modulate.a = 0.0
	box.scale = Vector2(0.7, 0.7)
	box.pivot_offset = Vector2(320.0, 90.0)
	panel.add_child(box)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = game_over_text
	title.add_theme_font_size_override("font_size", 104)
	title.add_theme_color_override("font_color", Color(1.0, 0.22, 0.12))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 12)
	box.add_child(title)

	if game_over_subtext != "":
		var subtext := Label.new()
		subtext.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtext.text = game_over_subtext
		subtext.add_theme_font_size_override("font_size", 32)
		subtext.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
		subtext.add_theme_color_override("font_outline_color", Color.BLACK)
		subtext.add_theme_constant_override("outline_size", 6)
		box.add_child(subtext)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(box, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(box, "scale", Vector2(1.12, 1.12), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(box, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_property(title, "modulate:a", 0.62, 0.08)
	tween.chain().tween_property(title, "modulate:a", 1.0, 0.08)

func _start_spectacle_camera(basket: Node3D, rider: Node3D) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.has_method("watch_fling"):
		camera.watch_fling(basket, rider)
	else:
		RideState.set_controls_locked(false)

func _update_flying_gondolas(delta: float) -> void:
	for index in _baskets.size():
		if not _gondola_flying[index]:
			continue

		_flight_ages[index] += delta
		_update_flying_basket(index, delta)
		_update_flying_rider(index, delta)
		_update_fling_disappear(index)

func _update_flying_basket(index: int, delta: float) -> void:
	var basket := _baskets[index]
	var velocity := _basket_velocities[index]
	velocity += Vector3.DOWN * 12.0 * delta
	var motion_result := _move_fling_body(
		basket,
		velocity,
		delta,
		_basket_bounces[index],
		basket_collision_bounciness
	)
	velocity = motion_result["velocity"] as Vector3
	_basket_bounces[index] = int(motion_result["bounce_count"])
	basket.rotate_object_local(Vector3.RIGHT, 2.1 * delta)

	_basket_velocities[index] = velocity

func _update_flying_rider(index: int, delta: float) -> void:
	var rider := _riders[index]
	if rider == null:
		return

	var velocity := _rider_velocities[index]
	velocity += Vector3.DOWN * 13.0 * delta
	var motion_result := _move_fling_body(
		rider,
		velocity,
		delta,
		_rider_bounces[index],
		rider_collision_bounciness
	)
	var previous_bounce_count := _rider_bounces[index]
	velocity = motion_result["velocity"] as Vector3
	_rider_bounces[index] = int(motion_result["bounce_count"])
	rider.rotate_object_local(_rider_spin_axes[index], _rider_spin_speeds[index] * delta)

	if _rider_bounces[index] > previous_bounce_count:
		_rider_spin_speeds[index] *= 0.74
	if velocity.length() <= fling_rest_speed:
		_rider_spin_speeds[index] *= 0.9

	_rider_velocities[index] = velocity


func _move_fling_body(body: Node3D, velocity: Vector3, delta: float, bounce_count: int, bounciness: float) -> Dictionary:
	var remaining := delta
	var current_velocity := velocity
	var iteration := 0

	while remaining > 0.0 and iteration < 3:
		iteration += 1
		var from := body.global_position
		var motion := current_velocity * remaining
		if motion.length_squared() <= 0.000001:
			break

		var hit := _cast_fling_motion(from, from + motion)
		if hit.is_empty():
			body.global_position = from + motion
			return _resolve_fallback_ground(body, current_velocity, bounce_count, bounciness)

		var hit_position := hit["position"] as Vector3
		var normal := (hit["normal"] as Vector3).normalized()
		var travel_fraction := clampf(from.distance_to(hit_position) / maxf(motion.length(), 0.001), 0.0, 1.0)
		body.global_position = hit_position + normal * fling_collision_skin
		bounce_count += 1

		# Floor-like surfaces bounce (an upright normal means the body landed
		# on top of something); anything closer to vertical - a tree trunk,
		# the backdrop, a wall - is a glancing hit, so it slides along the
		# surface instead of reflecting the body back the way it came.
		var is_floor_like := normal.dot(Vector3.UP) >= fling_floor_normal_dot
		if bounce_count > fling_collision_bounce_limit or not is_floor_like:
			current_velocity = _slide_and_dampen(current_velocity, normal)
		else:
			current_velocity = current_velocity.bounce(normal) * bounciness
			current_velocity = _apply_collision_friction(current_velocity, normal)

		if current_velocity.length() <= fling_rest_speed:
			current_velocity = Vector3.ZERO
			break

		remaining *= 1.0 - travel_fraction

	return _resolve_fallback_ground(body, current_velocity, bounce_count, bounciness)


func _cast_fling_motion(from: Vector3, to: Vector3) -> Dictionary:
	if _web_render_budget_enabled:
		return _cast_web_fling_motion(from, to)

	var space_state := get_world_3d().direct_space_state
	var direction := to - from
	if direction.length_squared() <= 0.000001:
		return {}

	var offset := direction.normalized() * fling_collision_radius
	var query := PhysicsRayQueryParameters3D.create(from, to + offset)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space_state.intersect_ray(query)


func _cast_web_fling_motion(from: Vector3, to: Vector3) -> Dictionary:
	var best_t := INF
	var best_normal := Vector3.ZERO
	var delta := to - from

	if from.y > fling_ground_y and to.y <= fling_ground_y and absf(delta.y) > 0.000001:
		best_t = clampf((fling_ground_y - from.y) / delta.y, 0.0, 1.0)
		best_normal = Vector3.UP

	if from.z < web_fling_wall_z and to.z >= web_fling_wall_z and absf(delta.z) > 0.000001:
		var wall_t := clampf((web_fling_wall_z - from.z) / delta.z, 0.0, 1.0)
		if wall_t < best_t:
			best_t = wall_t
			best_normal = Vector3.BACK

	if best_t == INF:
		return {}

	return {
		"position": from.lerp(to, best_t),
		"normal": best_normal,
	}


func _resolve_fallback_ground(body: Node3D, velocity: Vector3, bounce_count: int, bounciness: float) -> Dictionary:
	if body.global_position.y > fling_ground_y:
		return {"velocity": velocity, "bounce_count": bounce_count}

	body.global_position.y = fling_ground_y
	var normal := Vector3.UP
	if bounce_count > fling_collision_bounce_limit:
		return {
			"velocity": _slide_and_dampen(velocity, normal),
			"bounce_count": bounce_count,
		}

	bounce_count += 1
	var bounced := velocity.bounce(normal) * bounciness
	bounced = _apply_collision_friction(bounced, normal)
	return {
		"velocity": Vector3.ZERO if bounced.length() <= fling_rest_speed else bounced,
		"bounce_count": bounce_count,
	}


func _apply_collision_friction(velocity: Vector3, normal: Vector3) -> Vector3:
	var normal_component := normal * velocity.dot(normal)
	var tangent_component := velocity - normal_component
	return normal_component + tangent_component * fling_collision_friction


func _slide_and_dampen(velocity: Vector3, normal: Vector3) -> Vector3:
	var slid := velocity.slide(normal) * fling_collision_friction
	return Vector3.ZERO if slid.length() <= fling_rest_speed else slid

func _update_fling_disappear(index: int) -> void:
	var fade_progress := clampf((_flight_ages[index] - 2.2) / 1.25, 0.0, 1.0)
	if fade_progress <= 0.0:
		return

	var scale_weight := 1.0 - _smoother_step(fade_progress)
	var basket := _baskets[index]
	basket.scale = _basket_rest_scales[index] * maxf(scale_weight, 0.03)

	var rider := _riders[index]
	if rider != null:
		rider.scale = _rider_rest_scales[index] * maxf(scale_weight, 0.03)

	if fade_progress >= 1.0:
		basket.visible = false
		if rider != null:
			rider.visible = false

func _smoother_step(value: float) -> float:
	value = clampf(value, 0.0, 1.0)
	return value * value * value * (value * (value * 6.0 - 15.0) + 10.0)

func _update_hanger_bars(index: int, attachment: Vector3, basket_position: Vector3) -> void:
	if index >= _left_hanger_bars.size() or index >= _right_hanger_bars.size():
		return

	var left_offset := Vector3.LEFT * hanger_half_width
	var right_offset := Vector3.RIGHT * hanger_half_width
	var basket_top_offset := Vector3.UP * 1.2
	_set_bar_between(_left_hanger_bars[index], attachment + left_offset, basket_position + basket_top_offset + left_offset)
	_set_bar_between(_right_hanger_bars[index], attachment + right_offset, basket_position + basket_top_offset + right_offset)

func _set_bar_between(bar: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	var midpoint := (start + end) * 0.5
	var direction := end - start
	var length := direction.length()
	if length <= 0.001:
		return

	var cylinder := bar.mesh as CylinderMesh
	cylinder.height = length
	bar.global_position = midpoint
	bar.global_basis = _basis_from_y_axis(direction.normalized())

func _basis_from_y_axis(y_axis: Vector3) -> Basis:
	var x_axis := Vector3.FORWARD.cross(y_axis)
	if x_axis.length_squared() < 0.001:
		x_axis = Vector3.RIGHT
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)

func _get_frame_center_x() -> float:
	var left_arm := _find_node3d("frame_arm_left")
	var right_arm := _find_node3d("frame_arm_right")
	if left_arm != null and right_arm != null:
		return (left_arm.global_position.x + right_arm.global_position.x) * 0.5

	return _wheel.global_position.x
