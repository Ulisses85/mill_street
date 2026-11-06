@tool
class_name LevelList
extends Resource
## Ordered list of levels. Levels unlock one by one as the previous one is completed.

@export var levels: Array[LevelInfo] = []
@export_file("*.tscn") var main_menu_scene := "res://scenes/ui/main_menu.tscn"
@export_file("*.tscn") var level_select_scene := "res://scenes/ui/level_select.tscn"
