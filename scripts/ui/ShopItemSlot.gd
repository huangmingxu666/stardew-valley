extends PanelContainer
class_name ShopItemSlot

signal purchase_requested(entry_index: int)

@onready var icon_rect: TextureRect = $HBoxContainer/IconRect
@onready var name_label: Label = $HBoxContainer/NameLabel
@onready var price_label: Label = $HBoxContainer/PriceLabel
@onready var buy_button: Button = $HBoxContainer/BuyButton

var _entry_index: int = -1
var _price: int = 0


func setup(entry_index: int, item_data: ItemData, price: int, current_cash: int) -> void:
	_entry_index = entry_index
	_price = price
	
	if icon_rect != null and item_data != null:
		icon_rect.texture = item_data.icon_texture
		
	if name_label != null and item_data != null:
		name_label.text = item_data.get_display_name()
		
	if price_label != null:
		price_label.text = "%d 金币" % price
		
	if buy_button != null:
		if not buy_button.pressed.is_connected(_on_buy_button_pressed):
			buy_button.pressed.connect(_on_buy_button_pressed)
			
	update_status(current_cash)


func update_status(current_cash: int) -> void:
	if buy_button == null:
		return
		
	if current_cash < _price:
		buy_button.disabled = true
		buy_button.text = "金币不足"
	else:
		buy_button.disabled = false
		buy_button.text = "购买"


func _on_buy_button_pressed() -> void:
	if _entry_index >= 0:
		purchase_requested.emit(_entry_index)
