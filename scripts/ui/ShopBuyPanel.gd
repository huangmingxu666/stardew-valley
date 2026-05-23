extends Control
class_name ShopBuyPanel

signal close_requested

var _shop_inventory: ShopInventory
var _player_inventory: Inventory

@export var item_slot_scene: PackedScene = preload("res://scenes/ui/ShopItemSlot.tscn")

@onready var item_container: VBoxContainer = $NinePatchRect/VBoxContainer/ScrollContainer/ItemContainer
@onready var cash_label: Label = $NinePatchRect/VBoxContainer/Footer/CashLabel
@onready var message_label: Label = $NinePatchRect/VBoxContainer/Footer/MessageLabel
@onready var close_button: Button = $NinePatchRect/VBoxContainer/Header/CloseButton

# 保存生成的商品插槽引用，便于刷新状态
var _slot_nodes: Array = []

func _ready() -> void:
	if close_button != null:
		close_button.pressed.connect(_on_close_button_pressed)
	if message_label != null:
		message_label.text = ""


func setup(shop_inv: ShopInventory, player_inv: Inventory) -> void:
	_shop_inventory = shop_inv
	_player_inventory = player_inv
	_slot_nodes.clear()

	# 连接 GameState 金币改变信号
	var game_state = get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_signal("cash_changed"):
		if not game_state.cash_changed.is_connected(_on_cash_changed):
			game_state.cash_changed.connect(_on_cash_changed)

	# 监听商店购买信号，给玩家提供文字反馈
	if _shop_inventory != null:
		if not _shop_inventory.shop_purchase_completed.is_connected(_on_shop_purchase_completed):
			_shop_inventory.shop_purchase_completed.connect(_on_shop_purchase_completed)
		if not _shop_inventory.shop_purchase_failed.is_connected(_on_shop_purchase_failed):
			_shop_inventory.shop_purchase_failed.connect(_on_shop_purchase_failed)

	_populate_items()
	refresh()


func _populate_items() -> void:
	# 清空容器
	for child in item_container.get_children():
		child.queue_free()
	_slot_nodes.clear()

	if _shop_inventory == null or item_slot_scene == null:
		return

	var game_state = get_node_or_null("/root/GameState")
	var current_cash: int = 0
	if game_state != null:
		current_cash = int(game_state.call("get_current_cash"))

	var entries = _shop_inventory.get_entries()
	for index in range(entries.size()):
		var entry = entries[index]
		var item_data = entry.item_data
		if item_data == null:
			continue

		var slot_instance = item_slot_scene.instantiate()
		if slot_instance == null:
			continue
			
		item_container.add_child(slot_instance)
		slot_instance.setup(index, item_data, entry.price, current_cash)
		
		# 连接购买点击信号
		if not slot_instance.purchase_requested.is_connected(_on_buy_button_pressed):
			slot_instance.purchase_requested.connect(_on_buy_button_pressed)
			
		_slot_nodes.append(slot_instance)


func refresh() -> void:
	if message_label != null:
		message_label.text = ""

	# 刷新金币显示
	var game_state = get_node_or_null("/root/GameState")
	var current_cash: int = 0
	if game_state != null:
		current_cash = int(game_state.call("get_current_cash"))
	
	if cash_label != null:
		cash_label.text = "当前金币: %d" % current_cash

	# 刷新所有商品行按钮状态
	for slot in _slot_nodes:
		if is_instance_valid(slot):
			slot.update_status(current_cash)


func _on_buy_button_pressed(entry_index: int) -> void:
	if _shop_inventory == null:
		return
	
	# 执行购买
	var result = _shop_inventory.purchase(entry_index, 1, _player_inventory)
	if result.get("success", false):
		_show_feedback("购买成功: %s x1" % result.item_data.get_display_name(), Color.DARK_GREEN)
		refresh()
	# 失败时的反馈通过信号回调处理


func _show_feedback(msg: String, color: Color = Color.BLACK) -> void:
	if message_label != null:
		message_label.text = msg
		message_label.add_theme_color_override("font_color", color)
		# 3秒后清空提示信息
		var timer = get_tree().create_timer(3.0)
		timer.timeout.connect(func():
			if message_label != null and message_label.text == msg:
				message_label.text = ""
		)


func _on_close_button_pressed() -> void:
	close_requested.emit()


func _on_cash_changed(_current_cash: int, _total_cash: int) -> void:
	refresh()


func _on_shop_purchase_completed(_item_id: StringName, _quantity: int, _total_cost: int) -> void:
	# 成功购买的声音或效果可在此触发
	pass


func _on_shop_purchase_failed(_item_id: StringName, reason: String) -> void:
	_show_feedback("购买失败: %s" % reason, Color.RED)
