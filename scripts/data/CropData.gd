extends Resource
class_name CropData

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var seed_item: ItemData
@export var harvest_item: ItemData
@export var growth_texture: Texture2D
@export var growth_frame_size: Vector2i = Vector2i(32, 32)
@export_range(1, 64, 1) var growth_frame_count: int = 1
@export var stage_frame_counts: PackedInt32Array = PackedInt32Array([1])
@export var days_per_stage: PackedInt32Array = PackedInt32Array([1])
@export var regrowable: bool = false
@export_range(0, 999, 1) var regrow_days: int = 0
@export_range(1, 999, 1) var harvest_yield_min: int = 1
@export_range(1, 999, 1) var harvest_yield_max: int = 1
@export var seasons: PackedStringArray = []
@export var metadata: Dictionary = {}


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if id == &"":
		return "Unnamed Crop"

	return String(id).replace("_", " ").capitalize()


func get_stage_count() -> int:
	return max(stage_frame_counts.size(), days_per_stage.size())


func is_harvest_yield_valid() -> bool:
	return harvest_yield_min > 0 and harvest_yield_max >= harvest_yield_min
