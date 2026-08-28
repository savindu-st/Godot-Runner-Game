extends Node

@onready var player: CharacterBody3D = $player_body
@onready var spawn_timer: Timer = $spawn_timer
@onready var spawn_env_timer: Timer = $spawn_env_timer
@onready var spawn_obstacle_timer: Timer = $spawn_obstacle_timer

@onready var coin: PackedScene = preload("res://scenes/coin.tscn")
@onready var fence: PackedScene = preload("res://models/cartoon-assets/fence.tscn")

@onready var asphalt_mat: Material = preload("res://models/road_asphalt.tres")

@onready var env_move_script = preload("res://scripts/env_script.gd")

const NATURE_TREES: Array = [
	"res://models/nature/tree1.glb",
	"res://models/nature/tree2.glb",
	"res://models/nature/tree3.glb",
]
const OBSTACLE_MODELS: Array = [
	"res://models/nature/rock1.glb",
	"res://models/nature/rock2.glb",
]

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

# roadside street-name boards
var street_names: Array = [
	"Lagaan", "Girl's Hostel", "Boat Yard", "Civil Dep", "Thunmulla",
	"Seetha Gangula", "Sumanadasa", "Steel Building", "Basketball Court",
]
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
	_setup_road_segments()
	_setup_fences()
	_setup_signs()
	if SimConstants.SECURE_SPAWNS:
		call_deferred("_boot_secure_segment")
	for _i in 3:
		await get_tree().process_frame
	_load_nature()
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
	if name == "Lagaan":
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
	_collect(NATURE_TREES, tree_templates)
	_collect(OBSTACLE_MODELS, obstacle_templates)
	
	# Procedural Traffic Cone
	var cone := MeshInstance3D.new()
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.05
	cone_mesh.bottom_radius = 0.35
	cone_mesh.height = 0.8
	cone.mesh = cone_mesh
	var cone_mat := StandardMaterial3D.new()
	cone_mat.albedo_color = Color(1.0, 0.4, 0.0)
	cone.material_override = cone_mat
	cone.set_meta("height", 0.8)
	obstacle_templates.append(cone)

	# Procedural Speaker Box
	var speaker := MeshInstance3D.new()
	var speaker_mesh := BoxMesh.new()
	speaker_mesh.size = Vector3(0.6, 0.9, 0.5)
	speaker.mesh = speaker_mesh
	var speaker_mat := StandardMaterial3D.new()
	speaker_mat.albedo_color = Color(0.1, 0.1, 0.1)
	speaker.material_override = speaker_mat
	speaker.set_meta("height", 0.9)
	obstacle_templates.append(speaker)


func _obstacle_scale_for_template(tpl: MeshInstance3D, rng: SeededRng = null) -> Vector3:
	var h: float = maxf(float(tpl.get_meta("height", 1.0)), 0.01)
	var target_h: float
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


func _gather_meshes(n: Node, into: Array) -> void:
	if n is MeshInstance3D:
		into.append(n)
	for c in n.get_children():
		_gather_meshes(c, into)


func _make_mover(template: MeshInstance3D) -> Node3D:
	var mover := Node3D.new()
	mover.set_script(env_move_script)
	mover.add_child(template.duplicate())
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
		if abs(rp.z - pp.z) < HIT_Z and abs(rp.x - pp.x) < HIT_X and pp.y < JUMP_CLEAR_Y:
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
