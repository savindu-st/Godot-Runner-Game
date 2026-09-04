extends SceneTree

func _init():
	var remy = load("res://models/Remy/character (1).fbx")
	var inst = remy.instantiate()
	var aabb = AABB()
	var first = true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh:
			var maabb = mi.mesh.get_aabb()
			if first:
				aabb = maabb
				first = false
			else:
				aabb = aabb.merge(maabb)
	print("Remy AABB Position: ", aabb.position)
	print("Remy AABB Size: ", aabb.size)
	
	var leo = load("res://models/Leonard/character.fbx")
	var linst = leo.instantiate()
	var laabb = AABB()
	var lfirst = true
	for mi in linst.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh:
			var maabb = mi.mesh.get_aabb()
			if lfirst:
				laabb = maabb
				lfirst = false
			else:
				laabb = laabb.merge(maabb)
	print("Leo AABB Position: ", laabb.position)
	print("Leo AABB Size: ", laabb.size)
	quit()
