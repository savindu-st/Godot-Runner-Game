extends CharacterBody3D

signal character_ready

const PLAYER_MODEL: PackedScene = preload("res://models/anime-girl/anime-girl.glb")
const COIN_SFX: AudioStream = preload("res://sounds/coinpickup.wav")

@onready var audio_player: AudioStreamPlayer = $CoinSFX
@onready var death_audio: AudioStreamPlayer = $DeathSFX
var anim_player: AnimationPlayer

const JUMP_FORCE: float = 9.0
const GRAVITY: float = 22.0
const LANE_SWITCH_SPEED: float = 14.0      # how fast the player slides between lanes
const SWIPE_THRESHOLD: float = 40.0        # min finger travel (px) to count as a swipe

# 3 lanes, matching the obstacle/coin spawn positions in level.gd (road_spawnx)
const LANE_X: Array = [-2.0, 0.0, 2.0]

var ground_y: float = 0.0
var vertical_velocity: float = 0.0

var current_lane: int = 1                  # 0 = left, 1 = center, 2 = right
var jump_requested: bool = false

var run_anim: String = ""
var jump_anim: String = ""
var death_anim: String = ""
var dance_anim: String = ""
var is_jumping: bool = false

var game_started: bool = false
var is_dead: bool = false
var dying: bool = false
var game_over: bool = false
var coin_count: int = 0

var coin_label: Label
var _name_label: Label
var _best_label: Label
var _back_btn: Button
var overlay: Control
var result_label: Label

var _finish_data: Dictionary = {}
var _finish_done: bool = false
var _finish_success: bool = false
var _finish_ui_finalized: bool = false
var _finish_wait_timer: Timer
var _play_again_btn: Button
var _menu_btn: Button
var _start_overlay: Control
var _start_btn: Button
var _countdown_label: Label
var _countdown_running: bool = false
var _run_aborted: bool = false
var _hud_layer: CanvasLayer
var _character_model: Node3D
var _character_ready: bool = false

const FINISH_WAIT_SEC: float = 22.0

# swipe tracking
var _touch_start: Vector2 = Vector2.ZERO
var _swiped: bool = false

func _ready() -> void:
	# keep running while the tree is paused so we can detect the restart tap
	process_mode = Node.PROCESS_MODE_ALWAYS

	# rocks look for an area in this group to know they hit the player
	$collision_area.add_to_group("player_skeleton")
	call_deferred("_init_player")


func is_character_ready() -> bool:
	return _character_ready


func wait_for_character() -> void:
	if _character_ready:
		return
	await character_ready


func _init_player() -> void:
	await _ensure_character()
	ground_y = global_transform.origin.y
	_bind_anims()
	_enter_attract_mode()
	_setup_hud()
	if not RunSession.checkpoint_resolved.is_connected(_on_checkpoint_resolved):
		RunSession.checkpoint_resolved.connect(_on_checkpoint_resolved)
	if not RunSession.finish_resolved.is_connected(_on_finish_resolved):
		RunSession.finish_resolved.connect(_on_finish_resolved)
	if not AuthSession.profile_updated.is_connected(_on_profile_updated):
		AuthSession.profile_updated.connect(_on_profile_updated)
	if death_audio:
		death_audio.process_mode = Node.PROCESS_MODE_ALWAYS
		death_audio.add_to_group("web_audio")
		BrowserBridge.configure_audio_player(death_audio)
	if audio_player:
		audio_player.add_to_group("web_audio")
		if audio_player.stream == null:
			audio_player.stream = COIN_SFX
		BrowserBridge.configure_audio_player(audio_player)
	if not get_viewport().size_changed.is_connected(_layout_hud_panels):
		get_viewport().size_changed.connect(_layout_hud_panels)
	call_deferred("_layout_hud_panels")
	_refresh_coin_hud()


func _exit_tree() -> void:
	var vp := get_viewport()
	if vp and vp.size_changed.is_connected(_layout_hud_panels):
		vp.size_changed.disconnect(_layout_hud_panels)

