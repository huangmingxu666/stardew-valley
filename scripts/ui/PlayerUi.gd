extends CanvasLayer
class_name PlayerUiRoot

@export var debug_gold_amount: int = 250

const SAMPLE_ITEM_DEFINITIONS: Array[Dictionary] = [
	{"resource": "res://resources/items/Plant/Tomato/tomato.tres", "quantity": 12},
	{"resource": "res://resources/items/Plant/Tomato/tomato_seed.tres", "quantity": 18},
	{"id": "apple", "name": "Apple", "icon": "res://assets/Icon/Singles_Icons_32x32_Crops_Apple.png", "quantity": 6},
	{"id": "pumpkin", "name": "Pumpkin", "icon": "res://assets/Icon/Singles_Icons_32x32_Crops_Pumpkin.png", "quantity": 4},
	{"id": "corn_seed", "name": "Corn Seeds", "icon": "res://assets/Icon/Singles_Icons_32x32_Seed_Bags_Corn.png", "quantity": 15},
	{"id": "grape", "name": "Grape", "icon": "res://assets/Icon/Singles_Icons_32x32_Crops_Grape.png", "quantity": 9},
	{"id": "coffee_beans", "name": "Coffee Beans", "icon": "res://assets/Icon/Singles_Icons_32x32_Crops_Coffee.png", "quantity": 16},
	{"id": "baguette", "name": "Baguette", "icon": "res://assets/Icon/Singles_Icons_32x32_Food_Baguette.png", "quantity": 3},
	{"id": "cheese", "name": "Cheese", "icon": "res://assets/Icon/Singles_Icons_32x32_Food_Cheese.png", "quantity": 5},
	{"id": "trunk", "name": "Wood Trunk", "icon": "res://assets/Icon/Singles_Icons_32x32_Resources_Trunk_1.png", "quantity": 20},
	{"id": "wool", "name": "Wool", "icon": "res://assets/Icon/Singles_Icons_32x32_Resources_Whool_White.png", "quantity": 7},
	{"id": "onion_seed", "name": "Onion Seeds", "icon": "res://assets/Icon/Singles_Icons_32x32_Seed_Bags_Onion.png", "quantity": 14},
]
const INVENTORY_INPUT_LOCK_REASON: StringName = &"inventory_panel"
const SHIPPING_INPUT_LOCK_REASON: StringName = &"shipping_panel"
const SHOP_INPUT_LOCK_REASON: StringName = &"shop_panel"

var inventory: Inventory
var time_manager: TimeManager
var tool_controller: ToolController
var game_state

@onready var hud: HUDController = $HUD
@onready var inventory_panel: InventoryPanelUI = $InventoryPanel
@onready var shop_panel: ShopPanelUI = $ShopPanel
@onready var shop_buy_panel: Control = $ShopBuyPanel


