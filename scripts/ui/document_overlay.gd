class_name DocumentOverlay
extends CanvasLayer
# The in-game Operation Manual: a flippable bureaucratic document shown at the
# start of a shift (and re-openable from the pause menu). Pure Control UI — it
# builds once and auto-fits each page to a single sheet, so it's web/mobile
# cheap and never scrolls.
#
# Layout: one full A4-portrait sheet centred on screen, Back / Next arrows
# OUTSIDE the page (so text gets the whole sheet), page counter + the BEGIN
# SHIFT gate below.
#
# Two modes:
#   - shift start : no skipping; turn to the last page and sign to begin
#                   (confirm_label = "BEGIN SHIFT").
#   - review       : an X closes it from any page (allow_early_close = true).
# The caller owns the pause: stage_one pauses the tree before showing and
# unpauses on `closed`; the pause menu (already paused) just frees it.

signal closed

const DOC_PATH := "res://assets/ui/document.md"
const DEFAULT_PAGE_SFX := "res://assets/audio/ui/page_turn.ogg"  # drop a rustle here; auto-loaded

# TEMPORARY: until PmayerW delivers the real manual, show a two-page placeholder
# (cover + a fully redacted page) instead of parsing document.md. Flip this to
# false (or delete the placeholder branch) once the real content lands.
const USE_PLACEHOLDER := false  # real manual is live; placeholder kept for reference

const A4_RATIO := 0.707               # width / height of A4 portrait
const PAPER_HEIGHT_FRACTION := 0.92   # sheet height vs. viewport height
const PAPER_MAX_HEIGHT := 1000.0
const SIDE_GAP := 26.0                # gap between the sheet and the arrow buttons
const PAGE_MARGIN := 40               # inner paper margin
const BASE_BODY := 19                 # body font at scale 1.0
const MIN_FONT_SCALE := 0.55          # smallest auto-fit shrink before we give up

const PAPER_FILL := Color(0.90, 0.85, 0.73)      # aged manila
const PAPER_EDGE := Color(0.32, 0.26, 0.18)
const INK := Color(0.17, 0.15, 0.13)
const STAMP_RED := Color(0.54, 0.12, 0.07)
const PEN_BLUE := Color(0.20, 0.24, 0.46)        # previous operator's ballpoint

# The previous-operator's handwritten margin scribbles are authored as
# "(Liner Note: ...)" markers inside document.md and pulled per-page by
# DocMarkdown into each page's "note" field — see _update_note().

@export var confirm_label := "BEGIN SHIFT"
@export var allow_early_close := false
@export var page_turn_sfx: AudioStream

var _pages: Array = []
var _index := 0
var _paper_size := Vector2(700.0, 990.0)
var _holder: Control
var _body: RichTextLabel
var _counter: Label
var _back_btn: Button
var _next_btn: Button
var _confirm_btn: Button
var _note: Label
var _sfx: AudioStreamPlayer


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS  # works while the tree is paused
	if USE_PLACEHOLDER:
		_pages = _placeholder_pages()
	else:
		_pages = DocMarkdown.load_pages(DOC_PATH)
	if _pages.is_empty():
		_pages = [{
			"title": "Operation Manual",
			"bbcode": "[center][i]Manual unavailable.[/i][/center]",
			"raw": "",
		}]
	_setup_sfx()
	_build()
	_show_page(0)
	_fade_in()
	_request_pause_music()


# --- TEMPORARY placeholder content (remove once the real manual lands) --------

func _placeholder_pages() -> Array:
	# Sentinel "raw" values so the margin-note matcher never fires on these.
	return [
		{"title": "Operation Manual", "bbcode": _cover_bbcode(), "raw": "__cover__"},
		{"title": "Classified", "bbcode": _redacted_bbcode(), "raw": "__redacted__"},
	]


func _cover_bbcode() -> String:
	return "\n".join([
		"[center]",
		"\n\n",
		"[font_size=20]PROPERTY OF THE PARK AUTHORITY[/font_size]",
		"\n",
		"[font_size=54][b][color=#1c1714]OPERATION[/color][/b][/font_size]",
		"[font_size=54][b][color=#1c1714]MANUAL[/color][/b][/font_size]",
		"\n",
		"[font_size=26]RIDE OPERATOR DIVISION[/font_size]",
		"\n\n\n",
		"[font_size=18]FORM 27-B  ·  ISSUE [color=#0d0d0d]████[/color][/font_size]",
		"\n",
		"[font_size=22][color=#8a1f12][b]CLASSIFIED[/b][/color][/font_size]",
		"\n\n",
		"[font_size=15]DO NOT REMOVE FROM THE OPERATING AREA[/font_size]",
		"[/center]",
	])


