extends Control
class_name ShopPanelUI

const PENDING_SECTION: StringName = &"pending"

var inventory: Inventory
var shipping_manager
var _shop_slots: Array[SlotUI] = []
var _backpack_slots: Array[SlotUI] = []

@onready var shop_grid: GridContainer = $Shop/GridContainer
@onready var backpack_grid: GridContainer = $Backpack/GridContainer
@onready var pending_total_label: Label = $PendingTotal


func _ready() -> void:
	shipping_manager = get_node_or_null("/root/ShippingManager")
	_collect_slots()
	_refresh_ui()


func setup(target_inventory: Inventory) -> void:
	inventory = target_inventory
	_collect_slots()
	_connect_signals()
	_refresh_ui()


func _collect_slots() -> void:
	_shop_slots.clear()
	_backpack_slots.clear()

	var shop_index: int = 0
	for child: Node in shop_grid.get_children():
		var slot_ui: SlotUI = child as SlotUI
		if slot_ui == null:
			continue
		slot_ui.configure(null, PENDING_SECTION, shop_index)
		slot_ui.set_stack_provider(Callable(self, "_get_pending_stack").bind(shop_index))
		slot_ui.set_quick_action_mode(SlotUI.QuickActionMode.QUICK_WITHDRAW)
		slot_ui.set_drag_source_kind(SlotUI.DRAG_SOURCE_PENDING)
		slot_ui.set_external_drop_handlers(
			Callable(self, "_can_drop_to_pending_slot").bind(shop_index),
			Callable(self, "_drop_to_pending_slot").bind(shop_index)
		)
		if not slot_ui.quick_action_requested.is_connected(_on_slot_quick_action_requested):
			slot_ui.quick_action_requested.connect(_on_slot_quick_action_requested)
		_shop_slots.append(slot_ui)
		shop_index += 1

	var backpack_index: int = 0
	for child: Node in backpack_grid.get_children():
		var backpack_slot: SlotUI = child as SlotUI
		if backpack_slot == null:
			continue
		backpack_slot.configure(inventory, Inventory.SECTION_BACKPACK, backpack_index)
		backpack_slot.set_stack_provider()
		backpack_slot.set_quick_action_mode(SlotUI.QuickActionMode.QUICK_SELL)
		backpack_slot.set_drag_source_kind(SlotUI.DRAG_SOURCE_INVENTORY)
		backpack_slot.set_external_drop_handlers(
			Callable(self, "_can_drop_to_backpack_slot").bind(backpack_index),
			Callable(self, "_drop_to_backpack_slot").bind(backpack_index)
		)
		if not backpack_slot.quick_action_requested.is_connected(_on_slot_quick_action_requested):
			backpack_slot.quick_action_requested.connect(_on_slot_quick_action_requested)
		_backpack_slots.append(backpack_slot)
		backpack_index += 1


func _connect_signals() -> void:
	if inventory != null and not inventory.backpack_changed.is_connected(_refresh_ui):
		inventory.backpack_changed.connect(_refresh_ui)
	if shipping_manager != null and not shipping_manager.pending_sales_changed.is_connected(_refresh_ui):
		shipping_manager.pending_sales_changed.connect(_refresh_ui)


func _refresh_ui() -> void:
	for slot_ui: SlotUI in _shop_slots:
		slot_ui.refresh()
		slot_ui.set_selected(false)

	for backpack_slot: SlotUI in _backpack_slots:
		backpack_slot.refresh()
		backpack_slot.set_selected(false)

	if pending_total_label == null:
		return
	if shipping_manager == null:
		pending_total_label.text = "待结算：0"
		return
	pending_total_label.text = "待结算：%d" % shipping_manager.get_pending_total_value()


func _get_pending_stack(index: int) -> ItemStack:
	if shipping_manager == null:
		return null
	return shipping_manager.get_pending_stack(index)


