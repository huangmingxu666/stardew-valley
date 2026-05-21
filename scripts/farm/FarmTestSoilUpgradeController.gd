extends Node
class_name FarmTestSoilUpgradeController

signal level_upgrade_started(from_level: int, to_level: int)
signal level_upgrade_completed(new_level: int)
signal level_changed(old_level: int, new_level: int)
signal upgrade_available(next_level: int)
signal upgrade_blocked(current_level: int)
signal fade_completed(is_visible: bool)

const INPUT_LOCK_REASON: StringName = &"farm_test_soil_upgrade"
const SHOVEL_RESOURCE_PATH: String = "res://resources/tools/shovel.tres"
const WATERING_CAN_RESOURCE_PATH: String = "res://resources/tools/watering_can.tres"
const BARE_HANDS_RESOURCE_PATH: String = "res://resources/tools/bare_hands.tres"
const TOMATO_SEED_RESOURCE_PATH: String = "res://resources/items/Plant/Tomato/tomato_seed.tres"
const TOMATO_ITEM_RESOURCE_PATH: String = "res://resources/items/Plant/Tomato/tomato.tres"

@export_node_path("PlayerController") var player_path: NodePath
@export_node_path("FarmGrid") var farm_grid_path: NodePath
@export_node_path("CropRegistry") var crop_registry_path: NodePath
@export_node_path("Inventory") var inventory_path: NodePath
@export_node_path("TileMapLayer") var active_shoveled_layer_path: NodePath
@export_node_path("TileMapLayer") var active_fence_layer_path: NodePath
@export_node_path("TileMapLayer") var watered_overlay_layer_path: NodePath
@export_node_path("Node") var template_levels_root_path: NodePath
@export_node_path("Node") var upgrade_markers_root_path: NodePath
@export_node_path("ColorRect") var fade_rect_path: NodePath
@export_node_path("Node") var game_state_path: NodePath
@export var interact_action: StringName = &"交互"
@export var plant_action: StringName = &"use_left"
@export var interaction_radius: float = 48.0
@export_range(1, 99, 1) var starting_level: int = 1
@export var upgrade_enabled: bool = true
@export var fade_duration: float = 0.18
@export var hold_duration: float = 0.06
@export var upgrade_costs: Dictionary = {}

var _player: PlayerController
var _farm_grid: FarmGrid
var _crop_registry: CropRegistry
var _inventory: Inventory
var _active_shoveled_layer: TileMapLayer
var _active_fence_layer: TileMapLayer
var _watered_overlay_layer: TileMapLayer
var _fade_rect: ColorRect
var _game_state: Node
var _templates_by_level: Dictionary = {}
var _level_numbers: Array[int] = []
var _upgrade_markers: Array[Marker2D] = []
var _current_level: int = 0
var _upgrade_in_progress: bool = false
var _fade_tween: Tween
var _template_tile_cache: Dictionary = {}


func _ready() -> void:
	_player = get_node_or_null(player_path) as PlayerController
	_farm_grid = get_node_or_null(farm_grid_path) as FarmGrid
	_crop_registry = _resolve_crop_registry()
	_inventory = _resolve_inventory()
	_active_shoveled_layer = get_node_or_null(active_shoveled_layer_path) as TileMapLayer
	_active_fence_layer = get_node_or_null(active_fence_layer_path) as TileMapLayer
	_watered_overlay_layer = get_node_or_null(watered_overlay_layer_path) as TileMapLayer
	_fade_rect = get_node_or_null(fade_rect_path) as ColorRect
	_game_state = get_node_or_null(game_state_path)

	_collect_level_templates()
	_collect_upgrade_markers()
	_cache_and_clear_template_layers()
	_prepare_fade_rect()
	_initialize_active_level()
	_configure_test_inventory()
	_connect_grid_signals()
	_refresh_watered_overlay()
	_refresh_visual_indicators()


func _input(event: InputEvent) -> void:
	if _upgrade_in_progress or SceneTransition.is_input_locked():
		return
	_handle_seed_plant_input(event)


