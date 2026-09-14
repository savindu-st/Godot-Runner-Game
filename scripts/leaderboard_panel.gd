extends Control

signal request_open_auth()

var _dim: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _status_label: Label
var _list_container: VBoxContainer
var _personal_bar: PanelContainer
var _personal_label: Label
var _personal_action_btn: Button
var _refresh_btn: Button
var _close_btn: Button
var _loading_spinner: Label
var _is_loading: bool = false
var _top_scores: Array = []
var _my_rank_data: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	if not ApiClient.request_finished.is_connected(_on_api_response):
		ApiClient.request_finished.connect(_on_api_response)
	visible = false


func open() -> void:
	BrowserBridge.focus_canvas()
	BrowserBridge.dismiss_virtual_keyboard()
	visible = true
	if _dim:
		_dim.visible = true
		_dim.modulate.a = 0.0
	_panel.visible = true
	_panel.modulate.a = 0.0
	_panel.position.y = 40.0
	call_deferred("_relayout_panel")

	var t := create_tween().set_parallel(true)
	if _dim:
		t.tween_property(_dim, "modulate:a", 1.0, 0.2)
	t.tween_property(_panel, "modulate:a", 1.0, 0.2)
	t.tween_property(_panel, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_refresh_personal_bar()
	fetch_leaderboard()


func _relayout_panel() -> void:
	if _panel:
		BrowserBridge.apply_wide_popup(_panel, 0.78)


func close() -> void:
	var t := create_tween().set_parallel(true)
	if _dim:
		t.tween_property(_dim, "modulate:a", 0.0, 0.15)
	t.tween_property(_panel, "modulate:a", 0.0, 0.15)
	t.tween_property(_panel, "position:y", 30.0, 0.15)
	t.chain().tween_callback(func():
		visible = false
		if _dim:
			_dim.visible = false
		_panel.visible = false
	)


func fetch_leaderboard() -> void:
	if _is_loading:
		return
	_is_loading = true
	_show_loading(true)
	_status_label.text = ""
	
	# Fetch Top 20 from Supabase
	ApiClient.get_json("/v1/leaderboard")
	if AuthSession.is_logged_in():
		ApiClient.get_json("/v1/leaderboard/me")


func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.name = "LeaderboardDim"
	add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0.75)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	_dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventScreenTouch and e.pressed:
			close()
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			close()
	)

	_panel = PanelContainer.new()
	_panel.name = "LeaderboardPanel"
	add_child(_panel)
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())

	var margin := MarginContainer.new()
	_panel.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)

	var main_box := VBoxContainer.new()
	margin.add_child(main_box)
	main_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_box.add_theme_constant_override("separation", 12)

	# Header with Title
	_title_label = Label.new()
	main_box.add_child(_title_label)
	_title_label.text = "GLOBAL LEADERBOARD"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font = HudSign.get_hud_font()
	if font:
		_title_label.add_theme_font_override("font", font)
	_title_label.add_theme_font_size_override("font_size", BrowserBridge.popup_title_font() - 2)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.32)) # Gold
	_title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_title_label.add_theme_constant_override("outline_size", 10)

	# Pinned Personal Status Bar
	_personal_bar = PanelContainer.new()
	main_box.add_child(_personal_bar)
	_personal_bar.add_theme_stylebox_override("panel", _personal_bar_style())

	var p_margin := MarginContainer.new()
	_personal_bar.add_child(p_margin)
	p_margin.add_theme_constant_override("margin_left", 14)
	p_margin.add_theme_constant_override("margin_right", 14)
	p_margin.add_theme_constant_override("margin_top", 8)
	p_margin.add_theme_constant_override("margin_bottom", 8)

	var p_hbox := HBoxContainer.new()
	p_margin.add_child(p_hbox)
	p_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	p_hbox.add_theme_constant_override("separation", 12)

	_personal_label = Label.new()
	p_hbox.add_child(_personal_label)
	_personal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_personal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_personal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if font:
		_personal_label.add_theme_font_override("font", font)
	_personal_label.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font() - 2)
	_personal_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))

	_personal_action_btn = Button.new()
	p_hbox.add_child(_personal_action_btn)
	_personal_action_btn.custom_minimum_size = Vector2(140, 48)
	if font:
		_personal_action_btn.add_theme_font_override("font", font)
	_personal_action_btn.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font() - 4)
	_personal_action_btn.text = "SIGN IN"
	_personal_action_btn.add_theme_stylebox_override("normal", _pill_btn(Color(0.2, 0.65, 0.35)))
	_personal_action_btn.pressed.connect(func():
		close()
		request_open_auth.emit()
	)

	# Columns Header
	var cols_row := HBoxContainer.new()
	main_box.add_child(cols_row)
	cols_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols_row.add_theme_constant_override("separation", 8)

	var rank_hdr := Label.new()
	cols_row.add_child(rank_hdr)
	rank_hdr.custom_minimum_size.x = 80
	rank_hdr.text = "RANK"
	rank_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_hdr.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font() - 6)
	rank_hdr.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))

	var name_hdr := Label.new()
	cols_row.add_child(name_hdr)
	name_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_hdr.text = "PLAYER"
	name_hdr.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font() - 6)
	name_hdr.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))

	var dist_hdr := Label.new()
	cols_row.add_child(dist_hdr)
	dist_hdr.custom_minimum_size.x = 130
	dist_hdr.text = "DISTANCE"
	dist_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dist_hdr.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font() - 6)
	dist_hdr.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))

	# Scroll Container for Rankings List
	var scroll := ScrollContainer.new()
	main_box.add_child(scroll)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_list_container = VBoxContainer.new()
	scroll.add_child(_list_container)
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.add_theme_constant_override("separation", 6)

	# Loading & Status Indicator
	_status_label = Label.new()
	main_box.add_child(_status_label)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font() - 4)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))

	# Bottom Action Buttons
	var bottom_row := HBoxContainer.new()
	main_box.add_child(bottom_row)
	bottom_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_theme_constant_override("separation", 16)

	_refresh_btn = Button.new()
	bottom_row.add_child(_refresh_btn)
	_refresh_btn.custom_minimum_size = Vector2(0, BrowserBridge.popup_button_height())
	_refresh_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font:
		_refresh_btn.add_theme_font_override("font", font)
	_refresh_btn.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font())
	_refresh_btn.text = "REFRESH"
	_refresh_btn.add_theme_stylebox_override("normal", _pill_btn(Color(0.25, 0.38, 0.65)))
	_refresh_btn.pressed.connect(fetch_leaderboard)

	_close_btn = Button.new()
	bottom_row.add_child(_close_btn)
	_close_btn.custom_minimum_size = Vector2(0, BrowserBridge.popup_button_height())
	_close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font:
		_close_btn.add_theme_font_override("font", font)
	_close_btn.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font())
	_close_btn.text = "CLOSE"
	_close_btn.add_theme_stylebox_override("normal", _pill_btn(Color(0.28, 0.32, 0.42)))
	_close_btn.pressed.connect(close)


