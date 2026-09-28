class_name StorePanel
extends Control

## Store Menu for Ever Dash
## Displays persistent total coins and power-up catalog for future upgrades.

signal item_purchased(item_id: String)

const DEFAULT_POWERUPS: Array[Dictionary] = [
	{
		"id": "coin_magnet",
		"name": "COIN MAGNET",
		"desc": "Draws all nearby coins directly to you for 15s.",
		"price": 5000,
		"icon_path": "res://assets/ui/hud_coin.png",
		"badge": "AVAILABLE",
		"available": true,
	},
	{
		"id": "shield",
		"name": "ENERGY SHIELD",
		"desc": "Absorbs one fatal obstacle crash to keep running.",
		"price": 7500,
		"icon_path": "res://assets/ui/hud_crown.png",
		"badge": "AVAILABLE",
		"available": true,
	},
	{
		"id": "rocket_boost",
		"name": "ROCKET BOOST",
		"desc": "Blasts forward at supersonic speed with full invincibility.",
		"price": 12500,
		"icon_path": "res://assets/ui/hud_shoe.png",
		"badge": "AVAILABLE",
		"available": true,
	},
	{
		"id": "coin_doubler",
		"name": "2X MULTIPLIER",
		"desc": "Doubles the value of every collected coin for 20s.",
		"price": 10000,
		"icon_path": "res://assets/ui/hud_coin.png",
		"badge": "AVAILABLE",
		"available": true,
	},
]

var _dim: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _coins_sign: HudSign
var _items_container: VBoxContainer
var _close_btn: Button
var _powerup_items: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_powerup_items = DEFAULT_POWERUPS.duplicate(true)
	_build_ui()
	if not AuthSession.coins_changed.is_connected(_on_coins_changed):
		AuthSession.coins_changed.connect(_on_coins_changed)
	if not AuthSession.profile_updated.is_connected(_on_profile_updated):
		AuthSession.profile_updated.connect(_on_profile_updated)
	if not AuthSession.inventory_changed.is_connected(_on_inventory_changed):
		AuthSession.inventory_changed.connect(_on_inventory_changed)
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

	_refresh_coins_display()
	_populate_items()


func close(immediate: bool = false) -> void:
	if immediate or not is_inside_tree():
		visible = false
		if _dim:
			_dim.visible = false
		if _panel:
			_panel.visible = false
		return

	var t := create_tween().set_parallel(true)
	if _dim:
		t.tween_property(_dim, "modulate:a", 0.0, 0.15)
	t.tween_property(_panel, "modulate:a", 0.0, 0.15)
	t.tween_property(_panel, "position:y", 30.0, 0.15)
	t.chain().tween_callback(func():
		visible = false
		if _dim:
			_dim.visible = false
		if _panel:
			_panel.visible = false
	)


func _relayout_panel() -> void:
	if _panel:
		BrowserBridge.apply_wide_popup(_panel, 0.82)


func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.name = "StoreDim"
	add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0.75)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	_dim.gui_input.connect(func(e: InputEvent):
		if (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
			close()
	)

	_panel = PanelContainer.new()
	_panel.name = "StorePanel"
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

	# Store Header Title
	_title_label = Label.new()
	main_box.add_child(_title_label)
	_title_label.text = "POWER-UP STORE"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font = HudSign.get_hud_font()
	if font:
		_title_label.add_theme_font_override("font", font)
	_title_label.add_theme_font_size_override("font_size", BrowserBridge.popup_title_font() - 2)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	_title_label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.01, 0.95))
	_title_label.add_theme_constant_override("outline_size", 10)

	# Wallet Balance Bar
	var balance_bar := PanelContainer.new()
	main_box.add_child(balance_bar)
	balance_bar.add_theme_stylebox_override("panel", _balance_bar_style())

	var b_margin := MarginContainer.new()
	balance_bar.add_child(b_margin)
	b_margin.add_theme_constant_override("margin_left", 16)
	b_margin.add_theme_constant_override("margin_right", 16)
	b_margin.add_theme_constant_override("margin_top", 8)
	b_margin.add_theme_constant_override("margin_bottom", 8)

	var b_hbox := HBoxContainer.new()
	b_margin.add_child(b_hbox)
	b_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	b_hbox.add_theme_constant_override("separation", 10)

	_coins_sign = HudSign.create_sign(HudSign.SignType.COIN, "Coins: 0")
	b_hbox.add_child(_coins_sign)
	_coins_sign.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var balance_subtext := Label.new()
	b_hbox.add_child(balance_subtext)
	balance_subtext.text = "YOUR BALANCE"
	if font:
		balance_subtext.add_theme_font_override("font", font)
	balance_subtext.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font() - 6)
	balance_subtext.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))

	# Catalog Section Label
	var section_lbl := Label.new()
	main_box.add_child(section_lbl)
	section_lbl.text = "AVAILABLE UPGRADES & POWER-UPS"
	if font:
		section_lbl.add_theme_font_override("font", font)
	section_lbl.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font() - 6)
	section_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
	section_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Scroll Container for Item Cards
	var scroll := ScrollContainer.new()
	main_box.add_child(scroll)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_items_container = VBoxContainer.new()
	scroll.add_child(_items_container)
	_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_container.add_theme_constant_override("separation", 10)

	# Close Button
	_close_btn = Button.new()
	main_box.add_child(_close_btn)
	_close_btn.custom_minimum_size = Vector2(0, BrowserBridge.popup_button_height())
	_close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close_btn.text = "CLOSE"
	if font:
		_close_btn.add_theme_font_override("font", font)
	_close_btn.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font())
	_close_btn.add_theme_stylebox_override("normal", _pill_btn(Color(0.2, 0.55, 0.85)))
	_close_btn.pressed.connect(close)


