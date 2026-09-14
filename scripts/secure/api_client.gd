extends Node

signal request_finished(path: String, success: bool, status: int, body: Dictionary)

var _http: HTTPRequest
var _queue: Array[Dictionary] = []
var _in_flight: Dictionary = {}
var _flight_timer: Timer

const REQUEST_TIMEOUT_SEC: float = 15.0
const FLIGHT_WATCHDOG_SEC: float = 20.0


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = REQUEST_TIMEOUT_SEC
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_flight_timer = Timer.new()
	_flight_timer.one_shot = true
	add_child(_flight_timer)
	_flight_timer.timeout.connect(_on_flight_timeout)


func post_unsigned(path: String, body_dict: Dictionary = {}) -> void:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if SimConstants.has_supabase():
		headers.append("apikey: " + SimConstants.SUPABASE_ANON_KEY)
		headers.append("Authorization: Bearer " + SimConstants.SUPABASE_ANON_KEY)
	post_with_headers(path, body_dict, headers)


func post_with_jwt(path: String, body_dict: Dictionary = {}) -> void:
	if not AuthSession.is_logged_in():
		request_finished.emit(path, false, 0, {"error": "not_logged_in"})
		return
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Authorization: Bearer " + AuthSession.token,
	]
	if SimConstants.has_supabase():
		headers.append("apikey: " + SimConstants.SUPABASE_ANON_KEY)
	post_with_headers(path, body_dict, headers)


func post_with_headers(path: String, body_dict: Dictionary, headers: PackedStringArray) -> void:
	var body := JSON.stringify(body_dict)
	_enqueue(path, HTTPClient.METHOD_POST, headers, body)


func post_signed(path: String, body_dict: Dictionary) -> void:
	# If using Supabase directly, route RPC score submissions directly
	if SimConstants.has_supabase() and (path == "/v1/run/finish" or path == "/v1/score/submit"):
		post_with_jwt(path, body_dict)
		return

	if not RunSession.has_session():
		_log("POST %s blocked — no session yet" % path)
		request_finished.emit(path, false, 0, {"error": "no_session"})
		return

	var body := JSON.stringify(body_dict)
	var ts := str(int(Time.get_unix_time_from_system() * 1000.0))
	var nonce := _uuid()
	var sig := HmacSign.sign(RunSession.signing_secret, "POST", path, ts, nonce, body)
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"X-Session-Id: " + RunSession.session_id,
		"X-Timestamp: " + ts,
		"X-Nonce: " + nonce,
		"X-Signature: " + sig,
	]
	_enqueue(path, HTTPClient.METHOD_POST, headers, body)


func get_json(path: String) -> void:
	var headers: PackedStringArray = []
	if SimConstants.has_supabase():
		headers.append("apikey: " + SimConstants.SUPABASE_ANON_KEY)
		if AuthSession.is_logged_in():
			headers.append("Authorization: Bearer " + AuthSession.token)
		else:
			headers.append("Authorization: Bearer " + SimConstants.SUPABASE_ANON_KEY)
	elif AuthSession.is_logged_in():
		headers.append("Authorization: Bearer " + AuthSession.token)
	_enqueue(path, HTTPClient.METHOD_GET, headers, "")


func _enqueue(path: String, method: int, headers: PackedStringArray, body: String) -> void:
	var url := _full_url(path)
	var method_name := "GET" if method == HTTPClient.METHOD_GET else "POST"
	_log("%s %s -> %s" % [method_name, path, url])
	_queue.append({
		"path": path,
		"url": url,
		"method": method,
		"headers": headers,
		"body": body,
	})
	_pump_queue()


func _pump_queue() -> void:
	if not _in_flight.is_empty() or _queue.is_empty():
		return

	_in_flight = _queue.pop_front()
	var err := _http.request(
		_in_flight["url"],
		_in_flight["headers"],
		_in_flight["method"],
		_in_flight["body"],
	)
	if err != OK:
		var path: String = _in_flight.get("path", "")
		_log("%s failed to start (err %d)" % [path, err])
		_finish_request(path, false, 0, {"error": "request_failed", "code": err})
		return
	_flight_timer.start(FLIGHT_WATCHDOG_SEC)


