extends SceneTree

func _init() -> void:
	var seeds := [1, 42, 12345, 99999, 123456789, 987654321]
	var out_dir := ProjectSettings.globalize_path("res://../run-game-backend-go/testdata/golden")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for s in seeds:
		var entries := SegmentMapGen.generate(s)
		var path := out_dir + "/segment_map_seed_" + str(s) + ".json"
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(entries, "\t"))
		f.close()
		print("wrote ", path, " entries=", entries.size())
	quit()