func _redacted_bbcode() -> String:
	var lines := [
		"[center][font_size=30][b][color=#8a1f12]CLASSIFIED — CONTENTS OMITTED[/color][/b][/font_size][/center]",
		"",
		"[font_size=16][i]The remainder of this manual has been redacted pending operator authorization.[/i][/font_size]",
		"",
		_bar(34),
		_bar(21) + "   " + _bar(8),
		_bar(40),
		"",
		"[color=#8a1f12][b]§ ████████████[/b][/color]",
		_bar(29) + "  " + _bar(12),
		_bar(38),
		_bar(17),
		"",
		"[color=#8a1f12][b]§ ███████[/b][/color]",
		_bar(40),
		_bar(25) + "   " + _bar(10),
		_bar(33),
		"",
		_bar(40),
		_bar(19),
	]
	return "\n".join(lines)


func _bar(count: int) -> String:
	return "[color=#0d0d0d]%s[/color]" % "█".repeat(count)


# ------------------------------------------------------------------------------


func _setup_sfx() -> void:
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = "SFX"
	if page_turn_sfx == null and ResourceLoader.exists(DEFAULT_PAGE_SFX):
		page_turn_sfx = load(DEFAULT_PAGE_SFX)
	_sfx.stream = page_turn_sfx
	add_child(_sfx)


func _fade_in() -> void:
	# Fade the whole document in for a touch of ceremony.
	for child in get_children():
		if child is Control:
			child.modulate.a = 0.0
			create_tween().tween_property(child, "modulate:a", 1.0, 0.35)
			return


func _build() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var height := minf(viewport.y * PAPER_HEIGHT_FRACTION, PAPER_MAX_HEIGHT)
	_paper_size = Vector2(height * A4_RATIO, height)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Dim backdrop that also swallows clicks to the frozen scene behind.
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	# Column: [ arrows | sheet | arrows ] row, then the footer (counter + gate).
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(SIDE_GAP))
	column.add_child(row)

	_back_btn = _arrow_button("<", _prev)
	row.add_child(_back_btn)

	_holder = Control.new()
	_holder.custom_minimum_size = _paper_size
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_holder)

	_next_btn = _arrow_button(">", _next)
	row.add_child(_next_btn)

	_build_sheet()
	_build_footer(column)

	# Tilted handwritten margin note, overlaid bottom-right of the paper.
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_note.add_theme_color_override("font_color", PEN_BLUE)
	_note.add_theme_font_size_override("font_size", 20)
	_note.modulate = Color(1, 1, 1, 0.92)
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.rotation_degrees = -4.0
	_note.custom_minimum_size = Vector2(_paper_size.x - 120.0, 0.0)
	_note.size = Vector2(_paper_size.x - 120.0, 120.0)
	_note.position = Vector2(70.0, _paper_size.y - 150.0)
	_holder.add_child(_note)

	if allow_early_close:
		var x := Button.new()
		x.text = "X"
		x.flat = true
		x.focus_mode = Control.FOCUS_NONE
		x.add_theme_font_size_override("font_size", 26)
		x.add_theme_color_override("font_color", PAPER_EDGE)
		x.position = Vector2(_paper_size.x - 44.0, 8.0)
		x.pressed.connect(_dismiss)
		_holder.add_child(x)


func _build_sheet() -> void:
	var paper := PanelContainer.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.add_theme_stylebox_override("panel", _paper_style())
	_holder.add_child(paper)

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, PAGE_MARGIN)
	paper.add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	pad.add_child(vbox)

	vbox.add_child(_build_letterhead())
	vbox.add_child(HSeparator.new())

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = false
	_body.scroll_active = false          # the whole page shows at once
	_body.clip_contents = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_color_override("default_color", INK)
	_body.add_theme_font_size_override("normal_font_size", BASE_BODY)
	vbox.add_child(_body)


func _build_footer(column: VBoxContainer) -> void:
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 24)
	column.add_child(footer)

	_counter = Label.new()
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.custom_minimum_size = Vector2(150.0, 0.0)
	_counter.add_theme_color_override("font_color", Color(0.85, 0.82, 0.74))
	_counter.add_theme_font_size_override("font_size", 18)
	footer.add_child(_counter)

	_confirm_btn = MenuStyle.button(confirm_label, _dismiss)
	footer.add_child(_confirm_btn)


