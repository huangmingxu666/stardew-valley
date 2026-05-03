extends Resource
class_name ToolData

enum ToolKind {
	GENERIC,
	AXE,
	SHOVEL,
	WATERING_CAN,
	FISHING_ROD,
}

enum ToolAction {
	NONE,
	CHOP,
	TILL_SOIL,
	WATER_SOIL,
	FISH,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var tool_kind: ToolKind = ToolKind.GENERIC
@export var primary_action: ToolAction = ToolAction.NONE
@export_range(-1, 15, 1) var slot_index: int = -1
@export var icon_texture: Texture2D
@export var use_texture: Texture2D
@export var visual_data: ToolVisualData
@export_range(0.0, 256.0, 1.0) var interaction_distance: float = 32.0
@export var targets_tiles: bool = true
@export var can_affect_blocked_tiles: bool = false
@export var metadata: Dictionary = {}


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if id == &"":
		return "Unnamed Tool"

	return String(id).replace("_", " ").capitalize()


func has_slot() -> bool:
	return slot_index >= 0