func _on_slot_quick_action_requested(action: int, section: StringName, index: int) -> void:
	if shipping_manager == null or inventory == null:
		return

	match action:
		SlotUI.QuickActionMode.QUICK_SELL:
			if section == Inventory.SECTION_BACKPACK:
				shipping_manager.queue_from_inventory(inventory, section, index)
		SlotUI.QuickActionMode.QUICK_WITHDRAW:
			if section == PENDING_SECTION:
				shipping_manager.withdraw_to_inventory(inventory, index)


func _can_drop_to_pending_slot(data: Variant, target_index: int) -> bool:
	if shipping_manager == null or inventory == null:
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if not data.has(SlotUI.DRAG_SOURCE_KIND_KEY) or not data.has(SlotUI.DRAG_INDEX_KEY):
		return false

	var source_kind: StringName = StringName(String(data.get(SlotUI.DRAG_SOURCE_KIND_KEY, &"")))
	var from_index: int = int(data.get(SlotUI.DRAG_INDEX_KEY, -1))
	if source_kind == SlotUI.DRAG_SOURCE_INVENTORY:
		var from_section: StringName = StringName(String(data.get(SlotUI.DRAG_SECTION_KEY, &"")))
		return shipping_manager.can_queue_from_inventory(inventory, from_section, from_index, target_index)
	if source_kind == SlotUI.DRAG_SOURCE_PENDING:
		return shipping_manager.can_move_or_merge_pending(from_index, target_index)
	return false


func _drop_to_pending_slot(data: Variant, target_index: int) -> void:
	if not _can_drop_to_pending_slot(data, target_index):
		return

	var source_kind: StringName = StringName(String(data.get(SlotUI.DRAG_SOURCE_KIND_KEY, &"")))
	var from_index: int = int(data.get(SlotUI.DRAG_INDEX_KEY, -1))
	if source_kind == SlotUI.DRAG_SOURCE_INVENTORY:
		var from_section: StringName = StringName(String(data.get(SlotUI.DRAG_SECTION_KEY, &"")))
		shipping_manager.queue_from_inventory(inventory, from_section, from_index, target_index)
		return
	if source_kind == SlotUI.DRAG_SOURCE_PENDING:
		shipping_manager.move_or_merge_pending(from_index, target_index)


func _can_drop_to_backpack_slot(data: Variant, target_index: int) -> bool:
	if inventory == null:
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if not data.has(SlotUI.DRAG_SOURCE_KIND_KEY) or not data.has(SlotUI.DRAG_INDEX_KEY):
		return false

	var source_kind: StringName = StringName(String(data.get(SlotUI.DRAG_SOURCE_KIND_KEY, &"")))
	var from_index: int = int(data.get(SlotUI.DRAG_INDEX_KEY, -1))
	if source_kind == SlotUI.DRAG_SOURCE_PENDING:
		if shipping_manager == null:
			return false
		return shipping_manager.can_withdraw_to_inventory(inventory, from_index, Inventory.SECTION_BACKPACK, target_index)
	if source_kind == SlotUI.DRAG_SOURCE_INVENTORY:
		var from_section: StringName = StringName(String(data.get(SlotUI.DRAG_SECTION_KEY, &"")))
		if from_section == Inventory.SECTION_BACKPACK and from_index == target_index:
			return false
		return true
	return false


func _drop_to_backpack_slot(data: Variant, target_index: int) -> void:
	if not _can_drop_to_backpack_slot(data, target_index):
		return

	var source_kind: StringName = StringName(String(data.get(SlotUI.DRAG_SOURCE_KIND_KEY, &"")))
	var from_index: int = int(data.get(SlotUI.DRAG_INDEX_KEY, -1))
	if source_kind == SlotUI.DRAG_SOURCE_PENDING:
		shipping_manager.move_pending_to_inventory(inventory, from_index, Inventory.SECTION_BACKPACK, target_index)
		return

	var from_section: StringName = StringName(String(data.get(SlotUI.DRAG_SECTION_KEY, &"")))
	inventory.move_or_swap_stack(from_section, from_index, Inventory.SECTION_BACKPACK, target_index)
