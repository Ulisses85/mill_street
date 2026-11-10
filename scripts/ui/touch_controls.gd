extends CanvasLayer
## On-screen controls for phones and tablets: a virtual stick (left) and action buttons (right).
## They press the same input actions as the keyboard and gamepad, so gameplay code needs no changes.

## Show even without a touchscreen (handy for testing with the mouse).
@export var always_show := false
@export var stick_radius := 30.0
@export var dead_zone := 0.3
@export var button_radius := 17.0
@export var opacity := 0.75

const INK := Color("#1e1c28")
const BUTTONS := [
	# action, label, position from bottom-right, radius scale
	[&"punch", "A", Vector2(-34, -34), 1.25],      # Attack
	[&"kick", "S", Vector2(-80, -26), 1.0],        # Special (Kick in classic controls)
	[&"jump", "J", Vector2(-58, -70), 1.0],
	[&"defend", "D", Vector2(-108, -62), 0.85],
	[&"grab", "G", Vector2(-24, -84), 0.85],
]

var root: Control
var stick_touch := -1
var stick_center := Vector2.ZERO
var stick_vec := Vector2.ZERO
var button_touch := {}  # touch index -> action


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_PAUSABLE
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.draw.connect(_draw_controls)
	add_child(root)
	visible = always_show or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _size() -> Vector2:
	return root.get_viewport_rect().size


func _stick_home() -> Vector2:
	return Vector2(52, _size().y - 52)


func _button_pos(spec: Array) -> Vector2:
	return _size() + spec[2]


func _input(event: InputEvent) -> void:
	# appear on the first touch, hide again when a keyboard or gamepad is used
	if event is InputEventScreenTouch and not visible:
		visible = true
	elif not always_show and visible and (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
		visible = false
	if not visible:
		return
	if event is InputEventScreenTouch:
		var pos: Vector2 = root.get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed:
			if pos.x < _size().x * 0.45 and stick_touch == -1:
				stick_touch = event.index
				stick_center = pos if pos.distance_to(_stick_home()) > stick_radius * 2.0 else _stick_home()
				_update_stick(pos)
			else:
				for spec in BUTTONS:
					if pos.distance_to(_button_pos(spec)) < button_radius * spec[3] + 6.0:
						button_touch[event.index] = spec[0]
						Input.action_press(spec[0])
						break
		else:
			if event.index == stick_touch:
				stick_touch = -1
				_update_stick(stick_center)
			elif button_touch.has(event.index):
				Input.action_release(button_touch[event.index])
				button_touch.erase(event.index)
		root.queue_redraw()
	elif event is InputEventScreenDrag and event.index == stick_touch:
		_update_stick(root.get_global_transform_with_canvas().affine_inverse() * event.position)
		root.queue_redraw()


func _update_stick(pos: Vector2) -> void:
	var v := (pos - stick_center) / stick_radius
	if v.length() > 1.0:
		v = v.normalized()
	stick_vec = v
	_axis(&"move_left", &"move_right", v.x)
	_axis(&"move_up", &"move_down", v.y)


func _axis(neg: StringName, pos: StringName, value: float) -> void:
	if value < -dead_zone:
		Input.action_press(neg, -value)
		Input.action_release(pos)
	elif value > dead_zone:
		Input.action_press(pos, value)
		Input.action_release(neg)
	else:
		Input.action_release(neg)
		Input.action_release(pos)


func _draw_controls() -> void:
	var c := stick_center if stick_touch != -1 else _stick_home()
	var a := opacity
	root.draw_circle(c, stick_radius + 2, Color(INK, 0.5 * a))
	root.draw_circle(c, stick_radius, Color(0.93, 0.92, 0.95, 0.35 * a))
	root.draw_circle(c + stick_vec * stick_radius, 13, Color(INK, a))
	root.draw_circle(c + stick_vec * stick_radius, 11, Color(0.93, 0.92, 0.95, a))
	var f: Font = preload("res://assets/fonts/Silkscreen-Bold.ttf")
	for spec in BUTTONS:
		var p := _button_pos(spec)
		var r: float = button_radius * spec[3]
		var down: bool = spec[0] in button_touch.values()
		root.draw_circle(p, r + 2, Color(INK, a))
		root.draw_circle(p, r, Color("#ff3a2a", a) if down else Color(0.93, 0.92, 0.95, 0.8 * a))
		var w := f.get_string_size(spec[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		root.draw_string(f, p + Vector2(-w / 2, 3), spec[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE if down else INK)
