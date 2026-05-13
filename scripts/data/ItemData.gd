extends Resource
class_name ItemData

enum ItemKind {
	GENERIC,
	SEED,
	CROP,
	TOOL,
	MATERIAL,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon_texture: Texture2D
@export var stackable: bool = true
@export_range(1, 999, 1) var max_stack: int = 99
@export var item_kind: ItemKind = ItemKind.GENERIC
@export_range(0, 99999, 1) var sell_price: int = 0
@export var metadata: Dictionary = {}


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if id == &"":
		return "Unnamed Item"

	return String(id).replace("_", " ").capitalize()
