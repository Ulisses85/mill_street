@tool
class_name ComboData
extends Resource
## An ordered list of attacks triggered by repeatedly pressing the same button.

## A press within this time after the previous attack ends counts as part of the combo.
@export_range(0.0, 2.0, 0.01, "suffix:s") var combo_reset_time := 0.37
## If on, the combo only advances when the previous attack connected; a miss restarts it.
@export var continue_combo_on_hit := true
@export var attacks: Array[AttackData] = []
