extends Control

const MENU_BG: Texture2D = preload("res://assets/menu_bg.jpg")



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
var _characters_btn: Button
var _char_overlay: PanelContainer
var _char_overlay_dim: ColorRect
var _char_name_label: Label
var _char_viewport_container: SubViewportContainer
var _char_viewport: SubViewport
var _char_3d_root: Node3D
var _char_model_instance: Node3D
var _current_char_index: int = 0

var _maps_btn: Button
var _map_overlay: PanelContainer
var _map_overlay_dim: ColorRect
var _map_name_label: Label
var _map_viewport_container: SubViewportContainer
var _map_viewport: SubViewport
var _map_3d_root: Node3D
var _map_model_instance: Node3D
var _current_map_index: int = 0
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
	_title_label.add_theme_color_override("font_color", Color(1, 0.86, 0.32)) # Neon yellow
	_title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	_title_label.add_theme_constant_override("outline_size", 10)
	_title_label.text = "EVER DASH"
	
	_title_label.resized.connect(func():
		_title_label.pivot_offset = _title_label.size / 2.0
	)
	var title_tween = create_tween().set_loops()
	title_tween.tween_property(_title_label, "scale", Vector2(1.05, 1.05), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	title_tween.tween_property(_title_label, "scale", Vector2(1.0, 1.0), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	root.add_child(_spacer(8))

	var btn_col := VBoxContainer.new()
	root.add_child(btn_col)
	btn_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_col.add_theme_constant_override("separation", 14 if BrowserBridge.is_mobile_viewport() else 16)

	_play_btn = _add_menu_button(btn_col, "PLAY", Color(0.16, 0.72, 0.4), _on_play)
	_characters_btn = _add_menu_button(btn_col, "CHARACTERS", Color(0.2, 0.5, 0.75), _show_char_selection)
	_maps_btn = _add_menu_button(btn_col, "MAPS", Color(0.7, 0.3, 0.6), _show_map_selection)
	_add_menu_button(btn_col, "SETTINGS", Color(0.28, 0.32, 0.42), _show_settings)
	if OS.get_name() != "Web":
		_add_menu_button(btn_col, "QUIT", Color(0.45, 0.18, 0.18), _on_quit)

	_build_overlay()
	_build_settings_panel()
	_build_char_selection()
	_build_map_selection()

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


	_add_menu_button(_settings_box, "ABOUT US", Color(0.28, 0.32, 0.42), func(): _show_overlay("About Us", ABOUT_US_TEXT, true))
	_sound_btn = _add_menu_button(_settings_box, "", Color(0.28, 0.32, 0.42), _on_toggle_sound)
	_refresh_sound_label()



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
	var dim = get_node("SettingsDim")
	dim.modulate.a = 0
	_settings_panel.modulate.a = 0
	_settings_panel.position.y = 50
	_settings_panel.visible = true
	dim.visible = true
	var t = create_tween().set_parallel(true)
	t.tween_property(dim, "modulate:a", 1.0, 0.2)
	t.tween_property(_settings_panel, "modulate:a", 1.0, 0.2)
	t.tween_property(_settings_panel, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_settings() -> void:
	var dim = get_node("SettingsDim")
	var t = create_tween().set_parallel(true)
	t.tween_property(dim, "modulate:a", 0.0, 0.15)
	t.tween_property(_settings_panel, "modulate:a", 0.0, 0.15)
	t.tween_property(_settings_panel, "position:y", 50.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(func():
		_settings_panel.visible = false
		dim.visible = false
	)


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


func _add_menu_button(parent: Control, text: String, col: Color, cb: Callable) -> Button:
	var btn := Button.new()
	parent.add_child(btn)
	var h := BrowserBridge.menu_button_height()
	btn.custom_minimum_size = Vector2(0, h)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", _btn_font)
	btn.text = text
	btn.add_theme_stylebox_override("normal", _pill(col))
	btn.add_theme_stylebox_override("hover", _pill(col.lightened(0.2)))
	btn.add_theme_stylebox_override("pressed", _pill(col.darkened(0.2)))
	
	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(func(): btn.pivot_offset = btn.size / 2.0)
	
	btn.mouse_entered.connect(func():
		var t = create_tween()
		t.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_QUAD)
	)
	btn.mouse_exited.connect(func():
		var t = create_tween()
		t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD)
	)
	btn.button_down.connect(func():
		var t = create_tween()
		t.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.05).set_trans(Tween.TRANS_QUAD)
	)
	btn.button_up.connect(func():
		var t = create_tween()
		t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_QUAD)
	)
	
	btn.pressed.connect(cb)
	return btn