func _full_url(path: String) -> String:
	if path.begins_with("http://") or path.begins_with("https://"):
		return path
	if SimConstants.has_supabase():
		var base := SimConstants.SUPABASE_URL.rstrip("/")
		if path.begins_with("/auth/v1") or path.begins_with("/rest/v1"):
			return base + path
		if path == "/v1/auth/login":
			return base + "/auth/v1/token?grant_type=password"
		if path == "/v1/auth/register" or path == "/v1/auth/signup":
			return base + "/auth/v1/signup"
		if path == "/v1/auth/me":
			return base + "/auth/v1/user"
		if path == "/v1/leaderboard":
			return base + "/rest/v1/profiles?select=username,best_distance,best_coins&order=best_distance.desc,updated_at.asc&limit=20"
		if path == "/v1/leaderboard/me":
			return base + "/rest/v1/rpc/get_my_rank"
		if path == "/v1/run/finish" or path == "/v1/score/submit":
			return base + "/rest/v1/rpc/submit_score"
		return base + path
	var base := SimConstants.API_BASE.rstrip("/")
	if path.begins_with("/"):
		return base + path
	return base + "/" + path


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body_bytes: PackedByteArray) -> void:
	var path: String = _in_flight.get("path", "")
	if path == "":
		return
	var parsed: Dictionary = {}
	var raw := ""
	if body_bytes.size() > 0:
		raw = body_bytes.get_string_from_utf8()
		var json := JSON.new()
		if json.parse(raw) == OK:
			if json.data is Dictionary:
				parsed = json.data
			elif json.data is Array:
				parsed = {"data": json.data}
			else:
				parsed = {"value": json.data, "raw": raw}
		else:
			parsed = {"raw": raw}

	var ok := result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300
	if not ok:
		if not parsed.has("error"):
			if parsed.has("error_description"):
				parsed["error"] = parsed["error_description"]
			elif parsed.has("msg"):
				parsed["error"] = parsed["msg"]
			elif parsed.has("message"):
				parsed["error"] = parsed["message"]
			elif result != HTTPRequest.RESULT_SUCCESS:
				parsed["error"] = "connection_failed"
				parsed["message"] = "Could not reach server."
			elif code == 0:
				parsed["error"] = "connection_failed"
				parsed["message"] = "Could not reach server."

	if SimConstants.DEBUG_API:
		if ok:
			_log("OK %s HTTP %d -> %s" % [path, code, _truncate(raw)])
		else:
			_log("FAIL %s result=%d HTTP %d -> %s" % [path, result, code, _truncate(raw)])

	_finish_request(path, ok, code, parsed)


func _on_flight_timeout() -> void:
	if _in_flight.is_empty():
		return
	var path: String = _in_flight.get("path", "")
	_log("watchdog timeout on %s" % path)
	_http.cancel_request()
	if not _in_flight.is_empty():
		_finish_request(path, false, 0, {
			"error": "timeout",
			"message": "Server did not respond in time.",
		})


func _finish_request(path: String, ok: bool, code: int, parsed: Dictionary) -> void:
	if _in_flight.is_empty() or _in_flight.get("path", "") != path:
		return
	_flight_timer.stop()
	_in_flight = {}
	request_finished.emit(path, ok, code, parsed)
	_pump_queue()


func _log(msg: String) -> void:
	if SimConstants.DEBUG_API:
		print("[ApiClient] ", msg)


func _truncate(s: String, max_len: int = 240) -> String:
	if s.length() <= max_len:
		return s
	return s.substr(0, max_len) + "…"


func _uuid() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%08x-%04x-%04x-%04x-%012x" % [
		rng.randi(),
		rng.randi() & 0xFFFF,
		(rng.randi() & 0x0FFF) | 0x4000,
		(rng.randi() & 0x3FFF) | 0x8000,
		rng.randi() & 0xFFFFFFFFFFFF,
	]
