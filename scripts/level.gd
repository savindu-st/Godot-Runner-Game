extends Node

@onready var player: CharacterBody3D = $player_body
@onready var spawn_timer: Timer = $spawn_timer
@onready var spawn_env_timer: Timer = $spawn_env_timer
@onready var spawn_obstacle_timer: Timer = $spawn_obstacle_timer

@onready var coin: PackedScene = preload("res://scenes/coin.tscn")
@export_group("Map Assets")
@export var map_trees: Array[PackedScene] = []
@export var map_obstacles: Array[PackedScene] = []
@export var map_glb_obstacles: Array[String] = []
@export var map_glb_trees: Array[String] = []
@export var fence_scene: PackedScene
@export var road_material: Material

@export_group("Map Settings")
@export var map_street_names: Array[String] = []
@export var has_special_arch: bool = false
@export var bgm_override: AudioStream
@export var dense_environment: bool = false

@onready var fence: PackedScene = fence_scene
@onready var asphalt_mat: Material = road_material

@onready var env_move_script = preload("res://scripts/env_script.gd")

var tree_templates: Array = []
var obstacle_templates: Array = []

var _last_tree: int = -1
var _last_obstacle: int = -1

const LANE_SCROLL_SPEED: float = SimConstants.SCROLL_SPEED
var run_distance: float = 0.0

var startz: float = -50.0
var road_spawnx: Array = [-2, 0, 2]

const FENCE_COUNT: int = 40
const FENCE_SPACING: float = 1.5
const FENCE_WRAP_Z: float = 30.0
var fences: Array = []
var _fence_loop_len: float = FENCE_SPACING * FENCE_COUNT
var _fence_count: int = FENCE_COUNT

const ENV_TREE_X_MIN: float = 8.0
const ENV_TREE_X_MAX: float = 13.0

# scrolling road strips
const ROAD_SEGMENT_LEN: float = 5.0
const ROAD_SEGMENT_COUNT: int = 28
var _road_segment_count: int = ROAD_SEGMENT_COUNT
var road_segments: Array = []

var _last_left_building_dist: float = 0.0
var _last_right_building_dist: float = 0.0

# roadside street-name boards
var street_names: Array[String] = []
var sign_index: int = 0
var sign_timer: Timer
var sign_post_mat: StandardMaterial3D
var sign_pole_mat: StandardMaterial3D
var sign_frame_mat: StandardMaterial3D
var sign_reflector_mat: StandardMaterial3D

# concert boards spawn further down the road so they pass after the Lagaan sign
const CONCERT_ROAD_GAP: float = 38.0

var _segment_start_distance: float = 0.0
var _segment_spawns: Array = []
var _next_spawn_idx: int = 0
var _checkpoint_busy: bool = false
var _world_frozen: bool = false

const BGM := preload("res://sounds/background-music.mp3")

var _bgm_player: AudioStreamPlayer


func _ready():
	add_to_group("level")
	spawn_env_timer.stop()
	_setup_bgm()
	if not BrowserBridge.page_backgrounded.is_connected(_on_page_background):
		BrowserBridge.page_backgrounded.connect(_on_page_background)
	if not BrowserBridge.page_foregrounded.is_connected(_on_page_foreground):
		BrowserBridge.page_foregrounded.connect(_on_page_foreground)
	randomize()
	if SimConstants.SECURE_SPAWNS:
		spawn_timer.stop()
		spawn_obstacle_timer.stop()
		if not RunSession.checkpoint_resolved.is_connected(_on_checkpoint_resolved):
			RunSession.checkpoint_resolved.connect(_on_checkpoint_resolved)
	call_deferred("_deferred_level_boot")


func _deferred_level_boot() -> void:
	if player and player.has_method("wait_for_character"):
		await player.wait_for_character()
	else:
		await get_tree().process_frame
		await get_tree().process_frame
	if map_street_names.size() > 0:
		street_names = map_street_names.duplicate()
	else:
		street_names = ["No Name"]
		
	if fence == null:
		fence = preload("res://models/city/barrier_fence.tscn")
	if asphalt_mat == null:
		asphalt_mat = preload("res://models/road_city.tres")
		
	_setup_road_segments()
	_setup_fences()
	_setup_signs()
	if SimConstants.SECURE_SPAWNS:
		call_deferred("_boot_secure_segment")
	for _i in 3:
		await get_tree().process_frame
	_load_nature()
	
	if dense_environment:
		var z: float = startz
		while z < 30.0:
			_spawn_dense_prop(-1, z)
			_spawn_dense_prop(1, z)
			z += 12.0
			
	spawn_env_timer.start()


func _setup_fences() -> void:
	_fence_loop_len = FENCE_SPACING * _fence_count
	var z: float = -_fence_loop_len * 0.5
	for i in _fence_count:
		var fence_inst: Node3D = fence.instantiate()
		fences.append(fence_inst)
		add_child(fence_inst)
		fence_inst.position = Vector3(0.0, 0.0, z)
		z += FENCE_SPACING