func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s


func _pill(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.8) # Neo dark transparent
	sb.set_corner_radius_all(22)
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	sb.set_border_width_all(2)
	sb.border_color = c # Neon accent
	sb.shadow_size = 8
	sb.shadow_color = c * Color(1, 1, 1, 0.25)
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
	sb.bg_color = Color(0.04, 0.03, 0.08, 0.9)
	sb.set_corner_radius_all(20)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.4, 0.1, 0.8, 0.8)
	sb.shadow_size = 15
	sb.shadow_color = Color(0.4, 0.1, 0.8, 0.3)
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


func _build_char_selection() -> void:
	_char_overlay_dim = ColorRect.new()
	_char_overlay_dim.name = "CharOverlayDim"
	add_child(_char_overlay_dim)
	_char_overlay_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_char_overlay_dim.color = Color(0, 0, 0, 0.62)
	_char_overlay_dim.visible = false
	_char_overlay_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_char_overlay_dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventScreenTouch and e.pressed:
			_hide_char_selection()
		elif e is InputEventMouseButton and e.pressed:
			_hide_char_selection()
	)
	
	_char_overlay = PanelContainer.new()
	_char_overlay.name = "CharOverlayPanel"
	add_child(_char_overlay)
	_char_overlay.visible = false
	BrowserBridge.apply_wide_popup(_char_overlay, 0.85)
	_char_overlay.add_theme_stylebox_override("panel", _overlay_style())
	
	var margin = MarginContainer.new()
	_char_overlay.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	
	var main_box = VBoxContainer.new()
	margin.add_child(main_box)
	main_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_box.add_theme_constant_override("separation", 24)
	
	_char_name_label = Label.new()
	main_box.add_child(_char_name_label)
	_char_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_name_label.add_theme_font_size_override("font_size", BrowserBridge.popup_title_font() + 4)
	_char_name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.45))
	
	var middle_row = HBoxContainer.new()
	main_box.add_child(middle_row)
	middle_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle_row.custom_minimum_size = Vector2(0, 300)
	middle_row.add_theme_constant_override("separation", 16)
	
	var left_btn = Button.new()
	middle_row.add_child(left_btn)
	left_btn.text = "<"
	left_btn.custom_minimum_size = Vector2(60, 60)
	left_btn.add_theme_font_size_override("font_size", BrowserBridge.popup_title_font())
	left_btn.add_theme_stylebox_override("normal", _pill(Color(0.28, 0.32, 0.42)))
	left_btn.pressed.connect(func(): _cycle_character(-1))
	
	_char_viewport_container = SubViewportContainer.new()
	middle_row.add_child(_char_viewport_container)
	_char_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_char_viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_char_viewport_container.stretch = true
	
	_char_viewport = SubViewport.new()
	_char_viewport_container.add_child(_char_viewport)
	_char_viewport.transparent_bg = true
	_char_viewport.own_world_3d = true
	
	_char_3d_root = Node3D.new()
	_char_viewport.add_child(_char_3d_root)
	
	var cam = Camera3D.new()
	_char_3d_root.add_child(cam)
	cam.transform.origin = Vector3(0, 1.0, 2.5)
	
	var light = DirectionalLight3D.new()
	_char_3d_root.add_child(light)
	light.transform.basis = Basis().rotated(Vector3.RIGHT, -PI/4).rotated(Vector3.UP, PI/4)
	
	var right_btn = Button.new()
	middle_row.add_child(right_btn)
	right_btn.text = ">"
	right_btn.custom_minimum_size = Vector2(60, 60)
	right_btn.add_theme_font_size_override("font_size", BrowserBridge.popup_title_font())
	right_btn.add_theme_stylebox_override("normal", _pill(Color(0.28, 0.32, 0.42)))
	right_btn.pressed.connect(func(): _cycle_character(1))
	
	var select_btn = Button.new()
	main_box.add_child(select_btn)
	select_btn.custom_minimum_size = Vector2(0, BrowserBridge.popup_button_height())
	select_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_btn.text = "SELECT CHARACTER"
	select_btn.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font())
	select_btn.add_theme_stylebox_override("normal", _pill(Color(0.16, 0.72, 0.4)))
	select_btn.pressed.connect(_hide_char_selection)

