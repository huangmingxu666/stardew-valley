extends Node2D
class_name PlayerVisual

const TOOL_FRAME_SIZE: int = 32
const TOOL_GROUP_FRAME_COUNT: int = 6
const TOOL_SIDE_START_FRAME: int = 0
const TOOL_UP_START_FRAME: int = 6
const TOOL_DOWN_START_FRAME: int = 18

@export var body_idle_down: FrameAnimationClip
@export var body_idle_up: FrameAnimationClip
@export var body_idle_side: FrameAnimationClip
@export var body_move_down: FrameAnimationClip
@export var body_move_up: FrameAnimationClip
@export var body_move_side: FrameAnimationClip
@export var body_tool_use_down: FrameAnimationClip
@export var body_tool_use_up: FrameAnimationClip
@export var body_tool_use_side: FrameAnimationClip

@onready var body_sprite: Sprite2D = $BodySprite
@onready var tool_sprite: Sprite2D = $ToolSprite

var current_tool_data: ToolData
var current_tool_visual_data: ToolVisualData
var fallback_tool_visuals: Dictionary = {}
var _tool_display_mode: StringName = &""

func _ready() -> void:
	tool_sprite.visible = false

func show_idle(direction: StringName, cycle_time: float = 0.0) -> void:
	var clip: FrameAnimationClip = _get_clip(&"idle", direction)
	if clip == null:
		return

	_apply_direction_flip(direction)
	body_sprite.frame = clip.get_frame_at_time(cycle_time)
	_show_equipped_tool_clip(_get_equipped_tool_clip(&"idle", direction), direction, cycle_time)

func show_move(direction: StringName, cycle_time: float) -> void:
	var clip: FrameAnimationClip = _get_clip(&"move", direction)
	if clip == null:
		return

	_apply_direction_flip(direction)
	body_sprite.frame = clip.get_frame_at_time(cycle_time)
	_show_equipped_tool_clip(_get_equipped_tool_clip(&"move", direction), direction, cycle_time)

func show_tool_body(direction: StringName, cycle_time: float) -> void:
	var clip: FrameAnimationClip = _get_tool_body_clip(direction)
	if clip == null:
		show_idle(direction, cycle_time)
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
		&"tool_use":
			match direction:
				&"up":
					return body_tool_use_up
				&"left", &"right":
					return body_tool_use_side
				_:
					return body_tool_use_down
		_:
			return null

func _apply_direction_flip(direction: StringName) -> void:
	var should_flip: bool = direction == &"left"
	body_sprite.flip_h = should_flip
	tool_sprite.flip_h = should_flip

func set_tool_data(tool_data: ToolData) -> void:
	current_tool_data = tool_data
	current_tool_visual_data = _resolve_tool_visual_data(tool_data)
	_tool_display_mode = &""
	if current_tool_visual_data == null or current_tool_visual_data.get_equipped_texture() == null:
		hide_tool()
		tool_sprite.texture = null
		tool_sprite.hframes = 1
		tool_sprite.vframes = 1
		return

	_apply_tool_texture_mode(&"equipped")
	tool_sprite.frame = 0
	hide_tool()

func show_tool_use(direction: StringName, cycle_time: float) -> void:
	if current_tool_visual_data == null:
		return

	var clip: FrameAnimationClip = current_tool_visual_data.get_clip(direction)
	if clip == null:
		hide_tool()
		return

	_show_use_tool_clip(clip, direction, cycle_time)

func hide_tool() -> void:
	tool_sprite.visible = false

func get_tool_use_duration(direction: StringName) -> float:
	var tool_duration: float = 0.0
	if current_tool_visual_data != null:
		tool_duration = current_tool_visual_data.get_duration(direction)

	var body_duration: float = 0.0
	var body_clip: FrameAnimationClip = _get_tool_body_clip(direction)
	if body_clip != null and body_clip.fps > 0.0:
		body_duration = float(body_clip.get_frame_count()) / body_clip.fps

	return maxf(tool_duration, body_duration)

func get_tool_effect_time(direction: StringName) -> float:
	if current_tool_visual_data == null:
		return 0.0
	return current_tool_visual_data.get_effect_time(direction)

func _resolve_tool_visual_data(tool_data: ToolData) -> ToolVisualData:
	if tool_data == null:
		return null
	if tool_data.visual_data != null:
		return tool_data.visual_data

	var fallback_variant: Variant = fallback_tool_visuals.get(tool_data.id)
	if fallback_variant is ToolVisualData:
		return fallback_variant as ToolVisualData

	if tool_data.use_texture == null:
		return null

	var fallback_data: ToolVisualData = _build_fallback_tool_visual(tool_data)
	fallback_tool_visuals[tool_data.id] = fallback_data
	return fallback_data

