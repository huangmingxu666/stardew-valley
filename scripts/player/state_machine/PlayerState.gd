extends Node
class_name PlayerState

signal transitioned(new_state_name: StringName)

var state_machine: PlayerStateMachine
var player: PlayerController

func enter() -> void:
	pass

func exit() -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func process_update(_delta: float) -> void:
	pass

func resolve_player() -> PlayerController:
	if player != null:
		return player

	var current: Node = self
	while current != null:
		if current is PlayerController:
			player = current as PlayerController
			return player
		current = current.get_parent()

	return null

func handle_shared_actions() -> void:
	var player_ref: PlayerController = resolve_player()
	if player_ref == null:
		return

	if player_ref.consume_interact_requested():
		player_ref.try_interact()
