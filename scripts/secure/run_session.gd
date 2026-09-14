extends Node

signal run_ready(success: bool, error_message: String)
signal checkpoint_resolved(accepted: bool, data: Dictionary)
signal finish_resolved(success: bool, data: Dictionary)

var session_id: String = ""
var signing_secret: PackedByteArray = PackedByteArray()
var run_id: String = ""
var segment_index: int = 0
var current_seed: int = 0
var run_total_coins: int = 0
var offline_mode: bool = true
var run_active: bool = false
var run_scroll_start_ms: int = -1
var _run_scroll_peak_sec: float = 0.0

var _waiting_checkpoint: bool = false


func _ready() -> void:
	offline_mode = true
	ApiClient.request_finished.connect(_on_api_response)
	_log("API_BASE=%s offline=%s" % [SimConstants.API_BASE, offline_mode])


func has_session() -> bool:
	return session_id != "" and signing_secret.size() > 0


func is_online() -> bool:
	return not offline_mode and SimConstants.API_BASE != ""


func mark_run_scroll_started() -> void:
	run_scroll_start_ms = Time.get_ticks_msec()
	_run_scroll_peak_sec = 0.0


func run_scroll_elapsed_sec() -> float:
	if run_scroll_start_ms < 0:
		return _run_scroll_peak_sec
	var t: float = float(Time.get_ticks_msec() - run_scroll_start_ms) / 1000.0
	_run_scroll_peak_sec = maxf(_run_scroll_peak_sec, t)
	return _run_scroll_peak_sec


func run_scroll_elapsed_ms() -> int:
	return int(round(run_scroll_elapsed_sec() * 1000.0))


func _clear_run_scroll_clock() -> void:
	run_scroll_start_ms = -1
	_run_scroll_peak_sec = 0.0


func prepare_run() -> void:
	_start_offline_run("")


func restart_run() -> void:
	_start_offline_run("")


func _reset_online_state() -> void:
	offline_mode = false
	run_active = false
	session_id = ""
	signing_secret = PackedByteArray()
	run_id = ""
	segment_index = 0
	run_total_coins = 0
	_waiting_checkpoint = false
	_clear_run_scroll_clock()


func _start_offline_run(error_hint: String) -> void:
	offline_mode = true
	session_id = _random_id()
	signing_secret = _random_secret()
	run_id = _random_id()
	segment_index = 0
	current_seed = _random_segment_seed()
	run_total_coins = 0
	run_active = true
	_clear_run_scroll_clock()
	if error_hint != "":
		_log("offline fallback: %s" % error_hint)
	run_ready.emit(true, error_hint)


func _start_online_run() -> void:
	run_active = false
	_log("requesting session...")
	ApiClient.post_with_jwt("/v1/session/start", {})


func _begin_online_run() -> void:
	_log("session ok, requesting run/start...")
	ApiClient.post_signed("/v1/run/start", {})


func ensure_segment_for_level(initial_lane: int) -> void:
	if not run_active:
		if SimConstants.API_BASE.is_empty():
			_start_offline_run("level started without active run")
		else:
			_log("no active run — press PLAY from menu first")
			return
	MoveLog.reset(segment_index, current_seed, initial_lane)


func advance_offline_segment(payload: Dictionary) -> void:
	_log("checkpoint (offline): %s" % JSON.stringify(payload))
	segment_index += 1
	current_seed = _random_segment_seed()
	run_total_coins += _count_coins_in_payload(payload)
	checkpoint_resolved.emit(true, {
		"accepted": true,
		"next_seed": current_seed,
		"next_segment_index": segment_index,
		"segment_coins": _count_coins_in_payload(payload),
		"run_total_coins": run_total_coins,
	})


func submit_checkpoint(final_distance: float) -> void:
	if _waiting_checkpoint:
		return
	var payload := MoveLog.to_dict("segment_complete", final_distance)
	if offline_mode:
		advance_offline_segment(payload)
		return
	_waiting_checkpoint = true
	_log("checkpoint segment %d dist=%.1f payload=%s" % [segment_index, final_distance, JSON.stringify(payload)])
	ApiClient.post_signed("/v1/run/checkpoint", {
		"run_id": run_id,
		"move_log": payload,
	})


func submit_finish(final_distance: float, end_reason: String = "collision", total_distance: float = -1.0) -> void:
	var payload := MoveLog.to_dict(end_reason, final_distance)
	var duration: float = run_scroll_elapsed_sec()
	
	# Calculate total coins collected from move_log if not already counted
	var coins_in_segment := _count_coins_in_payload(payload)
	run_total_coins += coins_in_segment

	var dist_meters: int = int(round(total_distance if total_distance >= 0.0 else final_distance))

	# If Supabase is configured and player is logged in, submit to Supabase RPC
	if SimConstants.has_supabase() and AuthSession.is_logged_in():
		_log("Submitting finish to Supabase: dist=%dm coins=%d duration=%.1fs" % [dist_meters, run_total_coins, duration])
		ApiClient.post_with_jwt("/v1/run/finish", {
			"p_distance": dist_meters,
			"p_duration_sec": duration,
			"p_coins": run_total_coins,
		})
		return

	# If custom API server is configured with HMAC session
	if not offline_mode and SimConstants.API_BASE != "":
		_log("finish %s dist=%.1f payload=%s" % [end_reason, final_distance, JSON.stringify(payload)])
		ApiClient.post_signed("/v1/run/finish", {
			"run_id": run_id,
			"move_log": payload,
		})
		return

	# Guest / Offline Mode
	_log("finish (guest/offline): dist=%dm coins=%d" % [dist_meters, run_total_coins])
	run_active = false
	var is_new_best := dist_meters > AuthSession.best_distance
	if is_new_best:
		AuthSession.best_distance = dist_meters
	if run_total_coins > AuthSession.best_coins:
		AuthSession.best_coins = run_total_coins
	if is_new_best or run_total_coins > AuthSession.best_coins:
		AuthSession._persist()

	finish_resolved.emit(true, {
		"accepted": true,
		"final_distance": dist_meters,
		"best_distance": AuthSession.best_distance,
		"final_coins": run_total_coins,
		"best_coins": AuthSession.best_coins,
		"rank": 0,
		"is_new_best": is_new_best,
		"guest": true,
	})


