class_name MenuPanel
extends Control
## A centred menu: title, optional subtitle and a column of buttons. Works with keyboard,
## gamepad (ui_up / ui_down / ui_accept), mouse and touch. Runs while the game is paused.

var _box: VBoxContainer
var _dim: ColorRect


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UITheme.get_theme()
	_dim = ColorRect.new()
	_dim.color = Color(0.12, 0.11, 0.16, 0.72)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	center.add_child(_box)
	visible = false


## options: Array of [label: String, callback: Callable]
func open(title: String, subtitle: String, options: Array, title_color := Color.WHITE, dim := true, focus := 0) -> void:
	for c in _box.get_children():
		c.queue_free()
	_dim.visible = dim
	if title != "":
		_box.add_child(UITheme.label(title, 16, title_color))
	if subtitle != "":
		var s := UITheme.label(subtitle, 8, Color("#d2d1de"))
		_box.add_child(s)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	_box.add_child(spacer)
	var first: Button = null
	for o in options:
		var b := Button.new()
		b.text = o[0]
		b.custom_minimum_size = Vector2(150, 0)
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(func(): Sfx.play(&"swish"); (o[1] as Callable).call())
		b.focus_entered.connect(func(): Sfx.play(&"block", -14.0))
		var row := CenterContainer.new()
		row.add_child(b)
		_box.add_child(row)
		if first == null or options.find(o) == focus:
			first = b
	visible = true
	if first:
		first.call_deferred(&"grab_focus")


func close() -> void:
	visible = false
