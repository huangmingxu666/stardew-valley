extends Interactable
class_name ShippingBin

@export var closed_frame: int = 0
@export var open_frame: int = 10
@export var frame_step_duration: float = 0.04

var _player_in_range_count: int = 0
var _target_frame: int = 0
var _frame_step_accumulator: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	interaction_prompt = "Ship Items"
	if sprite != null:
		sprite.frame = closed_frame
	_target_frame = closed_frame

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if sprite == null or sprite.frame == _target_frame:
		_frame_step_accumulator = 0.0
		return

	_frame_step_accumulator += delta
	while _frame_step_accumulator >= frame_step_duration and sprite.frame != _target_frame:
		_frame_step_accumulator -= frame_step_duration
		if sprite.frame < _target_frame:
			sprite.frame += 1
		else:
			sprite.frame -= 1


func can_interact(_player: PlayerController) -> bool:
	return _player_in_range_count > 0


func interact(_player: PlayerController) -> void:
	print("Shipping bin interacted: test success")


func _on_body_entered(body: Node) -> void:
	if body is not PlayerController:
		return

	_player_in_range_count += 1
	_target_frame = open_frame


func _on_body_exited(body: Node) -> void:
	if body is not PlayerController:
		return

	_player_in_range_count = maxi(_player_in_range_count - 1, 0)
	if _player_in_range_count == 0:
		_target_frame = closed_frame
