extends Node
class_name CropRegistry

signal crop_planted(cell: Vector2i, crop_id: StringName, planted_timestamp: int)
signal crop_removed(cell: Vector2i, crop_id: StringName)
signal tool_action_completed(action: StringName, cell: Vector2i, result: Dictionary)

const TOOL_HAND: StringName = &""
const TOOL_WATERING_CAN: StringName = &"watering_can"
const TOOL_SHOVEL: StringName = &"shovel"
const GAME_TIME_NODE_PATH: NodePath = ^"/root/GameTime"

@export var auto_load_crops: bool = true
@export var crop_resource_paths: Array[String] = [
	"res://resources/crops/tomato_crop.tres",
]
@export_node_path("FarmGrid") var farm_grid_path: NodePath

var farm_grid: FarmGrid

var _crop_data_by_id: Dictionary = {}
var _crop_instance_by_cell: Dictionary = {}
var _crop_scene: PackedScene = preload("res://scenes/crops/Crop.tscn")
var _game_time: Node
var _crop_visual_root: Node2D


func _ready() -> void:
	_resolve_farm_grid()
	_resolve_crop_visual_root()
	if auto_load_crops:
		_load_configured_crop_resources()
	_connect_day_start_signal()


func _exit_tree() -> void:
	_disconnect_day_start_signal()


func load_crop_resource(resource_path: String) -> CropData:
	var resource: Resource = load(resource_path)
	var crop_data: CropData = resource as CropData
	if crop_data == null:
		push_error("CropRegistry: Failed to load CropData from path: %s" % resource_path)
		return null

	register_crop_data(crop_data)
	return crop_data


func register_crop_data(crop_data: CropData) -> void:
	if crop_data.id == &"":
		push_error("CropRegistry: Cannot register CropData with empty id")
		return

	_crop_data_by_id[crop_data.id] = crop_data


func get_crop_data(crop_id: StringName) -> CropData:
	var result: Variant = _crop_data_by_id.get(crop_id)
	return result as CropData


func get_all_crop_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key: Variant in _crop_data_by_id.keys():
		var id: StringName = StringName(String(key))
		ids.append(id)
	return ids


func get_crop_instance(cell: Vector2i) -> CropInstance:
	var result: Variant = _crop_instance_by_cell.get(cell)
	return result as CropInstance


func has_crop_at(cell: Vector2i) -> bool:
	return _crop_instance_by_cell.has(cell)


func get_all_crop_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for key: Variant in _crop_instance_by_cell.keys():
		var cell: Vector2i = Vector2i(key)
		cells.append(cell)
	return cells


func plant_crop(crop_data_id: StringName, cell: Vector2i, planted_timestamp: int = 0) -> Dictionary:
	print("CropRegistry.plant_crop called | crop_id=%s | cell=(%d, %d)" % [String(crop_data_id), cell.x, cell.y])
	var crop_data: CropData = get_crop_data(crop_data_id)
	if crop_data == null:
		print("CropRegistry.plant_crop failed: unknown crop")
		return _error_result("unknown_crop", "未知作物类型: %s" % String(crop_data_id))

	if farm_grid == null:
		print("CropRegistry.plant_crop failed: farm_grid is null")
		return _error_result("no_farm_grid", "未绑定FarmGrid")

	if not farm_grid.can_plant_crop(cell):
		var tile_state: FarmTileState = farm_grid.get_tile_state(cell)
		print(
			"CropRegistry.plant_crop blocked | has_tile=%s | tillable=%s | tilled=%s | blocked=%s | has_crop=%s"
			% [
				str(farm_grid.has_tile(cell)),
				str(tile_state != null and tile_state.tillable),
				str(tile_state != null and tile_state.tilled),
				str(tile_state != null and tile_state.blocked),
				str(tile_state != null and tile_state.has_crop()),
			]
		)
		return _error_result("cell_not_plantable", "该格子无法播种")

	if has_crop_at(cell):
		print("CropRegistry.plant_crop failed: crop instance already exists at cell")
		return _error_result("cell_occupied", "该格子已有作物")

	var instance: CropInstance = _crop_scene.instantiate() as CropInstance
	if instance == null:
		print("CropRegistry.plant_crop failed: instantiate crop scene returned null")
		return _error_result("instantiate_failed", "作物场景实例化失败")

	instance.initialize(crop_data, cell, planted_timestamp)
	var planted_tile_state: FarmTileState = farm_grid.get_tile_state(cell)
	if planted_tile_state != null and planted_tile_state.watered:
		instance.sync_watered_state(true)

	instance.crop_harvested.connect(_on_crop_harvested)
	instance.crop_destroyed.connect(_on_crop_destroyed)
	instance.growth_advanced.connect(_on_crop_growth_advanced)

	_add_crop_instance_to_world(instance, cell)
	var parent_path: String = String(instance.get_parent().get_path()) if instance.get_parent() != null else "<no_parent>"
	print(
		"CropRegistry.visual attach | crop_id=%s | cell=(%d, %d) | parent=%s | global_pos=(%.1f, %.1f) | z_index=%d"
		% [
			String(crop_data_id),
			cell.x,
			cell.y,
			parent_path,
			instance.global_position.x,
			instance.global_position.y,
			instance.z_index,
		]
	)

	_crop_instance_by_cell[cell] = instance

	farm_grid.plant_crop(cell, crop_data_id, 0, crop_data.growth_frame_count - 1)

	var timestamp: int = planted_timestamp
	if timestamp == 0:
		timestamp = int(Time.get_unix_time_from_system())

	crop_planted.emit(cell, crop_data_id, timestamp)
	print("CropRegistry.plant_crop success | crop_id=%s | cell=(%d, %d) | timestamp=%d" % [String(crop_data_id), cell.x, cell.y, timestamp])

	return {
		"success": true,
		"action": "plant",
		"crop_id": String(crop_data_id),
		"cell_x": cell.x,
		"cell_y": cell.y,
		"planted_timestamp": timestamp,
	}