func _refresh_personal_bar() -> void:
	if AuthSession.is_logged_in():
		var rank_str := "#%d" % AuthSession.global_rank if AuthSession.global_rank > 0 else "Unranked"
		_personal_label.text = "You: %s · %s · Best: %dm" % [rank_str, AuthSession.username, AuthSession.best_distance]
		_personal_action_btn.visible = false
	else:
		_personal_label.text = "Guest Mode (Local Best: %dm)" % AuthSession.best_distance
		_personal_action_btn.visible = true
		_personal_action_btn.text = "SIGN IN"


func _show_loading(is_loading: bool) -> void:
	if is_loading:
		_refresh_btn.disabled = true
		_refresh_btn.text = "LOADING..."
	else:
		_refresh_btn.disabled = false
		_refresh_btn.text = "REFRESH"


func _on_api_response(path: String, success: bool, _status: int, body: Dictionary) -> void:
	if path == "/v1/leaderboard":
		_is_loading = false
		_show_loading(false)
		if success:
			_top_scores = body.get("data", body.get("top", []))
			_populate_list()
		else:
			var err := str(body.get("error", body.get("message", "Could not connect to leaderboard.")))
			_status_label.text = "Error: %s" % err
	elif path == "/v1/leaderboard/me":
		if success:
			_my_rank_data = body
			if body.has("rank"):
				AuthSession.global_rank = int(body["rank"])
			if body.has("best_distance"):
				AuthSession.best_distance = int(body["best_distance"])
			if body.has("best_coins"):
				AuthSession.best_coins = int(body["best_coins"])
			_refresh_personal_bar()


