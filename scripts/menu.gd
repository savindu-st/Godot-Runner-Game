extends Control

const TICKET_URL: String = "https://epilogue.moraspirit.com"
const MENU_BG: Texture2D = preload("res://assets/menu_bg.jpg")

const WIN_TICKET_TEXT := (
	"The student in first place on the leaderboard wins a ticket to the Epilogue concert.\n\n"
	+ "We select a new winner each week until Epilogue concert day (28 July).\n\n"
	+ "Keep playing, climb the ranks, and good luck!\n\n"
	+ "Terms and conditions apply."
)

const ABOUT_US_TEXT := (
	"We are Moraspirit — The Voice of University Sports in Sri Lanka.\n\n"
	+ "This game is proudly developed by the Web and Technology pillar of Moraspirit.\n\n"
	+ "moraspirit.com"
)

var _overlay: PanelContainer
var _overlay_title: Label
var _overlay_body: Label
var _overlay_close: Button
var _overlay_back_to_settings: bool = false
var _settings_panel: PanelContainer
var _settings_box: VBoxContainer
var _sound_btn: Button
var _play_btn: Button
var _auth_panel: Control
var _login_btn: Button
var _logout_btn: Button
var _title_label: Label
var _subtitle_label: Label
var _menu_name_label: Label
var _menu_best_label: Label
var _play_wait_timer: Timer
var _offline_name_field: LineEdit
var _btn_font: int = 42
var _title_font: int = 92


func _ready() -> void:
	GameSettings.apply_sound()
	_apply_responsive_scale()
	_build_ui()
	_refresh_auth_ui()
	if not AuthSession.auth_ready.is_connected(_on_auth_ready):
		AuthSession.auth_ready.connect(_on_auth_ready)
	# Login opens via PLAY ("LOGIN TO PLAY") or Settings — not forced on load.
	if not ApiClient.request_finished.is_connected(_on_api_leaderboard):
		ApiClient.request_finished.connect(_on_api_leaderboard)
	if not AuthSession.profile_updated.is_connected(_on_profile_updated):
		AuthSession.profile_updated.connect(_on_profile_updated)
	if not get_viewport().size_changed.is_connected(_layout_menu_top_bar):
		get_viewport().size_changed.connect(_layout_menu_top_bar)
	if not VersionCheck.update_required.is_connected(_on_update_required):
		VersionCheck.update_required.connect(_on_update_required)
	call_deferred("_check_app_version")
	call_deferred("_focus_web_canvas")


func _focus_web_canvas() -> void:
	if OS.has_feature("web"):
		BrowserBridge.focus_canvas()


func _apply_responsive_scale() -> void:
	_btn_font = BrowserBridge.menu_button_font()
	_title_font = BrowserBridge.menu_title_font()


func _maybe_show_auth() -> void:
	pass


