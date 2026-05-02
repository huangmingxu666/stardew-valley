extends PlayerState
class_name PlayerIdleState

var idle_cycle_time: float = 0.0

func enter() -> void:
	var player_ref: PlayerController = resolve_player()
	if player_ref == null:
		return

	idle_cycle_time = 0.0
	player_ref.stop_movement()
	player_ref.show_idle_frame(idle_cycle_time)

func physics_update(delta: float) -> void:
	var player_ref: PlayerController = resolve_player()
	if player_ref == null:
		return

	handle_shared_actions()

	if player_ref.has_movement_input():
		transitioned.emit(&"Move")
		return

	idle_cycle_time += delta
	player_ref.stop_movement()
	player_ref.show_idle_frame(idle_cycle_time)
