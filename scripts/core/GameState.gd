extends Node

signal cash_changed(current_cash: int, total_cash: int)

@export_range(0, 99_999_999, 1) var starting_current_cash: int = 0
@export_range(0, 99_999_999, 1) var starting_total_cash: int = 0

var current_cash: int = 0
var total_cash: int = 0


func _ready() -> void:
	current_cash = max(starting_current_cash, 0)
	total_cash = max(starting_total_cash, current_cash)


func get_current_cash() -> int:
	return current_cash


func get_total_cash() -> int:
	return total_cash


func set_cash(value: int) -> void:
	current_cash = clampi(value, 0, 99_999_999)
	cash_changed.emit(current_cash, total_cash)


func set_total_cash(value: int) -> void:
	total_cash = clampi(max(value, current_cash), 0, 99_999_999)
	cash_changed.emit(current_cash, total_cash)


func set_cash_state(new_current_cash: int, new_total_cash: int) -> void:
	current_cash = clampi(new_current_cash, 0, 99_999_999)
	total_cash = clampi(max(new_total_cash, current_cash), 0, 99_999_999)
	cash_changed.emit(current_cash, total_cash)


func add_cash(amount: int) -> void:
	if amount <= 0:
		return

	current_cash = clampi(current_cash + amount, 0, 99_999_999)
	total_cash = clampi(total_cash + amount, 0, 99_999_999)
	cash_changed.emit(current_cash, total_cash)


func spend_cash(amount: int) -> bool:
	if amount <= 0:
		return true
	if amount > current_cash:
		return false

	current_cash -= amount
	cash_changed.emit(current_cash, total_cash)
	return true