func _on_auth_ready(_logged_in: bool) -> void:
	_refresh_auth_ui()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := TextureRect.new()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = MENU_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var gradient := ColorRect.new()
	add_child(gradient)
	gradient.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gradient.color = Color(0.12, 0.04, 0.18, 0.42)
	gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var edge := 20 if BrowserBridge.is_mobile_viewport() else 28
	margin.add_theme_constant_override("margin_left", edge)
	margin.add_theme_constant_override("margin_right", edge)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)

	var root := VBoxContainer.new()
	margin.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 16 if BrowserBridge.is_mobile_viewport() else 18)
	root.alignment = BoxContainer.ALIGNMENT_CENTER

	_title_label = Label.new()
	root.add_child(_title_label)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", _title_font)
	_title_label.add_theme_color_override("font_color", Color(1, 0.86, 0.32))
	_title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	_title_label.add_theme_constant_override("outline_size", 10)
	_title_label.text = "EPILOGUE"

	_subtitle_label = Label.new()
	root.add_child(_subtitle_label)
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", BrowserBridge.menu_subtitle_font())
	_subtitle_label.add_theme_color_override("font_color", Color(0.82, 0.9, 1.0))
	_subtitle_label.text = "Runner"

	var tag := Label.new()
	root.add_child(tag)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", BrowserBridge.menu_caption_font())
	tag.add_theme_color_override("font_color", Color(0.72, 0.78, 0.92, 0.85))
	tag.text = "28 July Concert"

	root.add_child(_spacer(8))

	var btn_col := VBoxContainer.new()
	root.add_child(btn_col)
	btn_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_col.add_theme_constant_override("separation", 14 if BrowserBridge.is_mobile_viewport() else 16)

	_play_btn = _add_menu_button(btn_col, "PLAY", Color(0.16, 0.72, 0.4), _on_play)
	_add_menu_button(btn_col, "SETTINGS", Color(0.28, 0.32, 0.42), _show_settings)
	_add_menu_button(btn_col, "LEADERBOARD", Color(0.55, 0.35, 0.12), _on_leaderboard)
	_add_menu_button(btn_col, "BUY A TICKET", Color(0.72, 0.48, 0.1), _on_buy_ticket)

	_build_overlay()
	_build_settings_panel()

	var auth_layer := CanvasLayer.new()
	auth_layer.name = "AuthLayer"
	auth_layer.layer = 100
	add_child(auth_layer)
	_auth_panel = load("res://scripts/auth_panel.gd").new()
	auth_layer.add_child(_auth_panel)
	_auth_panel.logged_in.connect(_on_logged_in)

	_build_menu_top_bar()


func _build_menu_top_bar() -> void:
	_menu_name_label = _menu_hud_label(HORIZONTAL_ALIGNMENT_LEFT, Color(0.9, 0.95, 1.0))
	add_child(_menu_name_label)

	_menu_best_label = _menu_hud_label(HORIZONTAL_ALIGNMENT_RIGHT, Color(1, 0.88, 0.42))
	add_child(_menu_best_label)

	call_deferred("_layout_menu_top_bar")
	_refresh_menu_top_bar()


func _layout_menu_top_bar() -> void:
	if _menu_name_label == null:
		return
	var width := get_viewport().get_visible_rect().size.x
	if width <= 0.0:
		width = float(get_viewport().size.x)
	if width <= 0.0:
		width = 720.0
	var top := 18.0
	var height := 44.0
	var side_w := 220.0
	_menu_name_label.position = Vector2(18.0, top)
	_menu_name_label.size = Vector2(side_w, height)
	_menu_best_label.position = Vector2(width - side_w - 18.0, top)
	_menu_best_label.size = Vector2(side_w, height)


func _refresh_menu_top_bar() -> void:
	if _menu_name_label == null:
		return
	var show_hud := true
	_menu_name_label.visible = show_hud
	_menu_best_label.visible = show_hud
	if not show_hud:
		return
	var player_name := AuthSession.username.strip_edges()
	if player_name == "":
		player_name = AuthSession.index_number.strip_edges()
	if player_name == "":
		player_name = "Guest"
	_menu_name_label.text = player_name
	_menu_best_label.text = "Best %d" % AuthSession.best_coins


func _menu_hud_label(align: HorizontalAlignment, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 20
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", BrowserBridge.hud_font())
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 5)
	return label


func _on_profile_updated(_body: Dictionary) -> void:
	_refresh_menu_top_bar()