func _arrow_button(label: String, callback: Callable) -> Button:
	var btn := MenuStyle.button(label, callback)
	btn.custom_minimum_size = Vector2(72.0, 96.0)
	btn.add_theme_font_size_override("font_size", 34)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return btn


func _build_letterhead() -> HBoxContainer:
	var row := HBoxContainer.new()

	var left := Label.new()
	left.text = "FORM 27-B  ·  RIDE OPERATOR DIVISION"
	left.add_theme_color_override("font_color", PAPER_EDGE)
	left.add_theme_font_size_override("font_size", 16)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)

	var stamp := Label.new()
	stamp.text = "  CLASSIFIED  "
	stamp.add_theme_color_override("font_color", STAMP_RED)
	stamp.add_theme_font_size_override("font_size", 18)
	stamp.add_theme_stylebox_override("normal", DocumentOverlay._stamp_style())
	stamp.rotation_degrees = 4.0
	row.add_child(stamp)
	return row


func _paper_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER_FILL
	sb.border_color = PAPER_EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	sb.shadow_size = 14
	sb.set_content_margin_all(0)
	return sb


static func _stamp_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(0.54, 0.12, 0.07)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(4)
	return sb


func _show_page(index: int) -> void:
	_index = clampi(index, 0, _pages.size() - 1)
	var page: Dictionary = _pages[_index]
	_update_note(page)
	_update_footer()
	_render_fit(page)


# Render the page at full size, then shrink the font just enough that the whole
# sheet fits with no scrolling. One measure + at most one re-render.
func _render_fit(page: Dictionary) -> void:
	var raw := String(page.get("raw", ""))
	_body.add_theme_font_size_override("normal_font_size", BASE_BODY)
	# Pages carry their markdown in "raw"; the synthetic fallback page has none,
	# so fall back to its prebuilt bbcode instead of rendering an empty sheet.
	if raw.is_empty():
		_body.text = String(page.get("bbcode", ""))
		return
	_body.text = DocMarkdown.to_bbcode(raw, 1.0)
	await get_tree().process_frame

	var available := _body.size.y
	var content := _body.get_content_height()
	if available <= 0.0 or content <= available:
		return

	var scale := clampf((available / content) * 0.97, MIN_FONT_SCALE, 1.0)
	_body.add_theme_font_size_override("normal_font_size", int(round(BASE_BODY * scale)))
	_body.text = DocMarkdown.to_bbcode(raw, scale)


func _update_note(page: Dictionary) -> void:
	_note.text = String(page.get("note", ""))
	_note.visible = not _note.text.is_empty()


func _update_footer() -> void:
	_counter.text = "PAGE %d / %d" % [_index + 1, _pages.size()]
	_back_btn.disabled = _index == 0
	var on_last := _index >= _pages.size() - 1
	_next_btn.disabled = on_last
	_confirm_btn.visible = on_last


func _next() -> void:
	if _index < _pages.size() - 1:
		_turn_page(_index + 1)


func _prev() -> void:
	if _index > 0:
		_turn_page(_index - 1)


func _turn_page(index: int) -> void:
	if _sfx.stream != null:
		_sfx.play()
	var music := _pause_music()
	if music != null:
		music.page_turn_duck()  # subtle volume dip under the page rustle
	_show_page(index)


func _dismiss() -> void:
	var music := _pause_music()
	if music != null:
		music.release(self)
	closed.emit()
	queue_free()


# --- Shared downtime music (the PauseMusic node in stage_one.tscn) -------------

func _pause_music() -> PauseMusicPlayer:
	return get_tree().get_first_node_in_group("pause_music") as PauseMusicPlayer


func _request_pause_music() -> void:
	var music := _pause_music()
	if music != null:
		music.request(self)


func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action("ui_right") or (event is InputEventKey and event.keycode == KEY_RIGHT):
		_next()
		get_viewport().set_input_as_handled()
	elif event.is_action("ui_left") or (event is InputEventKey and event.keycode == KEY_LEFT):
		_prev()
		get_viewport().set_input_as_handled()
	elif allow_early_close and event is InputEventKey and event.keycode == KEY_ESCAPE:
		_dismiss()
		get_viewport().set_input_as_handled()