func _setup_bgm() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BackgroundMusic"
	if bgm_override:
		_bgm_player.stream = bgm_override
	else:
		_bgm_player.stream = BGM
	_bgm_player.volume_db = -2.0
	_bgm_player.add_to_group("web_audio")
	BrowserBridge.configure_audio_player(_bgm_player, true)
	add_child(_bgm_player)


func _on_page_background() -> void:
	if _bgm_player and _bgm_player.playing:
		_bgm_player.stop()


func _on_page_foreground() -> void:
	if _bgm_player and GameSettings.sound_enabled and player and player.game_started:
		if not _bgm_player.playing:
			_bgm_player.play()


func begin_run() -> void:
	if not GameSettings.sound_enabled:
		return
	BrowserBridge.unlock_web_audio()
	if _bgm_player and not _bgm_player.playing:
		_bgm_player.play()


func _boot_secure_segment() -> void:
	if player == null:
		return
	RunSession.ensure_segment_for_level(player.current_lane)
	_init_secure_segment()


func get_segment_distance() -> float:
	return run_distance - _segment_start_distance


func get_scroll_speed() -> float:
	return SimConstants.scroll_speed_at_sec(RunSession.run_scroll_elapsed_sec())


func _game_stopped() -> bool:
	if player == null:
		return true
	if not player.game_started:
		return true
	return player.is_dead or player.game_over


func is_world_active() -> bool:
	return not _game_stopped()


func freeze_world() -> void:
	if _world_frozen:
		return
	_world_frozen = true
	spawn_timer.stop()
	spawn_env_timer.stop()
	spawn_obstacle_timer.stop()
	if sign_timer:
		sign_timer.stop()
	if _bgm_player and _bgm_player.playing:
		_bgm_player.stop()
	for c in get_tree().get_nodes_in_group("coins"):
		if is_instance_valid(c):
			_halt_node(c)
			var coin_area: Area3D = c.get_node_or_null("Area3D") as Area3D
			if coin_area:
				coin_area.monitoring = false
				coin_area.monitorable = false
	for n in get_tree().get_nodes_in_group("scrollers"):
		if is_instance_valid(n):
			_halt_node(n)


