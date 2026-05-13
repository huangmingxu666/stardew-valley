extends Node
class_name SleepTransitionController

signal sleep_transition_started(source: Node)
signal sleep_transition_midpoint(source: Node, time_manager: TimeManager)
signal sleep_transition_finished(source: Node)

const INPUT_LOCK_REASON: StringName = &"sleep_transition"

@export_range(0.05, 3.0, 0.05) var fade_in_duration: float = 0.45
@export_range(0.0, 3.0, 0.05) var hold_duration: float = 0.2
@export_range(0.05, 3.0, 0.05) var fade_out_duration: float = 0.45

var _overlay_layer: CanvasLayer
var _overlay_rect: ColorRect
var _is_playing: bool = false


func is_playing() -> bool:
	return _is_playing


func play_sleep_transition(source: Node = null) -> void:
	if _is_playing:
		return

	_is_playing = true
	SceneTransition.acquire_input_lock(INPUT_LOCK_REASON)
	_ensure_overlay()
	_attach_overlay_to_root()
	overlay_to_front()

	sleep_transition_started.emit(source)
	await _fade_to_alpha(1.0, fade_in_duration)

	var time_manager: TimeManager = _resolve_time_manager()
	sleep_transition_midpoint.emit(source, time_manager)
	if time_manager != null:
		time_manager.request_sleep_skip_to_next_day()

	if hold_duration > 0.0:
		await get_tree().create_timer(hold_duration).timeout

	await _fade_to_alpha(0.0, fade_out_duration)
	sleep_transition_finished.emit(source)
	SceneTransition.release_input_lock(INPUT_LOCK_REASON)
	_is_playing = false


func overlay_to_front() -> void:
	if _overlay_layer != null:
		_overlay_layer.layer = max(_overlay_layer.layer, 100)


func _ensure_overlay() -> void:
	if _overlay_layer != null and is_instance_valid(_overlay_layer):
		return

	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "SleepTransitionOverlay"
	_overlay_layer.layer = 100

	_overlay_rect = ColorRect.new()
	_overlay_rect.name = "BlackMask"
	_overlay_rect.color = Color(0, 0, 0, 0)
	_overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_rect.anchor_right = 1.0
	_overlay_rect.anchor_bottom = 1.0

	_overlay_layer.add_child(_overlay_rect)


func _attach_overlay_to_root() -> void:
	if _overlay_layer == null:
		return

	var root: Window = get_tree().root
	if _overlay_layer.get_parent() != root:
		if _overlay_layer.get_parent() != null:
			_overlay_layer.get_parent().remove_child(_overlay_layer)
		root.add_child(_overlay_layer)


func _fade_to_alpha(target_alpha: float, duration: float) -> void:
	if _overlay_rect == null:
		return

	if duration <= 0.0:
		var color: Color = _overlay_rect.color
		color.a = target_alpha
		_overlay_rect.color = color
		return

	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_overlay_rect, "color:a", target_alpha, duration)
	await tween.finished


func _resolve_time_manager() -> TimeManager:
	var game_time: TimeManager = get_node_or_null("/root/GameTime") as TimeManager
	if game_time != null:
		return game_time

	return _find_first_time_manager(get_tree().current_scene)


func _find_first_time_manager(root: Node) -> TimeManager:
	if root == null:
		return null
	if root is TimeManager:
		return root as TimeManager

	for child: Node in root.get_children():
		var resolved: TimeManager = _find_first_time_manager(child)
		if resolved != null:
			return resolved

	return null
