extends Node

## Stores JWT from register/login. Persists in browser for up to 60 days.

signal auth_ready(logged_in: bool)
signal profile_updated(body: Dictionary)

const STORAGE_KEY: String = "epilogue_runner_auth"
const SESSION_SECONDS: int = 60 * 24 * 60 * 60  # 60 days

var token: String = ""
var user_id: int = 0
var index_number: String = ""
var username: String = ""
var best_coins: int = 0

var _validating: bool = false


func _ready() -> void:
	if not ApiClient.request_finished.is_connected(_on_api_response):
		ApiClient.request_finished.connect(_on_api_response)
	_restore_from_storage()
	if SimConstants.API_BASE == "":
		auth_ready.emit(false)
		return
	if is_logged_in():
		_validate_token()
	else:
		auth_ready.emit(false)


func is_logged_in() -> bool:
	return token != ""


func set_auth(body: Dictionary) -> void:
	token = str(body.get("token", token))
	user_id = int(body.get("user_id", user_id))
	index_number = str(body.get("index_number", index_number))
	username = str(body.get("username", body.get("name", username)))
	best_coins = int(body.get("best_coins", best_coins))
	_persist()
	profile_updated.emit(body)


func clear() -> void:
	token = ""
	user_id = 0
	index_number = ""
	username = ""
	best_coins = 0
	BrowserBridge.storage_remove(STORAGE_KEY)


func _persist() -> void:
	if token == "" and not SimConstants.API_BASE.is_empty():
		return
	var payload := {
		"token": token,
		"user_id": user_id,
		"index_number": index_number,
		"username": username,
		"best_coins": best_coins,
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
	var saved_at := int(data.get("saved_at", 0))
	var now := int(Time.get_unix_time_from_system())
	if not SimConstants.API_BASE.is_empty() and (saved_at <= 0 or now - saved_at > SESSION_SECONDS):
		clear()
		return
	token = str(data.get("token", ""))
	user_id = int(data.get("user_id", 0))
	index_number = str(data.get("index_number", ""))
	username = str(data.get("username", data.get("name", "")))
	best_coins = int(data.get("best_coins", 0))


func _validate_token() -> void:
	if _validating or SimConstants.API_BASE == "":
		return
	_validating = true
	ApiClient.get_json("/v1/auth/me")


func _on_api_response(path: String, success: bool, _status: int, body: Dictionary) -> void:
	if path != "/v1/auth/me":
		return
	_validating = false
	if success:
		set_auth(body)
		auth_ready.emit(true)
	else:
		clear()
		auth_ready.emit(false)
