extends Node
class_name PlayerStateMachine

signal state_changed(previous_state: StringName, new_state: StringName)

@export_node_path var initial_state_path: NodePath

var player: PlayerController
var current_state: PlayerState
var states: Dictionary = {}

func _ready() -> void:
	player = get_parent() as PlayerController
	for child: Node in get_children():
		if child is PlayerState:
			var state: PlayerState = child as PlayerState
			states[child.name] = state
			state.player = player
			state.state_machine = self
			state.transitioned.connect(_on_transition)

	var initial_state: PlayerState = get_node_or_null(initial_state_path) as PlayerState
	if initial_state == null:
		push_warning("PlayerStateMachine is missing an initial state.")
		return

	current_state = initial_state
	current_state.enter()
	state_changed.emit(&"", StringName(current_state.name))

func physics_update(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)

func process_update(delta: float) -> void:
	if current_state != null:
		current_state.process_update(delta)

func _on_transition(new_state_name: StringName) -> void:
	var next_state_variant: Variant = states.get(String(new_state_name))
	if not (next_state_variant is PlayerState):
		push_warning("Unknown player state: %s" % String(new_state_name))
		return

	var previous_state: PlayerState = current_state
	if previous_state != null and previous_state.name == String(new_state_name):
		return

	if previous_state != null:
		previous_state.exit()

	current_state = next_state_variant as PlayerState
	current_state.enter()
	state_changed.emit(
		StringName(previous_state.name) if previous_state != null else &"",
		StringName(current_state.name)
	)
