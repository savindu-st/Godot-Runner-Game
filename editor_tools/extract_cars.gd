@tool
extends EditorScript

func _run():
	print("Starting extraction...")
	var path = "res://assets/lowpoly_cars_pickup_sedan_police_stationwagon.glb"
	var packed_scene = load(path) as PackedScene
	if not packed_scene:
		print("Failed to load GLB file. Make sure Godot has imported it.")
		return

	var root = packed_scene.instantiate()
	
	var out_dir = "res://models/city/"
	var d = DirAccess.open(out_dir)
	if not d:
		DirAccess.make_dir_absolute(out_dir)
		
	var extracted_paths = []

	for child in root.get_children():
		var car_name = child.name.to_lower().replace(" ", "_")
		var out_path = out_dir + "car_" + car_name + ".tscn"
		
		# Create a new Node3D root for the car
		var new_root = Node3D.new()
		new_root.name = "Car_" + child.name.replace(" ", "")
		
		# Duplicate the car mesh and add it to the new root
		var car_dup = child.duplicate()
		car_dup.transform = Transform3D() # Reset transform
		new_root.add_child(car_dup)
		car_dup.owner = new_root
		
		# Ensure all children of the car (like wheels) also get their owner set
		_set_owner_recursive(car_dup, new_root)
		
		# Save as PackedScene
		var new_scene = PackedScene.new()
		new_scene.pack(new_root)
		var err = ResourceSaver.save(new_scene, out_path)
		if err == OK:
			print("Extracted: ", out_path)
			extracted_paths.append(out_path)
		else:
			print("Failed to save: ", out_path, " Error code: ", err)
			
		new_root.free()

	root.free()
	
	print("\nExtracted Paths:")
	for p in extracted_paths:
		print(p)
		
func _set_owner_recursive(node: Node, owner_node: Node):
	for c in node.get_children():
		c.owner = owner_node
		_set_owner_recursive(c, owner_node)
