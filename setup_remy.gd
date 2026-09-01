extends SceneTree

func _init():
	var fbx_scene = load("res://models/Remy/character (1).fbx")
	if not fbx_scene:
		print("Failed to load FBX")
		quit()
		return
		
	var inst = fbx_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	inst.name = "character"
	
	var anim_player = inst.get_node_or_null("AnimationPlayer")
	if not anim_player:
		anim_player = inst.find_child("AnimationPlayer", true, false)
		
	if anim_player:
		var lib = load("res://models/Leonard/leonard_anims.tres")
		anim_player.add_animation_library("leonard_anims", lib)
	
	var packed = PackedScene.new()
	packed.pack(inst)
	ResourceSaver.save(packed, "res://models/Remy/character.tscn")
	print("Remy created successfully")
	quit()
