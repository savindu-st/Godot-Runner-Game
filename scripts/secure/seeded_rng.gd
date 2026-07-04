class_name SeededRng
extends RefCounted

var _rng: RandomNumberGenerator


func _init(seed: int) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed


static func chunk_seed(segment_seed: int, chunk_index: int) -> int:
	return hash("key-%d-chunk-%d-salt" % [segment_seed, chunk_index])


func randf() -> float:
	return _rng.randf()


func randf_range(a: float, b: float) -> float:
	return _rng.randf_range(a, b)


func randi_range(a: int, b: int) -> int:
	return _rng.randi_range(a, b)


func randi_mod(n: int) -> int:
	if n <= 0:
		return 0
	return _rng.randi() % n
