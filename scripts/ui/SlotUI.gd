extends Control
class_name SlotUI

signal quick_equip_requested(section: StringName, index: int)

const DRAG_SECTION_KEY: StringName = &"from_section"
const DRAG_INDEX_KEY: StringName = &"from_index"

var inventory: Inventory
var section: StringName = &""
var slot_index: int = -1
var current_stack: ItemStack
var allow_mouse_interaction: bool = true
var allow_drag_source: bool = true
var allow_drop_target: bool = true
var allow_quick_equip: bool = true
var allow_hover_highlight: bool = false
var _is_selected: bool = false
var _is_hovered: bool = false

@onready var background: TextureRect = $Bg
@onready var selected_frame: TextureRect = $SelectedFrame
@onready var icon: TextureRect = $Overlay/Icon
@onready var count_label: Label = $Overlay/CountLabel


func _ready() -> void:
	_apply_interaction_flags()
	if selected_frame != null and background != null:
		selected_frame.texture = background.texture
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	count_label.text = ""
	_refresh_highlight()


func configure(target_inventory: Inventory, target_section: StringName, target_index: int) -> void:
	inventory = target_inventory
	section = target_section
	slot_index = target_index
	refresh()


func set_interaction_flags(
	mouse_enabled: bool,
	drag_source_enabled: bool = true,
	drop_target_enabled: bool = true,
	quick_equip_enabled: bool = true,
	hover_highlight_enabled: bool = false
) -> void:
	allow_mouse_interaction = mouse_enabled
	allow_drag_source = drag_source_enabled
	allow_drop_target = drop_target_enabled
	allow_quick_equip = quick_equip_enabled
	allow_hover_highlight = hover_highlight_enabled
	_apply_interaction_flags()
	_refresh_highlight()


func refresh() -> void:
	current_stack = null
	if inventory != null:
		current_stack = inventory.get_slot_stack(section, slot_index)

	if current_stack == null or current_stack.is_empty():
		icon.texture = null
		count_label.text = ""
		count_label.visible = false
		tooltip_text = ""
		return

	icon.texture = current_stack.icon_texture
	count_label.visible = current_stack.quantity > 1
	count_label.text = str(current_stack.quantity)
	tooltip_text = current_stack.display_name


func set_selected(is_selected: bool) -> void:
	_is_selected = is_selected
	_refresh_highlight()


func _gui_input(event: InputEvent) -> void:
	if not allow_mouse_interaction:
		return
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button == null:
		return
	if not mouse_button.pressed or mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	if inventory == null:
		return
	if allow_quick_equip and mouse_button.shift_pressed and current_stack != null and not current_stack.is_empty():
		quick_equip_requested.emit(section, slot_index)
		accept_event()
		return
	if section == Inventory.SECTION_HOTBAR:
		inventory.set_selected_hotbar_index(slot_index)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not allow_drag_source:
		return null
	if current_stack == null or current_stack.is_empty():
		return null

	var preview: Control = _build_drag_preview()
	set_drag_preview(preview)
	return {
		DRAG_SECTION_KEY: section,
		DRAG_INDEX_KEY: slot_index,
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not allow_drop_target:
		return false
	if inventory == null:
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	return data.has(DRAG_SECTION_KEY) and data.has(DRAG_INDEX_KEY)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not allow_drop_target:
		return
	if inventory == null or typeof(data) != TYPE_DICTIONARY:
		return

	var from_section_variant: Variant = data.get(DRAG_SECTION_KEY, &"")
	var from_index_variant: Variant = data.get(DRAG_INDEX_KEY, -1)
	var from_section: StringName = StringName(String(from_section_variant))
	var from_index: int = int(from_index_variant)
	if inventory.move_or_swap_stack(from_section, from_index, section, slot_index) and section == Inventory.SECTION_HOTBAR:
		inventory.set_selected_hotbar_index(slot_index)


func _build_drag_preview() -> Control:
	var preview_root: Control = Control.new()
	preview_root.custom_minimum_size = Vector2(48, 48)
	preview_root.position = Vector2(-24, -24)

	var preview_bg: TextureRect = TextureRect.new()
	preview_bg.texture = background.texture
	preview_bg.stretch_mode = TextureRect.STRETCH_SCALE
	preview_bg.position = Vector2(-24, -24)
	preview_bg.custom_minimum_size = Vector2(48, 48)
	preview_bg.anchor_right = 1.0
	preview_bg.anchor_bottom = 1.0
	preview_root.add_child(preview_bg)

	var preview_icon: TextureRect = TextureRect.new()
	preview_icon.texture = icon.texture
	preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_icon.position = Vector2(-16, -16)
	preview_icon.custom_minimum_size = Vector2(32, 32)
	preview_root.add_child(preview_icon)

	return preview_root


func _apply_interaction_flags() -> void:
	if allow_mouse_interaction or allow_drag_source or allow_drop_target:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		return

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_ARROW


func _on_mouse_entered() -> void:
	_is_hovered = true
	_refresh_highlight()


func _on_mouse_exited() -> void:
	_is_hovered = false
	_refresh_highlight()


func _refresh_highlight() -> void:
	if selected_frame == null:
		return

	var show_hover: bool = allow_hover_highlight and _is_hovered
	selected_frame.visible = _is_selected or show_hover
	if _is_selected:
		selected_frame.self_modulate = Color(1.0, 0.88, 0.39, 0.45)
	elif show_hover:
		selected_frame.self_modulate = Color(1.0, 1.0, 1.0, 0.18)
