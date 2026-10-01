extends Node
## Coins: the single soft currency.

signal coins_changed(total: int, delta: int)


func get_coins() -> int:
	return int(SaveManager.data.get("coins", 0))


func add_coins(amount: int, save: bool = true) -> void:
	if amount <= 0:
		return
	SaveManager.data["coins"] = get_coins() + amount
	SaveManager.add_stat("total_coins_earned", amount)
	coins_changed.emit(get_coins(), amount)
	if save:
		SaveManager.save_game()


func can_afford(price: int) -> bool:
	return get_coins() >= price


func spend(price: int) -> bool:
	if price < 0 or not can_afford(price):
		return false
	SaveManager.data["coins"] = get_coins() - price
	coins_changed.emit(get_coins(), -price)
	return true