func _show_char_selection() -> void:
	_current_char_index = GameSettings.selected_character_index
	_refresh_char_preview()
	_char_overlay_dim.modulate.a = 0
	_char_overlay.modulate.a = 0
	_char_overlay.position.y = 50
	_char_overlay.visible = true
	_char_overlay_dim.visible = true
	var t = create_tween().set_parallel(true)
	t.tween_property(_char_overlay_dim, "modulate:a", 1.0, 0.2)
	t.tween_property(_char_overlay, "modulate:a", 1.0, 0.2)
	t.tween_property(_char_overlay, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_char_selection() -> void:
	var t = create_tween().set_parallel(true)
	t.tween_property(_char_overlay_dim, "modulate:a", 0.0, 0.15)
	t.tween_property(_char_overlay, "modulate:a", 0.0, 0.15)
	t.tween_property(_char_overlay, "position:y", 50.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(func():
		_char_overlay.visible = false
		_char_overlay_dim.visible = false
	)

func _cycle_character(dir: int) -> void:
	_current_char_index += dir
	if _current_char_index < 0:
		_current_char_index = 4
	elif _current_char_index > 4:
		_current_char_index = 0
	GameSettings.set_selected_character(_current_char_index)
	_refresh_char_preview()

func _refresh_char_preview() -> void:
	if _current_char_index == 0:
		_char_name_label.text = "Anime Girl"
	elif _current_char_index == 1:
		_char_name_label.text = "Crimson Runner"
	elif _current_char_index == 2:
		_char_name_label.text = "Azure Sprinter"
	elif _current_char_index == 3:
		_char_name_label.text = "Leonard"
	elif _current_char_index == 4:
		_char_name_label.text = "Remy"

	if _char_model_instance:
		_char_model_instance.queue_free()
		_char_model_instance = null
	
	var models = [
		preload("res://models/anime-girl/anime-girl.glb"),
		preload("res://models/character2/character2.glb"),
		preload("res://models/character3/character3.glb"),
		preload("res://models/Leonard/character.tscn"),
		preload("res://models/Remy/character.tscn")
	]
	
	_char_model_instance = models[_current_char_index].instantiate()
	
	var scale_val = 0.85
	if _current_char_index == 4:
		scale_val = 0.4
	_char_model_instance.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3(scale_val, scale_val, scale_val)), Vector3.ZERO)
	_char_3d_root.add_child(_char_model_instance)
	
	var anim_player = _char_model_instance.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim_player == null:
		anim_player = _char_model_instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player:
		if _current_char_index == 4:
			for lib_name in anim_player.get_animation_library_list():
				var lib = anim_player.get_animation_library(lib_name)
				var new_lib = AnimationLibrary.new()
				for anim_name in lib.get_animation_list():
					var anim = lib.get_animation(anim_name).duplicate()
					for i in range(anim.get_track_count()):
						var path_str = String(anim.track_get_path(i))
						if "mixamorig9_" in path_str:
							anim.track_set_path(i, NodePath(path_str.replace("mixamorig9_", "mixamorig_")))
						if anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
							for k in range(anim.track_get_key_count(i)):
								anim.track_set_key_value(i, k, anim.track_get_key_value(i, k) * 2.125)
					new_lib.add_animation(anim_name, anim)
				anim_player.remove_animation_library(lib_name)
				anim_player.add_animation_library(lib_name, new_lib)
		
		var target_anim = ""
		for anim_name in anim_player.get_animation_list():
			var lower = String(anim_name).to_lower()
			if "danc" in lower or "idle" in lower:
				target_anim = anim_name
				break
		if target_anim == "":
			for anim_name in anim_player.get_animation_list():
				if "run" in String(anim_name).to_lower():
					target_anim = anim_name
					break
		if target_anim != "":
			var anim = anim_player.get_animation(target_anim)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
			anim_player.play(target_anim)
	
	var tint := Color.WHITE
	if _current_char_index == 1:
		tint = Color(1.0, 0.4, 0.4)
	elif _current_char_index == 2:
		tint = Color(0.4, 0.6, 1.0)
	
	_matte_meshes(_char_model_instance, tint)


