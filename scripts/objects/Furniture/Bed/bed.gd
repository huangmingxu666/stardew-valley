extends Interactable
class_name Bed


func _ready() -> void:
	interaction_prompt = "Sleep"


func can_interact(_player: PlayerController) -> bool:
	return not SleepTransition.is_playing()


func interact(_player: PlayerController) -> void:
	SleepTransition.play_sleep_transition(self)
