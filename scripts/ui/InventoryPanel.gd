extends Control
class_name InventoryPanelUI

const HOTBAR_VISUAL_SLOT_COUNT: int = 10

var inventory: Inventory
var game_state
var _slot_controls: Array[SlotUI] = []
var _customization_slots: Array[PlayerCustomizationSlot] = []
var _trash_drop_area: TrashDropArea

@onready var slot_grid: GridContainer = $Backpack/GridContainer
@onready var current_cash_label: Label = $Character_and_Information/Information/VBoxContainer/Current_cash
@onready var total_cash_label: Label = $Character_and_Information/Information/VBoxContainer/Total_cash


func setup(target_inventory: Inventory, target_game_state) -> void:
	inventory = target_inventory
	game_state = target_game_state
	_collect_slots()
	_collect_customization_slots()
	_trash_drop_area = _find_first_trash_drop_area(self)
	if _trash_drop_area != null:
		_trash_drop_area.configure(inventory)
	_connect_inventory_signals()
	_connect_game_state_signals()
	_refresh_slots()
	_refresh_cash_labels()


func _collect_slots() -> void:
	_slot_controls.clear()
	var visual_index: int = 0
	var hotbar_start_index: int = maxi(slot_grid.get_child_count() - HOTBAR_VISUAL_SLOT_COUNT, 0)
	for child: Node in slot_grid.get_children():
		var slot_ui: SlotUI = child as SlotUI
		if slot_ui == null:
			continue
		var section: StringName = Inventory.SECTION_BACKPACK
		var slot_index: int = visual_index
		if visual_index >= hotbar_start_index:
			section = Inventory.SECTION_HOTBAR
			slot_index = visual_index - hotbar_start_index
		slot_ui.configure(inventory, section, slot_index)
		slot_ui.set_quick_action_mode(SlotUI.QuickActionMode.QUICK_EQUIP)
		if not slot_ui.quick_equip_requested.is_connected(_on_quick_equip_requested):
			slot_ui.quick_equip_requested.connect(_on_quick_equip_requested)
		_slot_controls.append(slot_ui)
		visual_index += 1


func _collect_customization_slots() -> void:
	_customization_slots.clear()
	for slot: PlayerCustomizationSlot in _find_customization_slots(self):
		slot.configure(inventory)
		_customization_slots.append(slot)


func _connect_inventory_signals() -> void:
	if inventory == null:
		return
	if not inventory.backpack_changed.is_connected(_refresh_slots):
		inventory.backpack_changed.connect(_refresh_slots)
	if not inventory.hotbar_changed.is_connected(_refresh_slots):
		inventory.hotbar_changed.connect(_refresh_slots)
	if not inventory.selected_hotbar_index_changed.is_connected(_on_selected_hotbar_index_changed):
		inventory.selected_hotbar_index_changed.connect(_on_selected_hotbar_index_changed)


func _connect_game_state_signals() -> void:
	if game_state == null:
		return
	if not game_state.cash_changed.is_connected(_on_cash_changed):
		game_state.cash_changed.connect(_on_cash_changed)


func _refresh_slots() -> void:
	for slot_ui: SlotUI in _slot_controls:
		slot_ui.refresh()
		slot_ui.set_selected(false)


func _on_selected_hotbar_index_changed(_index: int) -> void:
	_refresh_slots()


func _on_quick_equip_requested(section: StringName, index: int) -> void:
	for slot: PlayerCustomizationSlot in _customization_slots:
		if slot.is_empty() and slot.try_equip_from_inventory(section, index):
			return


func _on_cash_changed(_current_cash: int, _total_cash: int) -> void:
	_refresh_cash_labels()


func _refresh_cash_labels() -> void:
	if current_cash_label == null or total_cash_label == null:
		return
	if game_state == null:
		current_cash_label.text = "目前持有现金：0"
		total_cash_label.text = "总收入：0"
		return

	current_cash_label.text = "目前持有现金：%d" % game_state.get_current_cash()
	total_cash_label.text = "总收入：%d" % game_state.get_total_cash()


func _find_first_trash_drop_area(root: Node) -> TrashDropArea:
	if root == null:
		return null
	if root is TrashDropArea:
		return root as TrashDropArea
	for child: Node in root.get_children():
		var resolved: TrashDropArea = _find_first_trash_drop_area(child)
		if resolved != null:
			return resolved
	return null


func _find_customization_slots(root: Node) -> Array[PlayerCustomizationSlot]:
	var results: Array[PlayerCustomizationSlot] = []
	if root == null:
		return results
	if root is PlayerCustomizationSlot:
		results.append(root as PlayerCustomizationSlot)
	for child: Node in root.get_children():
		results.append_array(_find_customization_slots(child))
	return results
