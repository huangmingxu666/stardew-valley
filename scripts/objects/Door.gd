extends Interactable
class_name Door

@export_file("*.tscn") var destination_scene_path: String = ""
@export var destination_spawn_marker: StringName = &""
@export var record_current_scene_as_return: bool = false
@export var frame_duration: float = 0.05
@export_range(1, 32, 1) var frame_count: int = 7
@export var closed_frame: int = 0
@export var open_frame: int = 6
@export var play_open_animation: bool = true
@export var door_visible: bool = true
@export var door_texture: Texture2D = null

var _transitioning: bool = false

@onready var door_sprite: Sprite2D = $DoorSprite


func _ready() -> void:
	if door_sprite == null:
		return

	if door_texture != null:
		door_sprite.texture = door_texture

	door_sprite.visible = door_visible
	door_sprite.hframes = max(frame_count, 1)
	door_sprite.frame = clampi(closed_frame, 0, door_sprite.hframes - 1)


func can_interact(_player: PlayerController) -> bool:
	return not _transitioning and not destination_scene_path.is_empty()


func interact(_player: PlayerController) -> void:
	if _transitioning:
		return

	_transitioning = true
	SceneTransition.lock_input_for_seconds(SceneTransition.TRANSITION_INPUT_LOCK_SECONDS)
	if _player != null:
		_player.clear_input_state()
	if record_current_scene_as_return:
		var current_scene: Node = get_tree().current_scene
		if current_scene != null:
			SceneTransition.record_return_scene(current_scene.scene_file_path)
		if _player != null:
			SceneTransition.record_return_position(_player.global_position)

	if play_open_animation and door_visible and door_sprite != null:
		await _play_open_animation()

	SceneTransition.travel_to_scene(destination_scene_path, destination_spawn_marker)


func _play_open_animation() -> void:
	var start_frame: int = clampi(closed_frame, 0, door_sprite.hframes - 1)
	var target_frame: int = clampi(open_frame, 0, door_sprite.hframes - 1)
	if start_frame == target_frame:
		door_sprite.frame = target_frame
		return

	var step: int = 1 if target_frame > start_frame else -1
	for frame_index: int in range(start_frame, target_frame + step, step):
		door_sprite.frame = frame_index
		if frame_index != target_frame:
			await get_tree().create_timer(frame_duration).timeout
