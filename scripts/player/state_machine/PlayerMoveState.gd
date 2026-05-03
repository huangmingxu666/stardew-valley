extends PlayerState
class_name PlayerMoveState

@export var stop_buffer_duration: float = 0.08

var walk_cycle_time: float = 0.0
var stop_buffer_time: float = 0.0

func enter() -> void:
	var player_ref: PlayerController = resolve_player()
	if player_ref == null:
		return

	stop_buffer_time = 0.0
	player_ref.show_move_frame(walk_cycle_time)

func physics_update(delta: float) -> void:
	var player_ref: PlayerController = resolve_player()
	if player_ref == null:
		return

	handle_shared_actions()
	if player_ref.consume_tool_use_requested() and player_ref.has_selected_tool():
		transitioned.emit(&"ToolUse")
		return

	if player_ref.has_movement_input():
		stop_buffer_time = 0.0
		walk_cycle_time += delta
		player_ref.apply_movement(delta)
		player_ref.show_move_frame(walk_cycle_time)
		return

	stop_buffer_time += delta
	player_ref.stop_movement()
	player_ref.show_move_frame(walk_cycle_time)

	if stop_buffer_time >= stop_buffer_duration:
		walk_cycle_time = 0.0
		transitioned.emit(&"Idle")

func exit() -> void:
	var player_ref: PlayerController = resolve_player()
	if player_ref == null:
		return

	player_ref.stop_movement()
