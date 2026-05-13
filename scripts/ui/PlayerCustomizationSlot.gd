extends Control
class_name PlayerCustomizationSlot

const DRAG_SECTION_KEY: StringName = &"from_section"
const DRAG_INDEX_KEY: StringName = &"from_index"

@export var slot_id: StringName = &""

var inventory: Inventory
var equipped_stack: ItemStack

@onready var background: TextureRect = $Bg
@onready var selected_frame: TextureRect = $SelectedFrame
@onready var icon: TextureRect = $Overlay/Icon


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_CAN_DROP
	if selected_frame != null and background != null:
		selected_frame.texture = background.texture
	selected_frame.visible = false
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_refresh_visual()


func configure(target_inventory: Inventory, target_slot_id: StringName = &"") -> void:
	inventory = target_inventory
	if target_slot_id != &"":
		slot_id = target_slot_id
	_refresh_visual()


func is_empty() -> bool:
	return equipped_stack == null or equipped_stack.is_empty()


func try_equip_from_inventory(from_section: StringName, from_index: int) -> bool:
	if inventory == null:
		return false

	var from_stack: ItemStack = inventory.get_slot_stack(from_section, from_index)
	if from_stack == null or from_stack.is_empty():
		return false

	var previous_stack: ItemStack = equipped_stack
	equipped_stack = from_stack

	if previous_stack == null or previous_stack.is_empty():
		inventory.clear_slot(from_section, from_index)
	else:
		inventory.set_stack(from_section, from_index, previous_stack)

	_refresh_visual()
	return true


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if inventory == null:
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	return data.has(DRAG_SECTION_KEY) and data.has(DRAG_INDEX_KEY)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if inventory == null or typeof(data) != TYPE_DICTIONARY:
		return

	var from_section_variant: Variant = data.get(DRAG_SECTION_KEY, &"")
	var from_index_variant: Variant = data.get(DRAG_INDEX_KEY, -1)
	var from_section: StringName = StringName(String(from_section_variant))
	var from_index: int = int(from_index_variant)
	try_equip_from_inventory(from_section, from_index)


func _refresh_visual() -> void:
	if equipped_stack == null or equipped_stack.is_empty():
		icon.texture = null
		tooltip_text = ""
		return

	icon.texture = equipped_stack.icon_texture
	tooltip_text = equipped_stack.display_name
