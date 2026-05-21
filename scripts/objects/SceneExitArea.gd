extends Area2D
class_name SceneExitArea

@export_file("*.tscn") var destination_scene_path: String = ""
@export var destination_spawn_marker: StringName = &""
@export var use_recorded_return_scene: bool = false

var _transitioning: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	var resolved_scene_path: String = _resolve_destination_scene_path()
	if _transitioning or resolved_scene_path.is_empty():
		return

	if body is not PlayerController:
		return

	_transitioning = true
	SceneTransition.travel_to_scene(resolved_scene_path, destination_spawn_marker)


func _resolve_destination_scene_path() -> String:
	if use_recorded_return_scene:
		var recorded_scene_path: String = SceneTransition.get_recorded_return_scene()
		if not recorded_scene_path.is_empty():
			return recorded_scene_path

	return destination_scene_path