func _halt_node(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		if child is Timer:
			(child as Timer).stop()


func _init_secure_segment() -> void:
	# New coin/rock map for this segment — scroll speed clock is unchanged.
	_segment_spawns = SegmentMapGen.generate(RunSession.current_seed)
	_next_spawn_idx = 0
	_segment_start_distance = run_distance
	_checkpoint_busy = false
	_clear_gameplay_spawns()


func _clear_gameplay_spawns() -> void:
	for n in get_tree().get_nodes_in_group("coins"):
		if is_instance_valid(n):
			n.queue_free()
	for n in get_tree().get_nodes_in_group("obstacles"):
		if is_instance_valid(n):
			n.queue_free()


func _process_secure_spawns() -> void:
	var d: float = get_segment_distance()
	while _next_spawn_idx < _segment_spawns.size():
		var entry: Dictionary = _segment_spawns[_next_spawn_idx]
		if d + SimConstants.SPAWN_LEAD < float(entry.distance):
			break
		_spawn_map_entry(entry)
		_next_spawn_idx += 1


func _spawn_map_entry(entry: Dictionary) -> void:
	match String(entry.get("kind", "")):
		"coin":
			_spawn_seeded_coin(entry)
		"rock", "obstacle":
			_spawn_seeded_obstacle(entry)


func _spawn_seeded_coin(entry: Dictionary) -> void:
	var coin_inst: MeshInstance3D = coin.instantiate()
	add_child(coin_inst)
	coin_inst.set_meta("object_id", int(entry.object_id))
	coin_inst.set_meta("spawn_lane", int(entry.lane))
	coin_inst.set_meta("map_distance", float(entry.distance))
	coin_inst.global_transform.origin = Vector3(
		road_spawnx[int(entry.lane)],
		0.4,
		startz
	)


func _spawn_seeded_obstacle(entry: Dictionary) -> void:
	if obstacle_templates.is_empty():
		return
	var rng := SeededRng.new(int(entry.object_id) + RunSession.current_seed)
	var idx: int = rng.randi_mod(obstacle_templates.size())
	var mover := _make_mover(obstacle_templates[idx])
	mover.add_to_group("obstacles")
	mover.set_meta("object_id", int(entry.object_id))
	mover.set_meta("spawn_lane", int(entry.lane))
	mover.set_meta("map_distance", float(entry.distance))
	add_child(mover)
	mover.global_transform.origin = Vector3(road_spawnx[int(entry.lane)], 0.0, startz)
	if mover.has_meta("slide_clear"):
		mover.rotation.y = mover.get_meta("y_rot", PI)
	elif mover.has_meta("is_car"):
		var base_rot: float = PI / 2.0 if rng.randf() > 0.5 else -PI / 2.0
		mover.rotation.y = base_rot + rng.randf_range(-0.25, 0.25)
	else:
		mover.rotation.y = rng.randf() * TAU
	mover.scale = _obstacle_scale_for_template(obstacle_templates[idx], rng)


func _lane_index_from_x(x: float) -> int:
	var best: int = 0
	var best_d: float = INF
	for i in SimConstants.LANE_X.size():
		var d: float = absf(x - float(SimConstants.LANE_X[i]))
		if d < best_d:
			best_d = d
			best = i
	return best


func _on_checkpoint_resolved(accepted: bool, _data: Dictionary) -> void:
	_checkpoint_busy = false
	if not accepted:
		return
	if player == null or player.is_dead or player.game_over:
		return
	RunSession.apply_next_segment(player.current_lane)
	_init_secure_segment()


func _try_segment_checkpoint() -> void:
	if _checkpoint_busy or player == null or player.is_dead or player.game_over:
		return
	if get_segment_distance() < SimConstants.SEGMENT_LENGTH:
		return
	_checkpoint_busy = true
	RunSession.submit_checkpoint(get_segment_distance())


func _setup_road_segments() -> void:
	var z: float = -ROAD_SEGMENT_LEN * _road_segment_count * 0.5
	for i in _road_segment_count:
		var seg := MeshInstance3D.new()
		seg.name = "road_seg_%d" % i
		var pm := PlaneMesh.new()
		pm.size = Vector2(6.4, ROAD_SEGMENT_LEN)
		seg.mesh = pm
		seg.material_override = asphalt_mat
		seg.position = Vector3(0.0, 0.02, z)
		add_child(seg)
		road_segments.append(seg)
		z += ROAD_SEGMENT_LEN


func _setup_signs() -> void:
	sign_pole_mat = StandardMaterial3D.new()
	sign_pole_mat.albedo_color = Color(0.42, 0.44, 0.48)
	sign_pole_mat.metallic = 0.72
	sign_pole_mat.roughness = 0.38

	sign_post_mat = StandardMaterial3D.new()
	sign_post_mat.albedo_color = Color(0.04, 0.22, 0.12)
	sign_post_mat.roughness = 0.55
	sign_post_mat.metallic = 0.08

	sign_frame_mat = StandardMaterial3D.new()
	sign_frame_mat.albedo_color = Color(0.94, 0.95, 0.93)
	sign_frame_mat.roughness = 0.35
	sign_frame_mat.metallic = 0.15

	sign_reflector_mat = StandardMaterial3D.new()
	sign_reflector_mat.albedo_color = Color(0.95, 0.78, 0.12)
	sign_reflector_mat.emission_enabled = true
	sign_reflector_mat.emission = Color(0.9, 0.7, 0.1)
	sign_reflector_mat.emission_energy_multiplier = 0.35
	sign_reflector_mat.metallic = 0.4
	sign_reflector_mat.roughness = 0.25

	sign_timer = Timer.new()
	sign_timer.name = "sign_timer"
	sign_timer.wait_time = 8.0
	sign_timer.autostart = true
	sign_timer.timeout.connect(_on_sign_timer)
	add_child(sign_timer)


func _on_sign_timer() -> void:
	if _game_stopped():
		return
	var name: String = street_names[sign_index]
	if name == "Lagaan" and has_special_arch:
		_spawn_sign("Lagaan")
		_spawn_concert_boards()
		sign_index = (sign_index + 1) % street_names.size()
		var concert_z: float = startz - CONCERT_ROAD_GAP
		var concert_travel: float = abs(concert_z) / get_scroll_speed()
		sign_timer.wait_time = concert_travel + 4.0
		return
	_spawn_sign(name)
	sign_index = (sign_index + 1) % street_names.size()
	sign_timer.wait_time = randf_range(7.5, 11.0)


func _spawn_concert_boards() -> void:
	var z_pos: float = startz - CONCERT_ROAD_GAP
	_spawn_epilogue_arch(z_pos)
	_spawn_concert_side(-5.5, z_pos, "CONCERT", "28 JULY", 22.0, 14.0)
	_spawn_concert_side(5.5, z_pos, "LIVE MUSIC", "28 JULY", -22.0, 14.0)


func _spawn_epilogue_arch(z: float) -> void:
	# decorative gateway over the road — no collision, the boy runs straight under it
	var root := Node3D.new()
	root.set_script(env_move_script)
	root.set_meta("lifetime", 14.0)
	add_child(root)
	root.global_transform.origin = Vector3(0.0, 0.0, z)

	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.95, 0.78, 0.18)
	gold.metallic = 0.65
	gold.roughness = 0.28
	gold.emission_enabled = true
	gold.emission = Color(0.85, 0.62, 0.08)
	gold.emission_energy_multiplier = 0.4

	var banner := StandardMaterial3D.new()
	banner.albedo_color = Color(0.42, 0.07, 0.52)
	banner.emission_enabled = true
	banner.emission = Color(0.32, 0.04, 0.4)
	banner.emission_energy_multiplier = 0.5
	banner.roughness = 0.42

	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.9, 0.2, 0.36)
	accent.emission_enabled = true
	accent.emission = Color(0.7, 0.1, 0.26)
	accent.emission_energy_multiplier = 0.45

	const POST_X: float = 3.45
	const POST_H: float = 3.65
	const BEAM_Y: float = 3.72

	for side_x in [-POST_X, POST_X]:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.28, POST_H, 0.28)
		post.mesh = pm
		post.material_override = sign_pole_mat
		post.position = Vector3(side_x, POST_H * 0.5, 0.0)
		root.add_child(post)

		var cap := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.42, 0.18, 0.42)
		cap.mesh = cm
		cap.material_override = gold
		cap.position = Vector3(side_x, POST_H + 0.06, 0.0)
		root.add_child(cap)

	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(7.35, 0.32, 0.34)
	beam.mesh = bm
	beam.material_override = gold
	beam.position = Vector3(0.0, BEAM_Y, 0.0)
	root.add_child(beam)

	var sign_panel := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(6.8, 1.15, 0.1)
	sign_panel.mesh = sm
	sign_panel.material_override = banner
	sign_panel.position = Vector3(0.0, BEAM_Y + 0.72, 0.0)
	root.add_child(sign_panel)

	var sign_frame := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(7.05, 1.38, 0.07)
	sign_frame.mesh = fm
	sign_frame.material_override = gold
	sign_frame.position = Vector3(0.0, BEAM_Y + 0.72, -0.03)
	root.add_child(sign_frame)

	for i in range(9):
		var bulb := MeshInstance3D.new()
		var bulb_mesh := SphereMesh.new()
		bulb_mesh.radius = 0.065
		bulb_mesh.height = 0.13
		bulb.mesh = bulb_mesh
		var bulb_mat := StandardMaterial3D.new()
		bulb_mat.albedo_color = Color(1.0, 0.9, 0.4) if i % 2 == 0 else Color(0.5, 0.82, 1.0)
		bulb_mat.emission_enabled = true
		bulb_mat.emission = bulb_mat.albedo_color
		bulb_mat.emission_energy_multiplier = 1.15
		bulb.material_override = bulb_mat
		bulb.position = Vector3(-3.2 + i * 0.8, BEAM_Y - 0.12, 0.0)
		root.add_child(bulb)

	var ribbon := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(7.1, 0.14, 0.06)
	ribbon.mesh = rm
	ribbon.material_override = accent
	ribbon.position = Vector3(0.0, BEAM_Y + 1.38, 0.05)
	root.add_child(ribbon)

	var title := Label3D.new()
	title.text = "EPILOGUE"
	title.font_size = 130
	title.pixel_size = 0.0054
	title.modulate = Color(1, 1, 1)
	title.outline_size = 18
	title.outline_modulate = Color(0.12, 0.02, 0.18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector3(0.0, BEAM_Y + 0.72, 0.12)
	root.add_child(title)

	var subtitle := Label3D.new()
	subtitle.text = "28 JULY"
	subtitle.font_size = 72
	subtitle.pixel_size = 0.004
	subtitle.modulate = Color(1.0, 0.88, 0.32)
	subtitle.outline_size = 10
	subtitle.outline_modulate = Color(0.15, 0.04, 0.22)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector3(0.0, BEAM_Y + 0.38, 0.1)
	root.add_child(subtitle)


func _spawn_concert_side(x: float, z: float, title: String, date_line: String, rot_y: float, lifetime: float) -> void:
	var root := Node3D.new()
	root.set_script(env_move_script)
	root.set_meta("lifetime", lifetime)
	add_child(root)
	root.global_transform.origin = Vector3(x, 0.0, z)
	_add_concert_sign(root, title, date_line, rot_y)


func _spawn_sign(text: String) -> Node3D:
	var root := Node3D.new()
	root.set_script(env_move_script)
	root.set_meta("lifetime", 10.0)
	add_child(root)
	root.global_transform.origin = Vector3(-5.2, 0.0, startz)
	_add_street_sign(root, text, Vector3.ZERO, 22.0)
	return root


func _add_street_sign(root: Node3D, text: String, pos: Vector3, rot_y: float) -> void:
	var mount := Node3D.new()
	mount.position = pos
	mount.rotation_degrees.y = rot_y
	root.add_child(mount)
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.055
	pole_mesh.bottom_radius = 0.07
	pole_mesh.height = 3.35
	pole.mesh = pole_mesh
	pole.material_override = sign_pole_mat
	pole.position = Vector3(0.0, 1.675, 0.0)
	mount.add_child(pole)

	# base plate
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.22
	base_mesh.bottom_radius = 0.26
	base_mesh.height = 0.08
	base.mesh = base_mesh
	base.material_override = sign_pole_mat
	base.position = Vector3(0.0, 0.04, 0.0)
	mount.add_child(base)

	# yellow reflector strip on pole (real roadside detail)
	var reflector := MeshInstance3D.new()
	var ref_mesh := BoxMesh.new()
	ref_mesh.size = Vector3(0.14, 0.22, 0.04)
	reflector.mesh = ref_mesh
	reflector.material_override = sign_reflector_mat
	reflector.position = Vector3(0.08, 0.55, 0.0)
	mount.add_child(reflector)

	# white outer frame
	var frame := MeshInstance3D.new()
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(3.85, 1.05, 0.07)
	frame.mesh = frame_mesh
	frame.material_override = sign_frame_mat
	frame.position = Vector3(0.0, 3.15, 0.0)
	mount.add_child(frame)

	# green sign face
	var board := MeshInstance3D.new()
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(3.55, 0.82, 0.09)
	board.mesh = board_mesh
	board.material_override = sign_post_mat
	board.position = Vector3(0.0, 3.15, 0.02)
	mount.add_child(board)

	var label := Label3D.new()
	label.text = text.to_upper()
	label.font_size = 120
	label.pixel_size = 0.0055
	label.modulate = Color(1, 1, 1)
	label.outline_size = 18
	label.outline_modulate = Color(0.02, 0.08, 0.05)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var approx_w: float = float(text.length()) * label.font_size * label.pixel_size * 0.58
	if approx_w > 3.2:
		label.pixel_size *= 3.2 / approx_w
	label.position = Vector3(0.0, 3.15, 0.08)
	mount.add_child(label)


func _add_concert_sign(root: Node3D, title: String, date_line: String, rot_y: float) -> void:
	root.rotation_degrees.y = rot_y

	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.95, 0.78, 0.18)
	gold.metallic = 0.65
	gold.roughness = 0.28
	gold.emission_enabled = true
	gold.emission = Color(0.85, 0.62, 0.08)
	gold.emission_energy_multiplier = 0.45

	var banner := StandardMaterial3D.new()
	banner.albedo_color = Color(0.45, 0.08, 0.55)
	banner.emission_enabled = true
	banner.emission = Color(0.35, 0.05, 0.42)
	banner.emission_energy_multiplier = 0.55
	banner.roughness = 0.4

	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.92, 0.22, 0.38)
	accent.emission_enabled = true
	accent.emission = Color(0.75, 0.12, 0.28)
	accent.emission_energy_multiplier = 0.5

	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.06
	pole_mesh.bottom_radius = 0.08
	pole_mesh.height = 4.1
	pole.mesh = pole_mesh
	pole.material_override = sign_pole_mat
	pole.position = Vector3(0.0, 2.05, 0.0)
	root.add_child(pole)

	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.28
	base_mesh.bottom_radius = 0.34
	base_mesh.height = 0.1
	base.mesh = base_mesh
	base.material_override = gold
	base.position = Vector3(0.0, 0.05, 0.0)
	root.add_child(base)

	for i in range(5):
		var flag := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.55, 0.38, 0.03)
		flag.mesh = fm
		flag.material_override = gold if i % 2 == 0 else accent
		flag.position = Vector3(-1.1 + i * 0.55, 4.35, 0.0)
		flag.rotation_degrees.z = -18.0 if i % 2 == 0 else 18.0
		root.add_child(flag)

	for i in range(7):
		var bulb := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.07
		bm.height = 0.14
		bulb.mesh = bm
		var bulb_mat := StandardMaterial3D.new()
		bulb_mat.albedo_color = Color(1.0, 0.92, 0.45) if i % 2 == 0 else Color(0.55, 0.85, 1.0)
		bulb_mat.emission_enabled = true
		bulb_mat.emission = bulb_mat.albedo_color
		bulb_mat.emission_energy_multiplier = 1.2
		bulb.material_override = bulb_mat
		bulb.position = Vector3(-1.5 + i * 0.5, 4.05, 0.12)
		root.add_child(bulb)

	var frame := MeshInstance3D.new()
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(4.35, 1.35, 0.08)
	frame.mesh = frame_mesh
	frame.material_override = gold
	frame.position = Vector3(0.0, 3.55, 0.0)
	root.add_child(frame)

	var board := MeshInstance3D.new()
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(4.05, 1.05, 0.1)
	board.mesh = board_mesh
	board.material_override = banner
	board.position = Vector3(0.0, 3.55, 0.02)
	root.add_child(board)

	for side in [-1, 1]:
		var ribbon := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.18, 1.2, 0.04)
		ribbon.mesh = rm
		ribbon.material_override = accent
		ribbon.position = Vector3(side * 2.18, 3.55, 0.04)
		root.add_child(ribbon)

	var title_label := Label3D.new()
	title_label.text = title.to_upper()
	title_label.font_size = 100
	title_label.pixel_size = 0.005
	title_label.modulate = Color(1, 1, 1)
	title_label.outline_size = 16
	title_label.outline_modulate = Color(0.15, 0.02, 0.2)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector3(0.0, 3.62, 0.1)
	root.add_child(title_label)

	var date_label := Label3D.new()
	date_label.text = date_line.to_upper()
	date_label.font_size = 88
	date_label.pixel_size = 0.0046
	date_label.modulate = Color(1.0, 0.88, 0.35)
	date_label.outline_size = 14
	date_label.outline_modulate = Color(0.2, 0.05, 0.3)
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	date_label.position = Vector3(0.0, 3.28, 0.1)
	root.add_child(date_label)


