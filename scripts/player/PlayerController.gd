extends CharacterBody2D
class_name PlayerController

signal facing_changed(direction: StringName)

@export var move_speed: float = 92.0
@export var tile_size: int = 32
@export var debug_draw_target_tile: bool = true
@export_range(0.0, 1.0, 0.01) var target_tile_advance_ratio: float = 0.33
@export var input_up_action: StringName = &"up"
@export var input_down_action: StringName = &"down"
@export var input_left_action: StringName = &"left"
@export var input_right_action: StringName = &"right"
@export var interact_action: StringName = &"交互"
@export var use_left_action: StringName = &"use_left"

var move_input: Vector2 = Vector2.ZERO
var facing_vector: Vector2 = Vector2.DOWN
var facing_direction: StringName = &"down"
var facing_locked: bool = false
var pressed_order: Array[StringName] = []
var interact_requested: bool = false
var tool_use_requested: bool = false

@onready var visual: PlayerVisual = $Visual
@onready var interactor: PlayerInteractor = $PlayerInteractor
@onready var tool_controller: ToolController = $ToolController
@onready var state_machine: PlayerStateMachine = $StateMachine

func _ready() -> void:
	facing_changed.connect(_on_facing_changed)
	_on_facing_changed(facing_direction)

func _input(event: InputEvent) -> void:
	if SceneTransition.is_input_locked():
		return

	for action: StringName in _get_move_actions():
		if event.is_action_pressed(action, false, true):
			pressed_order.erase(action)
			pressed_order.append(action)
		elif event.is_action_released(action):
			pressed_order.erase(action)

	if interact_action != &"" and event.is_action_pressed(interact_action, false, true):
		interact_requested = true
	if (
		use_left_action != &""
		and event.is_action_pressed(use_left_action, false, true)
		and has_selected_tool()
		and not is_tool_use_locked()
		and not is_inventory_input_blocked()
	):
		tool_use_requested = true

	if tool_controller != null:
		tool_controller.handle_input(event)

func _physics_process(delta: float) -> void:
	if SceneTransition.is_input_locked():
		clear_input_state()
		if debug_draw_target_tile:
			queue_redraw()
		return

	_refresh_input_state()
	if state_machine != null:
		state_machine.physics_update(delta)

	if debug_draw_target_tile:
		queue_redraw()

func _process(delta: float) -> void:
	if state_machine != null:
		state_machine.process_update(delta)

func has_movement_input() -> bool:
	return move_input.length_squared() > 0.0

func apply_movement(_delta: float) -> void:
	velocity = move_input.normalized() * move_speed
	move_and_slide()

func stop_movement() -> void:
	velocity = Vector2.ZERO
	move_and_slide()

func clear_input_state() -> void:
	move_input = Vector2.ZERO
	pressed_order.clear()
	interact_requested = false
	tool_use_requested = false
	stop_movement()

func show_idle_frame(cycle_time: float = 0.0) -> void:
	if visual == null:
		return

	visual.show_idle(facing_direction, cycle_time)

func show_move_frame(cycle_time: float) -> void:
	if visual == null:
		return

	visual.show_move(facing_direction, cycle_time)

func show_tool_body_frame(cycle_time: float) -> void:
	if visual == null:
		return

	visual.show_tool_body(facing_direction, cycle_time)

func set_selected_tool_data(tool_data: ToolData) -> void:
	if visual == null:
		return

	visual.set_tool_data(tool_data)

func get_selected_tool_data() -> ToolData:
	if tool_controller == null:
		return null

	return tool_controller.get_selected_tool_data()

func try_use_current_tool() -> bool:
	if tool_controller == null:
		return false

	return tool_controller.use_current_tool()

func consume_tool_use_requested() -> bool:
	if is_inventory_input_blocked():
		tool_use_requested = false
		return false

	var requested: bool = tool_use_requested
	tool_use_requested = false
	return requested

func has_selected_tool() -> bool:
	return get_selected_tool_data() != null

func lock_facing() -> void:
	facing_locked = true

func unlock_facing() -> void:
	facing_locked = false

func is_tool_use_locked() -> bool:
	if state_machine == null or state_machine.current_state == null:
		return false

	return state_machine.current_state is PlayerToolUseState