func _unhandled_input(event: InputEvent) -> void:
	if _upgrade_in_progress or SceneTransition.is_input_locked():
		return
	if _upgrade_in_progress or SceneTransition.is_input_locked() or not upgrade_enabled:
		return
	if interact_action == &"" or not event.is_action_pressed(interact_action, false, true):
		return
	if not _is_player_near_upgrade_marker():
		return

	var next_level: int = get_next_level()
	if next_level <= 0:
		return

	get_viewport().set_input_as_handled()
	try_upgrade()


func can_upgrade() -> bool:
	if _upgrade_in_progress or not upgrade_enabled:
		return false
	if get_next_level() <= 0:
		return false
	if not _is_player_near_upgrade_marker():
		return false
	if _game_state != null:
		var cost: int = get_upgrade_cost(get_next_level())
		if cost > 0 and _game_state.get_current_cash() < cost:
			return false
	return true


func try_upgrade() -> bool:
	if not can_upgrade():
		var current_level: int = _current_level
		if current_level > 0:
			upgrade_blocked.emit(current_level)
		return false

	var next_level: int = get_next_level()
	level_upgrade_started.emit(_current_level, next_level)
	_run_upgrade_sequence(next_level)
	return true


func get_current_level() -> int:
	return _current_level


func get_next_level() -> int:
	if _level_numbers.is_empty():
		return 0

	for level_number: int in _level_numbers:
		if level_number > _current_level:
			return level_number

	return 0


func get_max_level() -> int:
	if _level_numbers.is_empty():
		return 0
	return _level_numbers[_level_numbers.size() - 1]


func is_upgrading() -> bool:
	return _upgrade_in_progress


func has_reached_max_level() -> bool:
	return get_next_level() <= 0


func set_upgrade_enabled(enabled: bool) -> void:
	upgrade_enabled = enabled
	_refresh_visual_indicators()


func apply_upgrade_level(level_number: int) -> bool:
	if _upgrade_in_progress:
		return false
	if not _template_tile_cache.has(level_number):
		return false

	_apply_level(level_number)
	_refresh_visual_indicators()
	return true


func play_fade_in(target_alpha: float = 1.0) -> Tween:
	return _start_fade_to_alpha(target_alpha)


func play_fade_out(target_alpha: float = 0.0) -> Tween:
	return _start_fade_to_alpha(target_alpha)


func get_fade_progress() -> float:
	if _fade_rect == null:
		return 0.0
	return _fade_rect.color.a


func get_upgrade_cost(to_level: int) -> int:
	var key: int = to_level
	if upgrade_costs.has(key):
		var cost_variant: Variant = upgrade_costs.get(key)
		return int(cost_variant) if cost_variant != null else 0
	for level_key: Variant in upgrade_costs.keys():
		if int(level_key) == to_level:
			var cost_variant: Variant = upgrade_costs.get(level_key)
			return int(cost_variant) if cost_variant != null else 0
	return 0


func _run_upgrade_sequence(next_level: int) -> void:
	if _upgrade_in_progress:
		return

	var old_level: int = _current_level
	_upgrade_in_progress = true
	SceneTransition.acquire_input_lock(INPUT_LOCK_REASON)
	if _player != null:
		_player.clear_input_state()

	var fade_in_tween: Tween = _start_fade_to_alpha(1.0)
	if fade_in_tween != null:
		await fade_in_tween.finished
	_apply_level(next_level)

	if _game_state != null:
		var cost: int = get_upgrade_cost(next_level)
		if cost > 0:
			_game_state.spend_cash(cost)

	level_changed.emit(old_level, _current_level)

	if hold_duration > 0.0:
		await get_tree().create_timer(hold_duration).timeout
	var fade_out_tween: Tween = _start_fade_to_alpha(0.0)
	if fade_out_tween != null:
		await fade_out_tween.finished

	if _player != null:
		_player.clear_input_state()
	SceneTransition.release_input_lock(INPUT_LOCK_REASON)
	_upgrade_in_progress = false
	level_upgrade_completed.emit(_current_level)
	_refresh_visual_indicators()