func _load_nature() -> void:
	if map_trees.is_empty():
		var NATURE_TREES: Array = [
			"res://models/city/streetlamp.tscn",
		]
		_collect(NATURE_TREES, tree_templates)
	else:
		_collect_packed(map_trees, tree_templates)
		for glb_path in map_glb_trees:
			_collect_glb(glb_path, tree_templates)
		
	if map_obstacles.is_empty():
		var OBSTACLE_MODELS: Array = [
			"res://models/city/trash_can.tscn",
			"res://models/city/fire_hydrant.tscn",
			"res://models/city/jersey_barrier.tscn",
		]
		_collect(OBSTACLE_MODELS, obstacle_templates)
	else:
		_collect_packed(map_obstacles, obstacle_templates)
		for glb_path in map_glb_obstacles:
			_collect_glb(glb_path, obstacle_templates)
	



func _obstacle_scale_for_template(tpl: Node3D, rng: SeededRng = null) -> Vector3:
	var h: float = maxf(float(tpl.get_meta("height", 1.0)), 0.01)
	var target_h: float
	if tpl.has_meta("target_height"):
		target_h = tpl.get_meta("target_height")
		if rng:
			target_h *= rng.randf_range(0.9, 1.1)
		else:
			target_h *= randf_range(0.9, 1.1)
	else:
		if rng:
			target_h = rng.randf_range(0.82, 1.05)
		else:
			target_h = randf_range(0.82, 1.05)
	var s: float = target_h / h
	return Vector3(s, s, s)