func _build_map_selection() -> void:
	_map_overlay_dim = ColorRect.new()
	_map_overlay_dim.name = "MapOverlayDim"
	add_child(_map_overlay_dim)
	_map_overlay_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_overlay_dim.color = Color(0, 0, 0, 0.62)
	_map_overlay_dim.visible = false
	_map_overlay_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_map_overlay_dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventScreenTouch and e.pressed:
			_hide_map_selection()
		elif e is InputEventMouseButton and e.pressed:
			_hide_map_selection()
	)
	
	_map_overlay = PanelContainer.new()
	_map_overlay.name = "MapOverlayPanel"
	add_child(_map_overlay)
	_map_overlay.visible = false
	BrowserBridge.apply_wide_popup(_map_overlay, 0.75)
	_map_overlay.add_theme_stylebox_override("panel", _overlay_style())
	
	var margin = MarginContainer.new()
	_map_overlay.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	
	var main_box = VBoxContainer.new()
	margin.add_child(main_box)
	main_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_box.add_theme_constant_override("separation", 24)
	
	var title_label = Label.new()
	main_box.add_child(title_label)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.text = "SELECT MAP"
	title_label.add_theme_font_size_override("font_size", BrowserBridge.popup_title_font())
	title_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	
	var middle_row = HBoxContainer.new()
	main_box.add_child(middle_row)
	middle_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle_row.custom_minimum_size = Vector2(0, 150)
	middle_row.add_theme_constant_override("separation", 16)
	
	var left_btn = Button.new()
	middle_row.add_child(left_btn)
	left_btn.text = "<"
	left_btn.custom_minimum_size = Vector2(60, 60)
	left_btn.add_theme_font_size_override("font_size", BrowserBridge.popup_title_font())
	left_btn.add_theme_stylebox_override("normal", _pill(Color(0.28, 0.32, 0.42)))
	left_btn.pressed.connect(func(): _cycle_map(-1))
	
	_map_name_label = Label.new()
	middle_row.add_child(_map_name_label)
	_map_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_map_name_label.add_theme_font_size_override("font_size", BrowserBridge.popup_title_font() + 10)
	_map_name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.45))
	
	var right_btn = Button.new()
	middle_row.add_child(right_btn)
	right_btn.text = ">"
	right_btn.custom_minimum_size = Vector2(60, 60)
	right_btn.add_theme_font_size_override("font_size", BrowserBridge.popup_title_font())
	right_btn.add_theme_stylebox_override("normal", _pill(Color(0.28, 0.32, 0.42)))
	right_btn.pressed.connect(func(): _cycle_map(1))
	
	var select_btn = Button.new()
	main_box.add_child(select_btn)
	select_btn.custom_minimum_size = Vector2(0, BrowserBridge.popup_button_height())
	select_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_btn.text = "CONFIRM"
	select_btn.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font())
	select_btn.add_theme_stylebox_override("normal", _pill(Color(0.16, 0.72, 0.4)))
	select_btn.pressed.connect(_hide_map_selection)

func _show_map_selection() -> void:
	_current_map_index = GameSettings.selected_map_index
	_refresh_map_preview()
	_map_overlay_dim.modulate.a = 0
	_map_overlay.modulate.a = 0
	_map_overlay.position.y = 50
	_map_overlay.visible = true
	_map_overlay_dim.visible = true
	var t = create_tween().set_parallel(true)
	t.tween_property(_map_overlay_dim, "modulate:a", 1.0, 0.2)
	t.tween_property(_map_overlay, "modulate:a", 1.0, 0.2)
	t.tween_property(_map_overlay, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_map_selection() -> void:
	var t = create_tween().set_parallel(true)
	t.tween_property(_map_overlay_dim, "modulate:a", 0.0, 0.15)
	t.tween_property(_map_overlay, "modulate:a", 0.0, 0.15)
	t.tween_property(_map_overlay, "position:y", 50.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(func():
		_map_overlay.visible = false
		_map_overlay_dim.visible = false
	)

func _cycle_map(dir: int) -> void:
	_current_map_index += dir
	if _current_map_index < 0:
		_current_map_index = 1
	elif _current_map_index > 1:
		_current_map_index = 0
	GameSettings.set_selected_map(_current_map_index)
	_refresh_map_preview()

func _refresh_map_preview() -> void:
	if _current_map_index == 0:
		_map_name_label.text = "Campus"
	elif _current_map_index == 1:
		_map_name_label.text = "City"


func _matte_meshes(node: Node, tint: Color = Color.WHITE) -> void:
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
					if tint != Color.WHITE:
						sm.albedo_color = tint
				mi.set_surface_override_material(si, flat)
	for child in node.get_children():
		_matte_meshes(child, tint)


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
	if GameSettings.selected_map_index == 1:
		get_tree().change_scene_to_file("res://scenes/level_city.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/level.tscn")


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
