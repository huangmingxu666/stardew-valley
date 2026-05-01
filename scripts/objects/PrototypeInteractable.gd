extends Interactable
class_name PrototypeInteractable

@export var inactive_color: Color = Color(0.78, 0.45, 0.18, 1.0)
@export var active_color: Color = Color(0.98, 0.82, 0.38, 1.0)

var is_active: bool = false

@onready var body_visual: Polygon2D = $BodyVisual
@onready var glow_visual: Polygon2D = $GlowVisual

func _ready() -> void:
	interaction_prompt = "Toggle Test Marker"
	_refresh_visuals()

func interact(_player: PlayerController) -> void:
	is_active = not is_active
	interaction_prompt = "Reset Test Marker" if is_active else "Toggle Test Marker"
	_refresh_visuals()
	print("Prototype interactable toggled: %s" % str(is_active))

func _refresh_visuals() -> void:
	body_visual.color = active_color if is_active else inactive_color
	glow_visual.visible = is_active