func apply_next_segment(initial_lane: int) -> void:
	# Segment map/log reset only — never reset run_scroll_start_ms (speed keeps climbing).
	MoveLog.reset(segment_index, current_seed, initial_lane)


func _on_api_response(path: String, success: bool, status: int, body: Dictionary) -> void:
	if path == "/v1/session/start":
		if success:
			session_id = str(body.get("session_id", ""))
			var secret_b64 := str(body.get("signing_secret", ""))
			signing_secret = Marshalls.base64_to_raw(secret_b64) if secret_b64 != "" else PackedByteArray()
			if not has_session():
				_handle_online_failure("session/start missing session_id or signing_secret")
				return
			_log("session_id=%s" % session_id)
			_begin_online_run()
		else:
			_handle_online_failure(_format_api_error("session/start", status, body))
		return

	if path == "/v1/run/start":
		if success:
			run_id = str(body.get("run_id", ""))
			segment_index = int(body.get("segment_index", 0))
			current_seed = int(body.get("seed", _random_segment_seed()))
			run_total_coins = 0
			run_active = true
			offline_mode = false
			_clear_run_scroll_clock()
			_log("run_id=%s seed=%d (online)" % [run_id, current_seed])
			run_ready.emit(true, "")
		else:
			_handle_online_failure(_format_api_error("run/start", status, body))
		return

	if path == "/v1/run/checkpoint":
		_waiting_checkpoint = false
		if success and body.get("accepted", false):
			run_total_coins = int(body.get("run_total_coins", body.get("run_total_score", run_total_coins)))
			segment_index = int(body.get("next_segment_index", segment_index + 1))
			current_seed = int(body.get("next_seed", _random_segment_seed()))
			_log("checkpoint accepted coins=%d next_seed=%d" % [run_total_coins, current_seed])
			checkpoint_resolved.emit(true, body)
		else:
			_log("checkpoint rejected: %s" % str(body))
			checkpoint_resolved.emit(false, body)
		return

	if path == "/v1/run/finish":
		run_active = false
		var accepted: bool = success and bool(body.get("accepted", false))
		if accepted:
			var submitted_dist: int = int(body.get("submitted_distance", body.get("final_distance", 0)))
			var best_dist: int = int(body.get("best_distance", AuthSession.best_distance))
			run_total_coins = int(body.get("final_coins", body.get("submitted_coins", run_total_coins)))
			var best_c: int = int(body.get("best_coins", AuthSession.best_coins))
			var rank: int = int(body.get("rank", AuthSession.global_rank))
			AuthSession.best_distance = best_dist
			AuthSession.best_coins = best_c
			AuthSession.global_rank = rank
			AuthSession.profile_updated.emit(body)
			_log("finish accepted dist=%dm coins=%d rank=%s" % [submitted_dist, run_total_coins, str(body.get("rank", "?"))])
			var res := body.duplicate()
			res["final_distance"] = submitted_dist
			res["best_distance"] = best_dist
			res["final_coins"] = run_total_coins
			res["best_coins"] = best_c
			res["rank"] = rank
			finish_resolved.emit(true, res)
		else:
			var err_body := body.duplicate()
			if not err_body.has("message"):
				err_body["message"] = _format_finish_error(success, status, body)
			_log("finish rejected: %s" % str(err_body))
			err_body["best_distance"] = AuthSession.best_distance
			err_body["final_coins"] = run_total_coins
			err_body["best_coins"] = AuthSession.best_coins
			finish_resolved.emit(false, err_body)


func _handle_online_failure(reason: String) -> void:
	if SimConstants.OFFLINE_FALLBACK:
		_start_offline_run(reason)
	else:
		run_ready.emit(false, reason)


func _format_api_error(label: String, status: int, body: Dictionary) -> String:
	if str(body.get("error", "")) == "timeout":
		return "%s timed out — server not responding." % label
	if str(body.get("error", "")) in ["connection_failed", "request_failed"] or status == 0:
		return "%s failed — cannot reach server at %s." % [label, SimConstants.API_BASE]
	var err := str(body.get("error", body.get("message", body.get("raw", ""))))
	if err == "":
		err = str(body)
	return "%s HTTP %d — %s" % [label, status, err]


func _format_finish_error(success: bool, status: int, body: Dictionary) -> String:
	if not success:
		var code := str(body.get("error", ""))
		if code == "request_failed" or status == 0:
			return "Connection failed — could not validate score."
		if code == "not_logged_in":
			return "Session expired — log in again."
		if code == "no_session":
			return "Run session lost — return to menu and play again."
	return _format_api_error("finish", status, body)


func _count_coins_in_payload(payload: Dictionary) -> int:
	var coins: int = 0
	for e in payload.get("events", []):
		if e is Dictionary and e.get("kind", "") == "coin":
			coins += 1
	return coins


func _random_segment_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(100000000, 999999999)


func _random_id() -> String:
	return "%d-%d" % [Time.get_ticks_usec(), randi()]


func _random_secret() -> PackedByteArray:
	var buf := PackedByteArray()
	buf.resize(32)
	for i in 32:
		buf[i] = randi() % 256
	return buf


func _log(msg: String) -> void:
	if SimConstants.DEBUG_API:
		print("[RunSession] ", msg)