func _ready() -> void:
	visible = true
	inventory = _resolve_inventory()
	time_manager = _resolve_time_manager()
	tool_controller = _find_first_tool_controller(get_tree().current_scene)
	game_state = get_node_or_null("/root/GameState") as GameState

	if inventory != null:
		inventory.ensure_default_tool_loadout(_load_default_tools())
		# 只在背包完全为空时填充示例数据，避免覆盖玩家已有物品
		if not _inventory_has_any_content(inventory):
			_seed_mock_backpack_if_needed()

	if hud != null:
		hud.setup(inventory, time_manager, game_state)

	if inventory_panel != null:
		inventory_panel.setup(inventory, game_state)
		inventory_panel.visible = false
		_sync_inventory_input_lock()
		_sync_hotbar_visibility()

	if shop_panel != null:
		shop_panel.setup(inventory)
		shop_panel.visible = false
		_sync_shipping_input_lock()
		_sync_hotbar_visibility()

	if shop_buy_panel != null:
		shop_buy_panel.setup(null, inventory)
		shop_buy_panel.visible = false
		shop_buy_panel.close_requested.connect(close_shop_panel)
		_sync_shop_input_lock()
		_sync_hotbar_visibility()

	if game_state != null and game_state.get_current_cash() == 0 and game_state.get_total_cash() == 0 and debug_gold_amount > 0:
		game_state.set_cash_state(debug_gold_amount, debug_gold_amount)

	if inventory != null and not inventory.selected_hotbar_index_changed.is_connected(_on_selected_hotbar_index_changed):
		inventory.selected_hotbar_index_changed.connect(_on_selected_hotbar_index_changed)

	if tool_controller != null and not tool_controller.selected_tool_changed.is_connected(_on_selected_tool_changed):
		tool_controller.selected_tool_changed.connect(_on_selected_tool_changed)

	_sync_tool_selection_from_hotbar()


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_ESCAPE:
		if close_all_panels():
			get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_TAB:
		if inventory_panel != null:
			if inventory_panel.visible:
				close_inventory_panel()
			else:
				open_inventory_panel()
		get_viewport().set_input_as_handled()
		return

	var hotbar_index: int = _keycode_to_hotbar_index(key_event.keycode)
	if hotbar_index < 0 or inventory == null:
		return
	if tool_controller != null and tool_controller.player != null and tool_controller.player.is_tool_use_locked():
		get_viewport().set_input_as_handled()
		return

	inventory.set_selected_hotbar_index(hotbar_index)
	get_viewport().set_input_as_handled()


func _on_selected_hotbar_index_changed(_index: int) -> void:
	_sync_tool_selection_from_hotbar()


func _on_selected_tool_changed(tool_id: StringName) -> void:
	if inventory == null:
		return

	var slot_index: int = inventory.find_hotbar_index_by_item_id(tool_id)
	if slot_index >= 0 and inventory.selected_hotbar_index != slot_index:
		inventory.set_selected_hotbar_index(slot_index)


func _sync_tool_selection_from_hotbar() -> void:
	if inventory == null or tool_controller == null:
		return

	var selected_stack: ItemStack = inventory.get_selected_hotbar_stack()
	if selected_stack == null:
		tool_controller.clear_selected_tool()
		return

	var selected_tool: ToolData = selected_stack.source_data as ToolData
	if selected_tool == null or not tool_controller.has_tool(selected_tool.id):
		tool_controller.clear_selected_tool()
		return

	if tool_controller.get_selected_tool_id() != selected_tool.id:
		tool_controller.select_tool_by_id(selected_tool.id)


func _resolve_inventory() -> Inventory:
	var found_inventory: Inventory = _find_first_inventory(get_tree().current_scene)
	if found_inventory != null:
		return found_inventory

	var game_state_node = get_node_or_null("/root/GameState")
	if game_state_node != null:
		var global_inv = game_state_node.get_node_or_null("GlobalInventory")
		if global_inv is Inventory:
			return global_inv

	var mock_inventory: Inventory = Inventory.new()
	mock_inventory.name = "GlobalInventory"
	mock_inventory.hotbar_size = 10
	mock_inventory.backpack_size = 30
	mock_inventory.hotbar_slots.resize(mock_inventory.hotbar_size)
	mock_inventory.backpack_slots.resize(mock_inventory.backpack_size)

	if game_state_node != null:
		game_state_node.add_child(mock_inventory)
	else:
		add_child(mock_inventory)
	return mock_inventory


func _resolve_time_manager() -> TimeManager:
	var game_time: TimeManager = get_node_or_null("/root/GameTime") as TimeManager
	if game_time != null:
		return game_time

	var found_time_manager: TimeManager = _find_first_time_manager(get_tree().current_scene)
	if found_time_manager != null:
		return found_time_manager

	var mock_time_manager: TimeManager = TimeManager.new()
	mock_time_manager.name = "TimeManager"
	add_child(mock_time_manager)
	return mock_time_manager


func _load_default_tools() -> Array[ToolData]:
	var tools: Array[ToolData] = []
	for resource_path: String in ToolController.DEFAULT_TOOL_RESOURCE_PATHS:
		var tool_data: ToolData = load(resource_path) as ToolData
		if tool_data != null:
			tools.append(tool_data)
	return tools


