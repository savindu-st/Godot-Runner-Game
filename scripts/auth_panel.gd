extends Control

signal logged_in()

var _mode: String = "login"
var _panel: PanelContainer
var _title: Label
var _email_field: LineEdit
var _name_field: LineEdit
var _password_field: LineEdit
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
	var dim = get_node_or_null("AuthDim")
	if dim:
		dim.visible = true
		dim.modulate.a = 0.0
	_panel.visible = true
	_panel.modulate.a = 0.0
	_panel.position.y = 40.0
	call_deferred("_relayout_panel")
	_show_status("")

	var t := create_tween().set_parallel(true)
	if dim:
		t.tween_property(dim, "modulate:a", 1.0, 0.2)
	t.tween_property(_panel, "modulate:a", 1.0, 0.2)
	t.tween_property(_panel, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _relayout_panel() -> void:
	if _panel:
		BrowserBridge.apply_wide_popup(_panel, 0.72)


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.name = "AuthDim"
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.75)
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
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)

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
	var font = HudSign.get_hud_font()
	if font:
		_title.add_theme_font_override("font", font)
	_title.add_theme_font_size_override("font_size", BrowserBridge.popup_title_font())
	_title.add_theme_color_override("font_color", Color(1, 0.88, 0.35))
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_title.add_theme_constant_override("outline_size", 8)

	_email_field = _field(box, "Email Address", LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS)
	_email_field.max_length = 120

	_name_field = _field(box, "Display Username (Leaderboard)", LineEdit.KEYBOARD_TYPE_DEFAULT)
	_name_field.max_length = 32

	_password_field = _field(box, "Password (min 6 chars)", LineEdit.KEYBOARD_TYPE_PASSWORD)
	_password_field.secret = true
	_password_field.max_length = 64

	_status = Label.new()
	box.add_child(_status)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font() - 4)
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
	var font = HudSign.get_hud_font()
	if font:
		btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font() + 4)
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", _pill(col))
	btn.add_theme_stylebox_override("hover", _pill(col.lightened(0.12)))
	btn.add_theme_stylebox_override("pressed", _pill(col.darkened(0.12)))
	btn.add_theme_stylebox_override("disabled", _pill(col.darkened(0.3)))
	return btn


func _field(parent: Control, placeholder: String, keyboard_type: LineEdit.VirtualKeyboardType = LineEdit.KEYBOARD_TYPE_DEFAULT) -> LineEdit:
	var f := LineEdit.new()
	parent.add_child(f)
	f.placeholder_text = placeholder
	f.custom_minimum_size = Vector2(0, BrowserBridge.popup_button_height() - 8)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font())
	f.virtual_keyboard_type = keyboard_type
	f.caret_blink = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.3, 0.4, 0.6, 0.5)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	f.add_theme_stylebox_override("normal", sb)
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
	for field in [_email_field, _name_field, _password_field]:
		if field:
			field.release_focus()
	
	var dim = get_node_or_null("AuthDim")
	var t := create_tween().set_parallel(true)
	if dim:
		t.tween_property(dim, "modulate:a", 0.0, 0.15)
	t.tween_property(_panel, "modulate:a", 0.0, 0.15)
	t.tween_property(_panel, "position:y", 30.0, 0.15)
	t.chain().tween_callback(func():
		visible = false
		if dim:
			dim.visible = false
		_panel.visible = false
	)


func _on_submit_pressed() -> void:
	_run_submit()


func _run_submit() -> void:
	if _busy:
		return
	await _sync_fields_from_keyboard()
	if _busy:
		return

	var email := _email_field.text.strip_edges()
	var password := _password_field.text.strip_edges()
	var username := _name_field.text.strip_edges()

	if email == "" or password == "":
		_show_status("Email and password are required.")
		return

	if not email.contains("@") or not email.contains("."):
		_show_status("Please enter a valid email address.")
		return

	if password.length() < 6:
		_show_status("Password must be at least 6 characters.")
		return

	if _mode == "register" and username == "":
		_show_status("Please choose a display username for the leaderboard.")
		return

	_busy = true
	_submit_btn.disabled = true
	_toggle_btn.disabled = true
	_close_btn.disabled = true
	_show_status("Connecting…")

	if _mode == "login":
		var payload := {
			"email": email,
			"password": password,
		}
		ApiClient.post_unsigned("/v1/auth/login", payload)
	else:
		var payload := {
			"email": email,
			"password": password,
			"data": {
				"username": username,
			},
		}
		ApiClient.post_unsigned("/v1/auth/register", payload)


func _sync_fields_from_keyboard() -> void:
	BrowserBridge.dismiss_virtual_keyboard()
	for field in [_email_field, _name_field, _password_field]:
		if field and field.has_focus():
			field.release_focus()
	await get_tree().process_frame
	await get_tree().process_frame


func _show_status(msg: String, is_success: bool = false) -> void:
	_status.text = msg
	if is_success:
		_status.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	else:
		_status.add_theme_color_override("font_color", Color(1, 0.55, 0.5))


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.12, 0.98)
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 0.82, 0.22, 0.85) # Gold rim
	sb.shadow_size = 16
	sb.shadow_color = Color(1.0, 0.82, 0.22, 0.25)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


func _pill(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(2)
	sb.border_color = c.lightened(0.2)
	sb.shadow_size = 6
	sb.shadow_color = c * Color(1, 1, 1, 0.3)
	return sb


func _set_mode(mode: String) -> void:
	_mode = mode
	var is_login := mode == "login"
	_title.text = "SIGN IN" if is_login else "REGISTER"
	_name_field.visible = not is_login
	_submit_btn.text = "LOGIN" if is_login else "CREATE ACCOUNT"
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
		# If response has token or access_token, user is fully logged in
		if body.has("access_token") or body.has("token"):
			AuthSession.set_auth(body)
			AuthSession.refresh_profile()
			_close()
			logged_in.emit()
		elif body.has("user") and not body.has("access_token"):
			# Email confirmation is required by Supabase project settings
			_show_status("Registration successful! Check your email to confirm, then log in.", true)
			_set_mode("login")
		else:
			AuthSession.set_auth(body)
			_close()
			logged_in.emit()
	else:
		var err := str(body.get("error", body.get("message", body.get("error_description", body.get("raw", "Request failed")))))
		_show_status(_format_auth_error(err, status))


func _format_auth_error(err: String, status: int) -> String:
	var lower := err.to_lower()
	if "invalid login credentials" in lower or "invalid_grant" in lower:
		return "Incorrect email or password."
	if "already registered" in lower or "already exists" in lower or "user already registered" in lower:
		return "That email is already registered. Please login."
	if "password should be at least" in lower:
		return "Password must be at least 6 characters long."
	if "valid email" in lower or "invalid email" in lower:
		return "Please enter a valid email address."
	if "rate limit" in lower:
		return "Too many attempts. Please wait a minute and try again."
	if "connection_failed" in lower or "timeout" in lower or "request_failed" in lower or status == 0:
		return "Cannot reach server. Check internet connection and Supabase URL."
	return "%s (%d)" % [err, status]
