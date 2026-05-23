extends Area2D
class_name WorldItemPickup

const PICKUP_SECTION_ORDER: Array[StringName] = [
	Inventory.SECTION_BACKPACK,
	Inventory.SECTION_HOTBAR,
]

@export var burst_damping: float = 360.0
@export var attraction_acceleration: float = 900.0
@export var attraction_max_speed: float = 180.0
@export var launch_duration_seconds: float = 0.26
@export var launch_peak_height_min: float = 12.0
@export var launch_peak_height_max: float = 20.0
@export var failed_pickup_retry_seconds: float = 0.18
@export var pickup_completion_distance: float = 18.0

var stack: ItemStack
var velocity: Vector2 = Vector2.ZERO

var _retry_cooldown_remaining: float = 0.0
var _pickup_in_progress: bool = false
var _is_initialized: bool = false
var _has_landed: bool = false
var _tracked_player: PlayerController
var _resolved_inventory: Inventory
var _launch_elapsed: float = 0.0
var _launch_peak_height: float = 0.0
var _launch_start_position: Vector2 = Vector2.ZERO
var _launch_target_position: Vector2 = Vector2.ZERO
var _launch_ground_velocity: Vector2 = Vector2.ZERO

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if _pickup_in_progress:
		return

	_retry_cooldown_remaining = maxf(_retry_cooldown_remaining - delta, 0.0)

	if not _is_initialized:
		return

	if not _has_landed:
		_update_launch_arc(delta)
		return

	global_position += velocity * delta
	velocity = velocity.move_toward(Vector2.ZERO, burst_damping * delta)

	if _tracked_player == null or not is_instance_valid(_tracked_player):
		return

	var to_player: Vector2 = _tracked_player.global_position - global_position
	if to_player.length_squared() > 0.0001:
		var target_velocity: Vector2 = to_player.normalized() * attraction_max_speed
		velocity = velocity.move_toward(target_velocity, attraction_acceleration * delta)

	if to_player.length() <= pickup_completion_distance:
		_try_pickup()


func setup(item_stack: ItemStack, initial_velocity: Vector2 = Vector2.ZERO) -> void:
	stack = item_stack.duplicate_stack() if item_stack != null else null
	velocity = Vector2.ZERO
	_retry_cooldown_remaining = 0.0
	_is_initialized = true
	_has_landed = false
	_launch_elapsed = 0.0
	_launch_ground_velocity = initial_velocity
	_launch_start_position = global_position
	_launch_target_position = _launch_start_position + (_launch_ground_velocity * launch_duration_seconds)
	_launch_peak_height = _resolve_launch_peak_height(initial_velocity)
	_apply_visual()
	_apply_launch_visual(0.0)


func _apply_visual() -> void:
	if _sprite == null:
		return

	_sprite.texture = stack.icon_texture if stack != null else null


func _try_pickup() -> void:
	if _pickup_in_progress or _retry_cooldown_remaining > 0.0:
		return

	if stack == null or stack.is_empty():
		return

	var inventory: Inventory = _resolve_inventory()
	if inventory == null:
		# 没有背包系统时，直接播放拾取反馈并销毁（暂时跳过入包逻辑）
		_play_pickup_feedback()
		return

	var add_result: Dictionary = inventory.add_stack(stack, PICKUP_SECTION_ORDER)
	var added_quantity: int = int(add_result.get("added_quantity", 0))
	if added_quantity <= 0:
		_retry_cooldown_remaining = failed_pickup_retry_seconds
		return

	var remaining_quantity: int = int(add_result.get("remaining_quantity", 0))
	if remaining_quantity > 0:
		stack.quantity = remaining_quantity
		_retry_cooldown_remaining = failed_pickup_retry_seconds
		return

	_play_pickup_feedback()


func _update_launch_arc(delta: float) -> void:
	_launch_elapsed = minf(_launch_elapsed + delta, launch_duration_seconds)
	var duration: float = maxf(launch_duration_seconds, 0.001)
	var progress: float = clampf(_launch_elapsed / duration, 0.0, 1.0)
	global_position = _launch_start_position.lerp(_launch_target_position, progress)
	_apply_launch_visual(progress)
	if progress >= 1.0:
		_finish_landing()


func _apply_launch_visual(progress: float) -> void:
	if _sprite == null:
		return

	var arc_height: float = 4.0 * _launch_peak_height * progress * (1.0 - progress)
	_sprite.position = Vector2(0.0, -arc_height)


func _finish_landing() -> void:
	_has_landed = true
	global_position = _launch_target_position
	if _sprite != null:
		_sprite.position = Vector2.ZERO

	if _tracked_player != null and is_instance_valid(_tracked_player):
		var distance_to_player: float = _tracked_player.global_position.distance_to(global_position)
		if distance_to_player <= pickup_completion_distance:
			_try_pickup()


func _resolve_launch_peak_height(initial_velocity: Vector2) -> float:
	var speed_ratio: float = clampf(initial_velocity.length() / 44.0, 0.0, 1.0)
	return lerpf(launch_peak_height_min, launch_peak_height_max, speed_ratio)


func _play_pickup_feedback() -> void:
	_pickup_in_progress = true
	monitoring = false
	set_physics_process(false)
	if _collision_shape != null:
		_collision_shape.disabled = true

	var target_position: Vector2 = global_position
	if _tracked_player != null and is_instance_valid(_tracked_player):
		target_position = _tracked_player.global_position

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", target_position, 0.08)
	tween.tween_property(self, "scale", Vector2.ONE * 0.4, 0.08)
	tween.tween_property(self, "modulate:a", 0.0, 0.08)
	tween.finished.connect(queue_free)


func _resolve_inventory() -> Inventory:
	if _resolved_inventory != null and is_instance_valid(_resolved_inventory):
		return _resolved_inventory

	# 优先从全局 Autoload 获取
	var game_state_node: Node = get_node_or_null("/root/GameState")
	if game_state_node != null:
		var global_inv: Node = game_state_node.get_node_or_null("GlobalInventory")
		if global_inv is Inventory:
			_resolved_inventory = global_inv
			return _resolved_inventory

	# 降级：搜索本地场景树
	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		_resolved_inventory = _find_inventory(current_scene)
	return _resolved_inventory


func _find_inventory(root: Node) -> Inventory:
	if root is Inventory:
		return root as Inventory

	for child: Node in root.get_children():
		var resolved: Inventory = _find_inventory(child)
		if resolved != null:
			return resolved

	return null


func _on_body_entered(body: Node) -> void:
	if not _is_initialized:
		return

	var player: PlayerController = body as PlayerController
	if player == null:
		return

	_tracked_player = player
	if stack == null or stack.is_empty():
		return
	if _has_landed:
		_try_pickup()


func _on_body_exited(body: Node) -> void:
	if body == _tracked_player:
		_tracked_player = null
