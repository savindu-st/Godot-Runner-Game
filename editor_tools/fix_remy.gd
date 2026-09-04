extends SceneTree

func _init():
	var leo_lib = load("res://models/Leonard/leonard_anims.tres") as AnimationLibrary
	var remy_lib = AnimationLibrary.new()
	
	for anim_name in leo_lib.get_animation_list():
		var old_anim = leo_lib.get_animation(anim_name)
		var new_anim = old_anim.duplicate()
		for i in range(new_anim.get_track_count()):
			var path = new_anim.track_get_path(i)
			var path_str = String(path)
			if "mixamorig9_" in path_str:
				path_str = path_str.replace("mixamorig9_", "mixamorig_")
				new_anim.track_set_path(i, NodePath(path_str))
		remy_lib.add_animation(anim_name, new_anim)
		
	ResourceSaver.save(remy_lib, "res://models/Remy/remy_anims.tres")
	print("Saved remy_anims.tres")
	
	var remy_scene = load("res://models/Remy/character.tscn")
	var inst = remy_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	
	# Scale the character node to normal human size (assuming Mixamo 100x scale)
	inst.scale = Vector3(0.01, 0.01, 0.01)
	
	var ap = inst.find_child("AnimationPlayer", true, false)
	if ap:
		# Remove old library and add the new one
		for lib_name in ap.get_animation_library_list():
			ap.remove_animation_library(lib_name)
		
		var new_lib = load("res://models/Remy/remy_anims.tres")
		ap.add_animation_library("", new_lib)
		print("Replaced AnimationLibrary")
		
	var packed = PackedScene.new()
	packed.pack(inst)
	ResourceSaver.save(packed, "res://models/Remy/character.tscn")
	print("Saved character.tscn")
	
	quit(0)
