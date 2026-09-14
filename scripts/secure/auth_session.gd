extends Node

## Stores JWT from register/login. Persists in browser for up to 60 days.

signal auth_ready(logged_in: bool)
signal profile_updated(body: Dictionary)

const STORAGE_KEY: String = "epilogue_runner_auth"
const SESSION_SECONDS: int = 60 * 24 * 60 * 60  # 60 days

var token: String = ""
var user_id: String = ""
var email: String = ""
var index_number: String = ""
var username: String = "Guest"
var best_distance: int = 0
var best_coins: int = 0
var global_rank: int = 0

var _validating: bool = false


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
		_validate_token()
	else:
		if username == "":
			username = "Guest"
		auth_ready.emit(false)


func is_logged_in() -> bool:
	return token != ""


func set_auth(body: Dictionary) -> void:
	if body.has("access_token"):
		token = str(body.get("access_token", token))
	elif body.has("token"):
		token = str(body.get("token", token))

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
	if body.has("rank"):
		global_rank = int(body.get("rank", global_rank))

	_persist()
	profile_updated.emit(body)


func clear() -> void:
	token = ""
	user_id = ""
	email = ""
	index_number = ""
	username = "Guest"
	best_distance = 0
	best_coins = 0
	global_rank = 0
	BrowserBridge.storage_remove(STORAGE_KEY)
	profile_updated.emit({})


func refresh_profile() -> void:
	if not is_logged_in():
		return
	ApiClient.get_json("/v1/leaderboard/me")


func _persist() -> void:
	var has_backend := SimConstants.has_supabase() or not SimConstants.API_BASE.is_empty()
	if token == "" and has_backend:
		# Don't persist empty token if online mode is configured, unless guest has local name
		if username != "" and username != "Guest":
			BrowserBridge.storage_set(STORAGE_KEY, JSON.stringify({
				"username": username,
				"best_distance": best_distance,
				"best_coins": best_coins,
				"saved_at": int(Time.get_unix_time_from_system()),
			}))
		return
	var payload := {
		"token": token,
		"user_id": user_id,
		"email": email,
		"index_number": index_number,
		"username": username,
		"best_distance": best_distance,
		"best_coins": best_coins,
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
	if has_backend and (saved_at <= 0 or now - saved_at > SESSION_SECONDS):
		clear()
		return
	token = str(data.get("token", ""))
	user_id = str(data.get("user_id", ""))
	email = str(data.get("email", ""))
	index_number = str(data.get("index_number", ""))
	username = str(data.get("username", data.get("name", "Guest")))
	if username == "":
		username = "Guest"
	best_distance = int(data.get("best_distance", 0))
	best_coins = int(data.get("best_coins", 0))
	global_rank = int(data.get("rank", 0))


func _validate_token() -> void:
	if _validating:
		return
	var has_backend := SimConstants.has_supabase() or not SimConstants.API_BASE.is_empty()
	if not has_backend:
		return
	_validating = true
	if SimConstants.has_supabase():
		ApiClient.get_json("/v1/leaderboard/me")
	else:
		ApiClient.get_json("/v1/auth/me")


func _on_api_response(path: String, success: bool, _status: int, body: Dictionary) -> void:
	if path == "/v1/auth/me" or path == "/v1/leaderboard/me":
		_validating = false
		if success:
			set_auth(body)
			auth_ready.emit(true)
		else:
			# If token is invalid or expired, clear and notify
			if _status == 401 or _status == 403:
				clear()
				auth_ready.emit(false)
			else:
				# Network issue: keep local session
				auth_ready.emit(is_logged_in())