func _collect(paths: Array, into: Array) -> void:
	for p in paths:
		if not ResourceLoader.exists(p):
			continue
		var inst: Node = (load(p) as PackedScene).instantiate()
		add_child(inst)
		var meshes: Array = []
		_gather_meshes(inst, meshes)
		for m in meshes:
			var tpl := MeshInstance3D.new()
			tpl.mesh = m.mesh
			for si in m.get_surface_override_material_count():
				var om = m.get_surface_override_material(si)
				if om:
					tpl.set_surface_override_material(si, om)
			var gt: Transform3D = m.global_transform
			gt.origin = Vector3.ZERO
			tpl.transform = gt
			var h: float = tpl.get_aabb().size.y
			tpl.set_meta("height", h)
			into.append(tpl)
		remove_child(inst)
		inst.free()

func _collect_packed(packed_scenes: Array[PackedScene], into: Array) -> void:
	for p in packed_scenes:
		if p == null:
			continue
		var inst: Node3D = p.instantiate() as Node3D
		if inst == null:
			continue
		var meshes: Array = []
		_gather_meshes(inst, meshes)
		var max_y: float = 0.01
		for m in meshes:
			if m is MeshInstance3D:
				var aabb = m.get_aabb()
				var top_y = m.transform.origin.y + aabb.position.y + aabb.size.y
				if top_y > max_y:
					max_y = top_y
		inst.set_meta("height", max_y)
		into.append(inst)