func _collect_level_templates() -> void:
	_templates_by_level.clear()
	_level_numbers.clear()

	var levels_root: Node = get_node_or_null(template_levels_root_path)
	if levels_root == null:
		return

	for child: Node in levels_root.get_children():
		var level_number: int = _extract_level_number(child.name)
		if level_number <= 0:
			continue

		var shoveled_layer: TileMapLayer = _find_named_tile_map_layer(child, "Shoveled")
		if shoveled_layer == null:
			continue

		var fence_layer: TileMapLayer = _find_named_tile_map_layer(child, "Fence")
		_templates_by_level[level_number] = {
			"shoveled": shoveled_layer,
			"fence": fence_layer,
		}
		_level_numbers.append(level_number)

	_level_numbers.sort()


func _cache_and_clear_template_layers() -> void:
	_template_tile_cache.clear()

	for level_number: int in _level_numbers:
		var template_variant: Variant = _templates_by_level.get(level_number)
		if not (template_variant is Dictionary):
			continue

		var template: Dictionary = template_variant
		var level_cache: Dictionary = {}

		var shoveled_layer: TileMapLayer = template.get("shoveled") as TileMapLayer
		if shoveled_layer != null:
			var shoveled_cells: Array[Dictionary] = []
			shoveled_cells.assign(_collect_tile_cells(shoveled_layer))
			level_cache["shoveled"] = shoveled_cells
			shoveled_layer.clear()

		var fence_layer: TileMapLayer = template.get("fence") as TileMapLayer
		if fence_layer != null:
			var fence_cells: Array[Dictionary] = []
			fence_cells.assign(_collect_tile_cells(fence_layer))
			level_cache["fence"] = fence_cells
			fence_layer.clear()

		_template_tile_cache[level_number] = level_cache


func _collect_tile_cells(layer: TileMapLayer) -> Array[Dictionary]:
	var collected: Array[Dictionary] = []
	for cell: Vector2i in layer.get_used_cells():
		collected.append({
			"cell": cell,
			"source_id": layer.get_cell_source_id(cell),
			"atlas_coords": layer.get_cell_atlas_coords(cell),
			"alternative_tile": layer.get_cell_alternative_tile(cell),
		})
	return collected


func _write_cells_from_cache(target_layer: TileMapLayer, cached_cells: Array) -> void:
	target_layer.clear()
	for entry: Dictionary in cached_cells:
		var cell: Vector2i = entry.get("cell") as Vector2i
		var source_id: int = int(entry.get("source_id", -1))
		var atlas_coords: Vector2i = entry.get("atlas_coords") as Vector2i
		var alternative_tile: int = int(entry.get("alternative_tile", 0))
		target_layer.set_cell(cell, source_id, atlas_coords, alternative_tile)


func _collect_upgrade_markers() -> void:
	_upgrade_markers.clear()

	var markers_root: Node = get_node_or_null(upgrade_markers_root_path)
	if markers_root == null:
		return

	for child: Node in markers_root.get_children():
		if child is Marker2D:
			_upgrade_markers.append(child as Marker2D)


func _prepare_fade_rect() -> void:
	if _fade_rect == null:
		return

	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.z_index = 100
	var color: Color = _fade_rect.color
	color.a = 0.0
	_fade_rect.color = color
	_fade_rect.visible = false


func _initialize_active_level() -> void:
	if _active_shoveled_layer == null:
		return

	var inferred_level: int = _infer_active_level()
	if inferred_level > 0:
		_current_level = inferred_level
		_sync_farm_grid_from_active_layer()
		return

	if not _active_shoveled_layer.get_used_cells().is_empty():
		_current_level = _clamp_to_available_level(starting_level)
		_sync_farm_grid_from_active_layer()
		return

	var initial_level: int = _clamp_to_available_level(starting_level)
	if initial_level > 0:
		_apply_level(initial_level)


func _apply_level(level_number: int) -> void:
	var level_cache: Variant = _template_tile_cache.get(level_number)
	if not (level_cache is Dictionary):
		return

	var cache: Dictionary = level_cache
	var shoveled_cells: Array = cache.get("shoveled", [])
	var fence_cells: Array = cache.get("fence", [])

	_write_cells_from_cache(_active_shoveled_layer, shoveled_cells)
	if _active_fence_layer != null:
		_write_cells_from_cache(_active_fence_layer, fence_cells)

	_current_level = level_number
	_sync_farm_grid_from_active_layer()
	_refresh_watered_overlay()