# Wire the runner mesh (scene instance + retry if GPU upload fails on web).
func _ensure_character() -> void:
	_character_model = get_node_or_null("player") as Node3D
	if _character_model == null:
		_spawn_character_node()
	else:
		_apply_character_transform(_character_model)

	for _attempt in 8:
		if _character_model == null:
			_spawn_character_node()
		if _count_render_meshes(_character_model) > 0:
			_wire_animation_player()
			_matte_meshes(_character_model)
			_character_model.visible = true
			_mark_character_ready()
			return
		await get_tree().process_frame

	if _character_model:
		_character_model.queue_free()
		_character_model = null
		await get_tree().process_frame
	_spawn_character_node()
	_wire_animation_player()
	_matte_meshes(_character_model)
	if _character_model:
		_character_model.visible = true
	_mark_character_ready()


func _mark_character_ready() -> void:
	if _character_ready:
		return
	_character_ready = true
	character_ready.emit()


func _spawn_character_node() -> void:
	_character_model = PLAYER_MODEL.instantiate()
	_character_model.name = "player"
	add_child(_character_model)
	move_child(_character_model, 0)
	_apply_character_transform(_character_model)


func _apply_character_transform(model: Node3D) -> void:
	var s: float = 0.85
	model.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3(s, s, s)), Vector3.ZERO)


func _wire_animation_player() -> void:
	if _character_model == null:
		return
	anim_player = _character_model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim_player == null:
		anim_player = _character_model.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _count_render_meshes(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			count += 1
	for child in node.get_children():
		count += _count_render_meshes(child)
	return count


func _matte_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for si in mi.mesh.get_surface_count():
				var mat: Material = mi.get_surface_override_material(si)
				if mat == null:
					mat = mi.mesh.surface_get_material(si)
				if mat == null:
					continue
				var flat := mat.duplicate()
				if flat is StandardMaterial3D:
					var sm := flat as StandardMaterial3D
					sm.roughness = 1.0
					sm.metallic = 0.0
					sm.metallic_specular = 0.0
					sm.roughness_texture = null
					sm.metallic_texture = null
					sm.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				mi.set_surface_override_material(si, flat)
	for child in node.get_children():
		_matte_meshes(child)


func _setup_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 100
	_hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_hud_layer)

	# Top bar — menu on row 1 left; username row 2 left; best + coins stacked right.
	_name_label = _make_hud_label(_hud_layer, HORIZONTAL_ALIGNMENT_LEFT, Color(0.9, 0.95, 1.0))
	_name_label.add_theme_font_size_override("font_size", BrowserBridge.hud_hint_font() + 2)
	coin_label = _make_hud_label(_hud_layer, HORIZONTAL_ALIGNMENT_RIGHT, Color(1, 0.96, 0.78))
	coin_label.add_theme_font_size_override("font_size", BrowserBridge.hud_font() + 2)
	coin_label.text = "0"
	_best_label = _make_hud_label(_hud_layer, HORIZONTAL_ALIGNMENT_RIGHT, Color(1, 0.88, 0.42))
	_best_label.add_theme_font_size_override("font_size", BrowserBridge.hud_hint_font() + 2)

	_setup_back_button(_hud_layer)

	# ---- full-screen game-over overlay (dim + centered card) ----
	overlay = Control.new()
	_hud_layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false

	var bg := ColorRect.new()
	overlay.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.66)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var card := PanelContainer.new()
	overlay.add_child(card)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	BrowserBridge.apply_wide_popup(card, 0.48)
	card.add_theme_stylebox_override("panel", _card_style())

	var margin := MarginContainer.new()
	card.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)

	var box := VBoxContainer.new()
	margin.add_child(box)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 20)

	var title := Label.new()
	box.add_child(title)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", BrowserBridge.popup_title_font() + 8)
	title.add_theme_color_override("font_color", Color(1, 0.32, 0.28))
	title.text = "GAME OVER"

	result_label = Label.new()
	box.add_child(result_label)
	result_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font() + 4)
	result_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	result_label.text = "Score 0     Coins 0"

	box.add_child(_spacer(12))

	_play_again_btn = Button.new()
	box.add_child(_play_again_btn)
	_play_again_btn.custom_minimum_size = Vector2(0, BrowserBridge.popup_button_height())
	_play_again_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_again_btn.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font())
	_play_again_btn.text = "RESTART GAME"
	_play_again_btn.add_theme_stylebox_override("normal", _pill_style(Color(0.92, 0.95, 1.0)))
	_play_again_btn.add_theme_color_override("font_color", Color(0.08, 0.1, 0.14))
	_play_again_btn.pressed.connect(_restart)

	_menu_btn = Button.new()
	box.add_child(_menu_btn)
	_menu_btn.custom_minimum_size = Vector2(0, BrowserBridge.popup_button_height() - 8)
	_menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_btn.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font())
	_menu_btn.add_theme_color_override("font_color", Color(0.85, 0.72, 0.35))
	_menu_btn.text = "Menu"
	_menu_btn.add_theme_stylebox_override("normal", _pill_style(Color(0.12, 0.14, 0.2)))
	_menu_btn.pressed.connect(_go_menu)

	_setup_start_prompt(_hud_layer)
	call_deferred("_layout_hud_panels")


