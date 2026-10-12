extends SceneTree
func _init():
	var ps: PackedScene = load("res://assets/chars/tesu.glb")
	var n: Node = ps.instantiate()
	var sk: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
	print("SKEL ", sk.name, " bones ", sk.get_bone_count(), " first ", sk.get_bone_name(0), " ", sk.get_bone_name(5))
	var ap: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
	print("ANIMS ", ap.get_animation_list())
	var aabb := AABB()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		print("MESH ", mi.name, " ", mi.get_aabb())
	print("ROOT xform ", n.get_child(0).name, " ", (n.get_child(0) as Node3D).transform)
	quit()