func _copy_layer_tiles(source_layer: TileMapLayer, target_layer: TileMapLayer) -> void:
	target_layer.clear()
	for cell: Vector2i in source_layer.get_used_cells():
		target_layer.set_cell(
			cell,
			source_layer.get_cell_source_id(cell),
			source_layer.get_cell_atlas_coords(cell),
			source_layer.get_cell_alternative_tile(cell)
		)


func _sync_farm_grid_from_active_layer() -> void:
	if _farm_grid == null or _active_shoveled_layer == null:
		return

	var preserved_states: Dictionary = {}
	for cell: Vector2i in _farm_grid.get_all_cells():
		var existing_state: FarmTileState = _farm_grid.get_tile_state(cell)
		if existing_state != null:
			preserved_states[cell] = existing_state.duplicate_state()

	var tillable_cells: Array[Vector2i] = _active_shoveled_layer.get_used_cells()
	_farm_grid.clear_all_tiles()
	_farm_grid.register_tillable_cells(tillable_cells, FarmTileState.SURFACE_SOIL)

	for cell: Vector2i in tillable_cells:
		var preserved_state: FarmTileState = preserved_states.get(cell) as FarmTileState
		if preserved_state == null:
			continue

		var refreshed_state: FarmTileState = _farm_grid.get_tile_state(cell)
		if refreshed_state == null:
			continue

		refreshed_state.surface_type = preserved_state.surface_type
		refreshed_state.tilled = preserved_state.tilled
		refreshed_state.watered = preserved_state.watered
		refreshed_state.blocked = preserved_state.blocked
		refreshed_state.crop_id = preserved_state.crop_id
		refreshed_state.crop_stage = preserved_state.crop_stage
		refreshed_state.crop_max_stage = preserved_state.crop_max_stage
		_farm_grid.tile_state_changed.emit(cell, refreshed_state)


func _is_player_near_upgrade_marker() -> bool:
	if _player == null:
		return false

	var max_distance_sq: float = interaction_radius * interaction_radius
	for marker: Marker2D in _upgrade_markers:
		if marker == null:
			continue
		if _player.global_position.distance_squared_to(marker.global_position) <= max_distance_sq:
			return true

	return false


func _infer_active_level() -> int:
	if _active_shoveled_layer == null:
		return 0

	var active_cells: Array[Vector2i] = _active_shoveled_layer.get_used_cells()
	if active_cells.is_empty():
		return 0

	for level_number: int in _level_numbers:
		var level_cache: Variant = _template_tile_cache.get(level_number)
		if not (level_cache is Dictionary):
			continue

		var cache: Dictionary = level_cache
		var cached_shoveled: Array = cache.get("shoveled", [])
		var template_cells: Array[Vector2i] = []
		for entry: Dictionary in cached_shoveled:
			var cell: Vector2i = entry.get("cell") as Vector2i
			template_cells.append(cell)

		if _cell_sets_match(active_cells, template_cells):
			return level_number

	return 0


func _cell_sets_match(left_cells: Array[Vector2i], right_cells: Array[Vector2i]) -> bool:
	if left_cells.size() != right_cells.size():
		return false

	var left_set: Dictionary = {}
	for cell: Vector2i in left_cells:
		left_set[cell] = true

	for cell: Vector2i in right_cells:
		if not left_set.has(cell):
			return false

	return true


func _clamp_to_available_level(requested_level: int) -> int:
	if _level_numbers.is_empty():
		return 0

	var clamped_level: int = _level_numbers[0]
	for level_number: int in _level_numbers:
		if level_number <= requested_level:
			clamped_level = level_number
		else:
			break

	return clamped_level


func _find_named_tile_map_layer(root: Node, prefix: String) -> TileMapLayer:
	for child: Node in root.get_children():
		if child is TileMapLayer and child.name.begins_with(prefix):
			return child as TileMapLayer

	return null


func _extract_level_number(node_name: String) -> int:
	var digits: String = ""
	for character: String in node_name:
		if character >= "0" and character <= "9":
			digits += character

	if digits.is_empty():
		return 0

	return int(digits)


