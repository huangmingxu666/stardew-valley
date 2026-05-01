extends Node
class_name FarmGrid

signal tile_registered(cell: Vector2i, tile_state: FarmTileState)
signal tile_state_changed(cell: Vector2i, tile_state: FarmTileState)
signal grid_initialized()
signal watered_tiles_cleared()

@export var cell_size: Vector2i = Vector2i(32, 32)
@export var origin: Vector2 = Vector2.ZERO
@export var coordinate_layer_path: NodePath
@export var initialize_on_ready: bool = true
@export var initial_tillable_areas: Array[Rect2i] = []
@export var default_surface_type: StringName = FarmTileState.SURFACE_GRASS

var _tile_states: Dictionary = {}
var _coordinate_layer: TileMapLayer


func _ready() -> void:
	_resolve_coordinate_layer()
	if not initialize_on_ready:
		return

	initialize_from_config()


func initialize_from_config() -> void:
	for area: Rect2i in initial_tillable_areas:
		register_tillable_rect(area)

	grid_initialized.emit()


func clear_all_tiles() -> void:
	_tile_states.clear()


func set_coordinate_layer(layer: TileMapLayer) -> void:
	_coordinate_layer = layer


func world_to_cell(world_position: Vector2) -> Vector2i:
	if _coordinate_layer != null:
		var local_position: Vector2 = _coordinate_layer.to_local(world_position)
		return _coordinate_layer.local_to_map(local_position)

	var local_position: Vector2 = world_position - origin
	return Vector2i(
		int(floor(local_position.x / float(cell_size.x))),
		int(floor(local_position.y / float(cell_size.y)))
	)


func cell_to_world(cell: Vector2i, centered: bool = true) -> Vector2:
	if _coordinate_layer != null:
		var local_position: Vector2 = _coordinate_layer.map_to_local(cell)
		var world_position: Vector2 = _coordinate_layer.to_global(local_position)
		if centered:
			return world_position
		return world_position - (Vector2(cell_size) * 0.5)

	var top_left: Vector2 = origin + Vector2(cell.x * cell_size.x, cell.y * cell_size.y)
	if centered:
		return top_left + (Vector2(cell_size) * 0.5)
	return top_left


func register_tillable_rect(area: Rect2i, surface_type: StringName = &"") -> void:
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			register_tile(Vector2i(x, y), true, surface_type)


func register_tillable_cells(cells: Array[Vector2i], surface_type: StringName = &"") -> void:
	for cell: Vector2i in cells:
		register_tile(cell, true, surface_type)


func register_tile(
	cell: Vector2i,
	tillable: bool = false,
	surface_type: StringName = &"",
	blocked: bool = false
) -> FarmTileState:
	var state: FarmTileState = get_or_create_tile_state(cell)
	state.tillable = tillable
	state.surface_type = _resolve_surface_type(surface_type)
	state.blocked = blocked
	if blocked:
		state.reset_ground_state()

	tile_state_changed.emit(cell, state)
	return state


func has_tile(cell: Vector2i) -> bool:
	return _tile_states.has(cell)


func get_tile_state(cell: Vector2i) -> FarmTileState:
	return _tile_states.get(cell) as FarmTileState


func get_or_create_tile_state(cell: Vector2i) -> FarmTileState:
	var existing_state: FarmTileState = get_tile_state(cell)
	if existing_state != null:
		return existing_state

	var created_state: FarmTileState = FarmTileState.new()
	created_state.cell = cell
	created_state.surface_type = default_surface_type
	_tile_states[cell] = created_state
	tile_registered.emit(cell, created_state)
	return created_state


func get_all_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for key: Variant in _tile_states.keys():
		var cell: Vector2i = key
		cells.append(cell)
	return cells


func get_tillable_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in get_all_cells():
		var state: FarmTileState = get_tile_state(cell)
		if state != null and state.tillable:
			cells.append(cell)
	return cells


func is_cell_tillable(cell: Vector2i) -> bool:
	var state: FarmTileState = get_tile_state(cell)
	return state != null and state.tillable


func is_cell_blocked(cell: Vector2i) -> bool:
	var state: FarmTileState = get_tile_state(cell)
	return state != null and state.blocked


