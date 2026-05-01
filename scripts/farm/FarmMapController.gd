extends Node
class_name FarmMapController

@export var farm_grid_path: NodePath
@export var coordinate_layer_path: NodePath
@export var tillable_source_layer_path: NodePath
@export var soil_visual_layer_path: NodePath
@export_node_path("PlayerController") var player_path: NodePath
@export_node_path("Marker2D") var player_spawn_path: NodePath
@export var tillable_areas: Array[Rect2i] = []
@export var bootstrap_tillable_from_source_layer: bool = true
@export var manage_soil_visuals: bool = false
@export var snap_player_to_spawn_on_ready: bool = true
@export var dry_soil_source_id: int = -1
@export var dry_soil_atlas_coords: Vector2i = Vector2i(-1, -1)
@export var dry_soil_alternative_tile: int = 0
@export var watered_soil_source_id: int = -1
@export var watered_soil_atlas_coords: Vector2i = Vector2i(-1, -1)
@export var watered_soil_alternative_tile: int = 0

var _farm_grid: FarmGrid
var _coordinate_layer: TileMapLayer
var _tillable_source_layer: TileMapLayer
var _soil_visual_layer: TileMapLayer
var _player: PlayerController
var _player_spawn: Marker2D
var _managed_visual_cells: Dictionary = {}


func _ready() -> void:
	_farm_grid = get_node_or_null(farm_grid_path) as FarmGrid
	if _farm_grid == null:
		return

	_coordinate_layer = get_node_or_null(coordinate_layer_path) as TileMapLayer
	_tillable_source_layer = get_node_or_null(tillable_source_layer_path) as TileMapLayer
	_soil_visual_layer = get_node_or_null(soil_visual_layer_path) as TileMapLayer
	_player = get_node_or_null(player_path) as PlayerController
	_player_spawn = get_node_or_null(player_spawn_path) as Marker2D

	if _coordinate_layer != null:
		_farm_grid.set_coordinate_layer(_coordinate_layer)

	if bootstrap_tillable_from_source_layer and _tillable_source_layer != null:
		_farm_grid.register_tillable_cells(_tillable_source_layer.get_used_cells(), FarmTileState.SURFACE_SOIL)

	for area: Rect2i in tillable_areas:
		_farm_grid.register_tillable_rect(area, FarmTileState.SURFACE_SOIL)

	if not _farm_grid.tile_registered.is_connected(_on_tile_updated):
		_farm_grid.tile_registered.connect(_on_tile_updated)

	if not _farm_grid.tile_state_changed.is_connected(_on_tile_updated):
		_farm_grid.tile_state_changed.connect(_on_tile_updated)

	if snap_player_to_spawn_on_ready and _player != null and _player_spawn != null:
		_player.global_position = _player_spawn.global_position

	if manage_soil_visuals:
		refresh_all_visuals()


func get_player() -> PlayerController:
	return _player


func refresh_all_visuals() -> void:
	if _soil_visual_layer == null:
		return

	for key: Variant in _managed_visual_cells.keys():
		var cell: Vector2i = key
		_soil_visual_layer.erase_cell(cell)

	_managed_visual_cells.clear()

	for cell: Vector2i in _farm_grid.get_all_cells():
		var state: FarmTileState = _farm_grid.get_tile_state(cell)
		_sync_visual_cell(cell, state)


func _on_tile_updated(cell: Vector2i, tile_state: FarmTileState) -> void:
	_sync_visual_cell(cell, tile_state)


func _sync_visual_cell(cell: Vector2i, tile_state: FarmTileState) -> void:
	if not manage_soil_visuals or _soil_visual_layer == null:
		return

	if tile_state == null or not tile_state.tillable or not tile_state.tilled:
		if _managed_visual_cells.has(cell):
			_soil_visual_layer.erase_cell(cell)
			_managed_visual_cells.erase(cell)
		return

	var source_id: int = dry_soil_source_id
	var atlas_coords: Vector2i = dry_soil_atlas_coords
	var alternative_tile: int = dry_soil_alternative_tile

	if tile_state.watered and _is_visual_tile_valid(watered_soil_source_id, watered_soil_atlas_coords):
		source_id = watered_soil_source_id
		atlas_coords = watered_soil_atlas_coords
		alternative_tile = watered_soil_alternative_tile

	if not _is_visual_tile_valid(source_id, atlas_coords):
		if _managed_visual_cells.has(cell):
			_soil_visual_layer.erase_cell(cell)
			_managed_visual_cells.erase(cell)
		return

	_soil_visual_layer.set_cell(cell, source_id, atlas_coords, alternative_tile)
	_managed_visual_cells[cell] = true


func _is_visual_tile_valid(source_id: int, atlas_coords: Vector2i) -> bool:
	return source_id >= 0 and atlas_coords != Vector2i(-1, -1)