func _refresh_visual_indicators() -> void:
	if can_upgrade():
		upgrade_available.emit(get_next_level())


func _handle_seed_plant_input(event: InputEvent) -> bool:
	if plant_action == &"" or not event.is_action_pressed(plant_action, false, true):
		return false
	if _player == null or _crop_registry == null or _inventory == null:
		print("Plant failed: missing player/crop registry/inventory binding")
		return false

	var selected_stack: ItemStack = _inventory.get_selected_hotbar_stack()
	if selected_stack == null:
		print("Plant failed: no selected hotbar stack")
		return false
	print(
		"Plant input received | selected_item_id=%s | quantity=%d | source_type=%s"
		% [
			String(selected_stack.item_id),
			selected_stack.quantity,
			selected_stack.source_data.get_class() if selected_stack.source_data != null else "null",
		]
	)

	var item_data: ItemData = selected_stack.source_data as ItemData
	if item_data == null:
		print("Plant skipped: selected stack is not item data | item_id=%s" % String(selected_stack.item_id))
		return false
	if item_data.item_kind != ItemData.ItemKind.SEED:
		print("Plant skipped: selected item is not a seed | item_id=%s" % String(item_data.id))
		return false

	get_viewport().set_input_as_handled()
	var crop_id: StringName = StringName(item_data.metadata.get("crop_id", &""))
	if crop_id == &"":
		print("Plant failed: selected seed has no crop_id metadata | item_id=%s" % String(item_data.id))
		return true

	var target_cell: Vector2i = _player.get_target_tile()
	var tile_state: FarmTileState = _farm_grid.get_tile_state(target_cell) if _farm_grid != null else null
	print(
		"Plant target | crop_id=%s | cell=(%d, %d) | has_tile=%s | tillable=%s | tilled=%s | watered=%s | blocked=%s | has_crop=%s"
		% [
			String(crop_id),
			target_cell.x,
			target_cell.y,
			str(_farm_grid != null and _farm_grid.has_tile(target_cell)),
			str(tile_state != null and tile_state.tillable),
			str(tile_state != null and tile_state.tilled),
			str(tile_state != null and tile_state.watered),
			str(tile_state != null and tile_state.blocked),
			str(tile_state != null and tile_state.has_crop()),
		]
	)
	var plant_result: Dictionary = _crop_registry.plant_crop(crop_id, target_cell)
	if bool(plant_result.get("success", false)):
		print("Plant success | crop_id=%s | cell=(%d, %d)" % [String(crop_id), target_cell.x, target_cell.y])
		_consume_selected_seed(item_data)
	else:
		print(
			"Plant failed | crop_id=%s | cell=(%d, %d) | error=%s | message=%s"
			% [
				String(crop_id),
				target_cell.x,
				target_cell.y,
				String(plant_result.get("error_code", "")),
				String(plant_result.get("error_message", "")),
			]
		)
	return true


func _consume_selected_seed(item_data: ItemData) -> void:
	if _inventory == null or item_data == null:
		return

	var selected_index: int = _inventory.selected_hotbar_index
	var selected_stack: ItemStack = _inventory.get_selected_hotbar_stack()
	if selected_stack == null:
		return

	if selected_stack.quantity <= 1:
		_inventory.clear_slot(Inventory.SECTION_HOTBAR, selected_index)
		return

	var next_stack: ItemStack = selected_stack.duplicate_stack()
	next_stack.quantity -= 1
	_inventory.set_stack(Inventory.SECTION_HOTBAR, selected_index, next_stack)


func _resolve_crop_registry() -> CropRegistry:
	if not crop_registry_path.is_empty():
		return get_node_or_null(crop_registry_path) as CropRegistry

	return _find_first_crop_registry(get_tree().current_scene)


func _resolve_inventory() -> Inventory:
	if not inventory_path.is_empty():
		return get_node_or_null(inventory_path) as Inventory

	return _find_first_inventory(get_tree().current_scene)


