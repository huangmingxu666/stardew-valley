extends Node
class_name Inventory

signal inventory_changed
signal hotbar_changed
signal backpack_changed
signal slot_changed(section: StringName, index: int, stack: ItemStack)
signal selected_hotbar_index_changed(index: int)

const SECTION_HOTBAR: StringName = &"hotbar"
const SECTION_BACKPACK: StringName = &"backpack"

@export_range(1, 16, 1) var hotbar_size: int = 10
@export_range(1, 64, 1) var backpack_size: int = 40
@export var selected_hotbar_index: int = 0

var hotbar_slots: Array[ItemStack] = []
var backpack_slots: Array[ItemStack] = []


func _ready() -> void:
	_resize_slots()
	selected_hotbar_index = clampi(selected_hotbar_index, 0, hotbar_size - 1)


func get_hotbar_stacks() -> Array[ItemStack]:
	return hotbar_slots


func get_backpack_stacks() -> Array[ItemStack]:
	return backpack_slots


func get_slot_stack(section: StringName, index: int) -> ItemStack:
	var slots: Array[ItemStack] = _get_section_slots(section)
	if index < 0 or index >= slots.size():
		return null
	return slots[index]


func set_stack(section: StringName, index: int, stack: ItemStack) -> void:
	if not _set_stack_internal(section, index, stack):
		return
	_emit_section_change(section)
	slot_changed.emit(section, index, get_slot_stack(section, index))
	inventory_changed.emit()


func clear_slot(section: StringName, index: int) -> void:
	set_stack(section, index, null)


func add_item_data(item_data: ItemData, amount: int = 1) -> Dictionary:
	var stack: ItemStack = ItemStack.from_item_data(item_data, amount)
	if stack == null:
		return {
			"success": false,
			"fully_added": false,
			"added_quantity": 0,
			"remaining_quantity": max(amount, 0),
		}

	return add_stack(stack)


func add_stack(stack: ItemStack, preferred_sections: Array[StringName] = []) -> Dictionary:
	if stack == null or stack.is_empty():
		return {
			"success": false,
			"fully_added": false,
			"added_quantity": 0,
			"remaining_quantity": 0,
		}

	var source_quantity: int = stack.quantity
	var remaining_quantity: int = source_quantity
	var changed_slots: Array[Dictionary] = []
	var section_order: Array[StringName] = _resolve_add_section_order(preferred_sections)

	for section: StringName in section_order:
		remaining_quantity = _merge_stack_into_section(section, stack, remaining_quantity, changed_slots)
		if remaining_quantity <= 0:
			break

	for section: StringName in section_order:
		remaining_quantity = _place_stack_into_empty_slots(section, stack, remaining_quantity, changed_slots)
		if remaining_quantity <= 0:
			break

	_emit_add_stack_changes(changed_slots)

	return {
		"success": remaining_quantity < source_quantity,
		"fully_added": remaining_quantity <= 0,
		"added_quantity": source_quantity - remaining_quantity,
		"remaining_quantity": remaining_quantity,
	}


func move_or_swap_stack(
	from_section: StringName,
	from_index: int,
	to_section: StringName,
	to_index: int
) -> bool:
	if from_section == to_section and from_index == to_index:
		return false

	var from_stack: ItemStack = get_slot_stack(from_section, from_index)
	if from_stack == null or from_stack.is_empty():
		return false

	var to_stack: ItemStack = get_slot_stack(to_section, to_index)
	if from_stack.can_merge_with(to_stack):
		var transfer_amount: int = mini(from_stack.quantity, to_stack.remaining_capacity())
		if transfer_amount <= 0:
			return false

		to_stack.quantity += transfer_amount
		from_stack.quantity -= transfer_amount
		if from_stack.quantity <= 0:
			_set_stack_internal(from_section, from_index, null)
	else:
		_set_stack_internal(from_section, from_index, to_stack)
		_set_stack_internal(to_section, to_index, from_stack)

	_emit_move_change(from_section, from_index, to_section, to_index)
	return true


func set_selected_hotbar_index(index: int) -> void:
	if hotbar_size <= 0:
		return

	var clamped_index: int = clampi(index, 0, hotbar_size - 1)
	if clamped_index == selected_hotbar_index:
		return

	selected_hotbar_index = clamped_index
	selected_hotbar_index_changed.emit(selected_hotbar_index)
	hotbar_changed.emit()
	inventory_changed.emit()


func get_selected_hotbar_stack() -> ItemStack:
	return get_slot_stack(SECTION_HOTBAR, selected_hotbar_index)


func ensure_default_tool_loadout(tool_definitions: Array[ToolData]) -> void:
	var did_change: bool = false
	for tool_data: ToolData in tool_definitions:
		if tool_data == null:
			continue

		var target_index: int = tool_data.slot_index
		if target_index < 0 or target_index >= hotbar_slots.size():
			target_index = _find_first_empty_index(hotbar_slots)

		if target_index < 0:
			break
		if hotbar_slots[target_index] != null and not hotbar_slots[target_index].is_empty():
			continue

		hotbar_slots[target_index] = ItemStack.from_tool_data(tool_data)
		did_change = true

	if not did_change:
		return

	hotbar_changed.emit()
	inventory_changed.emit()
	for index: int in range(hotbar_slots.size()):
		slot_changed.emit(SECTION_HOTBAR, index, hotbar_slots[index])


func find_hotbar_index_by_item_id(item_id: StringName) -> int:
	for index: int in range(hotbar_slots.size()):
		var stack: ItemStack = hotbar_slots[index]
		if stack != null and stack.item_id == item_id:
			return index
	return -1


func _resize_slots() -> void:
	hotbar_slots.resize(hotbar_size)
	backpack_slots.resize(backpack_size)


func _get_section_slots(section: StringName) -> Array[ItemStack]:
	match section:
		SECTION_HOTBAR:
			return hotbar_slots
		SECTION_BACKPACK:
			return backpack_slots
		_:
			return []


func _set_stack_internal(section: StringName, index: int, stack: ItemStack) -> bool:
	var slots: Array[ItemStack] = _get_section_slots(section)
	if index < 0 or index >= slots.size():
		return false

	slots[index] = stack
	return true


func _emit_move_change(
	from_section: StringName,
	from_index: int,
	to_section: StringName,
	to_index: int
) -> void:
	slot_changed.emit(from_section, from_index, get_slot_stack(from_section, from_index))
	slot_changed.emit(to_section, to_index, get_slot_stack(to_section, to_index))
	_emit_section_change(from_section)
	if to_section != from_section:
		_emit_section_change(to_section)
	inventory_changed.emit()


func _emit_section_change(section: StringName) -> void:
	match section:
		SECTION_HOTBAR:
			hotbar_changed.emit()
		SECTION_BACKPACK:
			backpack_changed.emit()


func _find_first_empty_index(slots: Array[ItemStack]) -> int:
	for index: int in range(slots.size()):
		var stack: ItemStack = slots[index]
		if stack == null or stack.is_empty():
			return index
	return -1


func _resolve_add_section_order(preferred_sections: Array[StringName]) -> Array[StringName]:
	if not preferred_sections.is_empty():
		return preferred_sections

	return [
		SECTION_BACKPACK,
		SECTION_HOTBAR,
	]


func _merge_stack_into_section(
	section: StringName,
	source_stack: ItemStack,
	remaining_quantity: int,
	changed_slots: Array[Dictionary]
) -> int:
	var slots: Array[ItemStack] = _get_section_slots(section)
	if slots.is_empty():
		return remaining_quantity

	for index: int in range(slots.size()):
		if remaining_quantity <= 0:
			break

		var target_stack: ItemStack = slots[index]
		if target_stack == null or not source_stack.can_merge_with(target_stack):
			continue

		var transfer_amount: int = mini(remaining_quantity, target_stack.remaining_capacity())
		if transfer_amount <= 0:
			continue

		target_stack.quantity += transfer_amount
		remaining_quantity -= transfer_amount
		_record_changed_slot(changed_slots, section, index)

	return remaining_quantity


func _place_stack_into_empty_slots(
	section: StringName,
	source_stack: ItemStack,
	remaining_quantity: int,
	changed_slots: Array[Dictionary]
) -> int:
	var slots: Array[ItemStack] = _get_section_slots(section)
	if slots.is_empty():
		return remaining_quantity

	for index: int in range(slots.size()):
		if remaining_quantity <= 0:
			break

		var target_stack: ItemStack = slots[index]
		if target_stack != null and not target_stack.is_empty():
			continue

		var placed_stack: ItemStack = source_stack.duplicate_stack()
		placed_stack.quantity = mini(remaining_quantity, placed_stack.max_stack)
		slots[index] = placed_stack
		remaining_quantity -= placed_stack.quantity
		_record_changed_slot(changed_slots, section, index)

	return remaining_quantity


func _record_changed_slot(changed_slots: Array[Dictionary], section: StringName, index: int) -> void:
	for changed_slot: Dictionary in changed_slots:
		if StringName(String(changed_slot.get("section", ""))) == section and int(changed_slot.get("index", -1)) == index:
			return

	changed_slots.append({
		"section": String(section),
		"index": index,
	})


func _emit_add_stack_changes(changed_slots: Array[Dictionary]) -> void:
	if changed_slots.is_empty():
		return

	var changed_sections: Dictionary = {}
	for changed_slot: Dictionary in changed_slots:
		var section: StringName = StringName(String(changed_slot.get("section", "")))
		var index: int = int(changed_slot.get("index", -1))
		if index < 0:
			continue

		slot_changed.emit(section, index, get_slot_stack(section, index))
		changed_sections[section] = true

	for section_key: Variant in changed_sections.keys():
		var section: StringName = StringName(String(section_key))
		_emit_section_change(section)

	inventory_changed.emit()
