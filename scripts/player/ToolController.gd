extends Node
class_name ToolController

signal selected_tool_changed(tool_id: StringName)
signal selected_tool_data_changed(tool_data: ToolData)
signal tool_use_requested(tool_data: ToolData, target_cell: Vector2i, target_world_position: Vector2)
signal tool_used(tool_data: ToolData, target_cell: Vector2i, success: bool)

const DEFAULT_TOOL_RESOURCE_PATHS: Array[String] = [
	"res://resources/tools/axe.tres",
	"res://resources/tools/fishing_rod.tres",
	"res://resources/tools/shovel.tres",
	"res://resources/tools/watering_can.tres",
	"res://resources/tools/bare_hands.tres",
]

@export var tool_definitions: Array[ToolData] = []
@export_node_path("FarmGrid") var farm_grid_path: NodePath
@export_node_path("CropRegistry") var crop_registry_path: NodePath
@export var starting_tool_id: StringName = &""
@export var use_legacy_slot_input: bool = false

var player: PlayerController
var farm_grid: FarmGrid
var crop_registry: CropRegistry
var selected_tool_id: StringName = &""
var _tools_by_id: Dictionary = {}
var _tool_ids_by_slot: Dictionary = {}

func _ready() -> void:
	player = get_parent() as PlayerController
	_load_default_tool_definitions_if_needed()
	_rebuild_registry()
	_resolve_farm_grid()
	_resolve_crop_registry()
	_select_starting_tool()

func use_current_tool() -> bool:
	var tool_data: ToolData = get_selected_tool_data()
	if player == null or tool_data == null:
		return false

	var target_cell: Vector2i = player.get_target_tile_at_distance(tool_data.interaction_distance)
	var target_world_position: Vector2 = player.get_target_world_position_at_distance(tool_data.interaction_distance)
	tool_use_requested.emit(tool_data, target_cell, target_world_position)

	var success: bool = _apply_default_tool_action(tool_data, target_cell)
	tool_used.emit(tool_data, target_cell, success)
	return success

func handle_input(event: InputEvent) -> void:
	if not use_legacy_slot_input:
		return
	if player != null and player.is_tool_use_locked():
		return

	if event.is_action_pressed(&"tool_slot_1", false, true):
		select_tool_by_slot(0)
	elif event.is_action_pressed(&"tool_slot_2", false, true):
		select_tool_by_slot(1)
	elif event.is_action_pressed(&"tool_slot_3", false, true):
		select_tool_by_slot(2)
	elif event.is_action_pressed(&"tool_slot_4", false, true):
		select_tool_by_slot(3)

func select_tool_by_slot(slot_index: int) -> void:
	if slot_index < 0:
		return

	var tool_id_variant: Variant = _tool_ids_by_slot.get(slot_index, &"")
	var tool_id: StringName = StringName(String(tool_id_variant))
	if tool_id == &"":
		return

	select_tool_by_id(tool_id)

func select_tool_by_id(tool_id: StringName) -> void:
	if player != null and player.is_tool_use_locked() and selected_tool_id != tool_id:
		return

	var tool_data: ToolData = get_tool_data(tool_id)
	if tool_data == null:
		return

	selected_tool_id = tool_id
	_apply_selected_tool_visual(tool_data)
	selected_tool_changed.emit(selected_tool_id)
	selected_tool_data_changed.emit(tool_data)

func get_selected_tool_id() -> StringName:
	return selected_tool_id

func get_selected_tool_data() -> ToolData:
	return get_tool_data(selected_tool_id)

func get_tool_data(tool_id: StringName) -> ToolData:
	var tool_data_variant: Variant = _tools_by_id.get(tool_id)
	return tool_data_variant as ToolData

func get_ordered_tools() -> Array[ToolData]:
	var ordered_tools: Array[ToolData] = []
	for tool_data: ToolData in tool_definitions:
		if tool_data != null:
			ordered_tools.append(tool_data)
	return ordered_tools

func has_tool(tool_id: StringName) -> bool:
	return get_tool_data(tool_id) != null

func get_target_cell() -> Vector2i:
	if player == null:
		return Vector2i.ZERO
	var tool_data: ToolData = get_selected_tool_data()
	if tool_data == null:
		return player.get_target_tile()
	return player.get_target_tile_at_distance(tool_data.interaction_distance)

func get_target_world_position() -> Vector2:
	var tool_data: ToolData = get_selected_tool_data()
	if player == null or tool_data == null:
		return Vector2.ZERO
	return player.get_target_world_position_at_distance(tool_data.interaction_distance)

func _load_default_tool_definitions_if_needed() -> void:
	if not tool_definitions.is_empty():
		return

	for resource_path: String in DEFAULT_TOOL_RESOURCE_PATHS:
		var resource: Resource = load(resource_path)
		var tool_data: ToolData = resource as ToolData
		if tool_data != null:
			tool_definitions.append(tool_data)

func _rebuild_registry() -> void:
	_tools_by_id.clear()
	_tool_ids_by_slot.clear()

	for tool_data: ToolData in tool_definitions:
		if tool_data == null or tool_data.id == &"":
			continue

		_tools_by_id[tool_data.id] = tool_data
		if tool_data.has_slot():
			_tool_ids_by_slot[tool_data.slot_index] = tool_data.id

func _select_starting_tool() -> void:
	if starting_tool_id != &"" and has_tool(starting_tool_id):
		select_tool_by_id(starting_tool_id)
		return

	clear_selected_tool()

func clear_selected_tool() -> void:
	selected_tool_id = &""
	if player != null:
		player.set_selected_tool_data(null)
	selected_tool_changed.emit(selected_tool_id)

func _apply_selected_tool_visual(tool_data: ToolData) -> void:
	if player == null:
		return

	player.set_selected_tool_data(tool_data)

func _apply_default_tool_action(tool_data: ToolData, target_cell: Vector2i) -> bool:
	match tool_data.primary_action:
		ToolData.ToolAction.TILL_SOIL:
			if crop_registry != null and crop_registry.has_crop_at(target_cell):
				crop_registry.destroy_crop(target_cell)
				return true
			if farm_grid != null:
				return farm_grid.till_cell(target_cell)
			return false

		ToolData.ToolAction.WATER_SOIL:
			var any_success: bool = false
			if crop_registry != null:
				var crop_result: Dictionary = crop_registry.water_crop(target_cell)
				any_success = crop_result.get("success", false) or any_success
			if farm_grid != null:
				any_success = farm_grid.water_cell(target_cell) or any_success
			return any_success

		ToolData.ToolAction.HARVEST:
			if crop_registry == null:
				return false
			var harvest_result: Dictionary = crop_registry.harvest_crop(target_cell)
			return harvest_result.get("success", false)

		ToolData.ToolAction.DESTROY_CROP:
			if crop_registry == null:
				return false
			var destroy_result: Dictionary = crop_registry.destroy_crop(target_cell)
			return destroy_result.get("success", false)

		_:
			return false

func _resolve_crop_registry() -> void:
	if not crop_registry_path.is_empty():
		crop_registry = get_node_or_null(crop_registry_path) as CropRegistry
		if crop_registry != null:
			return

	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	crop_registry = _find_crop_registry(current_scene)

func _find_crop_registry(root: Node) -> CropRegistry:
	if root is CropRegistry:
		return root as CropRegistry

	for child: Node in root.get_children():
		var resolved: CropRegistry = _find_crop_registry(child)
		if resolved != null:
			return resolved

	return null

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