func _inventory_has_any_content(inv: Inventory) -> bool:
	for index: int in range(inv.hotbar_slots.size()):
		if inv.get_slot_stack(Inventory.SECTION_HOTBAR, index) != null:
			return true
	for index: int in range(inv.backpack_slots.size()):
		if inv.get_slot_stack(Inventory.SECTION_BACKPACK, index) != null:
			return true
	return false


func _seed_mock_backpack_if_needed() -> void:
	if inventory == null:
		return

	var tools: Array[ToolData] = _load_default_tools()
	_seed_hotbar_samples()

	for tool_index: int in range(mini(tools.size(), 4)):
		if inventory.get_slot_stack(Inventory.SECTION_BACKPACK, tool_index) != null:
			continue

		var copy_stack: ItemStack = ItemStack.from_tool_data(tools[tool_index])
		inventory.set_stack(Inventory.SECTION_BACKPACK, tool_index, copy_stack)

	var sample_index: int = 0
	for slot_index: int in range(4, inventory.backpack_size):
		if inventory.get_slot_stack(Inventory.SECTION_BACKPACK, slot_index) != null:
			continue

		inventory.set_stack(Inventory.SECTION_BACKPACK, slot_index, _build_sample_stack(sample_index))
		sample_index += 1


func _seed_hotbar_samples() -> void:
	var sample_index: int = 0
	for slot_index: int in range(4, inventory.hotbar_size):
		if inventory.get_slot_stack(Inventory.SECTION_HOTBAR, slot_index) != null:
			continue

		inventory.set_stack(Inventory.SECTION_HOTBAR, slot_index, _build_sample_stack(sample_index))
		sample_index += 1


func _build_sample_stack(sample_index: int) -> ItemStack:
	var definition: Dictionary = SAMPLE_ITEM_DEFINITIONS[sample_index % SAMPLE_ITEM_DEFINITIONS.size()]
	var item_resource_path_variant: Variant = definition.get("resource", "")
	var item_resource_path: String = String(item_resource_path_variant)
	if not item_resource_path.is_empty():
		var item_data: ItemData = load(item_resource_path) as ItemData
		if item_data != null:
			return ItemStack.from_item_data(item_data, int(definition.get("quantity", 1)))

	var sample_stack: ItemStack = ItemStack.new()
	sample_stack.item_id = StringName(String(definition["id"]))
	sample_stack.display_name = String(definition["name"])
	sample_stack.icon_texture = load(String(definition["icon"])) as Texture2D
	sample_stack.quantity = int(definition["quantity"])
	sample_stack.max_stack = 99
	sample_stack.stackable = true
	return sample_stack


func open_inventory_panel() -> void:
	if inventory_panel == null:
		return

	visible = true
	if shop_panel != null and shop_panel.visible:
		close_shipping_panel()

	inventory_panel.visible = true
	_sync_inventory_input_lock()
	_sync_hotbar_visibility()


func close_inventory_panel() -> void:
	if inventory_panel == null:
		return

	inventory_panel.visible = false
	_sync_inventory_input_lock()
	_sync_hotbar_visibility()


func close_all_panels() -> bool:
	var did_close: bool = false

	if inventory_panel != null and inventory_panel.visible:
		close_inventory_panel()
		did_close = true

	if has_method("close_shipping_panel"):
		var shipping_closed: Variant = call("close_shipping_panel")
		if shipping_closed is bool and shipping_closed:
			did_close = true

	if has_method("close_shop_panel"):
		var shop_closed: Variant = call("close_shop_panel")
		if shop_closed is bool and shop_closed:
			did_close = true

	return did_close


func _sync_inventory_input_lock() -> void:
	if inventory_panel != null and inventory_panel.visible:
		SceneTransition.acquire_input_lock(INVENTORY_INPUT_LOCK_REASON)
		return

	SceneTransition.release_input_lock(INVENTORY_INPUT_LOCK_REASON)


