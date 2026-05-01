extends CharacterBody2D
class_name PlayerController

signal facing_changed(direction: StringName)

@export var move_speed: float = 92.0
@export var tile_size: int = 32
@export var debug_draw_target_tile: bool = true
@export var input_up_action: StringName = &"up"
@export var input_down_action: StringName = &"down"
@export var input_left_action: StringName = &"left"
@export var input_right_action: StringName = &"right"
@export var interact_action: StringName = &"ui_accept"

var move_input: Vector2 = Vector2.ZERO
var facing_vector: Vector2 = Vector2.DOWN
var facing_direction: StringName = &"down"
var pressed_order: Array[StringName] = []
var interact_requested: bool = false

@onready var visual: PlayerVisual = $Visual
@onready var interactor: PlayerInteractor = $PlayerInteractor
@onready var state_machine: PlayerStateMachine = $StateMachine

func _ready() -> void:
	facing_changed.connect(_on_facing_changed)
	_on_facing_changed(facing_direction)

func _input(event: InputEvent) -> void:
	for action: StringName in _get_move_actions():
		if event.is_action_pressed(action, false, true):
			pressed_order.erase(action)
			pressed_order.append(action)
		elif event.is_action_released(action):
			pressed_order.erase(action)

	if interact_action != &"" and event.is_action_pressed(interact_action, false, true):
		interact_requested = true

func _physics_process(delta: float) -> void:
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

func show_idle_frame() -> void:
	if visual == null:
		return

	visual.show_idle(facing_direction)

func show_move_frame(cycle_time: float) -> void:
	if visual == null:
		return

	visual.show_move(facing_direction, cycle_time)

func consume_interact_requested() -> bool:
	var requested: bool = interact_requested
	interact_requested = false
	return requested

func try_interact() -> bool:
	if interactor == null:
		return false

	return interactor.try_interact(self)

func get_interaction_position(distance: float) -> Vector2:
	return global_position + (facing_vector * distance)

func get_target_tile() -> Vector2i:
	var target_world: Vector2 = get_interaction_position(float(tile_size))
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
	var last_action: StringName = &""
	for index: int in range(pressed_order.size() - 1, -1, -1):
		var candidate: StringName = pressed_order[index]
		if Input.is_action_pressed(candidate):
			last_action = candidate
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