func _build_settings_panel() -> void:
	var dim := ColorRect.new()
	dim.name = "SettingsDim"
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.62)
	dim.visible = false
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventScreenTouch and e.pressed:
			_hide_settings()
		elif e is InputEventMouseButton and e.pressed:
			_hide_settings()
	)

	_settings_panel = PanelContainer.new()
	_settings_panel.name = "SettingsPanel"
	add_child(_settings_panel)
	_settings_panel.visible = false
	BrowserBridge.apply_wide_popup(_settings_panel, 0.72)
	_settings_panel.add_theme_stylebox_override("panel", _overlay_style())

	var margin := MarginContainer.new()
	_settings_panel.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	_settings_box = VBoxContainer.new()
	scroll.add_child(_settings_box)
	_settings_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_box.custom_minimum_size.x = 0
	_settings_box.add_theme_constant_override("separation", 14)

	var settings_title := Label.new()
	_settings_box.add_child(settings_title)
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_title.add_theme_font_size_override("font_size", BrowserBridge.popup_title_font())
	settings_title.add_theme_color_override("font_color", Color(1, 0.9, 0.45))
	settings_title.text = "Settings"

	_login_btn = _add_menu_button(_settings_box, "LOGIN / REGISTER", Color(0.22, 0.38, 0.72), _show_auth_panel)
	_logout_btn = _add_menu_button(_settings_box, "LOGOUT", Color(0.35, 0.22, 0.22), _on_logout)
	_logout_btn.visible = false

	# Local nickname option for offline mode
	if true:
		var name_label := Label.new()
		_settings_box.add_child(name_label)
		name_label.text = "Set Guest Nickname:"
		name_label.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font())
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		_offline_name_field = LineEdit.new()
		_settings_box.add_child(_offline_name_field)
		_offline_name_field.placeholder_text = "Guest Name"
		_offline_name_field.text = AuthSession.username
		_offline_name_field.max_length = 32
		_offline_name_field.custom_minimum_size = Vector2(0, BrowserBridge.popup_button_height() - 8)
		_offline_name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_offline_name_field.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font())
		_offline_name_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_offline_name_field.text_changed.connect(_on_offline_name_changed)

	_add_menu_button(_settings_box, "WIN A TICKET", Color(0.55, 0.35, 0.12), func(): _show_overlay("Win a Ticket", WIN_TICKET_TEXT, true))
	_add_menu_button(_settings_box, "ABOUT US", Color(0.28, 0.32, 0.42), func(): _show_overlay("About Us", ABOUT_US_TEXT, true))
	_sound_btn = _add_menu_button(_settings_box, "", Color(0.28, 0.32, 0.42), _on_toggle_sound)
	_refresh_sound_label()

	if not _is_mobile():
		_add_menu_button(_settings_box, "QUIT", Color(0.45, 0.18, 0.18), _on_quit)

	var close_btn := Button.new()
	_settings_box.add_child(close_btn)
	close_btn.custom_minimum_size = Vector2(0, BrowserBridge.popup_button_height())
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.text = "CLOSE"
	close_btn.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font())
	close_btn.add_theme_stylebox_override("normal", _pill(Color(0.2, 0.55, 0.85)))
	close_btn.pressed.connect(_hide_settings)


func _show_settings() -> void:
	_refresh_auth_ui()
	_settings_panel.visible = true
	get_node("SettingsDim").visible = true


func _hide_settings() -> void:
	_settings_panel.visible = false
	get_node("SettingsDim").visible = false


func _refresh_auth_ui() -> void:
	var needs_auth := false
	if _login_btn:
		_login_btn.visible = false
	if _logout_btn:
		_logout_btn.visible = false
	if _play_btn:
		_play_btn.disabled = false
		_play_btn.text = "PLAY"
	_refresh_menu_top_bar()


func _show_auth_panel() -> void:
	_hide_settings()
	_hide_overlay()
	if _auth_panel.has_method("open"):
		_auth_panel.open()
	else:
		_auth_panel.visible = true


func _on_logged_in() -> void:
	_refresh_auth_ui()


func _on_logout() -> void:
	AuthSession.clear()
	RunSession.run_active = false
	_refresh_auth_ui()


var _lb_top: Array = []
var _lb_me: Dictionary = {}
var _lb_pending: int = 0
var _lb_failed: bool = false


func _on_leaderboard() -> void:
	_show_overlay("Leaderboard", "Leaderboard is not available in offline mode.")
	return