func handle_tool_action(tool_id: StringName, cell: Vector2i) -> Dictionary:
	var action: StringName = _resolve_tool_action(tool_id)
	var instance: CropInstance = get_crop_instance(cell)

	if action == &"":
		return _error_result("unknown_tool", "未识别的工具: %s" % String(tool_id))

	var result: Dictionary
	if instance == null:
		match action:
			CropInstance.ACTION_DESTROY:
				result = {
					"success": true,
					"action": String(action),
					"cell_x": cell.x,
					"cell_y": cell.y,
					"note": "cell_has_no_crop",
				}
				tool_action_completed.emit(action, cell, result)
				return result
			_:
				return _error_result("no_crop_at_cell", "该格子没有作物")

	match action:
		CropInstance.ACTION_HARVEST:
			result = instance.harvest()
		CropInstance.ACTION_WATER:
			var water_ok: bool = instance.water()
			result = {
				"success": water_ok,
				"action": String(action),
				"crop_id": String(instance.crop_data.id if instance.crop_data else &""),
				"cell_x": cell.x,
				"cell_y": cell.y,
			}
		CropInstance.ACTION_DESTROY:
			result = instance.destroy()
		_:
			result = _error_result("unsupported_action", "不支持的操作: %s" % String(action))

	tool_action_completed.emit(action, cell, result)
	return result


func water_crop(cell: Vector2i) -> Dictionary:
	return handle_tool_action(TOOL_WATERING_CAN, cell)


func harvest_crop(cell: Vector2i) -> Dictionary:
	return handle_tool_action(TOOL_HAND, cell)


func destroy_crop(cell: Vector2i) -> Dictionary:
	return handle_tool_action(TOOL_SHOVEL, cell)


func advance_all_crops_day() -> void:
	for cell: Vector2i in get_all_crop_cells():
		var instance: CropInstance = get_crop_instance(cell)
		if instance == null:
			continue

		if farm_grid != null:
			var tile_state: FarmTileState = farm_grid.get_tile_state(cell)
			if tile_state != null:
				instance.sync_watered_state(tile_state.watered)

		instance.advance_day()


func clear_watered_state_all() -> void:
	pass


func export_state() -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for cell: Vector2i in get_all_crop_cells():
		var instance: CropInstance = get_crop_instance(cell)
		if instance == null:
			continue

		states.append(instance.get_save_state())

	return states


func import_state(entries: Array[Dictionary]) -> void:
	_clear_all_instances()

	for entry: Dictionary in entries:
		var crop_id: StringName = StringName(String(entry.get("crop_id", "")))
		var crop_data: CropData = get_crop_data(crop_id)
		if crop_data == null:
			push_warning("CropRegistry: Unknown crop_id '%s' in save state, skipping" % String(crop_id))
			continue

		var cell_x: int = int(entry.get("cell_x", 0))
		var cell_y: int = int(entry.get("cell_y", 0))
		var cell: Vector2i = Vector2i(cell_x, cell_y)

		var instance: CropInstance = _crop_scene.instantiate() as CropInstance
		if instance == null:
			continue

		instance.initialize(crop_data, cell, int(entry.get("planted_timestamp", 0)))
		instance.load_save_state(entry)

		instance.crop_harvested.connect(_on_crop_harvested)
		instance.crop_destroyed.connect(_on_crop_destroyed)
		instance.growth_advanced.connect(_on_crop_growth_advanced)

		_add_crop_instance_to_world(instance, cell)

		_crop_instance_by_cell[cell] = instance