func _setup_back_button(layer: CanvasLayer) -> void:
	_back_btn = Button.new()
	layer.add_child(_back_btn)
	_back_btn.text = ""
	_back_btn.icon = _make_back_icon()
	_back_btn.expand_icon = true
	_back_btn.add_theme_constant_override("icon_max_width", 24)
	_back_btn.add_theme_stylebox_override("normal", _pill_style(Color(0.1, 0.12, 0.18, 0.88)))
	_back_btn.add_theme_stylebox_override("hover", _pill_style(Color(0.14, 0.16, 0.24, 0.92)))
	_back_btn.add_theme_stylebox_override("pressed", _pill_style(Color(0.08, 0.1, 0.15, 0.95)))
	_back_btn.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	_run_aborted = true
	_countdown_running = false
	if game_over:
		_go_menu()
		return
	RunSession.run_active = false
	var level := get_tree().get_first_node_in_group("level")
	if level and level.has_method("freeze_world"):
		level.freeze_world()
	_go_menu()


func _setup_start_prompt(layer: CanvasLayer) -> void:
	_start_overlay = Control.new()
	layer.add_child(_start_overlay)
	_start_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_start_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_start_btn = Button.new()
	_start_overlay.add_child(_start_btn)
	_start_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_start_btn.offset_top = -88.0
	_start_btn.offset_bottom = -28.0
	_start_btn.offset_left = -130.0
	_start_btn.offset_right = 130.0
	_start_btn.custom_minimum_size = Vector2(260, BrowserBridge.popup_button_height())
	_start_btn.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font() + 2)
	_start_btn.text = "START"
	_start_btn.add_theme_stylebox_override("normal", _pill_style(Color(0.16, 0.72, 0.4)))
	_start_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	_start_btn.pressed.connect(_on_start_pressed)

	_countdown_label = Label.new()
	_start_overlay.add_child(_countdown_label)
	_countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	_countdown_label.offset_top = -40.0
	_countdown_label.offset_bottom = 40.0
	_countdown_label.offset_left = -160.0
	_countdown_label.offset_right = 160.0
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_countdown_label.add_theme_font_size_override("font_size", BrowserBridge.popup_title_font() + 36)
	_countdown_label.add_theme_color_override("font_color", Color(1, 0.92, 0.35))
	_countdown_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_countdown_label.add_theme_constant_override("outline_size", 12)
	_countdown_label.visible = false


func _enter_attract_mode() -> void:
	game_started = false
	is_dead = false
	dying = false
	game_over = false
	coin_count = 0
	_finish_data = {}
	_finish_done = false
	_finish_success = false
	_finish_ui_finalized = false
	_refresh_coin_hud()
	if overlay:
		overlay.visible = false
	if _start_overlay:
		_start_overlay.visible = true
	if _start_btn:
		_start_btn.disabled = false
		_start_btn.visible = true
	if _countdown_label:
		_countdown_label.visible = false
	_countdown_running = false
	_run_aborted = false
	var idle_anim: String = dance_anim if dance_anim != "" else run_anim
	_play_anim(idle_anim, true)


func _on_start_pressed() -> void:
	if game_started or game_over or is_dead or _countdown_running:
		return
	BrowserBridge.unlock_web_audio()
	var level := get_tree().get_first_node_in_group("level")
	if level and level.has_method("begin_run"):
		level.begin_run()
	_countdown_running = true
	if _start_btn:
		_start_btn.disabled = true
		_start_btn.visible = false
	await _run_start_countdown()
	if _run_aborted or game_over or is_dead:
		_countdown_running = false
		return
	game_started = true
	_countdown_running = false
	RunSession.mark_run_scroll_started()
	if _start_overlay:
		_start_overlay.visible = false
	_play_anim(run_anim, true)


