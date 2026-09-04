extends SceneTree

func _init():
	var file = FileAccess.open("res://glb_dump.txt", FileAccess.WRITE)
	var paths = ["res://assets/solo_billboard.glb", "res://assets/billboard.glb"]
	for path in paths:
		file.store_line("=== " + path + " ===")
		var packed = ResourceLoader.load(path)
		var root = packed.instantiate()
		file.store_line("Root: " + root.name + " transform=" + str(root.transform))
		var queue = [root]
		while queue.size() > 0:
			var curr = queue.pop_front()
			if curr is MeshInstance3D:
				file.store_line("Mesh: " + curr.name)
				file.store_line("  Transform: " + str(curr.transform))
				file.store_line("  Global Transform: " + str(curr.global_transform))
				var aabb = curr.get_aabb()
				file.store_line("  AABB: " + str(aabb))
			for c in curr.get_children():
				queue.append(c)
	file.close()
	quit()