func _build_fallback_tool_visual(tool_data: ToolData) -> ToolVisualData:
	var fallback_data: ToolVisualData = ToolVisualData.new()
	fallback_data.tool_id = tool_data.id
	fallback_data.texture = tool_data.use_texture
	fallback_data.hframes = max(1, tool_data.use_texture.get_width() / TOOL_FRAME_SIZE)
	fallback_data.vframes = max(1, tool_data.use_texture.get_height() / TOOL_FRAME_SIZE)
	fallback_data.idle_side = _build_tool_clip(TOOL_SIDE_START_FRAME, TOOL_SIDE_START_FRAME)
	fallback_data.idle_up = _build_tool_clip(TOOL_UP_START_FRAME, TOOL_UP_START_FRAME)
	fallback_data.idle_down = _build_tool_clip(TOOL_DOWN_START_FRAME, TOOL_DOWN_START_FRAME)
	fallback_data.move_side = _build_tool_clip(TOOL_SIDE_START_FRAME, TOOL_SIDE_START_FRAME + TOOL_GROUP_FRAME_COUNT - 1)
	fallback_data.move_up = _build_tool_clip(TOOL_UP_START_FRAME, TOOL_UP_START_FRAME + TOOL_GROUP_FRAME_COUNT - 1)
	fallback_data.move_down = _build_tool_clip(TOOL_DOWN_START_FRAME, TOOL_DOWN_START_FRAME + TOOL_GROUP_FRAME_COUNT - 1)
	fallback_data.use_side = _build_tool_clip(TOOL_SIDE_START_FRAME, TOOL_SIDE_START_FRAME + TOOL_GROUP_FRAME_COUNT - 1)
	fallback_data.use_up = _build_tool_clip(TOOL_UP_START_FRAME, TOOL_UP_START_FRAME + TOOL_GROUP_FRAME_COUNT - 1)
	fallback_data.use_down = _build_tool_clip(TOOL_DOWN_START_FRAME, TOOL_DOWN_START_FRAME + TOOL_GROUP_FRAME_COUNT - 1)
	fallback_data.offset_side = Vector2(10.0, -18.0)
	fallback_data.offset_up = Vector2(4.0, -30.0)
	fallback_data.offset_down = Vector2(8.0, -8.0)
	fallback_data.z_index_side = 2
	fallback_data.z_index_up = -1
	fallback_data.z_index_down = 2
	fallback_data.effect_frame_index_side = 3
	fallback_data.effect_frame_index_up = 3
	fallback_data.effect_frame_index_down = 3
	return fallback_data

func _build_tool_clip(start_frame: int, end_frame: int) -> FrameAnimationClip:
	var clip: FrameAnimationClip = FrameAnimationClip.new()
	clip.start_frame = start_frame
	clip.end_frame = end_frame
	clip.step = 1
	clip.fps = 10.0
	clip.ping_pong = false
	clip.loop = false
	return clip

func _get_tool_body_clip(direction: StringName) -> FrameAnimationClip:
	if current_tool_visual_data != null:
		var tool_body_clip: FrameAnimationClip = current_tool_visual_data.get_body_clip(direction)
		if tool_body_clip != null:
			return tool_body_clip

	return _get_clip(&"tool_use", direction)

func _get_equipped_tool_clip(animation_group: StringName, direction: StringName) -> FrameAnimationClip:
	if current_tool_visual_data == null:
		return null

	match animation_group:
		&"idle":
			return current_tool_visual_data.get_idle_clip(direction)
		&"move":
			return current_tool_visual_data.get_move_clip(direction)
		_:
			return null

func _show_equipped_tool_clip(clip: FrameAnimationClip, direction: StringName, cycle_time: float) -> void:
	if current_tool_visual_data == null or clip == null:
		hide_tool()
		return

	_apply_tool_texture_mode(&"equipped")
	tool_sprite.visible = true
	tool_sprite.position = current_tool_visual_data.get_offset(direction)
	tool_sprite.z_index = current_tool_visual_data.get_z_index(direction)
	tool_sprite.frame = clip.get_frame_at_time(cycle_time)
	tool_sprite.flip_h = direction == &"left"

func _show_use_tool_clip(clip: FrameAnimationClip, direction: StringName, cycle_time: float) -> void:
	if current_tool_visual_data == null or clip == null:
		hide_tool()
		return

	_apply_tool_texture_mode(&"use")
	tool_sprite.visible = true
	tool_sprite.position = current_tool_visual_data.get_offset(direction)
	tool_sprite.z_index = current_tool_visual_data.get_z_index(direction)
	tool_sprite.frame = clip.get_frame_at_time(cycle_time)
	tool_sprite.flip_h = direction == &"left"

func _apply_tool_texture_mode(mode: StringName) -> void:
	if current_tool_visual_data == null:
		return
	if _tool_display_mode == mode:
		return

	var next_texture: Texture2D
	var next_hframes: int = 1
	var next_vframes: int = 1
	if mode == &"use":
		next_texture = current_tool_visual_data.get_use_texture()
		next_hframes = current_tool_visual_data.get_use_hframes()
		next_vframes = current_tool_visual_data.get_use_vframes()
	else:
		next_texture = current_tool_visual_data.get_equipped_texture()
		next_hframes = current_tool_visual_data.get_equipped_hframes()
		next_vframes = current_tool_visual_data.get_equipped_vframes()

	tool_sprite.texture = next_texture
	tool_sprite.hframes = next_hframes
	tool_sprite.vframes = next_vframes
	_tool_display_mode = mode
