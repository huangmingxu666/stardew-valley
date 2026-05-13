extends Node
class_name SceneSpawnController

@export_node_path("Node2D") var player_path: NodePath
@export_node_path("Marker2D") var default_spawn_path: NodePath
@export_node_path("Node") var spawn_markers_root_path: NodePath


func _ready() -> void:
	var player: Node2D = get_node_or_null(player_path) as Node2D
	if player == null:
		return

	var spawn_marker: Marker2D = _resolve_spawn_marker()
	if spawn_marker != null:
		player.global_position = spawn_marker.global_position

	SceneTransition.handle_player_spawn(player as PlayerController)


func _resolve_spawn_marker() -> Marker2D:
	var default_spawn: Marker2D = get_node_or_null(default_spawn_path) as Marker2D
	var markers_root: Node = get_node_or_null(spawn_markers_root_path)
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return default_spawn

	var pending_marker_name: StringName = SceneTransition.consume_spawn_marker(current_scene.scene_file_path)
	if pending_marker_name == &"" or markers_root == null:
		return default_spawn

	var pending_marker: Marker2D = markers_root.get_node_or_null(NodePath(String(pending_marker_name))) as Marker2D
	if pending_marker != null:
		return pending_marker

	return default_spawn