func _on_api_leaderboard(path: String, success: bool, _status: int, body: Dictionary) -> void:
	if path == "/v1/leaderboard":
		if success:
			_lb_top = body.get("top", [])
		else:
			_lb_failed = true
		_lb_pending -= 1
		_try_show_leaderboard()
	elif path == "/v1/leaderboard/me":
		if success:
			_lb_me = body
			if body.has("name"):
				AuthSession.username = str(body.get("name", AuthSession.username))
			if body.has("best_coins"):
				AuthSession.best_coins = int(body.get("best_coins", AuthSession.best_coins))
			_refresh_menu_top_bar()
		else:
			_lb_failed = true
		_lb_pending -= 1
		_try_show_leaderboard()


func _try_show_leaderboard() -> void:
	if _lb_pending > 0:
		return
	if _lb_failed and _lb_top.is_empty():
		_show_overlay("Leaderboard", GameSettings.USER_ERROR_MSG)
		_lb_top = []
		_lb_me = {}
		return
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Top 10")
	lines.append("")
	if _lb_top.is_empty():
		lines.append("No scores yet.")
	else:
		for row in _lb_top:
			if row is Dictionary:
				lines.append("#%d  %s  —  %d coins" % [
					int(row.get("rank", 0)),
					str(row.get("name", row.get("username", "?"))),
					int(row.get("coins", 0)),
				])
	if AuthSession.is_logged_in() and not _lb_me.is_empty():
		lines.append("")
		lines.append("Your score")
		var rank: int = int(_lb_me.get("rank", 0))
		var best: int = int(_lb_me.get("best_coins", _lb_me.get("coins", 0)))
		if rank > 0:
			lines.append("Rank #%d  ·  %d coins" % [rank, best])
		else:
			lines.append("No rank yet — play and collect coins!")
	_show_overlay("Leaderboard", "\n".join(lines))
	_lb_top = []
	_lb_me = {}


func _add_menu_button(parent: Control, text: String, col: Color, cb: Callable) -> Button:
	var btn := Button.new()
	parent.add_child(btn)
	var h := BrowserBridge.menu_button_height()
	btn.custom_minimum_size = Vector2(0, h)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", _btn_font)
	btn.text = text
	btn.add_theme_stylebox_override("normal", _pill(col))
	btn.add_theme_stylebox_override("hover", _pill(col.lightened(0.08)))
	btn.add_theme_stylebox_override("pressed", _pill(col.darkened(0.08)))
	btn.pressed.connect(cb)
	return btn


func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s


func _pill(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(22)
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	sb.shadow_size = 4
	sb.shadow_color = Color(0, 0, 0, 0.35)
	return sb


func _build_overlay() -> void:
	var dim := ColorRect.new()
	dim.name = "OverlayDim"
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.62)
	dim.visible = false
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventScreenTouch and e.pressed:
			_hide_overlay()
		elif e is InputEventMouseButton and e.pressed:
			_hide_overlay()
	)

	_overlay = PanelContainer.new()
	_overlay.name = "OverlayPanel"
	add_child(_overlay)
	_overlay.visible = false
	BrowserBridge.apply_wide_popup(_overlay, 0.66)
	_overlay.add_theme_stylebox_override("panel", _overlay_style())

	var margin := MarginContainer.new()
	_overlay.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)

	var box := VBoxContainer.new()
	margin.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 18)

	_overlay_title = Label.new()
	box.add_child(_overlay_title)
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_title.add_theme_font_size_override("font_size", BrowserBridge.popup_title_font())
	_overlay_title.add_theme_color_override("font_color", Color(1, 0.9, 0.45))

	var body_scroll := ScrollContainer.new()
	box.add_child(body_scroll)
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_overlay_body = Label.new()
	body_scroll.add_child(_overlay_body)
	_overlay_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_body.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font())
	_overlay_body.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0))

	_overlay_close = Button.new()
	box.add_child(_overlay_close)
	_overlay_close.custom_minimum_size = Vector2(0, BrowserBridge.popup_button_height())
	_overlay_close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overlay_close.text = "CLOSE"
	_overlay_close.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font())
	_overlay_close.add_theme_stylebox_override("normal", _pill(Color(0.2, 0.55, 0.85)))
	_overlay_close.pressed.connect(_hide_overlay)


