extends Area2D
class_name SceneExitArea

@export_file("*.tscn") var destination_scene_path: String = ""
@export var destination_spawn_marker: StringName = &""

var _transitioning: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _transitioning or destination_scene_path.is_empty():
		return

	if body is not PlayerController:
		return

	_transitioning = true
	SceneTransition.travel_to_scene(destination_scene_path, destination_spawn_marker)
