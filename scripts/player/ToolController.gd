extends Node
class_name ToolController

var player: PlayerController

func _ready() -> void:
	player = get_parent() as PlayerController

func use_current_tool() -> bool:
	return false
