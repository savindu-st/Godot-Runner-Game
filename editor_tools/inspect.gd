extends SceneTree

func _init():
	var packed = load("res://assets/buildings.glb")
	if packed:
		var root = packed.instantiate()
		print("Root: ", root.name)
		for child in root.get_children():
			print(" - Child: ", child.name)
	else:
		print("Failed to load")
	quit()