func _run_start_countdown() -> void:
	if _countdown_label == null:
		return
	_countdown_label.visible = true
	var steps: PackedStringArray = PackedStringArray(["3", "2", "1", "GO!"])
	for i in steps.size():
		if _run_aborted or not is_inside_tree():
			break
		_countdown_label.text = steps[i]
		var wait_sec: float = 0.65 if steps[i] == "GO!" else 0.85
		await get_tree().create_timer(wait_sec).timeout
	if _countdown_label and is_inside_tree():
		_countdown_label.visible = false


func _make_hud_label(parent: Node, align: HorizontalAlignment, color: Color) -> Label:
	var label := Label.new()
	parent.add_child(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", BrowserBridge.hud_font())
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 5)
	return label


func _layout_hud_panels() -> void:
	if not is_inside_tree():
		return
	var width := get_viewport().get_visible_rect().size.x
	if width <= 0.0:
		width = float(get_viewport().size.x)
	if width <= 0.0:
		width = 720.0

	var pad_left := maxf(BrowserBridge.popup_edge_margin() + 16.0, 28.0)
	var pad_right := maxf(BrowserBridge.popup_edge_margin() + 16.0, 28.0)
	var pad_top := 24.0
	var menu_size := 44.0
	var row_h := 34.0
	var row_gap := 10.0
	var col_gap := 16.0
	var right_w := clampf(width * 0.3, 96.0, 156.0)
	var right_x := width - pad_right - right_w

	if _back_btn:
		_back_btn.position = Vector2(pad_left, pad_top)
		_back_btn.size = Vector2(menu_size, menu_size)

	var name_top := pad_top + menu_size + row_gap
	var name_w := maxf(72.0, right_x - pad_left - col_gap)
	if _name_label:
		_name_label.position = Vector2(pad_left, name_top)
		_name_label.size = Vector2(name_w, row_h + 4.0)

	if _best_label:
		_best_label.position = Vector2(right_x, pad_top)
		_best_label.size = Vector2(right_w, row_h)

	if coin_label:
		coin_label.position = Vector2(right_x, pad_top + row_h + 4.0)
		coin_label.size = Vector2(right_w, row_h + 2.0)


func _refresh_coin_hud() -> void:
	if coin_label:
		coin_label.text = str(coin_count)
	var show_hud := true
	if _name_label:
		_name_label.visible = show_hud
	if _best_label:
		_best_label.visible = show_hud
	if not show_hud:
		return
	var player_name := AuthSession.username.strip_edges()
	if player_name == "":
		player_name = AuthSession.index_number.strip_edges()
	if player_name == "":
		player_name = "Guest"
	if _name_label:
		_name_label.text = player_name
	if _best_label:
		_best_label.text = "Best %d" % AuthSession.best_coins


func _on_profile_updated(_body: Dictionary) -> void:
	_refresh_coin_hud()


func _on_checkpoint_resolved(accepted: bool, data: Dictionary) -> void:
	if is_dead or dying or game_over:
		return
	if accepted:
		coin_count = int(data.get("run_total_coins", coin_count))
		_refresh_coin_hud()


func _on_finish_resolved(success: bool, data: Dictionary) -> void:
	_finish_data = data
	_finish_success = success
	_finish_done = true
	if success:
		_refresh_coin_hud()
	if game_over and not _finish_ui_finalized:
		_stop_finish_wait()
		_trigger_game_over()


func _card_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.14, 0.97)
	sb.set_corner_radius_all(20)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 0.35, 0.3, 0.7)
	sb.shadow_size = 16
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s

