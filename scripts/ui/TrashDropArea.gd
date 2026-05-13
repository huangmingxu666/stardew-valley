extends Control
class_name TrashDropArea

signal stack_trashed(section: StringName, index: int)

const DRAG_SECTION_KEY: StringName = &"from_section"
const DRAG_INDEX_KEY: StringName = &"from_index"

var inventory: Inventory


func configure(target_inventory: Inventory) -> void:
	inventory = target_inventory
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_CAN_DROP


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if inventory == null:
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	return data.has(DRAG_SECTION_KEY) and data.has(DRAG_INDEX_KEY)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if inventory == null or typeof(data) != TYPE_DICTIONARY:
		return

	var from_section_variant: Variant = data.get(DRAG_SECTION_KEY, &"")
	var from_index_variant: Variant = data.get(DRAG_INDEX_KEY, -1)
	var from_section: StringName = StringName(String(from_section_variant))
	var from_index: int = int(from_index_variant)
	inventory.clear_slot(from_section, from_index)
	stack_trashed.emit(from_section, from_index)
