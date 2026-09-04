extends MeshInstance3D

var timer: Timer = Timer.new()

func _ready():
	scale = Vector3(0.7, 0.7, 0.7)
	timer.wait_time = 5
	timer.autostart = true
# warning-ignore:return_value_discarded
	timer.connect("timeout", Callable(self, "timer_timeout"))
	add_child(timer)
	add_to_group("coins")

func _process(delta):
	if _collected:
		return
	var level := get_tree().get_first_node_in_group("level")
	if level and level.has_method("is_world_active") and not level.is_world_active():
		return
	var speed: float = SimConstants.SCROLL_SPEED
	if level and level.has_method("get_scroll_speed"):
		speed = level.get_scroll_speed()
	global_translate(Vector3(0, 0, speed * delta))
	rotate_y(5 * delta)
	
func timer_timeout():
	queue_free()

var _collected: bool = false
func collect():
	if _collected:
		return
	_collected = true
	var t = create_tween().set_parallel(true)
	# Go up and right
	t.tween_property(self, "position:y", position.y + 1.5, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position:x", position.x + 4.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# Spin fast
	t.tween_property(self, "rotation:y", rotation.y + PI * 2, 0.4).set_trans(Tween.TRANS_LINEAR)
	# Pop scale up slightly
	t.tween_property(self, "scale", Vector3(1.1, 1.1, 1.1), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Shrink to near 0
	t.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.3).set_delay(0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	if material_override:
		t.tween_property(material_override, "albedo_color:a", 0.0, 0.3).set_delay(0.1)
	
	t.chain().tween_callback(queue_free)
