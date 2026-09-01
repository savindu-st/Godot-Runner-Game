extends SceneTree

func _init():
	var leo = load("res://models/Leonard/character.fbx")
	var leo_inst = leo.instantiate()
	var leo_skel = leo_inst.find_child("Skeleton3D", true, false)
	print("--- Leonard Bones ---")
	if leo_skel:
		for i in min(5, leo_skel.get_bone_count()):
			print(leo_skel.get_bone_name(i))
			
	var remy = load("res://models/Remy/character (1).fbx")
	var remy_inst = remy.instantiate()
	var remy_skel = remy_inst.find_child("Skeleton3D", true, false)
	print("--- Remy Bones ---")
	if remy_skel:
		for i in min(5, remy_skel.get_bone_count()):
			print(remy_skel.get_bone_name(i))
			
	quit()
