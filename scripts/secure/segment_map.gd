class_name SegmentMapGen
extends RefCounted

## Deterministic spawns — difficulty ramps within each segment.
## Barriers block all 3 lanes at once (jump to clear). Coins trail before the wall.


static func generate(segment_seed: int) -> Array:
	var entries: Array = []
	var object_id: int = 1
	var chunk_count: int = int(ceil(SimConstants.SEGMENT_LENGTH / SimConstants.CHUNK_LENGTH))
	var lane_last_rock: Array = [-9999.0, -9999.0, -9999.0]

	for chunk_index in chunk_count:
		var rng := SeededRng.new(SeededRng.chunk_seed(segment_seed, chunk_index))
		var chunk_start: float = chunk_index * SimConstants.CHUNK_LENGTH
		var difficulty: float = float(chunk_index) / maxf(float(chunk_count - 1), 1.0)
		var chunk_rocks: Array = []

		if rng.randf() < SimConstants.BARRIER_CHUNK_CHANCE:
			object_id = _spawn_barrier(rng, chunk_start, entries, chunk_rocks, lane_last_rock, object_id)

		var target_rocks: int = int(round(lerpf(
			float(SimConstants.ROCKS_PER_CHUNK_MIN),
			float(SimConstants.ROCKS_PER_CHUNK_MAX),
			difficulty
		)))
		target_rocks = maxi(target_rocks - chunk_rocks.size(), 1)

		var lanes: Array = [0, 1, 2]
		_shuffle_array(lanes, rng)

		for i in target_rocks:
			var lane: int = lanes[i % lanes.size()]
			var slot_t: float = (float(i) + 0.5) / float(maxi(target_rocks, 1))
			var dist: float = chunk_start + 14.0 + slot_t * (SimConstants.CHUNK_LENGTH - 28.0)
			dist += rng.randf_range(-5.0, 5.0)
			if not _try_place_rock(entries, chunk_rocks, lane_last_rock, lane, dist, object_id):
				for alt_lane in lanes:
					if alt_lane == lane:
						continue
					if _try_place_rock(entries, chunk_rocks, lane_last_rock, alt_lane, dist + rng.randf_range(1.0, 6.0), object_id):
						object_id += 1
						break
			else:
				object_id += 1

		var coin_lines: int = int(round(lerpf(
			float(SimConstants.COIN_LINES_MIN),
			float(SimConstants.COIN_LINES_MAX),
			difficulty
		)))
		for _j in coin_lines:
			object_id = _spawn_coin_line(rng, chunk_start, entries, chunk_rocks, object_id)

		for _burst in 2:
			if rng.randf() < SimConstants.EXTRA_COIN_BURST_CHANCE:
				object_id = _spawn_coin_line(rng, chunk_start, entries, chunk_rocks, object_id)

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.distance == b.distance:
			return a.object_id < b.object_id
		return a.distance < b.distance
	)
	return entries


static func _chunk_difficulty(chunk_index: int, chunk_count: int) -> float:
	return float(chunk_index) / maxf(float(chunk_count - 1), 1.0)


static func _try_place_rock(
	entries: Array,
	chunk_rocks: Array,
	lane_last_rock: Array,
	lane: int,
	dist: float,
	object_id: int
) -> bool:
	if dist - lane_last_rock[lane] < SimConstants.MIN_ROCK_GAP:
		return false
	lane_last_rock[lane] = dist
	var entry := {
		"kind": "rock",
		"lane": lane,
		"distance": dist,
		"object_id": object_id,
	}
	entries.append(entry)
	chunk_rocks.append(entry)
	return true


static func _spawn_barrier(
	rng: SeededRng,
	chunk_start: float,
	entries: Array,
	chunk_rocks: Array,
	lane_last_rock: Array,
	object_id: int
) -> int:
	var base_dist: float = chunk_start + rng.randf_range(30.0, SimConstants.CHUNK_LENGTH - 50.0)

	# Full 3-lane wall — jump required.
	for lane in 3:
		var dist: float = base_dist + rng.randf_range(-SimConstants.BARRIER_SYNC_JITTER, SimConstants.BARRIER_SYNC_JITTER)
		if _try_place_rock(entries, chunk_rocks, lane_last_rock, lane, dist, object_id):
			object_id += 1

	var coin_count: int = rng.randi_range(SimConstants.BARRIER_COIN_MIN, SimConstants.BARRIER_COIN_MAX)
	var coin_lane: int = rng.randi_mod(SimConstants.NUM_LANES)
	var coin_base: float = base_dist - float(coin_count) * SimConstants.MIN_COIN_GAP - 6.0
	for j in coin_count:
		entries.append({
			"kind": "coin",
			"lane": coin_lane,
			"distance": coin_base + j * SimConstants.MIN_COIN_GAP,
			"object_id": object_id,
		})
		object_id += 1
	return object_id


static func _spawn_coin_line(
	rng: SeededRng,
	chunk_start: float,
	entries: Array,
	chunk_rocks: Array,
	object_id: int
) -> int:
	var lane: int = _pick_coin_lane(rng, chunk_rocks)
	var count: int = rng.randi_range(SimConstants.COIN_COUNT_MIN, SimConstants.COIN_COUNT_MAX)
	var max_start: float = SimConstants.CHUNK_LENGTH - float(count) * SimConstants.MIN_COIN_GAP - 15.0
	var base_dist: float = chunk_start + rng.randf_range(15.0, maxf(17.0, max_start))
	for j in count:
		entries.append({
			"kind": "coin",
			"lane": lane,
			"distance": base_dist + j * SimConstants.MIN_COIN_GAP,
			"object_id": object_id,
		})
		object_id += 1
	return object_id


static func _pick_coin_lane(rng: SeededRng, chunk_rocks: Array) -> int:
	if chunk_rocks.is_empty():
		return rng.randi_mod(SimConstants.NUM_LANES)
	var rock_count: Array = [0, 0, 0]
	for r in chunk_rocks:
		if r is Dictionary:
			var ln: int = int(r.get("lane", 0))
			if ln >= 0 and ln < 3:
				rock_count[ln] += 1
	var best_lane: int = 0
	var best_count: int = rock_count[0]
	for i in range(1, 3):
		if rock_count[i] < best_count:
			best_count = rock_count[i]
			best_lane = i
	if rock_count[0] == rock_count[1] and rock_count[1] == rock_count[2]:
		return rng.randi_mod(SimConstants.NUM_LANES)
	return best_lane


static func _shuffle_array(arr: Array, rng: SeededRng) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