func _populate_items() -> void:
	for child in _items_container.get_children():
		child.queue_free()

	for item in _powerup_items:
		var card := _build_item_card(item)
		_items_container.add_child(card)


func _build_item_card(item: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_style())

	var cm := MarginContainer.new()
	card.add_child(cm)
	cm.add_theme_constant_override("margin_left", 14)
	cm.add_theme_constant_override("margin_right", 14)
	cm.add_theme_constant_override("margin_top", 10)
	cm.add_theme_constant_override("margin_bottom", 10)

	var hbox := HBoxContainer.new()
	cm.add_child(hbox)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)

	# Item Icon
	var icon_slot := Control.new()
	icon_slot.custom_minimum_size = Vector2(44, 44)
	hbox.add_child(icon_slot)

	var icon_rect := TextureRect.new()
	icon_rect.size = Vector2(44, 44)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path := str(item.get("icon_path", "res://assets/ui/hud_coin.png"))
	if ResourceLoader.exists(icon_path):
		icon_rect.texture = load(icon_path)
	icon_slot.add_child(icon_rect)

	# Item Info (Title + Description)
	var info_box := VBoxContainer.new()
	hbox.add_child(info_box)
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.alignment = BoxContainer.ALIGNMENT_CENTER
	info_box.add_theme_constant_override("separation", 2)

	var name_lbl := Label.new()
	info_box.add_child(name_lbl)
	name_lbl.text = str(item.get("name", "Power-up"))
	var font = HudSign.get_hud_font()
	if font:
		name_lbl.add_theme_font_override("font", font)
	name_lbl.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font() - 2)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))

	var desc_lbl := Label.new()
	info_box.add_child(desc_lbl)
	desc_lbl.text = str(item.get("desc", ""))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font() - 6)
	desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82))

	# Action / Price / Status
	var action_box := VBoxContainer.new()
	hbox.add_child(action_box)
	action_box.alignment = BoxContainer.ALIGNMENT_CENTER
	action_box.add_theme_constant_override("separation", 4)

	var price: int = int(item.get("price", 5000))
	var item_id := str(item.get("id", ""))
	var owned_cnt: int = AuthSession.get_powerup_count(item_id)

	var owned_lbl := Label.new()
	action_box.add_child(owned_lbl)
	owned_lbl.text = "OWNED: %d" % owned_cnt
	if font:
		owned_lbl.add_theme_font_override("font", font)
	owned_lbl.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font() - 6)
	owned_lbl.add_theme_color_override("font_color", Color(0.35, 0.9, 0.6) if owned_cnt > 0 else Color(0.6, 0.65, 0.75))
	owned_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var price_lbl := Label.new()
	action_box.add_child(price_lbl)
	price_lbl.text = "%d 🪙" % price
	if font:
		price_lbl.add_theme_font_override("font", font)
	price_lbl.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font() - 4)
	price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var is_available: bool = bool(item.get("available", false))
	if is_available:
		var buy_btn := Button.new()
		action_box.add_child(buy_btn)
		buy_btn.custom_minimum_size = Vector2(100, 36)
		buy_btn.text = "BUY"
		if font:
			buy_btn.add_theme_font_override("font", font)
		buy_btn.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font() - 4)
		var can_afford: bool = AuthSession.total_coins >= price
		buy_btn.add_theme_stylebox_override("normal", _pill_btn(Color(0.2, 0.7, 0.35) if can_afford else Color(0.25, 0.3, 0.4)))
		buy_btn.pressed.connect(func(): _on_buy_pressed(item_id, price))
	else:
		var badge := Label.new()
		action_box.add_child(badge)
		badge.text = str(item.get("badge", "SOON"))
		if font:
			badge.add_theme_font_override("font", font)
		badge.add_theme_font_size_override("font_size", BrowserBridge.popup_body_font() - 6)
		badge.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	return card


func buy_item(item_id: String) -> bool:
	for item in _powerup_items:
		if item.get("id") == item_id:
			var price: int = int(item.get("price", 0))
			if AuthSession.spend_coins(price):
				AuthSession.add_powerup(item_id, 1)
				item_purchased.emit(item_id)
				_refresh_coins_display()
				_populate_items()
				return true
			else:
				if _coins_sign:
					_coins_sign.bounce(1.4)
				return false
	return false


func _on_buy_pressed(item_id: String, _price: int) -> void:
	buy_item(item_id)


func _on_inventory_changed() -> void:
	if is_inside_tree() and visible:
		_populate_items()


func _on_coins_changed(_new_total: int) -> void:
	_refresh_coins_display()


func _on_profile_updated(_body: Dictionary) -> void:
	_refresh_coins_display()


func _refresh_coins_display() -> void:
	if _coins_sign:
		_coins_sign.set_text("%d" % AuthSession.total_coins)
		_coins_sign.bounce(1.15)


func set_powerups(items: Array[Dictionary]) -> void:
	_powerup_items = items.duplicate(true)
	if is_inside_tree() and visible:
		_populate_items()


func add_powerup(item: Dictionary) -> void:
	_powerup_items.append(item)
	if is_inside_tree() and visible:
		_populate_items()


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.12, 0.95)
	sb.set_corner_radius_all(20)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 0.78, 0.2, 0.85) # Glowing gold rim
	sb.shadow_size = 18
	sb.shadow_color = Color(1.0, 0.7, 0.1, 0.25)
	sb.shadow_offset = Vector2(0, 6)
	return sb


func _balance_bar_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.12, 0.2, 0.85)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.25, 0.45, 0.75, 0.6)
	return sb


func _card_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.15, 0.8)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.2, 0.28, 0.42, 0.6)
	return sb


func _pill_btn(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb
