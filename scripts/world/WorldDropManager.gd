extends Node
class_name WorldDropManager

const ACTION_HARVEST: StringName = &"harvest"

@export_node_path("CropRegistry") var crop_registry_path: NodePath
@export_node_path("Node2D") var drop_parent_path: NodePath
@export var scatter_speed_min: float = 28.0
@export var scatter_speed_max: float = 44.0
@export var scatter_jitter_radius: float = 3.0
@export var scatter_angle_jitter: float = 0.28

var crop_registry: CropRegistry
var drop_parent: Node2D

var _pickup_scene: PackedScene = preload("res://scenes/objects/WorldItemPickup.tscn")
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_resolve_crop_registry()
	_resolve_drop_parent()
	_connect_crop_registry()


func _exit_tree() -> void:
	if crop_registry == null:
		return

	var callback: Callable = Callable(self, "_on_tool_action_completed")
	if crop_registry.tool_action_completed.is_connected(callback):
		crop_registry.tool_action_completed.disconnect(callback)


func _connect_crop_registry() -> void:
	if crop_registry == null:
		return

	var callback: Callable = Callable(self, "_on_tool_action_completed")
	if not crop_registry.tool_action_completed.is_connected(callback):
		crop_registry.tool_action_completed.connect(callback)


func _on_tool_action_completed(action: StringName, cell: Vector2i, result: Dictionary) -> void:
	if action != ACTION_HARVEST or not bool(result.get("success", false)):
		return

	var yield_count: int = int(result.get("yield_count", 0))
	if yield_count <= 0:
		return

	var crop_id: StringName = StringName(String(result.get("crop_id", "")))
	var crop_data: CropData = crop_registry.get_crop_data(crop_id) if crop_registry != null else null
	if crop_data == null or crop_data.harvest_item == null:
		return

	var origin: Vector2 = _resolve_drop_origin(cell)
	for index: int in range(yield_count):
		_spawn_drop(crop_data.harvest_item, origin, index, yield_count)


func _spawn_drop(item_data: ItemData, origin: Vector2, drop_index: int, drop_count: int) -> void:
	if item_data == null or _pickup_scene == null:
		return

	if drop_parent == null or not is_instance_valid(drop_parent):
		_resolve_drop_parent()
	if drop_parent == null:
		return

	var pickup: WorldItemPickup = _pickup_scene.instantiate() as WorldItemPickup
	if pickup == null:
		return

	drop_parent.add_child(pickup)
	pickup.global_position = origin + _get_spawn_jitter()
	pickup.setup(ItemStack.from_item_data(item_data, 1), _get_scatter_velocity(drop_index, drop_count))


func _resolve_drop_origin(cell: Vector2i) -> Vector2:
	if crop_registry != null and crop_registry.farm_grid != null:
		return crop_registry.farm_grid.cell_to_world(cell)

	return Vector2(cell) * 32.0


func _get_spawn_jitter() -> Vector2:
	return Vector2(
		_rng.randf_range(-scatter_jitter_radius, scatter_jitter_radius),
		_rng.randf_range(-scatter_jitter_radius, scatter_jitter_radius)
	)


func _get_scatter_velocity(drop_index: int, drop_count: int) -> Vector2:
	var base_angle: float = _rng.randf_range(0.0, TAU)
	if drop_count > 1:
		base_angle = (TAU * float(drop_index)) / float(drop_count)

	base_angle += _rng.randf_range(-scatter_angle_jitter, scatter_angle_jitter)
	var direction: Vector2 = Vector2.RIGHT.rotated(base_angle)

	var speed: float = _rng.randf_range(scatter_speed_min, scatter_speed_max)
	return direction * speed


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


func _resolve_drop_parent() -> void:
	if not drop_parent_path.is_empty():
		drop_parent = get_node_or_null(drop_parent_path) as Node2D
		if drop_parent != null:
			return

	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var prop_root: Node = current_scene.get_node_or_null("Prop")
	if prop_root is Node2D:
		drop_parent = prop_root as Node2D
		return

	if current_scene is Node2D:
		drop_parent = current_scene as Node2D
