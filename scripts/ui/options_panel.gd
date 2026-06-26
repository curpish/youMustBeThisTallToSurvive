class_name OptionsPanel
extends Control
# Reusable options overlay: Master / Music / SFX sliders + a fullscreen toggle.
# A pure view of the Settings autoload. Used on the title menu and inside the
# in-game pause overlay. Emits `closed` when the player backs out.

signal closed

const PANEL_WIDTH := 460.0
const FULLSCREEN_OFF_COLOR := Color(0.92, 0.91, 0.85)  # off-white when disabled


func _ready() -> void:
	# top_level makes our anchors resolve against the viewport instead of the
	# parent, so the panel centers on the actual screen no matter where this is
	# parented (title UI tree vs. pause overlay).
	top_level = true
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	process_mode = PROCESS_MODE_ALWAYS  # usable while the game is paused
	_build()


func _build() -> void:
	# Full-screen black backdrop at 80% opacity that also swallows clicks meant
	# for whatever is behind.
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.8)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# CenterContainer over the full rect keeps the panel centered at any
	# resolution / window size.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuStyle.style(
		Color(0.05, 0.05, 0.06, 0.96), Color(0.95, 0.75, 0.28)
	))
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	panel.add_child(box)

	var header := Label.new()
	header.text = "OPTIONS"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 36)
	header.add_theme_color_override("font_color", Color(1.0, 0.9, 0.54))
	box.add_child(header)

	_add_slider(box, "Master", Settings.master_linear, Settings.set_master)
	_add_slider(box, "Music", Settings.music_linear, Settings.set_music)
	_add_slider(box, "SFX", Settings.sfx_linear, Settings.set_sfx)

	# Set the fullscreen option apart from the audio sliders: a separator, then a
	# centered "Fullscreen" label with a checkbox to its right. Off-white + empty
	# box when disabled; normal gold + checked when enabled.
	box.add_child(HSeparator.new())

	var fullscreen_row := HBoxContainer.new()
	fullscreen_row.alignment = BoxContainer.ALIGNMENT_CENTER
	fullscreen_row.add_theme_constant_override("separation", 16)
	fullscreen_row.custom_minimum_size = Vector2(0.0, 56.0)
	box.add_child(fullscreen_row)

	var fullscreen_label := Label.new()
	fullscreen_label.text = "Fullscreen"
	fullscreen_label.add_theme_font_size_override("font_size", 30)
	fullscreen_label.mouse_filter = Control.MOUSE_FILTER_STOP
	fullscreen_row.add_child(fullscreen_label)

	var fullscreen_check := CheckBox.new()
	fullscreen_check.focus_mode = Control.FOCUS_NONE
	fullscreen_check.custom_minimum_size = Vector2(48.0, 48.0)
	fullscreen_check.button_pressed = Settings.is_fullscreen()
	fullscreen_row.add_child(fullscreen_check)

	var paint := func(on: bool) -> void:
		fullscreen_label.add_theme_color_override(
			"font_color", MenuStyle.FONT_GOLD if on else FULLSCREEN_OFF_COLOR
		)
	paint.call(fullscreen_check.button_pressed)
	fullscreen_check.toggled.connect(func(on: bool) -> void:
		Settings.set_fullscreen(on)
		paint.call(on)
	)
	# Clicking the label toggles the box too, so the whole option is a target.
	fullscreen_label.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			fullscreen_check.button_pressed = not fullscreen_check.button_pressed
	)

	box.add_child(MenuStyle.button("Back", _on_back))


# One row: caption on the left, slider, live percentage on the right.
func _add_slider(parent: VBoxContainer, label: String, value: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.custom_minimum_size = Vector2(0.0, 48.0)
	parent.add_child(row)

	var caption := Label.new()
	caption.text = label
	caption.custom_minimum_size = Vector2(90.0, 0.0)
	caption.add_theme_font_size_override("font_size", 24)
	caption.add_theme_color_override("font_color", MenuStyle.FONT_GOLD)
	row.add_child(caption)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size = Vector2(220.0, 40.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var readout := Label.new()
	readout.text = "%d%%" % roundi(value * 100.0)
	readout.custom_minimum_size = Vector2(56.0, 0.0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.add_theme_font_size_override("font_size", 24)
	readout.add_theme_color_override("font_color", MenuStyle.FONT_GOLD)
	row.add_child(readout)

	slider.value_changed.connect(func(v: float) -> void:
		readout.text = "%d%%" % roundi(v * 100.0)
		on_change.call(v)
	)


func _on_back() -> void:
	closed.emit()
	queue_free()
