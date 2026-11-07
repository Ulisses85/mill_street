@tool
class_name LevelInfo
extends Resource
## One entry in the level select.

@export var level_name := "MILL STREET"
@export_file("*.tscn") var scene := ""
@export var boss_name := ""
## Colours for the level-select card (darkest to lightest).
@export var palette: PackedColorArray = PackedColorArray()
