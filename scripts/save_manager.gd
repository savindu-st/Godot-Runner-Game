extends Node

## Stores local offline stats (distance, coins, powerups).

signal profile_updated(body: Dictionary)
signal coins_changed(new_total: int)
signal inventory_changed()

const STORAGE_KEY: String = "epilogue_runner_save"

var best_distance: int = 0
var best_coins: int = 0
var total_coins: int = 0

var powerup_inventory: Dictionary = {
	"coin_magnet": 0,
	"shield": 0,
	"rocket_boost": 0,
	"coin_doubler": 0,
}

func _ready() -> void:
	_restore_from_storage()


func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	total_coins += amount
	_persist()
	coins_changed.emit(total_coins)
	profile_updated.emit({"total_coins": total_coins})


func spend_coins(amount: int) -> bool:
	if amount <= 0 or total_coins < amount:
		return false
	total_coins -= amount
	_persist()
	coins_changed.emit(total_coins)
	profile_updated.emit({"total_coins": total_coins})
	return true


func get_powerup_count(id: String) -> int:
	return int(powerup_inventory.get(id, 0))


func add_powerup(id: String, count: int = 1) -> void:
	if count <= 0:
		return
	powerup_inventory[id] = get_powerup_count(id) + count
	_persist()
	inventory_changed.emit()


func use_powerup(id: String) -> bool:
	var current := get_powerup_count(id)
	if current <= 0:
		return false
	powerup_inventory[id] = current - 1
	_persist()
	inventory_changed.emit()
	return true


func clear() -> void:
	best_distance = 0
	best_coins = 0
	total_coins = 0
	powerup_inventory = {
		"coin_magnet": 0,
		"shield": 0,
		"rocket_boost": 0,
		"coin_doubler": 0,
	}
	BrowserBridge.storage_remove(STORAGE_KEY)
	profile_updated.emit({})
	inventory_changed.emit()


func persist() -> void:
	_persist()


func _persist() -> void:
	var payload := {
		"best_distance": best_distance,
		"best_coins": best_coins,
		"total_coins": total_coins,
		"powerup_inventory": powerup_inventory,
		"saved_at": int(Time.get_unix_time_from_system()),
	}
	BrowserBridge.storage_set(STORAGE_KEY, JSON.stringify(payload))


func _restore_from_storage() -> void:
	var raw := BrowserBridge.storage_get(STORAGE_KEY)
	if raw == "":
		return
	var json := JSON.new()
	if json.parse(raw) != OK or not json.data is Dictionary:
		clear()
		return
	var data: Dictionary = json.data
	
	best_distance = int(data.get("best_distance", 0))
	best_coins = int(data.get("best_coins", 0))
	total_coins = int(data.get("total_coins", 0))
	if data.has("powerup_inventory") and data["powerup_inventory"] is Dictionary:
		var inv: Dictionary = data["powerup_inventory"]
		for k in inv.keys():
			powerup_inventory[str(k)] = int(inv[k])
	
	inventory_changed.emit()
