extends Resource
class_name ToolVisualData

@export var tool_id: StringName
@export var texture: Texture2D
@export var hframes: int = 1
@export var vframes: int = 1
@export var use_texture: Texture2D
@export var use_hframes: int = 0
@export var use_vframes: int = 0
@export var idle_down: FrameAnimationClip
@export var idle_up: FrameAnimationClip
@export var idle_side: FrameAnimationClip
@export var move_down: FrameAnimationClip
@export var move_up: FrameAnimationClip
@export var move_side: FrameAnimationClip
@export var use_down: FrameAnimationClip
@export var use_up: FrameAnimationClip
@export var use_side: FrameAnimationClip
@export var body_use_down: FrameAnimationClip
@export var body_use_up: FrameAnimationClip
@export var body_use_side: FrameAnimationClip
@export var offset_down: Vector2 = Vector2.ZERO
@export var offset_up: Vector2 = Vector2.ZERO
@export var offset_side: Vector2 = Vector2.ZERO
@export var z_index_down: int = 1
@export var z_index_up: int = -1
@export var z_index_side: int = 1
@export_range(-1, 32, 1) var effect_frame_index_down: int = -1
@export_range(-1, 32, 1) var effect_frame_index_up: int = -1
@export_range(-1, 32, 1) var effect_frame_index_side: int = -1

func get_idle_clip(direction: StringName) -> FrameAnimationClip:
	match direction:
		&"up":
			return idle_up
		&"left", &"right":
			return idle_side
		_:
			return idle_down

func get_move_clip(direction: StringName) -> FrameAnimationClip:
	match direction:
		&"up":
			return move_up
		&"left", &"right":
			return move_side
		_:
			return move_down

func get_clip(direction: StringName) -> FrameAnimationClip:
	match direction:
		&"up":
			return use_up
		&"left", &"right":
			return use_side
		_:
			return use_down

func get_offset(direction: StringName) -> Vector2:
	match direction:
		&"up":
			return offset_up
		&"left", &"right":
			return offset_side
		_:
			return offset_down

func get_z_index(direction: StringName) -> int:
	match direction:
		&"up":
			return z_index_up
		&"left", &"right":
			return z_index_side
		_:
			return z_index_down

func get_body_clip(direction: StringName) -> FrameAnimationClip:
	match direction:
		&"up":
			return body_use_up
		&"left", &"right":
			return body_use_side
		_:
			return body_use_down

func get_duration(direction: StringName) -> float:
	var clip: FrameAnimationClip = get_clip(direction)
	if clip == null:
		return 0.0

	var frame_count: int = clip.get_frame_count()
	if frame_count <= 0 or clip.fps <= 0.0:
		return 0.0

	return float(frame_count) / clip.fps

func get_body_duration(direction: StringName) -> float:
	var clip: FrameAnimationClip = get_body_clip(direction)
	if clip == null:
		return 0.0

	var frame_count: int = clip.get_frame_count()
	if frame_count <= 0 or clip.fps <= 0.0:
		return 0.0

	return float(frame_count) / clip.fps

func get_effect_time(direction: StringName) -> float:
	var clip: FrameAnimationClip = get_clip(direction)
	if clip == null or clip.fps <= 0.0:
		return 0.0

	var frame_count: int = clip.get_frame_count()
	if frame_count <= 0:
		return 0.0

	var effect_index: int = _get_effect_frame_index(direction)
	if effect_index < 0:
		effect_index = frame_count / 2

	effect_index = clampi(effect_index, 0, frame_count - 1)
	return float(effect_index) / clip.fps

func get_equipped_texture() -> Texture2D:
	return texture

func get_equipped_hframes() -> int:
	return max(hframes, 1)

func get_equipped_vframes() -> int:
	return max(vframes, 1)

func get_use_texture() -> Texture2D:
	if use_texture != null:
		return use_texture
	return texture

func get_use_hframes() -> int:
	if use_texture != null and use_hframes > 0:
		return use_hframes
	return max(hframes, 1)

func get_use_vframes() -> int:
	if use_texture != null and use_vframes > 0:
		return use_vframes
	return max(vframes, 1)

func _get_effect_frame_index(direction: StringName) -> int:
	match direction:
		&"up":
			return effect_frame_index_up
		&"left", &"right":
			return effect_frame_index_side
		_:
			return effect_frame_index_down
