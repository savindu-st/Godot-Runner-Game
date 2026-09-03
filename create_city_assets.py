import os

os.makedirs('models/city', exist_ok=True)

def write_scene(filename, content):
    with open(f'models/city/{filename}', 'w') as f:
        f.write(content.strip() + '\n')

# 1. Tall building
write_scene('building1.tscn', """
[gd_scene format=3]

[sub_resource type="StandardMaterial3D" id="1"]
albedo_color = Color(0.25, 0.25, 0.28, 1)
roughness = 0.9

[sub_resource type="BoxMesh" id="2"]
size = Vector3(4, 16, 4)

[node name="Building1" type="Node3D"]

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 8, 0)
mesh = SubResource("2")
surface_material_override/0 = SubResource("1")
""")

# 2. Wide building
write_scene('building2.tscn', """
[gd_scene format=3]

[sub_resource type="StandardMaterial3D" id="1"]
albedo_color = Color(0.35, 0.3, 0.25, 1)
roughness = 0.9

[sub_resource type="BoxMesh" id="2"]
size = Vector3(6, 10, 5)

[node name="Building2" type="Node3D"]

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 5, 0)
mesh = SubResource("2")
surface_material_override/0 = SubResource("1")
""")

# 3. Small shop
write_scene('building3.tscn', """
[gd_scene format=3]

[sub_resource type="StandardMaterial3D" id="1"]
albedo_color = Color(0.4, 0.2, 0.2, 1)
roughness = 0.9

[sub_resource type="BoxMesh" id="2"]
size = Vector3(5, 6, 4)

[node name="Building3" type="Node3D"]

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 3, 0)
mesh = SubResource("2")
surface_material_override/0 = SubResource("1")
""")

# 4. Streetlamp
write_scene('streetlamp.tscn', """
[gd_scene format=3]

[sub_resource type="StandardMaterial3D" id="1"]
albedo_color = Color(0.1, 0.1, 0.1, 1)
metallic = 0.8
roughness = 0.4

[sub_resource type="CylinderMesh" id="2"]
top_radius = 0.05
bottom_radius = 0.1
height = 4.0

[sub_resource type="StandardMaterial3D" id="3"]
albedo_color = Color(1, 0.9, 0.6, 1)
emission_enabled = true
emission = Color(1, 0.9, 0.6, 1)
emission_energy_multiplier = 2.0

[sub_resource type="SphereMesh" id="4"]
radius = 0.3
height = 0.6

[node name="Streetlamp" type="Node3D"]

[node name="Pole" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 2, 0)
mesh = SubResource("2")
surface_material_override/0 = SubResource("1")

[node name="Bulb" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 4, 0)
mesh = SubResource("4")
surface_material_override/0 = SubResource("3")
""")

# 5. Barrier fence
write_scene('barrier_fence.tscn', """
[gd_scene format=3]

[sub_resource type="StandardMaterial3D" id="1"]
albedo_color = Color(0.6, 0.6, 0.6, 1)
metallic = 0.7
roughness = 0.3

[sub_resource type="BoxMesh" id="2"]
size = Vector3(1.5, 0.1, 0.1)

[sub_resource type="CylinderMesh" id="3"]
top_radius = 0.05
bottom_radius = 0.05
height = 0.8

[node name="BarrierFence" type="Node3D"]

[node name="Rail" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.6, 0)
mesh = SubResource("2")
surface_material_override/0 = SubResource("1")

[node name="Post1" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.6, 0.4, 0)
mesh = SubResource("3")
surface_material_override/0 = SubResource("1")

[node name="Post2" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.6, 0.4, 0)
mesh = SubResource("3")
surface_material_override/0 = SubResource("1")
""")

# 6. Trash can
write_scene('trash_can.tscn', """
[gd_scene format=3]

[sub_resource type="StandardMaterial3D" id="1"]
albedo_color = Color(0.2, 0.2, 0.2, 1)
roughness = 0.8

[sub_resource type="CylinderMesh" id="2"]
top_radius = 0.3
bottom_radius = 0.25
height = 0.8

[node name="TrashCan" type="Node3D"]

[node name="Body" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.4, 0)
mesh = SubResource("2")
surface_material_override/0 = SubResource("1")
""")

# 7. Fire hydrant
write_scene('fire_hydrant.tscn', """
[gd_scene format=3]

[sub_resource type="StandardMaterial3D" id="1"]
albedo_color = Color(0.8, 0.1, 0.1, 1)
roughness = 0.6
metallic = 0.3

[sub_resource type="CylinderMesh" id="2"]
top_radius = 0.15
bottom_radius = 0.18
height = 0.6

[node name="FireHydrant" type="Node3D"]

[node name="Body" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.3, 0)
mesh = SubResource("2")
surface_material_override/0 = SubResource("1")
""")

# 8. Jersey barrier
write_scene('jersey_barrier.tscn', """
[gd_scene format=3]

[sub_resource type="StandardMaterial3D" id="1"]
albedo_color = Color(0.7, 0.7, 0.7, 1)
roughness = 0.95

[sub_resource type="BoxMesh" id="2"]
size = Vector3(1.2, 0.8, 0.4)

[node name="JerseyBarrier" type="Node3D"]

[node name="Body" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.4, 0)
mesh = SubResource("2")
surface_material_override/0 = SubResource("1")
""")



print("Successfully created city models.")
