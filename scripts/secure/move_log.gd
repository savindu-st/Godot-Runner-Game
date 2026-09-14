extends Node

var segment_index: int = 0
var segment_seed: int = 0
var initial_lane: int = 1
var started_at_ms: int = 0
var events: Array = []
var _last_lane_change_ms: int = -99999


func reset(p_segment_index: int, p_seed: int, p_lane: int) -> void:
	segment_index = p_segment_index
	segment_seed = p_seed
	initial_lane = p_lane
	started_at_ms = Time.get_ticks_msec()
	events.clear()
	_last_lane_change_ms = -99999


func segment_elapsed_ms() -> int:
	return Time.get_ticks_msec() - started_at_ms


func add_event(kind: String, data: Dictionary) -> void:
	var e: Dictionary = data.duplicate()
	e["kind"] = kind
	e["t_ms"] = segment_elapsed_ms()
	events.append(e)


func can_log_lane_change() -> bool:
	return segment_elapsed_ms() - _last_lane_change_ms >= SimConstants.LANE_SWITCH_COOLDOWN_MS


func log_lane_change(from_lane: int, to_lane: int, distance: float) -> void:
	if from_lane == to_lane:
		return
	_last_lane_change_ms = segment_elapsed_ms()
	add_event("lane_change", {
		"from": from_lane,
		"to": to_lane,
		"distance": distance,
	})


func log_jump_start(distance: float) -> void:
	add_event("jump_start", {"distance": distance})


func log_jump_land(distance: float) -> void:
	add_event("jump_land", {"distance": distance})


func log_coin(object_id: int, lane: int, distance: float) -> void:
	add_event("coin", {
		"object_id": object_id,
		"lane": lane,
		"distance": distance,
	})


func log_collision(object_id: int, lane: int, distance: float) -> void:
	add_event("collision", {
		"object_id": object_id,
		"lane": lane,
		"distance": distance,
	})


func to_dict(end_reason: String, final_distance: float) -> Dictionary:
	return {
		"sim_version": SimConstants.SIM_VERSION,
		"segment_index": segment_index,
		"seed": segment_seed,
		"initial_lane": initial_lane,
		"events": events.duplicate(true),
		"end_reason": end_reason,
		"final_distance": final_distance,
		"client_duration_ms": segment_elapsed_ms(),
		"run_elapsed_ms": RunSession.run_scroll_elapsed_ms(),
	}
