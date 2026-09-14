@tool
extends SceneTree

func _init():
	print("Starting automated standup animation extraction...")
	
	# 1. Load the imported FBX scene
	var stand_scene = load("res://models/Leonard/Standing Up.fbx")
	if not stand_scene:
		print("Error: Could not load Standing Up.fbx")
		quit(1)
		return
		
	var stand_inst = stand_scene.instantiate()
	var stand_ap = stand_inst.find_child("AnimationPlayer", true, false)
	if not stand_ap:
		print("Error: No AnimationPlayer found in Standing Up.fbx")
		quit(1)
		return
		
	# 2. Extract the animation from the FBX
	var orig_anim: Animation = null
	for lib_name in stand_ap.get_animation_library_list():
		var lib = stand_ap.get_animation_library(lib_name)
		var anim_list = lib.get_animation_list()
		if anim_list.size() > 0:
			orig_anim = lib.get_animation(anim_list[0]).duplicate()
			break
			
	if not orig_anim:
		print("Error: No animation found in Standing Up.fbx")
		quit(1)
		return
		
	# 3. Process animation tracks for Leonard & Remy rig compatibility
	var hips_track = -1
	for i in range(orig_anim.get_track_count()):
		var path = str(orig_anim.track_get_path(i))
		# Ensure tracks use mixamorig9_ prefix for Leonard (Remy dynamically adapts from this)
		if "mixamorig_" in path and not "mixamorig9_" in path:
			path = path.replace("mixamorig_", "mixamorig9_")
			orig_anim.track_set_path(i, NodePath(path))
		if "Hips" in path and orig_anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
			hips_track = i
			
	if hips_track != -1:
		var key_count = orig_anim.track_get_key_count(hips_track)
		for k in range(key_count):
			var pos = orig_anim.track_get_key_value(hips_track, k)
			# Scale position from Remy units (2.125x) to Leonard units (1.0x)
			var scaled_pos = pos / 2.125
			var t = orig_anim.track_get_key_time(hips_track, k)
			# Smoothly center X and Z towards the end of standing up so running starts dead center
			if t >= 3.5:
				var alpha = clampf((t - 3.5) / 1.5, 0.0, 1.0)
				scaled_pos.x = lerpf(scaled_pos.x, 0.0, alpha)
				scaled_pos.z = lerpf(scaled_pos.z, 0.0, alpha)
			orig_anim.track_set_key_value(hips_track, k, scaled_pos)
			
	orig_anim.loop_mode = Animation.LOOP_NONE
	
	# 4. Save as standup.res
	var res_path = "res://models/Leonard/standup.res"
	var err = ResourceSaver.save(orig_anim, res_path)
	if err != OK:
		print("Error saving standup.res: ", err)
		quit(1)
		return
	print("Extracted and saved standup.res!")
	
	# 5. Add it to the leonard_anims.tres library
	var tres_path = "res://models/Leonard/leonard_anims.tres"
	var anims_lib = load(tres_path) as AnimationLibrary
	if anims_lib:
		var anim_res = load(res_path)
		if anims_lib.has_animation("standup"):
			anims_lib.remove_animation("standup")
		anims_lib.add_animation("standup", anim_res)
		var save_err = ResourceSaver.save(anims_lib, tres_path)
		if save_err != OK:
			print("Error saving leonard_anims.tres: ", save_err)
			quit(1)
			return
		print("Success! standup animation added to leonard_anims.tres and saved.")
	else:
		print("Error: Could not load leonard_anims.tres")
		quit(1)
		return
		
	quit(0)
