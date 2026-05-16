extends Node
class_name FarmTestSoilUpgradeController

const INPUT_LOCK_REASON: StringName = &"farm_test_soil_upgrade"

@export_node_path("PlayerController") var player_path: NodePath
@export_node_path("FarmGrid") var farm_grid_path: NodePath
@export_node_path("TileMapLayer") var active_shoveled_layer_path: NodePath
@export_node_path("TileMapLayer") var active_fence_layer_path: NodePath
@export_node_path("Node") var template_levels_root_path: NodePath
@export_node_path("Node") var upgrade_markers_root_path: NodePath
@export_node_path("ColorRect") var fade_rect_path: NodePath
@export var interact_action: StringName = &"交互"
@export var interaction_radius: float = 48.0
@export_range(1, 99, 1) var starting_level: int = 1
@export var fade_duration: float = 0.18
@export var hold_duration: float = 0.06

var _player: PlayerController
var _farm_grid: FarmGrid
var _active_shoveled_layer: TileMapLayer
var _active_fence_layer: TileMapLayer
var _fade_rect: ColorRect
var _templates_by_level: Dictionary = {}
var _level_numbers: Array[int] = []
var _upgrade_markers: Array[Marker2D] = []
var _current_level: int = 0
var _upgrade_in_progress: bool = false


func _ready() -> void:
	_player = get_node_or_null(player_path) as PlayerController
	_farm_grid = get_node_or_null(farm_grid_path) as FarmGrid
	_active_shoveled_layer = get_node_or_null(active_shoveled_layer_path) as TileMapLayer
	_active_fence_layer = get_node_or_null(active_fence_layer_path) as TileMapLayer
	_fade_rect = get_node_or_null(fade_rect_path) as ColorRect

	_collect_level_templates()
	_collect_upgrade_markers()
	_prepare_fade_rect()
	_initialize_active_level()


func _unhandled_input(event: InputEvent) -> void:
	if _upgrade_in_progress or SceneTransition.is_input_locked():
		return
	if interact_action == &"" or not event.is_action_pressed(interact_action, false, true):
		return
	if not _is_player_near_upgrade_marker():
		return

	var next_level: int = _get_next_level()
	if next_level <= 0:
		return

	get_viewport().set_input_as_handled()
	_run_upgrade_sequence(next_level)


func _run_upgrade_sequence(next_level: int) -> void:
	if _upgrade_in_progress:
		return

	_upgrade_in_progress = true
	SceneTransition.acquire_input_lock(INPUT_LOCK_REASON)
	if _player != null:
		_player.clear_input_state()

	await _fade_to_alpha(1.0)
	_apply_level(next_level)
	if hold_duration > 0.0:
		await get_tree().create_timer(hold_duration).timeout
	await _fade_to_alpha(0.0)

	if _player != null:
		_player.clear_input_state()
	SceneTransition.release_input_lock(INPUT_LOCK_REASON)
	_upgrade_in_progress = false


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
	var template_variant: Variant = _templates_by_level.get(level_number)
	if not (template_variant is Dictionary):
		return

	var template: Dictionary = template_variant
	var shoveled_layer: TileMapLayer = template.get("shoveled") as TileMapLayer
	var fence_layer: TileMapLayer = template.get("fence") as TileMapLayer
	if shoveled_layer == null or _active_shoveled_layer == null:
		return

	_copy_layer_tiles(shoveled_layer, _active_shoveled_layer)
	if _active_fence_layer != null:
		if fence_layer != null:
			_copy_layer_tiles(fence_layer, _active_fence_layer)
		else:
			_active_fence_layer.clear()

	_current_level = level_number
	_sync_farm_grid_from_active_layer()


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


func _get_next_level() -> int:
	if _level_numbers.is_empty():
		return 0

	for level_number: int in _level_numbers:
		if level_number > _current_level:
			return level_number

	return 0


func _infer_active_level() -> int:
	if _active_shoveled_layer == null:
		return 0

	var active_cells: Array[Vector2i] = _active_shoveled_layer.get_used_cells()
	if active_cells.is_empty():
		return 0

	for level_number: int in _level_numbers:
		var template_variant: Variant = _templates_by_level.get(level_number)
		if not (template_variant is Dictionary):
			continue

		var template: Dictionary = template_variant
		var shoveled_layer: TileMapLayer = template.get("shoveled") as TileMapLayer
		if shoveled_layer == null:
			continue
		if _cell_sets_match(active_cells, shoveled_layer.get_used_cells()):
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


func _fade_to_alpha(target_alpha: float) -> void:
	if _fade_rect == null:
		return

	_fade_rect.visible = true
	var current_color: Color = _fade_rect.color
	var target_color: Color = Color(current_color.r, current_color.g, current_color.b, target_alpha)
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "color", target_color, fade_duration)
	await tween.finished

	if is_zero_approx(target_alpha):
		_fade_rect.visible = false
