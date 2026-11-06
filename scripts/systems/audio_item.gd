@tool
class_name AudioItem
extends Resource
## One named sound. One clip from the list is picked at random each time it plays.

@export var item_name := &"hit"
@export var clips: Array[AudioStream] = []
@export_range(0.0, 1.0, 0.01) var volume := 0.5
## Random +/- amount added to the volume each play.
@export_range(0.0, 1.0, 0.01) var random_volume := 0.05
## Ignore calls that come sooner than this after the previous one.
@export_range(0.0, 1.0, 0.005, "suffix:s") var min_time_between_calls := 0.035
## Random +/- pitch change each play.
@export_range(0.0, 0.5, 0.01) var random_pitch := 0.07
@export var loop := false