func _sync_shipping_input_lock() -> void:
	if shop_panel != null and shop_panel.visible:
		SceneTransition.acquire_input_lock(SHIPPING_INPUT_LOCK_REASON)
		return

	SceneTransition.release_input_lock(SHIPPING_INPUT_LOCK_REASON)


func _sync_hotbar_visibility() -> void:
	if hud == null:
		return
	var should_show_hotbar: bool = true
	if inventory_panel != null and inventory_panel.visible:
		should_show_hotbar = false
	if shop_panel != null and shop_panel.visible:
		should_show_hotbar = false
	if shop_buy_panel != null and shop_buy_panel.visible:
		should_show_hotbar = false
	hud.set_hotbar_visible(should_show_hotbar)


func open_shipping_panel() -> void:
	if shop_panel == null:
		return

	visible = true
	if inventory_panel != null:
		inventory_panel.visible = false
		_sync_inventory_input_lock()

	shop_panel.visible = true
	_sync_shipping_input_lock()
	_sync_hotbar_visibility()


func close_shipping_panel() -> bool:
	if shop_panel == null:
		return false
	if not shop_panel.visible:
		return false

	shop_panel.visible = false
	_sync_shipping_input_lock()
	_sync_hotbar_visibility()
	return true


func is_shipping_panel_open() -> bool:
	return shop_panel != null and shop_panel.visible


func open_shop_panel(shop_inventory: ShopInventory) -> void:
	if shop_buy_panel == null:
		return

	visible = true
	if inventory_panel != null:
		inventory_panel.visible = false
		_sync_inventory_input_lock()
	if shop_panel != null:
		shop_panel.visible = false
		_sync_shipping_input_lock()

	shop_buy_panel.setup(shop_inventory, inventory)
	shop_buy_panel.visible = true
	_sync_shop_input_lock()
	_sync_hotbar_visibility()

	if time_manager != null:
		time_manager.pause_time(SHOP_INPUT_LOCK_REASON)


func close_shop_panel() -> bool:
	if shop_buy_panel == null:
		return false
	if not shop_buy_panel.visible:
		return false

	shop_buy_panel.visible = false
	_sync_shop_input_lock()
	_sync_hotbar_visibility()

	if time_manager != null:
		time_manager.resume_time(SHOP_INPUT_LOCK_REASON)

	return true


func is_shop_panel_open() -> bool:
	return shop_buy_panel != null and shop_buy_panel.visible


func _sync_shop_input_lock() -> void:
	if shop_buy_panel != null and shop_buy_panel.visible:
		SceneTransition.acquire_input_lock(SHOP_INPUT_LOCK_REASON)
		return

	SceneTransition.release_input_lock(SHOP_INPUT_LOCK_REASON)


func _keycode_to_hotbar_index(keycode: Key) -> int:
	match keycode:
		KEY_1:
			return 0
		KEY_2:
			return 1
		KEY_3:
			return 2
		KEY_4:
			return 3
		KEY_5:
			return 4
		KEY_6:
			return 5
		KEY_7:
			return 6
		KEY_8:
			return 7
		KEY_9:
			return 8
		KEY_0:
			return 9
		_:
			return -1


func _find_first_inventory(root: Node) -> Inventory:
	if root == null:
		return null
	if root is Inventory:
		return root as Inventory
	for child: Node in root.get_children():
		var resolved: Inventory = _find_first_inventory(child)
		if resolved != null:
			return resolved
	return null


func _find_first_time_manager(root: Node) -> TimeManager:
	if root == null:
		return null
	if root is TimeManager:
		return root as TimeManager
	for child: Node in root.get_children():
		var resolved: TimeManager = _find_first_time_manager(child)
		if resolved != null:
			return resolved
	return null


func _find_first_tool_controller(root: Node) -> ToolController:
	if root == null:
		return null
	if root is ToolController:
		return root as ToolController
	for child: Node in root.get_children():
		var resolved: ToolController = _find_first_tool_controller(child)
		if resolved != null:
			return resolved
	return null
