@tool
extends Node2D

const SOURCE_ID: int = 0
const GRASS_VARIANTS: Array[Vector2i] = [
	Vector2i(3, 2),
	Vector2i(5, 0),
	Vector2i(6, 0),
	Vector2i(4, 3),
]
const SOIL_PATCH: Array[Array] = [
	[Vector2i(-1, -1), Vector2i(20, 16)],
	[Vector2i(0, -1), Vector2i(21, 16)],
	[Vector2i(1, -1), Vector2i(22, 16)],
	[Vector2i(-1, 0), Vector2i(20, 17)],
	[Vector2i(0, 0), Vector2i(21, 17)],
	[Vector2i(1, 0), Vector2i(22, 17)],
	[Vector2i(-1, 1), Vector2i(20, 18)],
	[Vector2i(0, 1), Vector2i(21, 18)],
	[Vector2i(1, 1), Vector2i(22, 18)],
]
const WATER_PATCH: Array[Array] = [
	[Vector2i(-1, -1), Vector2i(24, 0)],
	[Vector2i(0, -1), Vector2i(25, 0)],
	[Vector2i(1, -1), Vector2i(26, 0)],
	[Vector2i(-1, 0), Vector2i(24, 1)],
	[Vector2i(0, 0), Vector2i(25, 1)],
	[Vector2i(1, 0), Vector2i(26, 1)],
	[Vector2i(-1, 1), Vector2i(24, 2)],
	[Vector2i(0, 1), Vector2i(25, 2)],
	[Vector2i(1, 1), Vector2i(26, 2)],
]

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var soil_layer: TileMapLayer = $SoilLayer
@onready var water_layer: TileMapLayer = $WaterLayer


func _enter_tree() -> void:
	call_deferred("_rebuild_preview")


func _ready() -> void:
	_rebuild_preview()


func _rebuild_preview() -> void:
	if not is_instance_valid(ground_layer):
		return

	ground_layer.clear()
	soil_layer.clear()
	water_layer.clear()

	_paint_ground(Rect2i(-14, -9, 28, 18))
	_paint_patch(soil_layer, Vector2i(-5, 1), SOIL_PATCH)
	_paint_patch(water_layer, Vector2i(6, 0), WATER_PATCH)


func _paint_ground(area: Rect2i) -> void:
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var coords: Vector2i = Vector2i(x, y)
			var atlas_coords: Vector2i = _pick_grass(coords)
			ground_layer.set_cell(coords, SOURCE_ID, atlas_coords)


func _paint_patch(layer: TileMapLayer, center: Vector2i, entries: Array[Array]) -> void:
	for entry: Array in entries:
		var local_offset: Vector2i = entry[0]
		var atlas_coords: Vector2i = entry[1]
		layer.set_cell(center + local_offset, SOURCE_ID, atlas_coords)


func _pick_grass(coords: Vector2i) -> Vector2i:
	var hash_value: int = abs(coords.x * 31 + coords.y * 17)
	return GRASS_VARIANTS[hash_value % GRASS_VARIANTS.size()]
