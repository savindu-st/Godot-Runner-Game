extends Control

signal logged_in()

var _mode: String = "login"
var _panel: PanelContainer
var _title: Label
var _index_field: LineEdit
var _name_field: LineEdit
var _status: Label
var _submit_btn: Button
var _toggle_btn: Button
var _close_btn: Button
var _busy: bool = false


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
	get_node("AuthDim").visible = true
	_panel.visible = true
	call_deferred("_relayout_panel")


func _relayout_panel() -> void:
	if _panel:
		BrowserBridge.apply_wide_popup(_panel, 0.68)


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.name = "AuthDim"
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.visible = false
	dim.gui_input.connect(_on_dim_tapped)

	_panel = PanelContainer.new()
	_panel.name = "AuthPanel"
	add_child(_panel)
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())

	var margin := MarginContainer.new()
	_panel.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var box := VBoxContainer.new()
	scroll.add_child(box)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)

	_title = Label.new()
	box.add_child(_title)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", BrowserBridge.popup_title_font())
	_title.add_theme_color_override("font_color", Color(1, 0.88, 0.35))

	_index_field = _field(box, "Index number (e.g. 201234A)", LineEdit.KEYBOARD_TYPE_DEFAULT)
	_index_field.max_length = 7
	_name_field = _field(box, "Username", LineEdit.KEYBOARD_TYPE_DEFAULT)

	_status = Label.new()
	box.add_child(_status)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font())
	_status.add_theme_color_override("font_color", Color(1, 0.55, 0.5))

	_submit_btn = _action_button(box, "LOGIN", Color(0.16, 0.72, 0.4))
	_submit_btn.pressed.connect(_on_submit_pressed)

	_toggle_btn = _action_button(box, "Need an account? Register", Color(0.22, 0.38, 0.72))
	_toggle_btn.pressed.connect(_toggle_mode)

	_close_btn = _action_button(box, "CLOSE", Color(0.28, 0.32, 0.42))
	_close_btn.pressed.connect(_on_close_pressed)

	_set_mode("login")


func _action_button(parent: Control, text: String, col: Color) -> Button:
	var btn := Button.new()
	parent.add_child(btn)
	btn.custom_minimum_size = Vector2(0, BrowserBridge.popup_button_height())
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font())
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", _pill(col))
	btn.add_theme_stylebox_override("hover", _pill(col.lightened(0.08)))
	btn.add_theme_stylebox_override("pressed", _pill(col.darkened(0.08)))
	btn.add_theme_stylebox_override("disabled", _pill(col.darkened(0.2)))
	return btn


func _field(parent: Control, placeholder: String, keyboard_type: int = LineEdit.KEYBOARD_TYPE_DEFAULT) -> LineEdit:
	var f := LineEdit.new()
	parent.add_child(f)
	f.placeholder_text = placeholder
	f.custom_minimum_size = Vector2(0, BrowserBridge.popup_button_height() - 8)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font())
	f.virtual_keyboard_type = keyboard_type
	f.caret_blink = true
	return f


func _on_dim_tapped(event: InputEvent) -> void:
	if _busy:
		return
	if event is InputEventScreenTouch and event.pressed:
		_close()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()


func _on_close_pressed() -> void:
	if _busy:
		return
	_close()


func _close() -> void:
	BrowserBridge.dismiss_virtual_keyboard()
	for field in [_index_field, _name_field]:
		if field:
			field.release_focus()
	visible = false
	get_node("AuthDim").visible = false
	_panel.visible = false


func _on_submit_pressed() -> void:
	_run_submit()


func _run_submit() -> void:
	if _busy:
		return
	await _sync_fields_from_keyboard()
	if _busy:
		return

	var index_num := NormalizeIndexNumber(_index_field.text.strip_edges())
	var username := _name_field.text.strip_edges()
	if index_num == "" or username == "":
		_show_status("Index number and username are required.")
		return
	if not _is_valid_index_number(index_num):
		_show_status("Index must start with 20–26, have 6 digits, and end with one letter (e.g. 201234A).")
		return

	_busy = true
	_submit_btn.disabled = true
	_toggle_btn.disabled = true
	_close_btn.disabled = true
	_show_status("Please wait…")

	var payload := {
		"index_number": index_num,
		"name": username,
	}
	if _mode == "login":
		ApiClient.post_unsigned("/v1/auth/login", payload)
	else:
		ApiClient.post_unsigned("/v1/auth/register", payload)


func NormalizeIndexNumber(raw: String) -> String:
	var s := raw.strip_edges()
	if s.is_empty():
		return s
	return s.substr(0, s.length() - 1) + s.substr(s.length() - 1, 1).to_upper()


func _is_valid_index_number(index_num: String) -> bool:
	if index_num.length() != 7:
		return false
	var prefix := index_num.substr(0, 2)
	if prefix != "20" and prefix != "21" and prefix != "22" and prefix != "23" and prefix != "24" and prefix != "25" and prefix != "26":
		return false
	for i in 2:
		var c := index_num[2 + i]
		if c < "0" or c > "9":
			return false
	for i in 2:
		var c := index_num[4 + i]
		if c < "0" or c > "9":
			return false
	var last := index_num[6]
	return (last >= "A" and last <= "Z") or (last >= "a" and last <= "z")


func _sync_fields_from_keyboard() -> void:
	BrowserBridge.dismiss_virtual_keyboard()
	for field in [_index_field, _name_field]:
		if field and field.has_focus():
			field.release_focus()
	await get_tree().process_frame
	await get_tree().process_frame


func _show_status(msg: String) -> void:
	_status.text = msg


func _panel_style() -> StyleBoxFlat:
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


func _pill(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(22)
	return sb


func _set_mode(mode: String) -> void:
	_mode = mode
	var is_login := mode == "login"
	_title.text = "Login" if is_login else "Register"
	_name_field.placeholder_text = "Username"
	_submit_btn.text = "LOGIN" if is_login else "REGISTER"
	_submit_btn.add_theme_stylebox_override("normal", _pill(Color(0.16, 0.72, 0.4) if is_login else Color(0.22, 0.38, 0.72)))
	_toggle_btn.text = "Need an account? Register" if is_login else "Already registered? Login"
	_show_status("")


func _toggle_mode() -> void:
	BrowserBridge.dismiss_virtual_keyboard()
	_set_mode("register" if _mode == "login" else "login")


func _on_api_response(path: String, success: bool, status: int, body: Dictionary) -> void:
	if path != "/v1/auth/login" and path != "/v1/auth/register":
		return
	_busy = false
	_submit_btn.disabled = false
	_toggle_btn.disabled = false
	_close_btn.disabled = false
	if success:
		AuthSession.set_auth(body)
		_close()
		logged_in.emit()
	else:
		var err := str(body.get("error", body.get("message", body.get("raw", "Request failed"))))
		_show_status(_format_auth_error(err, status))


func _format_auth_error(err: String, status: int) -> String:
	match err:
		"user_banned":
			return "Your account has been banned."
		"index_number_already_registered":
			return "That index number is already registered."
		"username_already_registered":
			return "That username is already taken — choose another."
		"invalid_credentials":
			return "Index number or username is incorrect."
		"invalid_index_number":
			return "Index must start with 20–26, have 6 digits, and end with one letter (e.g. 201234A)."
		"connection_failed", "timeout", "request_failed":
			return "Cannot reach server. Check your connection and try again."
	return "%s (%d)" % [err, status]