func _resolve_tool_action(tool_id: StringName) -> StringName:
	if tool_id == &"":
		return CropInstance.ACTION_HARVEST

	match tool_id:
		TOOL_WATERING_CAN:
			return CropInstance.ACTION_WATER
		TOOL_SHOVEL:
			return CropInstance.ACTION_DESTROY
		_:
			return &""


func _load_configured_crop_resources() -> void:
	for resource_path: String in crop_resource_paths:
		load_crop_resource(resource_path)


func _add_crop_instance_to_world(instance: CropInstance, cell: Vector2i) -> void:
	if instance == null:
		return

	if _crop_visual_root == null:
		_resolve_crop_visual_root()

	var parent_node: Node = self
	if _crop_visual_root != null:
		parent_node = _crop_visual_root
	parent_node.add_child(instance)
	instance.top_level = true

	if farm_grid != null:
		instance.global_position = farm_grid.cell_to_world(cell)


func _connect_day_start_signal() -> void:
	var game_time: Node = get_node_or_null(GAME_TIME_NODE_PATH)
	if game_time == null or not game_time.has_signal("day_started"):
		return

	var on_day_started_callable: Callable = Callable(self, "_on_day_started")
	if not game_time.is_connected("day_started", on_day_started_callable):
		game_time.connect("day_started", on_day_started_callable)

	_game_time = game_time


func _disconnect_day_start_signal() -> void:
	if _game_time == null:
		return

	var on_day_started_callable: Callable = Callable(self, "_on_day_started")
	if _game_time.is_connected("day_started", on_day_started_callable):
		_game_time.disconnect("day_started", on_day_started_callable)

	_game_time = null


func _resolve_crop_visual_root() -> void:
	if _crop_visual_root != null and is_instance_valid(_crop_visual_root):
		return

	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var prop_root: Node = current_scene.get_node_or_null("Prop")
	if prop_root is Node2D:
		_crop_visual_root = prop_root as Node2D
		return

	if current_scene is Node2D:
		_crop_visual_root = current_scene as Node2D


func _resolve_farm_grid() -> void:
	if not farm_grid_path.is_empty():
		farm_grid = get_node_or_null(farm_grid_path) as FarmGrid
		if farm_grid != null:
			return

	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	farm_grid = _find_farm_grid(current_scene)


func _find_farm_grid(root: Node) -> FarmGrid:
	if root is FarmGrid:
		return root as FarmGrid

	for child: Node in root.get_children():
		var resolved: FarmGrid = _find_farm_grid(child)
		if resolved != null:
			return resolved

	return null


func _clear_all_instances() -> void:
	for cell: Vector2i in get_all_crop_cells():
		var instance: CropInstance = get_crop_instance(cell)
		if instance == null:
			continue

		instance.crop_harvested.disconnect(_on_crop_harvested)
		instance.crop_destroyed.disconnect(_on_crop_destroyed)
		instance.growth_advanced.disconnect(_on_crop_growth_advanced)
		instance.queue_free()

	_crop_instance_by_cell.clear()


func _remove_instance(cell: Vector2i) -> void:
	var instance: CropInstance = get_crop_instance(cell)
	if instance == null:
		return

	instance.crop_harvested.disconnect(_on_crop_harvested)
	instance.crop_destroyed.disconnect(_on_crop_destroyed)
	instance.growth_advanced.disconnect(_on_crop_growth_advanced)
	instance.queue_free()
	_crop_instance_by_cell.erase(cell)


func _on_crop_harvested(crop_id: StringName, cell: Vector2i, _crop_item_id: StringName, _yield_count: int) -> void:
	var instance: CropInstance = get_crop_instance(cell)
	if instance == null:
		return

	if instance.is_dead:
		crop_removed.emit(cell, crop_id)
		if farm_grid != null:
			farm_grid.clear_crop(cell)
		_remove_instance(cell)
	else:
		if farm_grid != null:
			farm_grid.set_crop_stage(cell, instance.current_frame)


func _on_crop_destroyed(crop_id: StringName, cell: Vector2i) -> void:
	crop_removed.emit(cell, crop_id)
	if farm_grid != null:
		farm_grid.clear_crop(cell)
	_remove_instance(cell)


func _on_crop_growth_advanced(_crop_id: StringName, cell: Vector2i, current_frame: int, _total_frames: int) -> void:
	if farm_grid != null:
		farm_grid.set_crop_stage(cell, current_frame)


func _error_result(error_code: StringName, message: String) -> Dictionary:
	return {
		"success": false,
		"error_code": String(error_code),
		"error_message": message,
	}


func _on_day_started(_day: int) -> void:
	if farm_grid == null:
		_resolve_farm_grid()

	advance_all_crops_day()
	if farm_grid != null:
		farm_grid.clear_watered_tiles()
