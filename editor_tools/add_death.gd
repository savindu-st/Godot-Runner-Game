@tool
extends EditorScript

func _run():
	print("Starting automated death animation extraction...")
	
	# 1. Load the imported FBX scene
	var fall_scene = load("res://models/Leonard/Fall Over.fbx")
	if not fall_scene:
		print("Error: Could not load Fall Over.fbx")
		return
		
	var fall_inst = fall_scene.instantiate()
	var fall_ap = fall_inst.find_child("AnimationPlayer", true, false)
	if not fall_ap:
		print("Error: No AnimationPlayer found in Fall Over.fbx")
		return
		
	# 2. Extract the animation from the FBX
	var fall_anim = null
	for lib_name in fall_ap.get_animation_library_list():
		var lib = fall_ap.get_animation_library(lib_name)
		var anim_list = lib.get_animation_list()
		if anim_list.size() > 0:
			fall_anim = lib.get_animation(anim_list[0]).duplicate()
			break
			
	if not fall_anim:
		print("Error: No animation found in Fall Over.fbx")
		return
		
	# 3. Save it as death.res
	var res_path = "res://models/Leonard/death.res"
	ResourceSaver.save(fall_anim, res_path)
	print("Extracted and saved death.res!")
	
	# 4. Add it to the leonard_anims.tres library
	var tres_path = "res://models/Leonard/leonard_anims.tres"
	var anims_lib = load(tres_path) as AnimationLibrary
	if anims_lib:
		var anim_res = load(res_path)
		if anims_lib.has_animation("death"):
			anims_lib.remove_animation("death")
		anims_lib.add_animation("death", anim_res)
		ResourceSaver.save(anims_lib, tres_path)
		print("Success! The death animation has been added to leonard_anims.tres and is ready to use!")
	else:
		print("Error: Could not load leonard_anims.tres")
