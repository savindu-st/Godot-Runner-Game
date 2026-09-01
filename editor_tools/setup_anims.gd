extends SceneTree

func _init():
	var scene_path = "res://models/Leonard/character.tscn"
	var packed_scene = load(scene_path)
	if not packed_scene:
		print("Could not load scene")
		quit(1)
		return
	
	var scene = packed_scene.instantiate()
	
	# Find the AnimationPlayer (Godot usually names it AnimationPlayer)
	var anim_player = scene.get_node_or_null("AnimationPlayer")
	if not anim_player:
		anim_player = scene.find_child("AnimationPlayer", true, false)
	
	if not anim_player:
		print("No AnimationPlayer found in the scene")
		quit(1)
		return
		
	var library = anim_player.get_animation_library("")
	if not library:
		library = AnimationLibrary.new()
		anim_player.add_animation_library("", library)
	
	var anims = {
		"run": "res://models/Leonard/running.res",
		"jump": "res://models/Leonard/jump.res",
		"slide": "res://models/Leonard/slide.res"
	}
	
	for name in anims:
		var anim = load(anims[name])
		if anim and anim is Animation:
			if library.has_animation(name):
				library.remove_animation(name)
			library.add_animation(name, anim)
			print("Added " + name + " animation")
			
	# Also extract Fall Over.fbx automatically for death
	var fall_scene = load("res://models/Leonard/Fall Over.fbx")
	if fall_scene:
		var fall_inst = fall_scene.instantiate()
		var fall_ap = fall_inst.find_child("AnimationPlayer", true, false)
		if fall_ap:
			# Get the default library from FBX (usually has empty name or 'mixamo.com' or similar)
			var lib_list = fall_ap.get_animation_library_list()
			for lib_name in lib_list:
				var fall_lib = fall_ap.get_animation_library(lib_name)
				var anim_list = fall_lib.get_animation_list()
				for a_name in anim_list:
					var fall_anim = fall_lib.get_animation(a_name)
					# Mixamo animations usually have 'mixamo' in the name or are the only animation
					if library.has_animation("death"):
						library.remove_animation("death")
					library.add_animation("death", fall_anim)
					print("Added death animation directly from FBX!")
					break
				
	var packed = PackedScene.new()
	packed.pack(scene)
	ResourceSaver.save(packed, scene_path)
	print("Successfully packed and saved character.tscn with animations!")
	quit(0)
