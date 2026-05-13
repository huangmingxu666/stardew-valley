extends CanvasLayer
class_name PlayerUiRoot

@export var debug_gold_amount: int = 250

const SAMPLE_ITEM_DEFINITIONS: Array[Dictionary] = [
	{"id": "turnip", "name": "Turnip", "icon": "res://assets/Icon/Singles_Icons_32x32_Crops_Turnip.png", "quantity": 12},
	{"id": "carrot_seed", "name": "Carrot Seeds", "icon": "res://assets/Icon/Singles_Icons_32x32_Seed_Bags_Carrot.png", "quantity": 18},
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

var inventory: Inventory
var time_manager: TimeManager
var tool_controller: ToolController
var game_state

@onready var hud: HUDController = $HUD
@onready var inventory_panel: InventoryPanelUI = $InventoryPanel


func _ready() -> void:
	inventory = _resolve_inventory()
	time_manager = _resolve_time_manager()
	tool_controller = _find_first_tool_controller(get_tree().current_scene)
	game_state = get_node_or_null("/root/GameState") as GameState

	if inventory != null:
		inventory.ensure_default_tool_loadout(_load_default_tools())
		_seed_mock_backpack_if_needed()

	if hud != null:
		hud.setup(inventory, time_manager, game_state)

	if inventory_panel != null:
		inventory_panel.setup(inventory, game_state)
		inventory_panel.visible = false
		_sync_inventory_input_lock()
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

	if key_event.keycode == KEY_TAB:
		if inventory_panel != null:
			inventory_panel.visible = not inventory_panel.visible
			_sync_inventory_input_lock()
			_sync_hotbar_visibility()
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

	var mock_inventory: Inventory = Inventory.new()
	mock_inventory.name = "Inventory"
	mock_inventory.hotbar_size = 10
	mock_inventory.backpack_size = 30
	mock_inventory.hotbar_slots.resize(mock_inventory.hotbar_size)
	mock_inventory.backpack_slots.resize(mock_inventory.backpack_size)
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
	var sample_stack: ItemStack = ItemStack.new()
	sample_stack.item_id = StringName(String(definition["id"]))
	sample_stack.display_name = String(definition["name"])
	sample_stack.icon_texture = load(String(definition["icon"])) as Texture2D
	sample_stack.quantity = int(definition["quantity"])
	sample_stack.max_stack = 99
	sample_stack.stackable = true
	return sample_stack


func _sync_inventory_input_lock() -> void:
	if inventory_panel != null and inventory_panel.visible:
		SceneTransition.acquire_input_lock(INVENTORY_INPUT_LOCK_REASON)
		return

	SceneTransition.release_input_lock(INVENTORY_INPUT_LOCK_REASON)


func _sync_hotbar_visibility() -> void:
	if hud == null:
		return
	var should_show_hotbar: bool = inventory_panel == null or not inventory_panel.visible
	hud.set_hotbar_visible(should_show_hotbar)


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
