extends Node
class_name SceneTransitionState

const TRANSITION_INPUT_LOCK_SECONDS: float = 0.15

var _pending_scene_path: String = ""
var _pending_spawn_marker: StringName = &""
var _scene_change_scheduled: bool = false
var _input_locked_until_msec: int = 0
var _manual_input_lock_reasons: Dictionary = {}
var _recorded_return_scene_path: String = ""


func travel_to_scene(scene_path: String, spawn_marker: StringName = &"") -> void:
	if scene_path.is_empty():
		return

	if _scene_change_scheduled:
		return

	_pending_scene_path = scene_path
	_pending_spawn_marker = spawn_marker
	lock_input_for_seconds(TRANSITION_INPUT_LOCK_SECONDS)
	_scene_change_scheduled = true
	call_deferred("_apply_scene_change")


func record_return_scene(scene_path: String) -> void:
	if scene_path.is_empty():
		return

	_recorded_return_scene_path = scene_path


func get_recorded_return_scene() -> String:
	return _recorded_return_scene_path


func lock_input_for_seconds(duration_seconds: float) -> void:
	var duration_msec: int = maxi(int(round(duration_seconds * 1000.0)), 0)
	var target_msec: int = Time.get_ticks_msec() + duration_msec
	_input_locked_until_msec = maxi(_input_locked_until_msec, target_msec)


func acquire_input_lock(reason: StringName = &"default") -> void:
	_manual_input_lock_reasons[reason] = true


func release_input_lock(reason: StringName = &"default") -> void:
	_manual_input_lock_reasons.erase(reason)


func is_input_locked() -> bool:
	return not _manual_input_lock_reasons.is_empty() or Time.get_ticks_msec() < _input_locked_until_msec


func handle_player_spawn(player: PlayerController) -> void:
	lock_input_for_seconds(TRANSITION_INPUT_LOCK_SECONDS)
	if player == null:
		return

	player.clear_input_state()


func consume_spawn_marker(scene_path: String) -> StringName:
	if scene_path != _pending_scene_path:
		return &""

	var marker_name: StringName = _pending_spawn_marker
	clear_pending_spawn()
	return marker_name


func clear_pending_spawn() -> void:
	_pending_scene_path = ""
	_pending_spawn_marker = &""


func _apply_scene_change() -> void:
	var scene_path: String = _pending_scene_path
	_scene_change_scheduled = false
	if scene_path.is_empty():
		return

	get_tree().change_scene_to_file(scene_path)
