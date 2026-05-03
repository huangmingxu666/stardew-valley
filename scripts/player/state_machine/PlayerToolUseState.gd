extends PlayerState
class_name PlayerToolUseState

@export var fallback_duration: float = 0.35

var tool_cycle_time: float = 0.0
var tool_effect_applied: bool = false
var current_tool_data: ToolData
var current_duration: float = 0.35
var current_effect_time: float = 0.15

func enter() -> void:
	var player_ref: PlayerController = resolve_player()
	if player_ref == null:
		return

	current_tool_data = player_ref.get_selected_tool_data()
	if current_tool_data == null:
		transitioned.emit(&"Idle")
		return

	tool_cycle_time = 0.0
	tool_effect_applied = false
	current_duration = maxf(player_ref.get_current_tool_use_duration(), fallback_duration)
	current_effect_time = clampf(
		player_ref.get_current_tool_effect_time(),
		0.0,
		current_duration
	)
	player_ref.lock_facing()
	player_ref.stop_movement()
	player_ref.show_tool_body_frame(tool_cycle_time)
	player_ref.show_tool_use_frame(tool_cycle_time)

func physics_update(delta: float) -> void:
	var player_ref: PlayerController = resolve_player()
	if player_ref == null:
		return

	handle_shared_actions()
	player_ref.stop_movement()

	tool_cycle_time += delta
	player_ref.show_tool_body_frame(tool_cycle_time)
	player_ref.show_tool_use_frame(tool_cycle_time)

	if not tool_effect_applied and tool_cycle_time >= current_effect_time:
		tool_effect_applied = true
		player_ref.try_use_current_tool()

	if tool_cycle_time >= current_duration:
		player_ref.hide_tool_frame()
		if player_ref.has_movement_input():
			transitioned.emit(&"Move")
		else:
			transitioned.emit(&"Idle")

func exit() -> void:
	var player_ref: PlayerController = resolve_player()
	if player_ref == null:
		return

	player_ref.unlock_facing()
	player_ref.hide_tool_frame()
