class_name UITheme
extends RefCounted
## Pixel UI theme shared by all menus.

const INK := Color("#1e1c28")
const PAPER := Color("#ecebf3")
const ACCENT := Color("#ff3a2a")

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = preload("res://assets/fonts/Silkscreen-Bold.ttf")
	t.default_font_size = 8
	var normal := _box(PAPER, INK)
	var focus := _box(ACCENT, INK)
	var disabled := _box(Color("#b2b1c2"), Color("#6c6b7c"))
	for state in ["normal", "pressed"]:
		t.set_stylebox(state, "Button", normal)
	t.set_stylebox("hover", "Button", focus)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("hover_pressed", "Button", focus)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("#6c6b7c"))
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_color("font_outline_color", "Label", INK)
	t.set_constant("outline_size", "Label", 3)
	_theme = t
	return t


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(2)
	b.content_margin_left = 10
	b.content_margin_right = 10
	b.content_margin_top = 5
	b.content_margin_bottom = 5
	b.anti_aliasing = false
	return b


static func label(text: String, size := 8, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if size >= 16:
		l.add_theme_constant_override("outline_size", 4)
	return l
