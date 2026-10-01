extends Node
## Coins (the single soft currency) and stars (earned only by winning
## levels, spent on renovation tasks). Neither can go negative.

signal coins_changed(total: int, delta: int)
signal stars_changed(total: int, delta: int)


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


# --- Stars -------------------------------------------------------------------

func get_stars() -> int:
	return int(SaveManager.game().get("stars", 0))


func add_stars(amount: int, save: bool = true) -> void:
	if amount <= 0:
		return
	SaveManager.game()["stars"] = get_stars() + amount
	SaveManager.add_game_stat("stars_earned", amount)
	stars_changed.emit(get_stars(), amount)
	if save:
		SaveManager.save_game()


func spend_stars(amount: int) -> bool:
	if amount < 0 or get_stars() < amount:
		return false
	SaveManager.game()["stars"] = get_stars() - amount
	stars_changed.emit(get_stars(), -amount)
	return true