func _collect_glb(path: String, into: Array) -> void:
	if not ResourceLoader.exists(path):
		return
	var packed_scene = load(path) as PackedScene
	if not packed_scene:
		return
	var root = packed_scene.instantiate()
	add_child(root)
	
	var queue = [root]
	var found_cars = []
	var keywords = ["pickup", "sedan", "police", "stationwagon", "car"]
	
	while queue.size() > 0:
		var curr = queue.pop_front()
		var n = curr.name.to_lower()
		var is_car = false
		for k in keywords:
			if k in n and not ("root" in n) and not ("sketchfab" in n) and not ("scene" in n):
				is_car = true
				break
		if is_car:
			found_cars.append(curr)
		else:
			for c in curr.get_children():
				queue.append(c)
				
	if found_cars.is_empty():
		var target = root
		while target.get_child_count() == 1 and not (target.get_child(0) is MeshInstance3D):
			target = target.get_child(0)
		for c in target.get_children():
			found_cars.append(c)

	for car in found_cars:
		var inst = Node3D.new()
		inst.name = car.name
		
		var meshes: Array = []
		_gather_meshes(car, meshes)
		
		var fix_transform = Transform3D()
		var n_lower = car.name.to_lower()
		var p_lower = path.to_lower()
		var is_billboard = false
		
		if "solo_billboard" in p_lower or "solo_billboard" in n_lower:
			fix_transform = fix_transform.rotated(Vector3(1, 0, 0), -PI / 2.0)
			is_billboard = true
		elif "billboard" in p_lower or "billboard" in n_lower:
			fix_transform = fix_transform.rotated(Vector3(1, 0, 0), PI)
			is_billboard = true
		elif "pickup" in n_lower or "sedan" in n_lower or "police" in n_lower or "stationwagon" in n_lower or "car" in p_lower:
			inst.set_meta("is_car", true)

		var filtered_meshes = []
		for m in meshes:
			if not (m is MeshInstance3D) or not m.mesh:
				continue
			var m_name = m.name.to_lower()
			if "col" in m_name or "bound" in m_name or "shadow" in m_name:
				continue
			if abs(m.global_transform.basis.determinant()) < 0.0001:
				continue
			filtered_meshes.append(m)
		meshes = filtered_meshes
		
		var is_flat_plane = false
		var valid_bounds = false
		var min_x = 9999.0
		var max_x = -9999.0
		var min_y = 9999.0
		var max_y = -9999.0
		var min_z = 9999.0
		var max_z = -9999.0
		
		for m in meshes:
			if m is MeshInstance3D:
				var aabb = m.get_aabb()
				var gtrans = fix_transform
				if not is_billboard:
					gtrans = gtrans * m.global_transform
				for i in range(8):
					var corner = aabb.position
					if i & 1: corner.x += aabb.size.x
					if i & 2: corner.y += aabb.size.y
					if i & 4: corner.z += aabb.size.z
					var p = gtrans * corner
					min_x = min(min_x, p.x)
					max_x = max(max_x, p.x)
					min_y = min(min_y, p.y)
					max_y = max(max_y, p.y)
					min_z = min(min_z, p.z)
					max_z = max(max_z, p.z)
				valid_bounds = true
				
		if valid_bounds:
			var size_y = max_y - min_y
			if size_y < 0.2:
				is_flat_plane = true
		
		if is_flat_plane or not valid_bounds:
			continue
			
		# Create clean MeshInstance3D copies to avoid GLTF tree dependency bugs
		for m in meshes:
			if m is MeshInstance3D and m.mesh:
				var clean_mi = MeshInstance3D.new()
				clean_mi.mesh = m.mesh
				for si in m.mesh.get_surface_count():
					var mat = m.get_surface_override_material(si)
					if mat == null:
						mat = m.mesh.surface_get_material(si)
				if is_billboard:
					clean_mi.transform = fix_transform
				else:
					clean_mi.transform = fix_transform * m.global_transform
				inst.add_child(clean_mi)
			
		inst.set_meta("height", max_y - min_y)
		inst.set_meta("size_x", max_x - min_x)
		inst.set_meta("size_z", max_z - min_z)
		
		if "billboard" in path.to_lower() or "billboard" in inst.name.to_lower():
			inst.set_meta("slide_clear", true)
			inst.set_meta("target_height", 2.2)
			if "solo_billboard" in path.to_lower() or "solo_billboard" in inst.name.to_lower():
				inst.set_meta("y_rot", PI)
			else:
				inst.set_meta("y_rot", PI)
		else:
			inst.set_meta("target_height", 1.28)
		
		var center_x = (min_x + max_x) * 0.5
		var center_z = (min_z + max_z) * 0.5
		
		# Offset all children to center the obstacle and rest on the ground
		for child in inst.get_children():
			child.transform.origin += Vector3(-center_x, -min_y, -center_z)
			
		into.append(inst)
	remove_child(root)
	root.free()