func _populate_list() -> void:
	# Clear old children
	for child in _list_container.get_children():
		child.queue_free()

	if _top_scores.is_empty():
		var empty_lbl := Label.new()
		_list_container.add_child(empty_lbl)
		empty_lbl.text = "\nNo high scores recorded yet.\nBe the first to set a record!"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font())
		empty_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
		return

	var font = HudSign.get_hud_font()
	var current_username := AuthSession.username.strip_edges().to_lower()

	for i in range(_top_scores.size()):
		var entry = _top_scores[i]
		if not entry is Dictionary:
			continue

		var rank: int = i + 1
		var uname: String = str(entry.get("username", "Runner"))
		var dist: int = int(entry.get("best_distance", entry.get("distance", 0)))
		var is_me: bool = AuthSession.is_logged_in() and (uname.to_lower() == current_username)

		var row := PanelContainer.new()
		_list_container.add_child(row)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_stylebox_override("panel", _row_style(rank, is_me))

		var r_margin := MarginContainer.new()
		row.add_child(r_margin)
		r_margin.add_theme_constant_override("margin_left", 12)
		r_margin.add_theme_constant_override("margin_right", 12)
		r_margin.add_theme_constant_override("margin_top", 8)
		r_margin.add_theme_constant_override("margin_bottom", 8)

		var hbox := HBoxContainer.new()
		r_margin.add_child(hbox)
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_theme_constant_override("separation", 8)

		# Rank Badge
		var rank_lbl := Label.new()
		hbox.add_child(rank_lbl)
		rank_lbl.custom_minimum_size.x = 80
		rank_lbl.text = "#%d" % rank
		rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if font:
			rank_lbl.add_theme_font_override("font", font)
		rank_lbl.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font())
		rank_lbl.add_theme_color_override("font_color", _rank_color(rank))

		# Player Name
		var name_lbl := Label.new()
		hbox.add_child(name_lbl)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.text = uname + (" (YOU)" if is_me else "")
		if font:
			name_lbl.add_theme_font_override("font", font)
		name_lbl.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font() - 2)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4) if is_me else Color.WHITE)

		# Distance Score
		var dist_lbl := Label.new()
		hbox.add_child(dist_lbl)
		dist_lbl.custom_minimum_size.x = 130
		dist_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		dist_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dist_lbl.text = "%dm" % dist
		if font:
			dist_lbl.add_theme_font_override("font", font)
		dist_lbl.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font())
		dist_lbl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6))


func _rank_color(rank: int) -> Color:
	match rank:
		1:
			return Color(1.0, 0.84, 0.15) # Gold
		2:
			return Color(0.85, 0.88, 0.95) # Silver
		3:
			return Color(0.9, 0.58, 0.32) # Bronze
		_:
			return Color(0.65, 0.72, 0.85)


func _row_style(rank: int, is_me: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if is_me:
		sb.bg_color = Color(0.12, 0.22, 0.35, 0.9)
		sb.border_color = Color(0.3, 0.75, 1.0, 0.8)
		sb.set_border_width_all(2)
	elif rank == 1:
		sb.bg_color = Color(0.18, 0.14, 0.04, 0.8)
		sb.border_color = Color(1.0, 0.82, 0.2, 0.6)
		sb.set_border_width_all(1)
	elif rank % 2 == 0:
		sb.bg_color = Color(0.08, 0.10, 0.16, 0.75)
		sb.set_border_width_all(0)
	else:
		sb.bg_color = Color(0.05, 0.06, 0.10, 0.75)
		sb.set_border_width_all(0)
	sb.set_corner_radius_all(12)
	return sb


func _personal_bar_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.14, 0.22, 0.95)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.35, 0.65, 1.0, 0.7)
	sb.shadow_size = 8
	sb.shadow_color = Color(0.2, 0.5, 0.9, 0.25)
	return sb


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.10, 0.98)
	sb.set_corner_radius_all(24)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 0.82, 0.22, 0.85)
	sb.shadow_size = 20
	sb.shadow_color = Color(1.0, 0.82, 0.22, 0.25)
	return sb


func _pill_btn(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(2)
	sb.border_color = c.lightened(0.2)
	sb.shadow_size = 6
	sb.shadow_color = c * Color(1, 1, 1, 0.3)
	return sb