func can_till_cell(cell: Vector2i) -> bool:
	var state: FarmTileState = get_tile_state(cell)
	return state != null and state.can_till()


func till_cell(cell: Vector2i) -> bool:
	var state: FarmTileState = get_tile_state(cell)
	if state == null or not state.can_till():
		return false

	state.tilled = true
	state.watered = false
	tile_state_changed.emit(cell, state)
	return true


func clear_tilled_cell(cell: Vector2i) -> bool:
	var state: FarmTileState = get_tile_state(cell)
	if state == null:
		return false

	state.reset_ground_state()
	tile_state_changed.emit(cell, state)
	return true


func can_water_cell(cell: Vector2i) -> bool:
	var state: FarmTileState = get_tile_state(cell)
	return state != null and state.can_water()


func water_cell(cell: Vector2i) -> bool:
	var state: FarmTileState = get_tile_state(cell)
	if state == null or not state.can_water():
		return false

	state.watered = true
	tile_state_changed.emit(cell, state)
	return true


func clear_watered_tiles() -> void:
	var changed_cells: Array[Vector2i] = []
	for cell: Vector2i in get_all_cells():
		var state: FarmTileState = get_tile_state(cell)
		if state == null or not state.watered:
			continue

		state.watered = false
		changed_cells.append(cell)

	for cell: Vector2i in changed_cells:
		var state: FarmTileState = get_tile_state(cell)
		if state != null:
			tile_state_changed.emit(cell, state)

	if not changed_cells.is_empty():
		watered_tiles_cleared.emit()


func can_plant_crop(cell: Vector2i) -> bool:
	var state: FarmTileState = get_tile_state(cell)
	return state != null and state.can_plant()


func plant_crop(cell: Vector2i, crop_id: StringName, crop_stage: int = 0) -> bool:
	var state: FarmTileState = get_tile_state(cell)
	if state == null or not state.can_plant():
		return false

	state.set_crop(crop_id, crop_stage)
	tile_state_changed.emit(cell, state)
	return true


func set_crop_stage(cell: Vector2i, crop_stage: int) -> bool:
	var state: FarmTileState = get_tile_state(cell)
	if state == null or not state.has_crop():
		return false

	state.crop_stage = crop_stage
	tile_state_changed.emit(cell, state)
	return true


func clear_crop(cell: Vector2i) -> bool:
	var state: FarmTileState = get_tile_state(cell)
	if state == null or not state.has_crop():
		return false

	state.clear_crop()
	tile_state_changed.emit(cell, state)
	return true


func set_cell_blocked(cell: Vector2i, blocked: bool) -> void:
	var state: FarmTileState = get_or_create_tile_state(cell)
	state.blocked = blocked
	if blocked:
		state.reset_ground_state()
	tile_state_changed.emit(cell, state)


func set_cell_tillable(cell: Vector2i, tillable: bool) -> void:
	var state: FarmTileState = get_or_create_tile_state(cell)
	state.tillable = tillable
	if not tillable:
		state.reset_ground_state()
	tile_state_changed.emit(cell, state)


func set_surface_type(cell: Vector2i, surface_type: StringName) -> void:
	var state: FarmTileState = get_or_create_tile_state(cell)
	state.surface_type = _resolve_surface_type(surface_type)
	tile_state_changed.emit(cell, state)


func export_state() -> Array[Dictionary]:
	var exported_state: Array[Dictionary] = []
	for cell: Vector2i in get_all_cells():
		var state: FarmTileState = get_tile_state(cell)
		if state == null:
			continue

		exported_state.append(state.to_dictionary())

	return exported_state


func import_state(entries: Array[Dictionary], clear_existing: bool = true) -> void:
	if clear_existing:
		_tile_states.clear()

	for entry: Dictionary in entries:
		var state: FarmTileState = FarmTileState.from_dictionary(entry)
		_tile_states[state.cell] = state
		tile_registered.emit(state.cell, state)
		tile_state_changed.emit(state.cell, state)


func _resolve_coordinate_layer() -> void:
	if not coordinate_layer_path.is_empty():
		_coordinate_layer = get_node_or_null(coordinate_layer_path) as TileMapLayer


func _resolve_surface_type(surface_type: StringName) -> StringName:
	if surface_type == &"":
		return default_surface_type
	return surface_type
