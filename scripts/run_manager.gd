extends Node

signal run_ready(success: bool, error_message: String)
signal finish_resolved(success: bool, data: Dictionary)

var run_total_coins: int = 0
var coins_awarded_for_run: bool = false
var run_active: bool = false
var run_scroll_start_ms: int = -1
var _run_scroll_peak_sec: float = 0.0

func _ready() -> void:
	pass

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
	_start_offline_run()

func restart_run() -> void:
	_start_offline_run()

func _start_offline_run() -> void:
	run_total_coins = 0
	coins_awarded_for_run = false
	run_active = true
	_clear_run_scroll_clock()
	run_ready.emit(true, "")

func add_run_coins(amount: int) -> void:
	run_total_coins += amount

func submit_finish(final_distance: float) -> void:
	var dist_meters: int = int(round(final_distance))

	run_active = false
	var is_new_best := dist_meters > SaveManager.best_distance
	if is_new_best:
		SaveManager.best_distance = dist_meters
	
	if run_total_coins > SaveManager.best_coins:
		SaveManager.best_coins = run_total_coins
	
	if not coins_awarded_for_run:
		coins_awarded_for_run = true
		SaveManager.add_coins(run_total_coins)
	elif is_new_best or run_total_coins > SaveManager.best_coins:
		SaveManager.persist()

	finish_resolved.emit(true, {
		"accepted": true,
		"final_distance": dist_meters,
		"best_distance": SaveManager.best_distance,
		"final_coins": run_total_coins,
		"best_coins": SaveManager.best_coins,
		"total_coins": SaveManager.total_coins,
		"is_new_best": is_new_best,
	})
