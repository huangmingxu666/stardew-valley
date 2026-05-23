extends Interactable
class_name ShopCounter

@export var shop_inventory: NodePath


func _ready() -> void:
	interaction_prompt = "购买"


func interact(player: PlayerController) -> void:
	if player == null:
		return
	
	var shop_inv: ShopInventory = null
	
	# 1. 尝试通过导出的 NodePath 查找
	if not shop_inventory.is_empty():
		shop_inv = get_node_or_null(shop_inventory) as ShopInventory
	
	# 2. 如果没有配置或找不到，尝试通过名称在兄弟节点中自动查找
	if shop_inv == null:
		var parent = get_parent()
		if parent != null:
			shop_inv = parent.get_node_or_null("ShopInventory") as ShopInventory
	
	# 3. 如果依然找不到，尝试在当前场景内搜索任何 ShopInventory 类型节点
	if shop_inv == null:
		shop_inv = _find_shop_inventory_in_scene(get_tree().current_scene)

	if shop_inv == null:
		push_error("ShopCounter: shop_inventory is not configured and auto-discovery failed!")
		return

	# 尝试寻找 PlayerUiRoot
	var player_ui: PlayerUiRoot = _find_player_ui_root(get_tree().current_scene)
	if player_ui != null:
		player_ui.open_shop_panel(shop_inv)
	else:
		push_error("ShopCounter: PlayerUiRoot not found in current scene!")


func _find_shop_inventory_in_scene(root: Node) -> ShopInventory:
	if root == null:
		return null
	if root is ShopInventory:
		return root as ShopInventory
	for child: Node in root.get_children():
		var resolved: ShopInventory = _find_shop_inventory_in_scene(child)
		if resolved != null:
			return resolved
	return null


func _find_player_ui_root(root: Node) -> PlayerUiRoot:
	if root is PlayerUiRoot:
		return root as PlayerUiRoot
	for child: Node in root.get_children():
		var resolved: PlayerUiRoot = _find_player_ui_root(child)
		if resolved != null:
			return resolved
	return null
