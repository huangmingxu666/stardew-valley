extends PlayerState
class_name PlayerIdleState

func enter() -> void:
	var player_ref: PlayerController = resolve_player()
	if player_ref == null:
		return

	player_ref.stop_movement()
	player_ref.show_idle_frame()

func physics_update(_delta: float) -> void:
	var player_ref: PlayerController = resolve_player()
	if player_ref == null:
		return

	handle_shared_actions()

	if player_ref.has_movement_input():
		transitioned.emit(&"Move")
		return

	player_ref.stop_movement()
	player_ref.show_idle_frame()
