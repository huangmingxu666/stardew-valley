extends Node2D
class_name PlayerInteractor

var player: PlayerController

@onready var interact_probe: Area2D = $InteractProbe
@onready var probe_up: Marker2D = $ProbeAnchors/Up
@onready var probe_down: Marker2D = $ProbeAnchors/Down
@onready var probe_left: Marker2D = $ProbeAnchors/Left
@onready var probe_right: Marker2D = $ProbeAnchors/Right

func _ready() -> void:
	player = get_parent() as PlayerController
	set_facing_direction(&"down")

func set_facing_direction(direction: StringName) -> void:
	var anchor: Marker2D = _get_anchor(direction)
	if anchor == null:
		return

	interact_probe.position = anchor.position

func try_interact(actor: PlayerController = player) -> bool:
	if actor == null:
		return false

	var interactable: Interactable = find_interactable(actor)
	if interactable == null or not interactable.can_interact(actor):
		return false

	interactable.interact(actor)
	return true

func find_interactable(actor: PlayerController = player) -> Interactable:
	if actor == null:
		return null

	var nearest_interactable: Interactable
	var nearest_distance: float = INF
	for area: Area2D in interact_probe.get_overlapping_areas():
		var interactable: Interactable = _find_interactable_root(area)
		if interactable == null:
			continue

		var distance_to_player: float = actor.global_position.distance_squared_to(interactable.global_position)
		if distance_to_player < nearest_distance:
			nearest_distance = distance_to_player
			nearest_interactable = interactable

	return nearest_interactable

func _get_anchor(direction: StringName) -> Marker2D:
	match direction:
		&"up":
			return probe_up
		&"left":
			return probe_left
		&"right":
			return probe_right
		_:
			return probe_down

func _find_interactable_root(node: Node) -> Interactable:
	var current: Node = node
	while current != null:
		if current is Interactable:
			return current as Interactable
		current = current.get_parent()

	return null
