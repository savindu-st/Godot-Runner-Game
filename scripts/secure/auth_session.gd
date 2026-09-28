extends Node

## Stores JWT and refresh token from register/login. Persists in browser and desktop storage.

signal auth_ready(logged_in: bool)
signal profile_updated(body: Dictionary)
signal coins_changed(new_total: int)
signal inventory_changed()

const STORAGE_KEY: String = "epilogue_runner_auth"
const SESSION_SECONDS: int = 60 * 24 * 60 * 60  # 60 days

var token: String = ""
var refresh_token: String = ""
var expires_at: int = 0
var user_id: String = ""
var email: String = ""
var index_number: String = ""
var username: String = "Guest"
var best_distance: int = 0
var best_coins: int = 0
var total_coins: int = 0
var global_rank: int = 0

var powerup_inventory: Dictionary = {
	"coin_magnet": 0,
	"shield": 0,
	"rocket_boost": 0,
	"coin_doubler": 0,
}

var _validating: bool = false
var _refreshing: bool = false


func _ready() -> void:
	if not ApiClient.request_finished.is_connected(_on_api_response):
		ApiClient.request_finished.connect(_on_api_response)
	_restore_from_storage()
	var has_backend := SimConstants.has_supabase() or not SimConstants.API_BASE.is_empty()
	if not has_backend:
		if username == "" or username == "Guest":
			username = "Guest"
		auth_ready.emit(false)
		return
	if is_logged_in():
		var now := int(Time.get_unix_time_from_system())
		if refresh_token != "" and expires_at > 0 and now >= (expires_at - 60):
			_refresh_session()
		else:
			_validate_token()
	else:
		if username == "":
			username = "Guest"
		auth_ready.emit(false)


func is_logged_in() -> bool:
	return token != "" or refresh_token != ""


func set_auth(body: Dictionary) -> void:
	if body.has("access_token"):
		token = str(body.get("access_token", token))
	elif body.has("token"):
		token = str(body.get("token", token))

	if body.has("refresh_token") and str(body["refresh_token"]) != "":
		refresh_token = str(body["refresh_token"])

	var now := int(Time.get_unix_time_from_system())
	if body.has("expires_at"):
		expires_at = int(body["expires_at"])
	elif body.has("expires_in"):
		expires_at = now + int(body["expires_in"])

	if body.has("user") and body["user"] is Dictionary:
		var u: Dictionary = body["user"]
		user_id = str(u.get("id", user_id))
		email = str(u.get("email", email))
		if u.has("user_metadata") and u["user_metadata"] is Dictionary:
			var meta: Dictionary = u["user_metadata"]
			if meta.has("username") and str(meta["username"]) != "":
				username = str(meta["username"])

	if body.has("user_id"):
		user_id = str(body.get("user_id", user_id))
	if body.has("email"):
		email = str(body.get("email", email))
	if body.has("index_number"):
		index_number = str(body.get("index_number", index_number))
	if body.has("username") and str(body["username"]) != "":
		username = str(body.get("username", username))
	elif body.has("name") and str(body["name"]) != "":
		username = str(body.get("name", username))
	if body.has("best_distance"):
		best_distance = int(body.get("best_distance", best_distance))
	if body.has("best_coins"):
		best_coins = int(body.get("best_coins", best_coins))
	if body.has("total_coins"):
		total_coins = int(body.get("total_coins", total_coins))
	if body.has("rank"):
		global_rank = int(body.get("rank", global_rank))

	_persist()
	profile_updated.emit(body)


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
	token = ""
	refresh_token = ""
	expires_at = 0
	user_id = ""
	email = ""
	index_number = ""
	username = "Guest"
	best_distance = 0
	best_coins = 0
	total_coins = 0
	global_rank = 0
	powerup_inventory = {
		"coin_magnet": 0,
		"shield": 0,
		"rocket_boost": 0,
		"coin_doubler": 0,
	}
	BrowserBridge.storage_remove(STORAGE_KEY)
	profile_updated.emit({})
	inventory_changed.emit()


func refresh_profile() -> void:
	if not is_logged_in():
		return
	ApiClient.get_json("/v1/leaderboard/me")


func persist() -> void:
	_persist()


