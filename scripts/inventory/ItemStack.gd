extends Resource
class_name ItemStack

@export var item_id: StringName = &""
@export var display_name: String = ""
@export var icon_texture: Texture2D
@export_range(0, 999, 1) var quantity: int = 0
@export_range(1, 999, 1) var max_stack: int = 1
@export var stackable: bool = false
@export var source_data: Resource


static func from_item_data(item_data: ItemData, amount: int = 1) -> ItemStack:
	if item_data == null:
		return null

	var stack: ItemStack = ItemStack.new()
	stack.item_id = item_data.id
	stack.display_name = item_data.get_display_name()
	stack.icon_texture = item_data.icon_texture
	stack.quantity = max(amount, 1)
	stack.max_stack = max(item_data.max_stack, 1)
	stack.stackable = item_data.stackable
	stack.source_data = item_data
	return stack


static func from_tool_data(tool_data: ToolData) -> ItemStack:
	if tool_data == null:
		return null

	var stack: ItemStack = ItemStack.new()
	stack.item_id = tool_data.id
	stack.display_name = tool_data.get_display_name()
	stack.icon_texture = tool_data.icon_texture
	stack.quantity = 1
	stack.max_stack = 1
	stack.stackable = false
	stack.source_data = tool_data
	return stack


func is_empty() -> bool:
	return item_id == &"" or quantity <= 0


func can_merge_with(other: ItemStack) -> bool:
	if other == null:
		return false
	return (
		not is_empty()
		and not other.is_empty()
		and stackable
		and other.stackable
		and item_id == other.item_id
	)


func remaining_capacity() -> int:
	return max(max_stack - quantity, 0)


func duplicate_stack() -> ItemStack:
	var copy: ItemStack = ItemStack.new()
	copy.item_id = item_id
	copy.display_name = display_name
	copy.icon_texture = icon_texture
	copy.quantity = quantity
	copy.max_stack = max_stack
	copy.stackable = stackable
	copy.source_data = source_data
	return copy
