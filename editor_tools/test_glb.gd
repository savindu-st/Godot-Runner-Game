extends SceneTree

func _init():
    var path = "res://assets/solo_billboard.glb"
    var packed = ResourceLoader.load(path)
    var root = packed.instantiate()
    print("Root rotation: ", root.rotation_degrees)
    
    var queue = [root]
    while queue.size() > 0:
        var curr = queue.pop_front()
        if curr is MeshInstance3D:
            print("Mesh: ", curr.name)
            print("  Transform: ", curr.transform)
            print("  Global Transform: ", curr.global_transform)
            var aabb = curr.get_aabb()
            print("  AABB: ", aabb)
        for c in curr.get_children():
            queue.append(c)
    quit()
