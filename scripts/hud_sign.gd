class_name HudSign
extends PanelContainer

## Subway Surfers style HUD Sign / Badge
## Displays a 3D icon and chunky stylized text inside a glossy capsule.

enum SignType { COIN, BEST, DISTANCE, PLAYER }

const FONT_PATH := "res://assets/fonts/LilitaOne-Regular.ttf"

var sign_type: SignType = SignType.COIN
var icon_rect: TextureRect
var label: Label
var _icon_tween: Tween
var _badge_tween: Tween
var _idle_tween: Tween

var text: String:
	get:
		return label.text if label else ""
	set(val):
		if label:
			label.text = val

static var _cached_font: Font = null


static func get_hud_font() -> Font:
	if _cached_font == null:
		if ResourceLoader.exists(FONT_PATH):
			_cached_font = load(FONT_PATH)
	return _cached_font


static func create_sign(type: SignType, initial_text: String = "") -> HudSign:
	var sign_node := HudSign.new()
	sign_node.sign_type = type
	sign_node._build_ui(initial_text)
	return sign_node


func _build_ui(initial_text: String) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 42)
	
	# Determine theme colors and icon based on type
	var border_color: Color
	var font_color: Color
	var glow_color: Color
	var icon_path: String
	var icon_size: Vector2 = Vector2(34, 34)
	
	match sign_type:
		SignType.COIN:
			border_color = Color(1.0, 0.82, 0.22, 0.95)     # Bright gold rim
			font_color = Color(1.0, 0.92, 0.35)               # Rich gold font
			glow_color = Color(1.0, 0.75, 0.1, 0.35)
			icon_path = "res://assets/ui/hud_coin.png"
			icon_size = Vector2(36, 36)
		SignType.BEST:
			border_color = Color(1.0, 0.68, 0.16, 0.95)     # Amber gold rim
			font_color = Color(1.0, 0.84, 0.32)               # Neon amber font
			glow_color = Color(1.0, 0.6, 0.1, 0.3)
			icon_path = "res://assets/ui/hud_crown.png"
			icon_size = Vector2(34, 34)
		SignType.DISTANCE:
			border_color = Color(0.25, 0.95, 0.6, 0.95)     # Mint green rim
			font_color = Color(0.35, 1.0, 0.65)              # Bright emerald font
			glow_color = Color(0.2, 0.9, 0.5, 0.3)
			icon_path = "res://assets/ui/hud_shoe.png"
			icon_size = Vector2(34, 34)
		SignType.PLAYER:
			border_color = Color(0.25, 0.82, 1.0, 0.92)     # Electric cyan rim
			font_color = Color(0.85, 0.95, 1.0)              # Ice white-cyan font
			glow_color = Color(0.2, 0.75, 1.0, 0.28)
			icon_path = "res://assets/ui/hud_avatar.png"
			icon_size = Vector2(32, 32)

	# Capsule stylebox
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.12, 0.84) # Frosted dark glass
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(2)
	sb.border_color = border_color
	sb.shadow_size = 8
	sb.shadow_color = glow_color
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 10
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	add_theme_stylebox_override("panel", sb)

	# Layout container
	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(hbox)

	# Icon container & TextureRect
	var icon_slot := Control.new()
	icon_slot.custom_minimum_size = icon_size
	icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_slot)

	icon_rect = TextureRect.new()
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.size = icon_size
	icon_rect.position = Vector2.ZERO
	icon_rect.pivot_offset = icon_size / 2.0
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(icon_path):
		icon_rect.texture = load(icon_path)
	icon_slot.add_child(icon_rect)

	# Text label
	label = Label.new()
	label.name = "Text"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.clip_text = false
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	
	var font := get_hud_font()
	if font:
		label.add_theme_font_override("font", font)
	
	var font_sz := 24
	if sign_type == SignType.COIN or sign_type == SignType.BEST:
		font_sz = 26
	elif sign_type == SignType.DISTANCE:
		font_sz = 24
	elif sign_type == SignType.PLAYER:
		font_sz = 22
	label.add_theme_font_size_override("font_size", font_sz)
	
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01, 0.95))
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 4)
	
	label.text = initial_text
	hbox.add_child(label)


func set_text(new_text: String) -> void:
	if label:
		label.text = new_text


func get_text() -> String:
	return label.text if label else ""


## Positions the sign so its right edge touches right_x
func align_right(right_x: float, top_y: float) -> void:
	var w: float = maxf(get_combined_minimum_size().x, 90.0)
	var h: float = maxf(get_combined_minimum_size().y, 42.0)
	size = Vector2(w, h)
	position = Vector2(right_x - w, top_y)
	pivot_offset = size / 2.0


## Positions the sign so its left edge touches left_x
func align_left(left_x: float, top_y: float) -> void:
	var w: float = maxf(get_combined_minimum_size().x, 90.0)
	var h: float = maxf(get_combined_minimum_size().y, 42.0)
	size = Vector2(w, h)
	position = Vector2(left_x, top_y)
	pivot_offset = size / 2.0


## Subway Surfers squash & stretch bounce animation on pickup
func bounce(punch_scale: float = 1.35) -> void:
	if not is_inside_tree():
		return
	
	# 1. Icon squash & stretch wobble
	if icon_rect:
		if _icon_tween and _icon_tween.is_valid():
			_icon_tween.kill()
		_icon_tween = create_tween()
		_icon_tween.set_parallel(false)
		# Squash wide, stretch tall, settle with rotation wobble
		_icon_tween.tween_property(icon_rect, "scale", Vector2(1.35, 0.75), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_icon_tween.parallel().tween_property(icon_rect, "rotation", deg_to_rad(-14.0), 0.07)
		_icon_tween.tween_property(icon_rect, "scale", Vector2(0.85, 1.25), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_icon_tween.parallel().tween_property(icon_rect, "rotation", deg_to_rad(10.0), 0.09)
		_icon_tween.tween_property(icon_rect, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		_icon_tween.parallel().tween_property(icon_rect, "rotation", 0.0, 0.14)

	# 2. Entire badge punch
	if _badge_tween and _badge_tween.is_valid():
		_badge_tween.kill()
	pivot_offset = size / 2.0
	_badge_tween = create_tween()
	_badge_tween.tween_property(self, "scale", Vector2(punch_scale, punch_scale), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_badge_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)


## Celebratory flash effect (e.g. on new high score or distance milestone)
func flash_celebrate(flash_color: Color = Color(1.3, 1.3, 1.1, 1.0)) -> void:
	if not is_inside_tree():
		return
	var t := create_tween()
	t.tween_property(self, "modulate", flash_color, 0.12).set_trans(Tween.TRANS_QUAD)
	t.tween_property(self, "modulate", Color.WHITE, 0.25).set_trans(Tween.TRANS_QUAD)


## Subtle periodic idle breathing / wobble to give organic liveness
func start_idle_wobble() -> void:
	if not is_inside_tree():
		ready.connect(start_idle_wobble, CONNECT_ONE_SHOT)
		return
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = create_tween()
	_idle_tween.set_loops()
	
	# Gentle idle float
	var base_delay: float = 2.8 if sign_type == SignType.COIN else 4.0
	_idle_tween.tween_interval(base_delay)
	if icon_rect:
		_idle_tween.tween_property(icon_rect, "scale", Vector2(1.18, 1.18), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_idle_tween.parallel().tween_property(icon_rect, "rotation", deg_to_rad(8.0), 0.18)
		_idle_tween.tween_property(icon_rect, "scale", Vector2(1.0, 1.0), 0.26).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		_idle_tween.parallel().tween_property(icon_rect, "rotation", 0.0, 0.26)
