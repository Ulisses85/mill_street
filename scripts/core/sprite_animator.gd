@tool
class_name SpriteAnimator
extends Sprite2D
## Plays animations from a sprite sheet described by a JSON file (written by tools/sprite_pipeline).
## Frames are chosen from the owner's state timer in ticks, so visuals stay in lock-step with gameplay.
##
## sheet.json format:
## { "cell": [w, h], "anchor": [x, y], "anims": { "idle": { "row": 0, "frames": 8, "ticks_per_frame": 7, "loop": true } } }

@export_file("*.json") var sheet_json := "":
	set(v):
		sheet_json = v
		_load()
@export var preview_animation := &"idle":
	set(v):
		preview_animation = v
		if Engine.is_editor_hint():
			show_frame(preview_animation, 0)

var anims := {}
var cell := Vector2i(128, 112)
var anchor := Vector2i(64, 100)


func _ready() -> void:
	_load()
	material = ShaderMaterial.new()
	material.shader = preload("res://scripts/core/flash.gdshader")


func _load() -> void:
	if sheet_json == "" or not FileAccess.file_exists(sheet_json):
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sheet_json))
	if data.is_empty():
		return
	cell = Vector2i(data["cell"][0], data["cell"][1])
	anchor = Vector2i(data["anchor"][0], data["anchor"][1])
	anims = data["anims"]
	var png := sheet_json.get_basename() + ".png"
	if ResourceLoader.exists(png):
		texture = load(png)
	centered = false
	region_enabled = true
	offset = -Vector2(anchor)
	show_frame(preview_animation, 0)


func has_animation(anim: StringName) -> bool:
	return anims.has(String(anim))


func frame_count(anim: StringName) -> int:
	return int(anims[String(anim)]["frames"]) if has_animation(anim) else 1


## Shows the frame of `anim` that matches `ticks` since the animation started.
func show_frame(anim: StringName, ticks: int) -> void:
	var key := String(anim)
	if not anims.has(key):
		return
	var a: Dictionary = anims[key]
	var n := int(a["frames"])
	@warning_ignore("integer_division")
	var f: int = ticks / maxi(1, int(a["ticks_per_frame"]))
	f = f % n if a.get("loop", false) else min(f, n - 1)
	region_rect = Rect2(f * cell.x, int(a["row"]) * cell.y, cell.x, cell.y)


func set_flash(on: bool) -> void:
	if material:
		(material as ShaderMaterial).set_shader_parameter("flash", 1.0 if on else 0.0)
