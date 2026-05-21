extends Resource
class_name FarmTileState

const SURFACE_GRASS: StringName = &"grass"
const SURFACE_SOIL: StringName = &"soil"
const SURFACE_WATER: StringName = &"water"

const STAGE_NONE: int = -1

@export var cell: Vector2i = Vector2i.ZERO
@export var surface_type: StringName = SURFACE_GRASS
@export var tillable: bool = false
@export var tilled: bool = false
@export var watered: bool = false
@export var blocked: bool = false
@export var crop_id: StringName = &""
@export var crop_stage: int = STAGE_NONE
@export var crop_max_stage: int = STAGE_NONE


func can_till() -> bool:
	return tillable and not blocked and not tilled and not has_crop()


func can_water() -> bool:
	return tilled and not blocked


func can_plant() -> bool:
	return tilled and not blocked and not has_crop()


func can_harvest() -> bool:
	return tilled and not blocked and has_crop() and is_crop_mature()


func can_destroy_crop() -> bool:
	return has_crop()


func has_crop() -> bool:
	return crop_id != &""


func is_crop_mature() -> bool:
	if crop_max_stage <= STAGE_NONE:
		return false
	return crop_stage >= crop_max_stage


func set_crop(next_crop_id: StringName, next_crop_stage: int = 0, next_max_stage: int = STAGE_NONE) -> void:
	crop_id = next_crop_id
	crop_stage = next_crop_stage
	crop_max_stage = next_max_stage


func clear_crop() -> void:
	crop_id = &""
	crop_stage = STAGE_NONE
	crop_max_stage = STAGE_NONE


func reset_for_new_day() -> void:
	watered = false


func reset_ground_state() -> void:
	tilled = false
	watered = false
	clear_crop()


func duplicate_state() -> FarmTileState:
	var copy: FarmTileState = FarmTileState.new()
	copy.cell = cell
	copy.surface_type = surface_type
	copy.tillable = tillable
	copy.tilled = tilled
	copy.watered = watered
	copy.blocked = blocked
	copy.crop_id = crop_id
	copy.crop_stage = crop_stage
	copy.crop_max_stage = crop_max_stage
	return copy


func to_dictionary() -> Dictionary:
	return {
		"cell_x": cell.x,
		"cell_y": cell.y,
		"surface_type": String(surface_type),
		"tillable": tillable,
		"tilled": tilled,
		"watered": watered,
		"blocked": blocked,
		"crop_id": String(crop_id),
		"crop_stage": crop_stage,
		"crop_max_stage": crop_max_stage,
	}


static func from_dictionary(data: Dictionary) -> FarmTileState:
	var state: FarmTileState = FarmTileState.new()
	state.cell = Vector2i(
		int(data.get("cell_x", 0)),
		int(data.get("cell_y", 0))
	)
	state.surface_type = StringName(String(data.get("surface_type", String(SURFACE_GRASS))))
	state.tillable = bool(data.get("tillable", false))
	state.tilled = bool(data.get("tilled", false))
	state.watered = bool(data.get("watered", false))
	state.blocked = bool(data.get("blocked", false))
	state.crop_id = StringName(String(data.get("crop_id", "")))
	state.crop_stage = int(data.get("crop_stage", STAGE_NONE))
	state.crop_max_stage = int(data.get("crop_max_stage", STAGE_NONE))
	return state