func _overlay_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.17, 0.98)
	sb.set_corner_radius_all(20)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 0.85, 0.3, 0.45)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _show_overlay(title: String, body: String, back_to_settings: bool = false) -> void:
	_overlay_back_to_settings = back_to_settings
	_overlay_title.text = title
	_overlay_body.text = body
	_overlay_close.text = "BACK" if back_to_settings else "CLOSE"
	if back_to_settings:
		_hide_settings()
	_overlay.visible = true
	get_node("OverlayDim").visible = true
	call_deferred("_fit_overlay_body")


func _fit_overlay_body() -> void:
	var scroll := _overlay_body.get_parent()
	if scroll is ScrollContainer and scroll.size.x > 0:
		_overlay_body.custom_minimum_size.x = scroll.size.x


func _hide_overlay() -> void:
	_overlay.visible = false
	get_node("OverlayDim").visible = false
	if _overlay_back_to_settings:
		_overlay_back_to_settings = false
		_show_settings()


func _refresh_sound_label() -> void:
	if _sound_btn:
		_sound_btn.text = "SOUND: ON" if GameSettings.sound_enabled else "SOUND: OFF"


func _check_app_version() -> void:
	if SimConstants.API_BASE.is_empty():
		return
	VersionCheck.check()


func _on_update_required(message: String) -> void:
	if _play_btn:
		_play_btn.disabled = true
		_play_btn.text = "REFRESH PAGE"
	_show_overlay("Update required", message)


func _on_play() -> void:
	BrowserBridge.focus_canvas()
	BrowserBridge.unlock_web_audio()
	BrowserBridge.request_fullscreen()
	if _play_btn:
		_play_btn.disabled = true
		_play_btn.text = "LOADING..."
	_start_play_timeout()
	if RunSession.run_ready.is_connected(_on_run_ready):
		RunSession.run_ready.disconnect(_on_run_ready)
	RunSession.run_ready.connect(_on_run_ready, CONNECT_ONE_SHOT)
	RunSession.prepare_run()


func _start_play_timeout() -> void:
	if _play_wait_timer == null:
		_play_wait_timer = Timer.new()
		_play_wait_timer.one_shot = true
		_play_wait_timer.wait_time = 25.0
		add_child(_play_wait_timer)
		_play_wait_timer.timeout.connect(_on_play_timeout)
	_play_wait_timer.start()


func _stop_play_timeout() -> void:
	if _play_wait_timer:
		_play_wait_timer.stop()


func _on_play_timeout() -> void:
	if _play_btn == null or _play_btn.text != "LOADING...":
		return
	_refresh_auth_ui()
	_show_overlay("Error", GameSettings.USER_ERROR_MSG)


func _on_run_ready(success: bool, _error_message: String) -> void:
	_stop_play_timeout()
	_refresh_auth_ui()
	if not success:
		if _play_btn:
			_play_btn.disabled = SimConstants.API_BASE != "" and not AuthSession.is_logged_in()
		var msg := GameSettings.USER_ERROR_MSG
		if _error_message.contains("user_banned"):
			msg = "Your account has been banned."
		_show_overlay("Error", msg)
		return
	get_tree().change_scene_to_file("res://scenes/level.tscn")


func _on_buy_ticket() -> void:
	OS.shell_open(TICKET_URL)


func _on_toggle_sound() -> void:
	GameSettings.toggle_sound()
	_refresh_sound_label()


func _on_quit() -> void:
	get_tree().quit()


func _is_mobile() -> bool:
	var os := OS.get_name()
	return os == "Android" or os == "iOS" or os == "Web"


func _on_offline_name_changed(new_text: String) -> void:
	var clean_name = new_text.strip_edges()
	AuthSession.set_auth({
		"username": clean_name
	})
