@tool
extends EditorScript

func _run():
	print("Starting automated jump animation extraction...")
	
	# 1. Load the imported FBX scene
	var jump_scene = load("res://models/Leonard/Jump.fbx")
	if not jump_scene:
		print("Error: Could not load Jump.fbx")
		return
		
	var jump_inst = jump_scene.instantiate()
	var jump_ap = jump_inst.find_child("AnimationPlayer", true, false)
	if not jump_ap:
		print("Error: No AnimationPlayer found in Jump.fbx")
		return
		
	# 2. Extract the animation from the FBX
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
		
	# 3. Save it as jump.res (this will overwrite the old jump animation)
	var res_path = "res://models/Leonard/jump.res"
	ResourceSaver.save(jump_anim, res_path)
	print("Extracted and saved new jump.res!")
	
	# 4. Update leonard_anims.tres to use the new animation
	var tres_path = "res://models/Leonard/leonard_anims.tres"
	var anims_lib = load(tres_path) as AnimationLibrary
	if anims_lib:
		var anim_res = load(res_path)
		if anims_lib.has_animation("jump"):
			anims_lib.remove_animation("jump")
		anims_lib.add_animation("jump", anim_res)
		ResourceSaver.save(anims_lib, tres_path)
		print("Success! The new jump animation has been added to leonard_anims.tres and is ready to use!")
	else:
		print("Error: Could not load leonard_anims.tres")