func _persist() -> void:
	var has_backend := SimConstants.has_supabase() or not SimConstants.API_BASE.is_empty()
	if not is_logged_in() and has_backend:
		# Save local guest records & wallet
		BrowserBridge.storage_set(STORAGE_KEY, JSON.stringify({
			"username": username,
			"best_distance": best_distance,
			"best_coins": best_coins,
			"total_coins": total_coins,
			"powerup_inventory": powerup_inventory,
			"saved_at": int(Time.get_unix_time_from_system()),
		}))
		return
	var payload := {
		"token": token,
		"refresh_token": refresh_token,
		"expires_at": expires_at,
		"user_id": user_id,
		"email": email,
		"index_number": index_number,
		"username": username,
		"best_distance": best_distance,
		"best_coins": best_coins,
		"total_coins": total_coins,
		"powerup_inventory": powerup_inventory,
		"rank": global_rank,
		"saved_at": int(Time.get_unix_time_from_system()),
	}
	BrowserBridge.storage_set(STORAGE_KEY, JSON.stringify(payload))


func _restore_from_storage() -> void:
	var raw := BrowserBridge.storage_get(STORAGE_KEY)
	if raw == "":
		username = "Guest"
		return
	var json := JSON.new()
	if json.parse(raw) != OK or not json.data is Dictionary:
		clear()
		return
	var data: Dictionary = json.data
	var saved_at := int(data.get("saved_at", 0))
	var now := int(Time.get_unix_time_from_system())
	var has_backend := SimConstants.has_supabase() or not SimConstants.API_BASE.is_empty()
	if has_backend and saved_at > 0 and (now - saved_at > SESSION_SECONDS):
		clear()
		return
	token = str(data.get("token", ""))
	refresh_token = str(data.get("refresh_token", ""))
	expires_at = int(data.get("expires_at", 0))
	user_id = str(data.get("user_id", ""))
	email = str(data.get("email", ""))
	index_number = str(data.get("index_number", ""))
	username = str(data.get("username", data.get("name", "Guest")))
	if username == "":
		username = "Guest"
	best_distance = int(data.get("best_distance", 0))
	best_coins = int(data.get("best_coins", 0))
	total_coins = int(data.get("total_coins", 0))
	if data.has("powerup_inventory") and data["powerup_inventory"] is Dictionary:
		var inv: Dictionary = data["powerup_inventory"]
		for k in inv.keys():
			powerup_inventory[str(k)] = int(inv[k])
	global_rank = int(data.get("rank", 0))
	inventory_changed.emit()


func _validate_token() -> void:
	if _validating or _refreshing:
		return
	var has_backend := SimConstants.has_supabase() or not SimConstants.API_BASE.is_empty()
	if not has_backend:
		return
	_validating = true
	if SimConstants.has_supabase():
		ApiClient.get_json("/v1/leaderboard/me")
	else:
		ApiClient.get_json("/v1/auth/me")


func _refresh_session() -> void:
	if _refreshing or refresh_token == "":
		return
	var has_backend := SimConstants.has_supabase() or not SimConstants.API_BASE.is_empty()
	if not has_backend:
		return
	_refreshing = true
	_validating = false
	ApiClient.post_unsigned("/v1/auth/refresh", {
		"refresh_token": refresh_token
	})


func _on_api_response(path: String, success: bool, _status: int, body: Dictionary) -> void:
	if path == "/v1/auth/refresh":
		_refreshing = false
		if success:
			set_auth(body)
			auth_ready.emit(true)
			refresh_profile()
		else:
			if _status == 400 or _status == 401 or _status == 403:
				clear()
				auth_ready.emit(false)
			else:
				# Network issue: keep local session
				auth_ready.emit(is_logged_in())
		return

	if path == "/v1/auth/me" or path == "/v1/leaderboard/me":
		_validating = false
		if success:
			if body.get("authenticated") == false:
				# PostgREST returned 200 with authenticated=false! Try refreshing session if refresh_token is present
				if refresh_token != "":
					_refresh_session()
				else:
					clear()
					auth_ready.emit(false)
			else:
				set_auth(body)
				auth_ready.emit(true)
		else:
			if _status == 401 or _status == 403:
				if refresh_token != "":
					_refresh_session()
				else:
					clear()
					auth_ready.emit(false)
			else:
				# Network issue: keep local session
				auth_ready.emit(is_logged_in())
