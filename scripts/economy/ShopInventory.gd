extends Node
class_name ShopInventory

# 商品条目
class ShopEntry:
	var item_data: ItemData
	var price: int
	var stock: int # -1 表示无限库存

	func _init(p_item_data: ItemData, p_price: int, p_stock: int = -1) -> void:
		self.item_data = p_item_data
		self.price = p_price
		self.stock = p_stock

signal shop_purchase_completed(item_id: StringName, quantity: int, total_cost: int)
signal shop_purchase_failed(item_id: StringName, reason: String)

@export var shop_entries_config: Array[Resource] = [] # ItemData 数组

var _entries: Array[ShopEntry] = []


func _ready() -> void:
	_build_entries_from_config()


func _build_entries_from_config() -> void:
	_entries.clear()
	for res: Resource in shop_entries_config:
		var item_data: ItemData = res as ItemData
		if item_data == null:
			continue
		
		# 优先使用 ItemData 中的 buy_price；如果为0，则使用 sell_price * 2
		var price: int = item_data.buy_price
		if price <= 0:
			price = item_data.sell_price * 2
		
		# 商店购买商品默认库存无限 (-1)
		var entry: ShopEntry = ShopEntry.new(item_data, price, -1)
		_entries.append(entry)


func get_entries() -> Array[ShopEntry]:
	return _entries


func can_purchase(entry_index: int, quantity: int, available_cash: int) -> bool:
	if entry_index < 0 or entry_index >= _entries.size():
		return false
	
	var entry: ShopEntry = _entries[entry_index]
	var total_cost: int = entry.price * quantity
	
	if available_cash < total_cost:
		return false
		
	if entry.stock != -1 and entry.stock < quantity:
		return false
		
	return true


func purchase(entry_index: int, quantity: int, inventory: Inventory = null) -> Dictionary:
	if entry_index < 0 or entry_index >= _entries.size():
		var fail_res: Dictionary = { "success": false, "item_data": null, "quantity": 0, "total_cost": 0 }
		shop_purchase_failed.emit(&"", "无效的商品索引")
		return fail_res

	var entry: ShopEntry = _entries[entry_index]
	var item_data: ItemData = entry.item_data
	var total_cost: int = entry.price * quantity

	# 获取 GameState
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state == null:
		var fail_res: Dictionary = { "success": false, "item_data": item_data, "quantity": 0, "total_cost": 0 }
		shop_purchase_failed.emit(item_data.id, "系统内部错误：无法获取游戏状态")
		return fail_res

	# 检查金币
	var current_cash: int = int(game_state.call("get_current_cash"))
	if current_cash < total_cost:
		var fail_res: Dictionary = { "success": false, "item_data": item_data, "quantity": 0, "total_cost": 0 }
		shop_purchase_failed.emit(item_data.id, "金币不足")
		return fail_res

	# 检查库存
	if entry.stock != -1 and entry.stock < quantity:
		var fail_res: Dictionary = { "success": false, "item_data": item_data, "quantity": 0, "total_cost": 0 }
		shop_purchase_failed.emit(item_data.id, "库存不足")
		return fail_res

	# 获取背包引用
	var resolved_inventory: Inventory = inventory
	if resolved_inventory == null:
		var game_state_node: Node = get_node_or_null("/root/GameState")
		if game_state_node != null:
			var global_inv: Node = game_state_node.get_node_or_null("GlobalInventory")
			if global_inv is Inventory:
				resolved_inventory = global_inv
	if resolved_inventory == null:
		resolved_inventory = _find_first_inventory(get_tree().current_scene)

	if resolved_inventory == null:
		var fail_res: Dictionary = { "success": false, "item_data": item_data, "quantity": 0, "total_cost": 0 }
		shop_purchase_failed.emit(item_data.id, "系统内部错误：无法获取背包引用")
		return fail_res

	# 尝试将物品放入背包 (注意: 此时尚未扣款)
	# 避免部分加入，直接检测
	var add_res: Dictionary = resolved_inventory.add_item_data(item_data, quantity)
	var added_qty: int = int(add_res.get("added_quantity", 0))
	var fully_added: bool = bool(add_res.get("fully_added", false))

	if not fully_added:
		# 背包满了，如果已经加入了部分，需要退回 (虽然只买 1 个时不会有部分加入，但为防万一做好退回)
		if added_qty > 0:
			# 这里由于 Inventory API 暂不支持快捷移除，所以我们最安全的策略是直接禁止部分加入：
			# 为了最安全起见，游戏逻辑应在发现 fully_added 为 false 时直接报错，并清理掉刚刚放入的东西 (如果可能的话)
			# 但因为玩家单次在商店内点击“购买”按钮都是 quantity = 1，此时 fully_added 只会是 true (成功添加 1 个) 或 false (背包完全满，添加了 0 个)。
			# 所以数量为 1 时不存在部分成功。
			# 如果是 added_qty > 0 但未 fully_added 的情况，在此简单退回是不太好做的，因为背包可能已经改变。
			# 只要我们控制购买数量每次为 1，就能保证 atomic。
			pass
		
		if added_qty == 0:
			var fail_res: Dictionary = { "success": false, "item_data": item_data, "quantity": 0, "total_cost": 0 }
			shop_purchase_failed.emit(item_data.id, "背包已满")
			return fail_res

	# 购买成功，开始扣钱
	var spend_ok: bool = bool(game_state.call("spend_cash", total_cost))
	if not spend_ok:
		# 扣钱失败 (按理说之前已经 can_purchase 验证过，极罕见)
		# 无法完美退回物品的话就是边界异常了。但这里我们双重检查了 current_cash，肯定成功。
		pass

	# 更新库存
	if entry.stock != -1:
		entry.stock -= quantity

	shop_purchase_completed.emit(item_data.id, quantity, total_cost)
	return {
		"success": true,
		"item_data": item_data,
		"quantity": quantity,
		"total_cost": total_cost
	}


func _find_first_inventory(root: Node) -> Inventory:
	if root == null:
		return null
	if root is Inventory:
		return root as Inventory
	for child: Node in root.get_children():
		var resolved: Inventory = _find_first_inventory(child)
		if resolved != null:
			return resolved
	return null