func _configure_test_inventory() -> void:
	if _inventory == null:
		return

	for index: int in range(_inventory.hotbar_slots.size()):
		_inventory.clear_slot(Inventory.SECTION_HOTBAR, index)
	for index: int in range(_inventory.backpack_slots.size()):
		_inventory.clear_slot(Inventory.SECTION_BACKPACK, index)

	var shovel_data: ToolData = load(SHOVEL_RESOURCE_PATH) as ToolData
	var watering_can_data: ToolData = load(WATERING_CAN_RESOURCE_PATH) as ToolData
	var bare_hands_data: ToolData = load(BARE_HANDS_RESOURCE_PATH) as ToolData
	var tomato_seed_data: ItemData = load(TOMATO_SEED_RESOURCE_PATH) as ItemData
	var tomato_item_data: ItemData = load(TOMATO_ITEM_RESOURCE_PATH) as ItemData

	if shovel_data != null:
		_inventory.set_stack(Inventory.SECTION_HOTBAR, 0, ItemStack.from_tool_data(shovel_data))
	if watering_can_data != null:
		_inventory.set_stack(Inventory.SECTION_HOTBAR, 1, ItemStack.from_tool_data(watering_can_data))
	if bare_hands_data != null:
		_inventory.set_stack(Inventory.SECTION_HOTBAR, 2, ItemStack.from_tool_data(bare_hands_data))
	if tomato_seed_data != null:
		_inventory.set_stack(Inventory.SECTION_HOTBAR, 3, ItemStack.from_item_data(tomato_seed_data, 20))
	if tomato_item_data != null:
		_inventory.set_stack(Inventory.SECTION_BACKPACK, 0, ItemStack.from_item_data(tomato_item_data, 3))

	_inventory.set_selected_hotbar_index(3)


func _find_first_crop_registry(root: Node) -> CropRegistry:
	if root == null:
		return null
	if root is CropRegistry:
		return root as CropRegistry
	for child: Node in root.get_children():
		var resolved: CropRegistry = _find_first_crop_registry(child)
		if resolved != null:
			return resolved
	return null


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


func _connect_grid_signals() -> void:
	if _farm_grid == null:
		return
	if not _farm_grid.tile_state_changed.is_connected(_on_farm_tile_state_changed):
		_farm_grid.tile_state_changed.connect(_on_farm_tile_state_changed)


func _on_farm_tile_state_changed(cell: Vector2i, tile_state: FarmTileState) -> void:
	_sync_watered_overlay_cell(cell, tile_state)


func _refresh_watered_overlay() -> void:
	if _watered_overlay_layer == null:
		return

	_watered_overlay_layer.clear()
	if _farm_grid == null:
		return

	for cell: Vector2i in _farm_grid.get_all_cells():
		var tile_state: FarmTileState = _farm_grid.get_tile_state(cell)
		_sync_watered_overlay_cell(cell, tile_state)


func _sync_watered_overlay_cell(cell: Vector2i, tile_state: FarmTileState) -> void:
	if _watered_overlay_layer == null or _active_shoveled_layer == null:
		return

	if tile_state == null or not tile_state.tilled or not tile_state.watered:
		_watered_overlay_layer.erase_cell(cell)
		return

	var source_id: int = _active_shoveled_layer.get_cell_source_id(cell)
	if source_id < 0:
		_watered_overlay_layer.erase_cell(cell)
		return

	_watered_overlay_layer.set_cell(
		cell,
		source_id,
		_active_shoveled_layer.get_cell_atlas_coords(cell),
		_active_shoveled_layer.get_cell_alternative_tile(cell)
	)


func _start_fade_to_alpha(target_alpha: float) -> Tween:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
		_fade_tween = null

	if _fade_rect == null:
		return null

	_fade_rect.visible = true
	var current_color: Color = _fade_rect.color
	var target_color: Color = Color(current_color.r, current_color.g, current_color.b, target_alpha)
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_rect, "color", target_color, fade_duration)

	if not _fade_tween.finished.is_connected(_on_fade_tween_finished):
		_fade_tween.finished.connect(_on_fade_tween_finished.bind(target_alpha))

	return _fade_tween


func _on_fade_tween_finished(target_alpha: float) -> void:
	if is_zero_approx(target_alpha):
		_fade_rect.visible = false
	fade_completed.emit(not is_zero_approx(target_alpha))
