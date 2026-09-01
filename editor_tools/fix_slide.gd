@tool
extends EditorScript

func _run():
	var anim_path = "res://models/Leonard/slide.res"
	var anim = load(anim_path) as Animation
	if not anim:
		print("Could not load slide.res")
		return
		
	print("Fixing root motion in slide.res...")
	
	# Find the position track for the Hips bone
	var hips_track = -1
	for i in anim.get_track_count():
		var path = str(anim.track_get_path(i))
		if ("Hips" in path or "Root" in path) and anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
			hips_track = i
			break
			
	if hips_track == -1:
		print("Could not find Hips position track in slide.res")
		return
		
	# Zero out the Z (forward/backward) and X (left/right) movement, keep Y (up/down)
	var key_count = anim.track_get_key_count(hips_track)
	for k in range(key_count):
		var pos = anim.track_get_key_value(hips_track, k)
		# For Mixamo, forward/backward might be Z or Y depending on import, but Godot standardizes to Z
		# We'll lock X and Z, allowing the character to duck down (Y axis)
		var new_pos = Vector3(0.0, pos.y, 0.0)
		anim.track_set_key_value(hips_track, k, new_pos)
		
	ResourceSaver.save(anim, anim_path)
	print("Successfully fixed root motion! slide.res is now in-place.")