func _pill_style(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(32)
	return sb


func _make_back_icon() -> ImageTexture:
	var px := 32
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var color := Color(0.92, 0.95, 1.0)
	_stamp_line(img, Vector2i(21, 7), Vector2i(9, 16), color, 2)
	_stamp_line(img, Vector2i(9, 16), Vector2i(21, 25), color, 2)
	return ImageTexture.create_from_image(img)


func _stamp_line(img: Image, from: Vector2i, to: Vector2i, color: Color, half: int) -> void:
	var d := to - from
	var steps := maxi(maxi(absi(d.x), absi(d.y)), 1)
	for i in steps + 1:
		var t := float(i) / float(steps)
		var p := Vector2i(
			int(round(lerpf(float(from.x), float(to.x), t))),
			int(round(lerpf(float(from.y), float(to.y), t)))
		)
		for oy in range(-half, half + 1):
			for ox in range(-half, half + 1):
				var x := p.x + ox
				var y := p.y + oy
				if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
					continue
				img.set_pixel(x, y, color)

func _bind_anims() -> void:
	if anim_player == null:
		return
	run_anim = _find_anim(["running", "run"])
	jump_anim = _find_anim(["jump"])
	death_anim = _find_anim(["death", "fall"])
	dance_anim = _find_anim(["danc", "dance"])


func _find_anim(keywords: Array) -> String:
	for anim_name in anim_player.get_animation_list():
		var lower := String(anim_name).to_lower()
		for keyword in keywords:
			if String(keyword).to_lower() in lower:
				return anim_name
	return ""


func _play_anim(anim_name: String, loop: bool) -> void:
	if anim_name == "" or anim_player == null:
		return
	var anim: Animation = anim_player.get_animation(anim_name)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	anim_player.play(anim_name)

# --- input: swipe to change lane / jump, tap to restart ---------------------
func _unhandled_input(event: InputEvent) -> void:
	if game_over or not game_started:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
			_swiped = false
	elif event is InputEventScreenDrag:
		_evaluate_swipe(event.position)
	# mouse fallback (for testing on desktop)
	elif event is InputEventMouseButton:
		if event.pressed:
			_touch_start = event.position
			_swiped = false
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_evaluate_swipe(event.position)

func _evaluate_swipe(pos: Vector2) -> void:
	if _swiped:
		return
	var d: Vector2 = pos - _touch_start
	if absf(d.x) > SWIPE_THRESHOLD and absf(d.x) >= absf(d.y):
		_change_lane(1 if d.x > 0.0 else -1)
		_swiped = true
	elif d.y < -SWIPE_THRESHOLD:
		jump_requested = true
		_swiped = true

func _change_lane(dir: int) -> void:
	var old_lane: int = current_lane
	current_lane = clampi(current_lane + dir, 0, LANE_X.size() - 1)
	if old_lane == current_lane:
		return
	var level := get_tree().get_first_node_in_group("level")
	if level and level.has_method("get_segment_distance") and MoveLog.can_log_lane_change():
		MoveLog.log_lane_change(old_lane, current_lane, level.get_segment_distance())

func _restart() -> void:
	get_tree().paused = false
	if SimConstants.API_BASE.is_empty():
		RunSession.restart_run()
		get_tree().reload_current_scene()
		return
	if RunSession.run_ready.is_connected(_on_restart_run_ready):
		RunSession.run_ready.disconnect(_on_restart_run_ready)
	RunSession.run_ready.connect(_on_restart_run_ready, CONNECT_ONE_SHOT)
	RunSession.restart_run()


func _on_restart_run_ready(success: bool, error_message: String) -> void:
	if success:
		get_tree().reload_current_scene()
		return
	get_tree().paused = false
	_finish_success = false
	_finish_done = true
	_finish_data = {
		"message": GameSettings.USER_ERROR_MSG,
	}
	_finish_ui_finalized = false
	_trigger_game_over()


func _go_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _physics_process(delta: float) -> void:
	if game_over:
		return

	if is_dead:
		if not dying:
			_start_death()
		return

	if not game_started:
		return

	# keyboard fallback so it's also playable on desktop
	if Input.is_action_just_pressed("move_left"):
		_change_lane(-1)
	if Input.is_action_just_pressed("move_right"):
		_change_lane(1)
	if Input.is_action_just_pressed("jump"):
		jump_requested = true

	var pos: Vector3 = global_transform.origin

	# slide toward the target lane
	var target_x: float = LANE_X[current_lane]
	pos.x = move_toward(pos.x, target_x, LANE_SWITCH_SPEED * delta)

	# jump only when on the ground
	var on_ground: bool = pos.y <= ground_y + 0.01
	if on_ground and jump_requested:
		vertical_velocity = JUMP_FORCE
		is_jumping = true
		var level := get_tree().get_first_node_in_group("level")
		if level and level.has_method("get_segment_distance"):
			MoveLog.log_jump_start(level.get_segment_distance())
		if jump_anim != "":
			_play_anim(jump_anim, false)
	jump_requested = false

	# gravity + vertical move (no floor collider, handled manually)
	vertical_velocity -= GRAVITY * delta
	pos.y += vertical_velocity * delta
	if pos.y <= ground_y:
		pos.y = ground_y
		vertical_velocity = 0.0
		if is_jumping:
			is_jumping = false
			var level := get_tree().get_first_node_in_group("level")
			if level and level.has_method("get_segment_distance"):
				MoveLog.log_jump_land(level.get_segment_distance())
			_play_anim(run_anim, true)

	global_transform.origin = pos

func die() -> void:
	if is_dead:
		return
	is_dead = true
	var hitbox: Area3D = $collision_area
	hitbox.monitoring = false
	hitbox.monitorable = false
	var level := get_tree().get_first_node_in_group("level")
	if level and level.has_method("freeze_world"):
		level.freeze_world()


func _start_death() -> void:
	dying = true
	# submit_finish() runs in level.gd before this — response may arrive first
	if not _finish_done:
		_finish_success = false
		_finish_data = {}
	_finish_ui_finalized = false
	if death_audio and GameSettings.sound_enabled:
		death_audio.play()
	_play_anim(death_anim, false)
	var death_wait: float = 1.5
	if death_anim != "":
		var a := anim_player.get_animation(death_anim)
		if a:
			death_wait = maxf(a.length, 0.5)
	await get_tree().create_timer(death_wait, true).timeout
	if RunSession.offline_mode:
		_finish_success = true
		if coin_count > AuthSession.best_coins:
			AuthSession.set_auth({"best_coins": coin_count})
		_finish_data = {"final_coins": coin_count}
		_show_game_over_loading()
		_trigger_game_over()
		return
	_show_game_over_loading()
	if _finish_done:
		_trigger_game_over()
	else:
		_arm_finish_wait()


func _arm_finish_wait() -> void:
	if _finish_wait_timer == null:
		_finish_wait_timer = Timer.new()
		_finish_wait_timer.one_shot = true
		_finish_wait_timer.wait_time = FINISH_WAIT_SEC
		_finish_wait_timer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_finish_wait_timer)
		_finish_wait_timer.timeout.connect(_on_finish_wait_timeout)
	_finish_wait_timer.start()


