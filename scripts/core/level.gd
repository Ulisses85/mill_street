@tool
class_name Level
extends Node2D
## Root of a level scene. Holds the walkable floor area and the foreground parallax.
##
## Expected children: Background (Sprite2D), World (y-sorted Node2D with Player and WaveManager),
## Foreground (Node2D, parallax), BeatCamera, HUD.

static var current: Level = null

## Where units may stand: x = street length, y = floor depth band.
@export var walk_area := Rect2(0, 164, 2600, 82):
	set(v):
		walk_area = v
		queue_redraw()
## Foreground moves faster than the street for depth (1.25 = 25% faster).
@export var foreground_parallax := 1.25
## Optional: places Foreground signposts from the art pipeline's layout.json.
@export_file("*.json") var layout_json := ""
@export var signpost_texture: Texture2D
@export var show_walk_area_in_editor := true

@onready var foreground: Node2D = get_node_or_null("Foreground")
@onready var camera: Camera2D = get_node_or_null("BeatCamera")


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_place_signposts()


func _place_signposts() -> void:
	if not foreground or layout_json == "" or not signpost_texture or not FileAccess.file_exists(layout_json):
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(layout_json))
	for fx in data.get("signposts", []):
		var s := Sprite2D.new()
		s.texture = signpost_texture
		s.centered = false
		s.position = Vector2(float(fx) - 40.0, 214)
		foreground.add_child(s)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not foreground or not camera:
		return
	foreground.position.x = -camera.position.x * (foreground_parallax - 1.0)


func _draw() -> void:
	if Engine.is_editor_hint() and show_walk_area_in_editor:
		draw_rect(walk_area, Color(0.3, 0.9, 0.5, 0.15))
		draw_rect(walk_area, Color(0.3, 0.9, 0.5, 0.8), false, 1.0)
