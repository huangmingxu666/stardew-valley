extends Node2D
class_name PlayerVisual

@export var body_idle_down: FrameAnimationClip
@export var body_idle_up: FrameAnimationClip
@export var body_idle_side: FrameAnimationClip
@export var body_move_down: FrameAnimationClip
@export var body_move_up: FrameAnimationClip
@export var body_move_side: FrameAnimationClip

@onready var body_sprite: Sprite2D = $BodySprite
@onready var tool_sprite: Sprite2D = $ToolSprite

func _ready() -> void:
	tool_sprite.visible = false

func show_idle(direction: StringName, cycle_time: float = 0.0) -> void:
	var clip: FrameAnimationClip = _get_clip(&"idle", direction)
	if clip == null:
		return

	_apply_direction_flip(direction)
	body_sprite.frame = clip.get_frame_at_time(cycle_time)

func show_move(direction: StringName, cycle_time: float) -> void:
	var clip: FrameAnimationClip = _get_clip(&"move", direction)
	if clip == null:
		return

	_apply_direction_flip(direction)
	body_sprite.frame = clip.get_frame_at_time(cycle_time)

func _get_clip(animation_group: StringName, direction: StringName) -> FrameAnimationClip:
	match animation_group:
		&"idle":
			match direction:
				&"up":
					return body_idle_up
				&"left", &"right":
					return body_idle_side
				_:
					return body_idle_down
		&"move":
			match direction:
				&"up":
					return body_move_up
				&"left", &"right":
					return body_move_side
				_:
					return body_move_down
		_:
			return null

func _apply_direction_flip(direction: StringName) -> void:
	var should_flip: bool = direction == &"left"
	body_sprite.flip_h = should_flip
	tool_sprite.flip_h = should_flip
