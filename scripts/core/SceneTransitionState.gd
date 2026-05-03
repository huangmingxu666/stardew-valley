extends Node
class_name SceneTransitionState

var _pending_scene_path: String = ""
var _pending_spawn_marker: StringName = &""


func travel_to_scene(scene_path: String, spawn_marker: StringName = &"") -> void:
	if scene_path.is_empty():
		return

	_pending_scene_path = scene_path
	_pending_spawn_marker = spawn_marker
	get_tree().change_scene_to_file(scene_path)


func consume_spawn_marker(scene_path: String) -> StringName:
	if scene_path != _pending_scene_path:
		return &""

	var marker_name: StringName = _pending_spawn_marker
	clear_pending_spawn()
	return marker_name


func clear_pending_spawn() -> void:
	_pending_scene_path = ""
	_pending_spawn_marker = &""
