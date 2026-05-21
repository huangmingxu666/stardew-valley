extends Resource
class_name CropData

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var seed_item: ItemData
@export var harvest_item: ItemData
@export var seed_texture: Texture2D
@export var seed_visual_offset: Vector2 = Vector2.ZERO
@export var growth_texture: Texture2D
@export var growth_frame_size: Vector2i = Vector2i(32, 32)
@export var growth_visual_offset: Vector2 = Vector2.ZERO
@export var water_hint_offset: Vector2 = Vector2(0, -10)
@export var harvest_hint_offset: Vector2 = Vector2(0, -12)
@export_range(1, 64, 1) var growth_frame_count: int = 1
@export var stage_frame_counts: PackedInt32Array = PackedInt32Array([1])
@export var days_per_stage: PackedInt32Array = PackedInt32Array([1])
@export_range(1, 30, 1) var days_per_frame: int = 1
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


func get_total_growth_days() -> int:
	return growth_frame_count * days_per_frame


func get_stage_for_frame(frame: int) -> int:
	if stage_frame_counts.is_empty():
		return 0

	var cumulative: int = 0
	for stage_idx: int in range(stage_frame_counts.size()):
		cumulative += stage_frame_counts[stage_idx]
		if frame < cumulative:
			return stage_idx

	return stage_frame_counts.size() - 1


func get_days_required_for_frame(target_frame: int) -> int:
	return (target_frame + 1) * days_per_frame


func is_frame_mature(frame: int) -> bool:
	return frame >= growth_frame_count - 1
