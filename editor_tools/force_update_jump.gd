@tool
extends EditorScript

func _run():
	print("Force extracting and fixing jump animation...")
	
	var jump_scene = load("res://models/Leonard/Jump.fbx")
	if not jump_scene:
		print("Error: Could not load Jump.fbx")
		return
		
	var jump_inst = jump_scene.instantiate()
	var jump_ap = jump_inst.find_child("AnimationPlayer", true, false)
	if not jump_ap:
		print("Error: No AnimationPlayer found in Jump.fbx")
		return
		
	var jump_anim = null
	for lib_name in jump_ap.get_animation_library_list():
		var lib = jump_ap.get_animation_library(lib_name)
		var anim_list = lib.get_animation_list()
		if anim_list.size() > 0:
			jump_anim = lib.get_animation(anim_list[0]).duplicate()
			break
			
	if not jump_anim:
		print("Error: No animation found in Jump.fbx")
		return
		
	# --- Fix Root Motion directly on the new animation ---
	var hips_track = -1
	for i in jump_anim.get_track_count():
		var path = str(jump_anim.track_get_path(i))
		if ("Hips" in path or "Root" in path) and jump_anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
			hips_track = i
			break
			
	if hips_track != -1:
		for k in range(jump_anim.track_get_key_count(hips_track)):
			var pos = jump_anim.track_get_key_value(hips_track, k)
			# Zero out X and Z, keep Y
			jump_anim.track_set_key_value(hips_track, k, Vector3(0.0, pos.y, 0.0))
		print("Applied root motion fix (in-place).")
		
	# --- Save and FORCE cache update ---
	var res_path = "res://models/Leonard/jump.res"
	# take_over_path replaces the old cached jump.res in Godot's memory!
	jump_anim.take_over_path(res_path) 
	ResourceSaver.save(jump_anim, res_path)
	
	var tres_path = "res://models/Leonard/leonard_anims.tres"
	var anims_lib = load(tres_path) as AnimationLibrary
	if anims_lib:
		if anims_lib.has_animation("jump"):
			anims_lib.remove_animation("jump")
		# Add the newly created instance directly
		anims_lib.add_animation("jump", jump_anim)
		ResourceSaver.save(anims_lib, tres_path)
		print("Success! Forced leonard_anims.tres to use the actual new jump animation.")
	else:
		print("Error: Could not load leonard_anims.tres")
