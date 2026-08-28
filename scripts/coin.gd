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
