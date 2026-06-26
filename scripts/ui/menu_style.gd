class_name MenuStyle
extends RefCounted
# Shared menu look, extracted from title_scene so the title, pause overlay and
# options panel all match. Pure factory helpers — no state.

const FONT_GOLD := Color(1.0, 0.92, 0.7)
const FONT_HOVER := Color(0.72, 0.95, 1.0)


static func button(label: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(300.0, 58.0)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_stylebox_override("normal", style(Color(0.06, 0.05, 0.04, 0.78), Color(0.95, 0.75, 0.28)))
	btn.add_theme_stylebox_override("hover", style(Color(0.08, 0.16, 0.2, 0.9), Color(0.25, 0.72, 1.0)))
	btn.add_theme_stylebox_override("pressed", style(Color(0.02, 0.08, 0.1, 0.95), Color(0.25, 0.72, 1.0)))
	btn.add_theme_color_override("font_color", FONT_GOLD)
	btn.add_theme_color_override("font_hover_color", FONT_HOVER)
	if callback.is_valid():
		btn.pressed.connect(callback)
	return btn


static func style(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb
