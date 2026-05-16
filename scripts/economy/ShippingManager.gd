extends Node

signal pending_sales_changed

const SECTION_PENDING: StringName = &"pending"
const DEFAULT_PENDING_SLOT_COUNT: int = 30

@export_range(1, 64, 1) var pending_slot_count: int = DEFAULT_PENDING_SLOT_COUNT

var pending_slots: Array[ItemStack] = []


func _ready() -> void:
	pending_slots.resize(pending_slot_count)


func get_pending_stack(index: int) -> ItemStack:
	if index < 0 or index >= pending_slots.size():
		return null
	return pending_slots[index]


func get_pending_stacks() -> Array[ItemStack]:
	return pending_slots


func get_pending_total_value() -> int:
	var total_value: int = 0
	for stack: ItemStack in pending_slots:
		total_value += _get_stack_sell_value(stack)
	return total_value


func can_queue_from_inventory(
	inventory: Inventory,
	section: StringName,
	index: int,
	target_index: int = -1
) -> bool:
	if inventory == null:
		return false

	var source_stack: ItemStack = inventory.get_slot_stack(section, index)
	if not _is_sellable_stack(source_stack):
		return false

	if target_index >= 0:
		return _can_place_stack_in_pending_slot(source_stack, target_index)
	return _find_pending_target_for_stack(source_stack) >= 0


func queue_from_inventory(
	inventory: Inventory,
	section: StringName,
	index: int,
	target_index: int = -1
) -> bool:
	if not can_queue_from_inventory(inventory, section, index, target_index):
		return false

	var source_stack: ItemStack = inventory.get_slot_stack(section, index)
	var resolved_target_index: int = target_index
	if resolved_target_index < 0:
		resolved_target_index = _find_pending_target_for_stack(source_stack)

	var target_stack: ItemStack = get_pending_stack(resolved_target_index)
	if target_stack == null:
		pending_slots[resolved_target_index] = source_stack
	else:
		target_stack.quantity += source_stack.quantity

	inventory.clear_slot(section, index)
	pending_sales_changed.emit()
	return true


func can_withdraw_to_inventory(
	inventory: Inventory,
	pending_index: int,
	target_section: StringName = Inventory.SECTION_BACKPACK,
	target_index: int = -1
) -> bool:
	if inventory == null:
		return false

	var pending_stack: ItemStack = get_pending_stack(pending_index)
	if pending_stack == null or pending_stack.is_empty():
		return false

	if target_index >= 0:
		return _can_place_stack_in_inventory_slot(inventory, pending_stack, target_section, target_index)
	return _find_inventory_target_for_stack(inventory, pending_stack, target_section) >= 0


func withdraw_to_inventory(inventory: Inventory, pending_index: int) -> bool:
	return move_pending_to_inventory(inventory, pending_index, Inventory.SECTION_BACKPACK, -1)


func move_pending_to_inventory(
	inventory: Inventory,
	pending_index: int,
	target_section: StringName,
	target_index: int = -1
) -> bool:
	if not can_withdraw_to_inventory(inventory, pending_index, target_section, target_index):
		return false

	var pending_stack: ItemStack = get_pending_stack(pending_index)
	var resolved_target_index: int = target_index
	if resolved_target_index < 0:
		resolved_target_index = _find_inventory_target_for_stack(inventory, pending_stack, target_section)

	var target_stack: ItemStack = inventory.get_slot_stack(target_section, resolved_target_index)
	if target_stack == null:
		inventory.set_stack(target_section, resolved_target_index, pending_stack)
	else:
		target_stack.quantity += pending_stack.quantity
		inventory.set_stack(target_section, resolved_target_index, target_stack)

	pending_slots[pending_index] = null
	pending_sales_changed.emit()
	return true


func can_move_or_merge_pending(from_index: int, to_index: int) -> bool:
	if from_index == to_index:
		return false

	var from_stack: ItemStack = get_pending_stack(from_index)
	if from_stack == null or from_stack.is_empty():
		return false
	if not _is_pending_index_valid(to_index):
		return false

	var to_stack: ItemStack = get_pending_stack(to_index)
	if to_stack == null:
		return true
	if from_stack.can_merge_with(to_stack):
		return to_stack.remaining_capacity() >= from_stack.quantity
	return true


func move_or_merge_pending(from_index: int, to_index: int) -> bool:
	if not can_move_or_merge_pending(from_index, to_index):
		return false

	var from_stack: ItemStack = get_pending_stack(from_index)
	var to_stack: ItemStack = get_pending_stack(to_index)
	if to_stack == null:
		pending_slots[to_index] = from_stack
		pending_slots[from_index] = null
	elif from_stack.can_merge_with(to_stack):
		to_stack.quantity += from_stack.quantity
		pending_slots[from_index] = null
	else:
		pending_slots[from_index] = to_stack
		pending_slots[to_index] = from_stack

	pending_sales_changed.emit()
	return true


func commit_pending_sales() -> int:
	var total_value: int = get_pending_total_value()
	var had_pending_items: bool = false
	for index: int in range(pending_slots.size()):
		if pending_slots[index] != null:
			had_pending_items = true
		pending_slots[index] = null

	if had_pending_items:
		pending_sales_changed.emit()
	return total_value


func _is_sellable_stack(stack: ItemStack) -> bool:
	if stack == null or stack.is_empty():
		return false

	var item_data: ItemData = stack.source_data as ItemData
	return item_data != null and item_data.sell_price > 0


func _get_stack_sell_value(stack: ItemStack) -> int:
	if not _is_sellable_stack(stack):
		return 0

	var item_data: ItemData = stack.source_data as ItemData
	return item_data.sell_price * stack.quantity


func _find_pending_target_for_stack(stack: ItemStack) -> int:
	for index: int in range(pending_slots.size()):
		var pending_stack: ItemStack = pending_slots[index]
		if pending_stack != null and pending_stack.can_merge_with(stack) and pending_stack.remaining_capacity() >= stack.quantity:
			return index

	for index: int in range(pending_slots.size()):
		if pending_slots[index] == null:
			return index
	return -1


func _find_inventory_target_for_stack(
	inventory: Inventory,
	stack: ItemStack,
	target_section: StringName
) -> int:
	var slots: Array[ItemStack] = _get_inventory_slots(inventory, target_section)
	for index: int in range(slots.size()):
		var inventory_stack: ItemStack = slots[index]
		if inventory_stack != null and inventory_stack.can_merge_with(stack) and inventory_stack.remaining_capacity() >= stack.quantity:
			return index

	for index: int in range(slots.size()):
		if slots[index] == null:
			return index
	return -1


func _can_place_stack_in_pending_slot(stack: ItemStack, target_index: int) -> bool:
	if not _is_sellable_stack(stack):
		return false
	if not _is_pending_index_valid(target_index):
		return false

	var target_stack: ItemStack = get_pending_stack(target_index)
	if target_stack == null:
		return true
	if target_stack.can_merge_with(stack):
		return target_stack.remaining_capacity() >= stack.quantity
	return false


func _can_place_stack_in_inventory_slot(
	inventory: Inventory,
	stack: ItemStack,
	target_section: StringName,
	target_index: int
) -> bool:
	if inventory == null:
		return false

	var slots: Array[ItemStack] = _get_inventory_slots(inventory, target_section)
	if target_index < 0 or target_index >= slots.size():
		return false

	var target_stack: ItemStack = inventory.get_slot_stack(target_section, target_index)
	if target_stack == null:
		return true
	if target_stack.can_merge_with(stack):
		return target_stack.remaining_capacity() >= stack.quantity
	return false


func _get_inventory_slots(inventory: Inventory, section: StringName) -> Array[ItemStack]:
	match section:
		Inventory.SECTION_HOTBAR:
			return inventory.get_hotbar_stacks()
		Inventory.SECTION_BACKPACK:
			return inventory.get_backpack_stacks()
		_:
			return []


func _is_pending_index_valid(index: int) -> bool:
	return index >= 0 and index < pending_slots.size()