func consume_interact_requested() -> bool:
	var requested: bool = interact_requested
	interact_requested = false
	return requested

func try_interact() -> bool:
	if interactor == null:
		return false

	return interactor.try_interact(self)

func show_tool_use_frame(cycle_time: float) -> void:
	if visual == null:
		return

	visual.show_tool_use(facing_direction, cycle_time)

func hide_tool_frame() -> void:
	if visual == null:
		return

	visual.hide_tool()

func get_current_tool_use_duration() -> float:
	if visual == null:
		return 0.0

	return visual.get_tool_use_duration(facing_direction)

func get_current_tool_effect_time() -> float:
	if visual == null:
		return 0.0

	return visual.get_tool_effect_time(facing_direction)

func get_interaction_position(distance: float) -> Vector2:
	return global_position + (facing_vector * distance)

func get_target_world_position_at_distance(distance: float) -> Vector2:
	var sample_distance: float = _get_target_sample_distance(distance)
	return get_interaction_position(sample_distance)

func get_target_tile() -> Vector2i:
	return get_target_tile_at_distance(float(tile_size))

func get_target_tile_at_distance(distance: float) -> Vector2i:
	var target_world: Vector2 = get_target_world_position_at_distance(distance)
	return Vector2i(
		int(floor(target_world.x / float(tile_size))),
		int(floor(target_world.y / float(tile_size)))
	)

func _draw() -> void:
	if not debug_draw_target_tile:
		return

	var target_tile: Vector2i = get_target_tile()
	var tile_world_position: Vector2 = Vector2(target_tile.x * tile_size, target_tile.y * tile_size)
	draw_rect(
		Rect2(to_local(tile_world_position), Vector2(tile_size, tile_size)),
		Color(0.98, 0.87, 0.35, 0.85),
		false,
		1.5
	)

func _refresh_input_state() -> void:
	var horizontal: float = Input.get_axis(String(input_left_action), String(input_right_action))
	var vertical: float = Input.get_axis(String(input_up_action), String(input_down_action))
	move_input = Vector2(horizontal, vertical)
	_update_facing_from_pressed_order()

func _update_facing_from_pressed_order() -> void:
	if facing_locked:
		return

	var last_action: StringName = &""
	for index: int in range(pressed_order.size() - 1, -1, -1):
		var candidate: StringName = pressed_order[index]
		if Input.is_action_pressed(candidate):
			last_action = candidate
			break

	if last_action == &"":
		for action: StringName in _get_move_actions():
			if Input.is_action_pressed(action):
				last_action = action
				break

	if last_action == &"":
		return

	var new_direction: StringName = _action_to_direction(last_action)
	if new_direction == facing_direction:
		return

	facing_direction = new_direction
	facing_vector = _direction_to_vector(facing_direction)
	facing_changed.emit(facing_direction)

func _action_to_direction(action: StringName) -> StringName:
	match action:
		input_left_action:
			return &"left"
		input_right_action:
			return &"right"
		input_up_action:
			return &"up"
		_:
			return &"down"

func _direction_to_vector(direction: StringName) -> Vector2:
	match direction:
		&"up":
			return Vector2.UP
		&"left":
			return Vector2.LEFT
		&"right":
			return Vector2.RIGHT
		_:
			return Vector2.DOWN

func _on_facing_changed(direction: StringName) -> void:
	if interactor != null:
		interactor.set_facing_direction(direction)

func _get_move_actions() -> Array[StringName]:
	return [
		input_left_action,
		input_right_action,
		input_up_action,
		input_down_action,
	]

func _get_target_sample_distance(distance: float) -> float:
	var advance_offset: float = float(tile_size) * target_tile_advance_ratio
	return maxf(distance - advance_offset, 0.0)

func is_inventory_input_blocked() -> bool:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return false

	return _has_visible_inventory_panel(current_scene)

func _has_visible_inventory_panel(root: Node) -> bool:
	if root is InventoryPanelUI:
		return (root as Control).is_visible_in_tree()

	for child: Node in root.get_children():
		if _has_visible_inventory_panel(child):
			return true

	return false
