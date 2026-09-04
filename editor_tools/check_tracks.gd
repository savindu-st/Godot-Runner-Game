extends SceneTree

func _init():
	var lib = load("res://models/Leonard/leonard_anims.tres")
	var anim = lib.get_animation("run")
	var pos_tracks = 0
	for i in range(anim.get_track_count()):
		if anim.track_get_type(i) == 1: # TYPE_POSITION_3D
			pos_tracks += 1
			print("Pos track: ", anim.track_get_path(i))
	print("Total position tracks: ", pos_tracks)
	quit()