func _gather_meshes(n: Node, into: Array) -> void:
	if n is MeshInstance3D:
		into.append(n)
	for c in n.get_children():
		_gather_meshes(c, into)


func _make_mover(template: Node3D) -> Node3D:
	var mover := Node3D.new()
	mover.set_script(env_move_script)
	mover.add_child(template.duplicate())
	for m in template.get_meta_list():
		mover.set_meta(m, template.get_meta(m))
	return mover


func _on_spawn_timer_timeout():
	if _game_stopped():
		return
	spawn_timer.wait_time = randf_range(1.2, 2.2)
	var lane_idx: int = randi() % 3
	var count: int = 4 + (randi() % 5)
	for i in count:
		var coin_inst: MeshInstance3D = coin.instantiate()
		add_child(coin_inst)
		coin_inst.global_transform.origin = Vector3(
			road_spawnx[lane_idx],
			0.4,
			startz + i * 2.5
		)


func _on_spawn_env_timer_timeout():
	if _game_stopped():
		return
	if dense_environment:
		return
	var side: int = 1 if randf() < 0.5 else -1
	_spawn_tree(side)
	if randf() < 0.3:
		_spawn_tree(-side)
	spawn_env_timer.wait_time = randf_range(1.25, 2.1)


func _spawn_tree(dir: int) -> void:
	if tree_templates.is_empty():
		return
	var idx: int = randi() % tree_templates.size()
	if tree_templates.size() > 1 and idx == _last_tree:
		idx = (idx + 1) % tree_templates.size()
	_last_tree = idx

	var mover := _make_mover(tree_templates[idx])
	add_child(mover)
	var s: float = randf_range(0.8, 1.2)
	mover.global_transform.origin = Vector3(
		dir * randf_range(ENV_TREE_X_MIN, ENV_TREE_X_MAX),
		0.0,
		startz + randf_range(-4.0, 4.0)
	)
	mover.rotation.y = randf() * TAU
	mover.scale = Vector3(s, s, s)

