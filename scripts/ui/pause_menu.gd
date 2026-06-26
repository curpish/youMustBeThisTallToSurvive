extends CanvasLayer
# In-game pause overlay. ESC (or the on-screen button, for touch) freezes the
# sim via get_tree().paused and draws a PAUSED menu on top of the live scene, so
# Resume continues the exact run. Restart re-runs the current difficulty. The
# shared OptionsPanel is opened from here. Reuses the title's button look.

const OptionsPanelScene := preload("res://scripts/ui/options_panel.gd")

var _menu_root: Control
var _buttons: VBoxContainer
var _pause_tab: Button
var _options: OptionsPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep working while the tree is paused
	layer = 50
	_build()
	_set_open(false)


func _build() -> void:
	# Small always-on tab so touch players (no Esc key) can open the menu.
	_pause_tab = MenuStyle.button("II", _toggle)
	_pause_tab.custom_minimum_size = Vector2(64.0, 48.0)
	_pause_tab.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_pause_tab.offset_left = 16.0
	_pause_tab.offset_top = -64.0
	_pause_tab.offset_right = 80.0
	_pause_tab.offset_bottom = -16.0
	add_child(_pause_tab)

	_menu_root = Control.new()
	_menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_menu_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_root.add_child(dim)

	# CenterContainer over the full rect centers the button column exactly,
	# instead of anchoring it at the center point and letting it grow off-center.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_root.add_child(center)

	_buttons = VBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 16)
	center.add_child(_buttons)

	var paused := Label.new()
	paused.text = "PAUSED"
	paused.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	paused.add_theme_font_size_override("font_size", 56)
	paused.add_theme_color_override("font_color", Color(1.0, 0.9, 0.54))
	paused.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.0))
	paused.add_theme_constant_override("outline_size", 8)
	_buttons.add_child(paused)

	_buttons.add_child(MenuStyle.button("Resume", _resume))
	_buttons.add_child(MenuStyle.button("Restart", _restart))
	_buttons.add_child(MenuStyle.button("Options", _open_options))
	_buttons.add_child(MenuStyle.button("Gameplay Feedback Survey", GameOrchestrator.open_feedback_survey))
	_buttons.add_child(MenuStyle.button("Quit To Menu", _quit_to_menu))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	_set_open(not _menu_root.visible)


func _set_open(open: bool) -> void:
	get_tree().paused = open
	_menu_root.visible = open
	_pause_tab.visible = not open
	if not open and _options != null:
		_options.queue_free()
		_options = null


func _resume() -> void:
	_set_open(false)


func _restart() -> void:
	get_tree().paused = false
	GameOrchestrator.restart()


func _quit_to_menu() -> void:
	get_tree().paused = false
	GameOrchestrator.return_to_title()


func _open_options() -> void:
	_buttons.visible = false
	_options = OptionsPanelScene.new()
	_options.closed.connect(_on_options_closed)
	_menu_root.add_child(_options)


func _on_options_closed() -> void:
	_options = null
	_buttons.visible = true
