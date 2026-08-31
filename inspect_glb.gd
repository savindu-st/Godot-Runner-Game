extends SceneTree

func _init():
	var scene = preload("res://models/anime-girl/anime-girl.glb").instantiate()
	_print_tree(scene, "")
	quit()

func _print_tree(node, indent):
	var msg = indent + node.name + " (" + node.get_class() + ")"
	if node is MeshInstance3D:
		var mi = node as MeshInstance3D
		if mi.mesh:
			msg += " mesh=" + str(mi.mesh.get_class())
			for i in range(mi.mesh.get_surface_count()):
				var mat = mi.mesh.surface_get_material(i)
				if mat:
					msg += " mat["+str(i)+"]="+str(mat.get_class())
				else:
					msg += " mat["+str(i)+"]=null"
	print(msg)
	for child in node.get_children():
		_print_tree(child, indent + "  ")