func _stop_finish_wait() -> void:
	if _finish_wait_timer:
		_finish_wait_timer.stop()


func _on_finish_wait_timeout() -> void:
	if _finish_ui_finalized or _finish_done:
		return
	_finish_success = false
	_finish_done = true
	_finish_data = {
		"error": "timeout",
		"message": GameSettings.USER_ERROR_MSG,
	}
	_trigger_game_over()


func _show_game_over_loading() -> void:
	game_over = true
	result_label.text = "Loading..."
	if _play_again_btn:
		_play_again_btn.disabled = true
	if _menu_btn:
		_menu_btn.disabled = true
	overlay.visible = true
	overlay.modulate.a = 1.0


func _trigger_game_over() -> void:
	if _finish_ui_finalized:
		return
	_finish_ui_finalized = true
	_stop_finish_wait()
	if not game_over:
		game_over = true
		overlay.visible = true
		overlay.modulate.a = 1.0

	get_tree().paused = true

	if _play_again_btn:
		_play_again_btn.disabled = false
	if _menu_btn:
		_menu_btn.disabled = false

	var lines: PackedStringArray = PackedStringArray()
	if _finish_success:
		var display_coins: int = int(_finish_data.get("final_coins", 0))
		lines.append("Coins %d" % display_coins)
		var rank: int = int(_finish_data.get("rank", 0))
		if rank > 0:
			lines.append("Rank #%d" % rank)
	else:
		lines.append(GameSettings.USER_ERROR_MSG)

	result_label.text = "\n".join(lines)
	overlay.visible = true
	overlay.modulate.a = 1.0


func _on_collision_area_entered(area) -> void:
	if not game_started or is_dead or dying or game_over:
		return
	var parent = area.get_parent()
	if parent.is_in_group("coins"):
		_play_coin_sfx()
		coin_count += 1
		_refresh_coin_hud()
		var level := get_tree().get_first_node_in_group("level")
		if level and level.has_method("get_segment_distance"):
			var oid: int = int(parent.get_meta("object_id", -1))
			var lane: int = int(parent.get_meta("spawn_lane", current_lane))
			var dist: float = float(parent.get_meta("map_distance", level.get_segment_distance()))
			MoveLog.log_coin(oid, lane, dist)
		parent.queue_free()


func _play_coin_sfx() -> void:
	if not GameSettings.sound_enabled or audio_player == null:
		return
	if audio_player.stream == null:
		audio_player.stream = COIN_SFX
	if OS.has_feature("web"):
		BrowserBridge.unlock_web_audio()
	audio_player.play()
