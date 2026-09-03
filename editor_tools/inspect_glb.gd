extends SceneTree

func _init():
    var path = "res://assets/lowpoly_cars_pickup_sedan_police_stationwagon.glb"
    var packed_scene = load(path)
    if not packed_scene:
        print("Failed to load GLB")
        quit()
        return

    var root = packed_scene.instantiate()
    print("Root: ", root.name)
    _print_tree(root, "")
    
    quit()

func _print_tree(node: Node, indent: String):
    print(indent, node.name, " (", node.get_class(), ")")
    if node is AnimationPlayer:
        var ap = node as AnimationPlayer
        print(indent, "  Animations: ", ap.get_animation_list())
    for child in node.get_children():
        _print_tree(child, indent + "  ")