func _spawn_dense_prop(side: int, z_pos: float) -> void:
	if tree_templates.is_empty():
		return
	var idx: int = randi() % tree_templates.size()
	if tree_templates.size() > 1 and idx == _last_tree:
		idx = (idx + 1) % tree_templates.size()
	_last_tree = idx

	var mover := _make_mover(tree_templates[idx])
	add_child(mover)
	
	var is_building = "building" in tree_templates[idx].name.to_lower()
	var base_scale = 0.4 if is_building else 1.0
	
	if is_building:
		# Front is along Z. To face road (+X from left, -X from right):
		mover.rotation.y = -PI / 2.0 if side == -1 else PI / 2.0
	else:
		mover.rotation.y = PI / 2.0 if side == -1 else -PI / 2.0
		
	# Since they are all rotated by 90 degrees (either PI/2 or -PI/2), the width towards the road is size_z
	var w = mover.get_meta("size_z", 8.0)
	if not is_building and mover.get_meta("size_z", -1.0) == -1.0:
		w = 2.0 # Default for packed scenes like streetlamps
		
	w *= base_scale
		
	var road_edge = 7.5 # Pushed further out
	var offset_x = road_edge + (w * 0.5)
	
	# Space them out to the edges
	mover.global_transform.origin = Vector3(side * offset_x, 0.0, z_pos)
		
	var s: float = base_scale * randf_range(0.95, 1.05)
	mover.scale = Vector3(s, s, s)


func _on_spawn_obstacle_timer_timeout():
	if _game_stopped():
		return
	spawn_obstacle_timer.wait_time = randf_range(1.6, 2.8)
	if obstacle_templates.is_empty():
		return
	var lanes: Array = [0, 1, 2]
	lanes.shuffle()
	var block_count: int = 1 + (randi() % 2)
	for i in block_count:
		_spawn_obstacle(lanes[i])


func _spawn_obstacle(lane_idx: int) -> void:
	var idx: int = randi() % obstacle_templates.size()
	if obstacle_templates.size() > 1 and idx == _last_obstacle:
		idx = (idx + 1) % obstacle_templates.size()
	_last_obstacle = idx

	var mover := _make_mover(obstacle_templates[idx])
	mover.add_to_group("obstacles")
	add_child(mover)
	mover.global_transform.origin = Vector3(road_spawnx[lane_idx], 0.0, startz)
	if mover.has_meta("slide_clear"):
		mover.rotation.y = mover.get_meta("y_rot", PI)
	elif mover.has_meta("is_car"):
		var base_rot: float = PI / 2.0 if randf() > 0.5 else -PI / 2.0
		mover.rotation.y = base_rot + randf_range(-0.25, 0.25)
	else:
		mover.rotation.y = randf() * TAU
	mover.scale = _obstacle_scale_for_template(obstacle_templates[idx])


const HIT_Z: float = 0.9
const HIT_X: float = 0.9
const JUMP_CLEAR_Y: float = 0.72


func _process(delta: float) -> void:
	if _game_stopped():
		return
	var speed: float = get_scroll_speed()
	run_distance += speed * delta
	_scroll_road_segments(delta, speed)
	_scroll_fences(delta, speed)
	
	if dense_environment:
		if run_distance > _last_left_building_dist + 12.0:
			_spawn_dense_prop(-1, startz)
			_last_left_building_dist = run_distance
		if run_distance > _last_right_building_dist + 12.0:
			_spawn_dense_prop(1, startz)
			_last_right_building_dist = run_distance
			
	if SimConstants.SECURE_SPAWNS:
		_process_secure_spawns()
		_try_segment_checkpoint()


func _scroll_road_segments(delta: float, speed: float) -> void:
	if road_segments.is_empty():
		return
	var dz: float = speed * delta
	for seg in road_segments:
		seg.position.z += dz
	var min_z: float = INF
	for seg in road_segments:
		min_z = minf(min_z, seg.position.z)
	for seg in road_segments:
		if seg.position.z > 28.0:
			min_z -= ROAD_SEGMENT_LEN
			seg.position.z = min_z


func _scroll_fences(delta: float, speed: float) -> void:
	if fences.is_empty():
		return
	var dz: float = speed * delta
	for fence_inst in fences:
		if not is_instance_valid(fence_inst):
			continue
		fence_inst.position.z += dz
		while fence_inst.position.z > FENCE_WRAP_Z:
			fence_inst.position.z -= _fence_loop_len


func _physics_process(_delta: float) -> void:
	if _game_stopped():
		return
	var pp: Vector3 = player.global_transform.origin
	for r in get_tree().get_nodes_in_group("obstacles"):
		if not is_instance_valid(r):
			continue
		var rp: Vector3 = r.global_transform.origin
		if abs(rp.z - pp.z) < HIT_Z and abs(rp.x - pp.x) < HIT_X:
			var is_overhead := r.has_meta("slide_clear")
			if is_overhead:
				if player.is_sliding:
					continue
			else:
				if pp.y >= JUMP_CLEAR_Y:
					continue

			if SimConstants.SECURE_SPAWNS:
				var oid: int = int(r.get_meta("object_id", -1))
				var lane: int = int(r.get_meta("spawn_lane", _lane_index_from_x(rp.x)))
				var dist: float = float(r.get_meta("map_distance", get_segment_distance()))
				# Failed jump: jump_start is logged at takeoff; log land before crash so replay
				# knows the player hit the obstacle low, not cleared it while airborne.
				if player.is_jumping:
					MoveLog.log_jump_land(dist)
				MoveLog.log_collision(oid, lane, dist)
				player.die()
				RunSession.submit_finish(dist, "collision")
			else:
				player.die()
			return
