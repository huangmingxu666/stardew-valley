extends CanvasLayer
class_name HUDController

var inventory: Inventory
var time_manager: TimeManager
var game_state

var _hotbar_slots: Array[SlotUI] = []
var _money_digits: Array[Label] = []

@onready var hotbar_grid: GridContainer = $Root/HotBar/GridContainer
@onready var hotbar_panel: Control = $Root/HotBar
@onready var time_label: Label = $Root/TopRight/TopRightTime/HBoxContainer/TimeRow/TimeLeft
@onready var season_label: Label = $Root/TopRight/TopRightSeason/HBoxContainer/Season
@onready var week_label: Label = $Root/TopRight/TopRightSeason/HBoxContainer/Week


func setup(target_inventory: Inventory, target_time_manager: TimeManager, target_game_state) -> void:
	inventory = target_inventory
	time_manager = target_time_manager
	game_state = target_game_state
	_collect_hotbar_slots()
	_collect_money_digits()
	_connect_inventory_signals()
	_connect_time_signals()
	_connect_game_state_signals()
	_refresh_hotbar()
	_refresh_time()
	if game_state != null:
		set_gold(game_state.get_current_cash())
	else:
		set_gold(0)


func set_gold(value: int) -> void:
	if _money_digits.is_empty():
		return

	var clamped_value: int = clampi(value, 0, 99_999_999)
	var text: String = str(clamped_value).lpad(_money_digits.size(), "0")
	for index: int in range(_money_digits.size()):
		_money_digits[index].text = text.substr(index, 1)


func set_hotbar_visible(is_visible: bool) -> void:
	if hotbar_panel == null:
		return
	hotbar_panel.visible = is_visible


func _collect_hotbar_slots() -> void:
	_hotbar_slots.clear()
	var slot_index: int = 0
	for child: Node in hotbar_grid.get_children():
		var slot_ui: SlotUI = child as SlotUI
		if slot_ui == null:
			continue
		slot_ui.configure(inventory, Inventory.SECTION_HOTBAR, slot_index)
		slot_ui.set_interaction_flags(false, false, false, false, false)
		_hotbar_slots.append(slot_ui)
		slot_index += 1


func _collect_money_digits() -> void:
	_money_digits.clear()
	var digits_root: Node = $Root/TopRight/TopRightMoney/GridContainer/HBoxContainer/HBoxContainer
	for child: Node in digits_root.get_children():
		var label: Label = child.get_node_or_null("BG/Icon") as Label
		if label != null:
			_money_digits.append(label)


func _connect_inventory_signals() -> void:
	if inventory == null:
		return
	if not inventory.hotbar_changed.is_connected(_refresh_hotbar):
		inventory.hotbar_changed.connect(_refresh_hotbar)
	if not inventory.selected_hotbar_index_changed.is_connected(_on_selected_hotbar_index_changed):
		inventory.selected_hotbar_index_changed.connect(_on_selected_hotbar_index_changed)


func _connect_time_signals() -> void:
	if time_manager == null:
		return
	if not time_manager.time_changed.is_connected(_on_time_changed):
		time_manager.time_changed.connect(_on_time_changed)


func _connect_game_state_signals() -> void:
	if game_state == null:
		return
	if not game_state.cash_changed.is_connected(_on_cash_changed):
		game_state.cash_changed.connect(_on_cash_changed)


func _refresh_hotbar() -> void:
	for index: int in range(_hotbar_slots.size()):
		var slot_ui: SlotUI = _hotbar_slots[index]
		slot_ui.refresh()
		slot_ui.set_selected(inventory != null and inventory.selected_hotbar_index == index)


func _refresh_time() -> void:
	if time_manager == null:
		time_label.text = "08:00"
		season_label.text = "1日"
		week_label.text = "星期一"
		return

	time_label.text = "%02d:%02d" % [time_manager.current_hour, time_manager.current_minute]
	season_label.text = "%d日" % time_manager.get_day_of_season()
	week_label.text = time_manager.get_weekday_label()


func _on_time_changed(_day: int, _hour: int, _minute: int) -> void:
	_refresh_time()


func _on_selected_hotbar_index_changed(_index: int) -> void:
	_refresh_hotbar()


func _on_cash_changed(current_cash: int, _total_cash: int) -> void:
	set_gold(current_cash)
