extends Node

const SIM_VERSION: int = 11
const CLIENT_BUILD: String = "dev"

const NUM_LANES: int = 3
const LANE_X: Array = [-2.0, 0.0, 2.0]

const SEGMENT_LENGTH: float = 25000.0
const CHUNK_LENGTH: float = 200.0

const SCROLL_SPEED: float = 15.0
const SPEED_RAMP_INTERVAL_SEC: float = 10.0
const SPEED_RAMP_INCREMENT: float = 2.0
const LANE_SWITCH_SPEED: float = 14.0
const LANE_SWITCH_COOLDOWN_MS: int = 100

const JUMP_FORCE: float = 9.0
const GRAVITY: float = 22.0
const JUMP_CLEAR_Y: float = 0.72

const HIT_Z: float = 0.9
const HIT_X: float = 0.9

const COIN_SCORE: int = 1
const DISTANCE_SCORE_PER_UNIT: float = 0.0
const LOCAL_SCORE_PER_SEC: float = 0.0

# Local dev: http://localhost:8080 — GitHub Pages CI replaces this at export time.
const API_BASE: String = "http://localhost:8080"
const OFFLINE_FALLBACK: bool = false
const DEBUG_API: bool = false
const SECURE_SPAWNS: bool = true

const SPAWN_Z: float = -50.0
const SPAWN_LEAD: float = 55.0

# --- spawn density (segment_map.gd) — max practical density ---
const MIN_ROCK_GAP: float = 18.0
const MIN_COIN_GAP: float = 4.0
const ROCKS_PER_CHUNK_MIN: int = 8
const ROCKS_PER_CHUNK_MAX: int = 15
const BARRIER_CHUNK_CHANCE: float = 0.48
const BARRIER_SYNC_JITTER: float = 0.6
const BARRIER_COIN_MIN: int = 10
const BARRIER_COIN_MAX: int = 18
const COIN_LINES_MIN: int = 4
const COIN_LINES_MAX: int = 8
const COIN_COUNT_MIN: int = 14
const COIN_COUNT_MAX: int = 22
const EXTRA_COIN_BURST_CHANCE: float = 0.82
const EXTRA_COIN_BURST_MIN: int = 10
const EXTRA_COIN_BURST_MAX: int = 16


static func scroll_speed_at_sec(elapsed_sec: float) -> float:
	if elapsed_sec < 0.0:
		elapsed_sec = 0.0
	var tier: int = int(floor(elapsed_sec / SPEED_RAMP_INTERVAL_SEC))
	return SCROLL_SPEED + float(tier) * SPEED_RAMP_INCREMENT


static func duration_ms_for_distance(distance: float) -> float:
	if distance <= 0.0:
		return 0.0
	var remaining: float = distance
	var tier: int = 0
	var ms: float = 0.0
	while remaining > 0.0:
		var speed: float = scroll_speed_at_sec(float(tier) * SPEED_RAMP_INTERVAL_SEC)
		var tier_dist: float = speed * SPEED_RAMP_INTERVAL_SEC
		if remaining <= tier_dist:
			ms += (remaining / speed) * 1000.0
			return ms
		remaining -= tier_dist
		ms += SPEED_RAMP_INTERVAL_SEC * 1000.0
		tier += 1
	return ms


static func distance_at_duration_ms(duration_ms: int) -> float:
	if duration_ms <= 0:
		return 0.0
	var elapsed: float = float(duration_ms) / 1000.0
	var tier: int = int(floor(elapsed / SPEED_RAMP_INTERVAL_SEC))
	var rem: float = elapsed - float(tier) * SPEED_RAMP_INTERVAL_SEC
	var dist: float = 0.0
	for i in tier:
		dist += scroll_speed_at_sec(float(i) * SPEED_RAMP_INTERVAL_SEC) * SPEED_RAMP_INTERVAL_SEC
	dist += scroll_speed_at_sec(float(tier) * SPEED_RAMP_INTERVAL_SEC) * rem
	return dist


static func duration_ms_for_distance_from_start(distance: float, start_elapsed_sec: float) -> float:
	if distance <= 0.0:
		return 0.0
	var remaining: float = distance
	var elapsed: float = maxf(0.0, start_elapsed_sec)
	var ms: float = 0.0
	while remaining > 0.0:
		var speed: float = scroll_speed_at_sec(elapsed)
		var tier: int = int(floor(elapsed / SPEED_RAMP_INTERVAL_SEC))
		var tier_end: float = float(tier + 1) * SPEED_RAMP_INTERVAL_SEC
		var time_left_in_tier: float = tier_end - elapsed
		var dist_in_tier: float = speed * time_left_in_tier
		if remaining <= dist_in_tier:
			ms += (remaining / speed) * 1000.0
			return ms
		remaining -= dist_in_tier
		ms += time_left_in_tier * 1000.0
		elapsed = tier_end
	return ms
