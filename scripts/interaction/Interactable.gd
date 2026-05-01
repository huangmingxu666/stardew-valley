extends Area2D
class_name Interactable

@export var interaction_prompt: String = "Interact"

func can_interact(_player: PlayerController) -> bool:
	return true

func interact(_player: PlayerController) -> void:
	pass

func get_prompt() -> String:
	return interaction_prompt
